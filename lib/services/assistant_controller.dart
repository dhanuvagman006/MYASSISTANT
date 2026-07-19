import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/chat_message.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import 'region_language.dart';
import 'voice_service.dart';

enum OrbState { idle, listening, thinking, speaking }

/// The assistant's brain, independent of any screen.
///
/// The whole wake → listen → answer → speak loop lives here, so it keeps
/// running when the screen is off or the user is in another tab — the UI
/// merely observes it.
///
/// Wake word engines, best first:
///  1. Porcupine (on-device, ~100 ms, screen-off capable) — used when a
///     PICOVOICE_ACCESS_KEY is provided and assets/wake/hey_hari_android.ppn
///     exists.
///  2. Fallback: Android speech recognizer transcript watching
///     (foreground only, higher latency).
///
/// Screen-off operation additionally requires the microphone foreground
/// service (started/stopped with the wake toggle) and the manifest
/// entries documented in the README.
class AssistantController extends ChangeNotifier {
  AssistantController._();
  static final AssistantController instance = AssistantController._();

  final _voice = VoiceService.instance;
  final _history = <ChatMessage>[];

  OrbState state = OrbState.idle;
  bool micReady = false;
  bool wakeEnabled = true;
  bool onDeviceWake = false; // true when Porcupine is active
  String partial = '';
  String? lastHeard;
  String? lastReply;

  /// Live input loudness 0..1 while recording — drives the orb pulse so
  /// the user can SEE the mic is hearing them.
  double micLevel = 0;

  /// Recognizer language chosen by the user in the picker (persisted).
  /// null = Auto: use the regional language detected from location,
  /// falling back to the device recognizer default.
  String? sttLocaleId;
  String? sttLocaleName;

  /// Regional language resolved from the user's location (Auto mode).
  String? autoLocaleId;
  String? autoLocaleName;

  /// What the recognizer actually uses.
  String? get effectiveLocaleId => sttLocaleId ?? autoLocaleId;

  PorcupineManager? _porcupine;
  bool _initialized = false;

  static const _accessKey = String.fromEnvironment('PICOVOICE_ACCESS_KEY');
  static const _modelAsset = 'assets/wake/hey_hari_android.ppn';

  static const _wakePrefKey = 'wake_word_enabled';
  static const _sttLocalePrefKey = 'stt_locale_id';
  static const _sttLocaleNamePrefKey = 'stt_locale_name';

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Respect the user's saved choice — the mic and the foreground
    // service never start if they switched the wake word off.
    try {
      final prefs = await SharedPreferences.getInstance();
      wakeEnabled = prefs.getBool(_wakePrefKey) ?? true;
      sttLocaleId = prefs.getString(_sttLocalePrefKey);
      sttLocaleName = prefs.getString(_sttLocaleNamePrefKey);
    } catch (_) {}

    micReady = await _voice.init();
    ReminderNotifications.instance.sync(); // permissions + schedules
    await _initPorcupine();
    if (micReady && wakeEnabled) await _startWake();
    notifyListeners();

    // Regional language from location (non-blocking; Auto mode only).
    _detectRegionalLanguage();
  }

  /// Karnataka -> Kannada, Kerala -> Malayalam, etc. Only applies while
  /// the user hasn't picked a language themselves, and only if the
  /// device recognizer actually supports the regional locale.
  ///
  /// ORDER MATTERS: GPS runs FIRST so the location permission dialog
  /// actually appears (previously the IP path usually succeeded and the
  /// app never touched location at all). IP stays as the no-permission
  /// fallback. As a side effect the resolved city is saved to the user's
  /// memory so Hari can personalize ("weather in Mysuru" etc.).
  Future<void> _detectRegionalLanguage() async {
    if (sttLocaleId != null) return; // user's explicit choice wins
    if (autoLocaleId != null) return; // conversation already set a language
    try {
      // 1) Device location (asks permission on first run).
      final wanted = <String>[...await RegionLanguage.candidates()];
      // 2) IP-based via the backend — zero permissions, works everywhere.
      if (wanted.isEmpty) {
        final byIp = await ApiService.fetchRegionLocale();
        if (byIp != null) wanted.add(byIp);
      }
      // Share the fix with the API layer → weather headers on every chat.
      ApiService.geoLat = RegionLanguage.lastLat;
      ApiService.geoLng = RegionLanguage.lastLng;
      _saveCityToMemory(); // fire-and-forget; reuses the same fix/permission
      if (wanted.isEmpty) return;
      final supported = await _voice.sttLocales();
      if (supported.isEmpty) return;

      String norm(String id) => id.toLowerCase().replaceAll('-', '_');
      for (final want in wanted) {
        final w = norm(want);
        // Exact locale, else same language any region.
        for (final exact in [true, false]) {
          for (final l in supported) {
            final id = norm(l.localeId);
            final match = exact
                ? id == w
                : id.split('_').first == w.split('_').first;
            if (match) {
              autoLocaleId = l.localeId;
              autoLocaleName = l.name;
              notifyListeners();
              return;
            }
          }
        }
      }
    } catch (_) {}
  }

  /// Saves the user's current city into their backend memory (at most
  /// once per app session) so replies can be location-aware.
  bool _citySaved = false;
  Future<void> _saveCityToMemory() async {
    if (_citySaved) return;
    _citySaved = true;
    try {
      final city = await RegionLanguage.currentCity();
      ApiService.geoLat = RegionLanguage.lastLat;
      ApiService.geoLng = RegionLanguage.lastLng;
      if (city != null) {
        await ApiService.addMemory('current_city', 'Is currently in $city',
            category: 'context');
      }
    } catch (_) {
      _citySaved = false; // retry next session
    }
  }

  // ---------------- GREETING ON SIGN-IN / APP OPEN ----------------

  bool _greeted = false;
  int? _greetedUserId;

  /// Speaks a personalized hello once per app session. The text comes
  /// from the backend (built from the user's memory); when Hari barely
  /// knows the user it ends with ONE get-to-know-you question — in that
  /// case the mic opens automatically so the answer flows through the
  /// normal /chat loop and the memory extractor learns from it.
  Future<void> greetOnLaunch() async {
    final uid = AuthService.instance.user?.id;
    if (uid != null && uid != _greetedUserId) _greeted = false; // new account
    if (_greeted || !micReady || state != OrbState.idle) return;
    _greeted = true;
    _greetedUserId = uid;

    final greeting = await ApiService.fetchGreeting();
    if (greeting == null || state != OrbState.idle) return;

    await _pauseWake();
    state = OrbState.speaking;
    lastReply = greeting;
    // The greeting is part of the conversation — the AI must remember
    // what it asked when the user's answer arrives.
    _history.add(ChatMessage(role: 'assistant', content: greeting));
    notifyListeners();

    await _voice.speak(greeting);

    state = OrbState.idle;
    notifyListeners();

    if (greeting.contains('?')) {
      // Hari asked something — listen for the answer right away.
      await ask();
    } else {
      await _startWake();
    }
  }

  Future<void> _initPorcupine() async {
    if (_accessKey.isEmpty) return;
    try {
      // Verify the trained model is bundled before handing it to Porcupine.
      await rootBundle.load(_modelAsset);
      _porcupine = await PorcupineManager.fromKeywordPaths(
        _accessKey,
        [_modelAsset],
        (_) => _onWake(),
      );
      onDeviceWake = true;
    } catch (_) {
      _porcupine = null;
      onDeviceWake = false; // fall back to transcript watching
    }
  }

  // ---------------- WAKE MANAGEMENT ----------------

  Future<void> _startWake() async {
    if (!micReady || !wakeEnabled || state != OrbState.idle) return;
    await _startForegroundService();
    if (_porcupine != null) {
      try {
        await _porcupine!.start();
        return;
      } catch (_) {
        onDeviceWake = false;
      }
    }
    await _voice.startWatching(onWake: _onWake);
  }

  Future<void> _pauseWake() async {
    if (_porcupine != null) {
      try {
        await _porcupine!.stop();
      } catch (_) {}
    }
    await _voice.stopWatching();
  }

  Future<void> setWakeEnabled(bool v) async {
    wakeEnabled = v;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_wakePrefKey, v);
    } catch (_) {}
    if (v) {
      await _startWake();
    } else {
      await _pauseWake();
      await _stopForegroundService();
    }
  }

  /// Languages the device recognizer supports, for the picker UI.
  Future<List<stt.LocaleName>> availableLanguages() =>
      _voice.sttLocales();

  Future<void> setSttLocale(String? localeId, String? localeName) async {
    sttLocaleId = localeId;
    sttLocaleName = localeName;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (localeId == null) {
        await prefs.remove(_sttLocalePrefKey);
        await prefs.remove(_sttLocaleNamePrefKey);
      } else {
        await prefs.setString(_sttLocalePrefKey, localeId);
        await prefs.setString(_sttLocaleNamePrefKey, localeName ?? localeId);
      }
    } catch (_) {}
    if (localeId == null) _detectRegionalLanguage();
  }

  void _onWake() {
    HapticFeedback.heavyImpact();
    ApiService.warm(); // wake the network path immediately
    ask();
  }

  // ---------------- THE ANSWER LOOP ----------------

  Future<void> ask() async {
    // A denied-then-granted mic permission used to leave the app stuck on
    // "Microphone unavailable" until restart — retry initialization here.
    if (!micReady) {
      micReady = await _voice.reinit();
      notifyListeners();
      if (!micReady) return;
    }
    if (state != OrbState.idle) return;
    await _pauseWake();
    // Let the wake recognizer fully release the microphone before the
    // recorder grabs it — starting both back-to-back made the mic flap
    // on/off and miss the first words on many devices.
    await Future.delayed(const Duration(milliseconds: 250));

    state = OrbState.listening;
    partial = '';
    notifyListeners();

    final question = await _captureAnyLanguage();

    await _answerOnce(question);

    state = OrbState.idle;
    notifyListeners();
    await _startWake();
  }

  /// Capture path, best first:
  ///  1. CLOUD (Whisper via backend /stt) — record m4a, auto language
  ///     detection: Kannada, Hindi, English, mixed — no locale needed.
  ///  2. Device recognizer with the effective locale, if recording or
  ///     transcription fails (offline, permission, server down).
  Future<String> _captureAnyLanguage() async {
    // 1) Cloud path (preferred).
    if (await _voice.canRecord()) {
      final path = await _voice.recordUntilSilence(
        onLevel: (l) {
          micLevel = l;
          notifyListeners();
        },
      );
      micLevel = 0;
      if (path == null) {
        // User cancelled (orb tap) → genuinely stop.
        if (_voice.lastRecordingCancelled) return '';
        // VAD heard nothing — DON'T give up silently anymore. The old
        // behaviour ("mic turns on and off but nothing happens") ended
        // here; now we hand over to the device recognizer, which has its
        // own tuned endpointing and often hears what the VAD missed.
      } else {
        partial = '…';
        notifyListeners();
        try {
          return await ApiService.transcribe(
            path,
            // Manual pick in "I speak…" = lock transcription to it.
            forceLanguage: _iso(sttLocaleId),
            // Auto + known region = bias detection (Kannada wins over the
            // Hindi misdetection, but English/Hindi speech still works).
            hintLanguage: sttLocaleId == null ? _iso(autoLocaleId) : null,
          );
        } catch (_) {
          // Server unreachable AFTER the user already spoke — ask them to
          // repeat once via the device recognizer instead of going mute.
          partial = '';
          notifyListeners();
        }
      }
    }

    // 2) Device recognizer (recorder unavailable, VAD missed the speech,
    //    or cloud STT failed).
    final q = await _voice.captureQuestion(
      localeId: effectiveLocaleId,
      onPartial: (p) {
        partial = p;
        notifyListeners();
      },
      onLevel: (l) {
        micLevel = l;
        notifyListeners();
      },
    );
    micLevel = 0;
    return q;
  }

  /// 'kn_IN' / 'kn-IN' -> 'kn' (ISO-639-1 for Whisper). null-safe.
  static String? _iso(String? localeId) {
    if (localeId == null || localeId.isEmpty) return null;
    final code = localeId.split(RegExp('[-_]')).first.toLowerCase();
    return code.length == 2 ? code : null;
  }

  /// question -> reply -> speak. Interrupt by tapping the orb.
  Future<void> _answerOnce(String question) async {
    question = question.trim();
    if (question.isEmpty) return;

    state = OrbState.thinking;
    lastHeard = question;
    lastReply = null;
    notifyListeners();

    String reply;
    try {
      _history.add(ChatMessage(role: 'user', content: question));
      // Keep the payload small for latency; backend trims further.
      final window = _history.length > 12
          ? _history.sublist(_history.length - 12)
          : _history;
      reply = await ApiService.sendChat(window);
      _history.add(ChatMessage(role: 'assistant', content: reply));
    } catch (_) {
      reply = "I couldn't reach the assistant. Please check your connection.";
    }

    // FOLLOW THE CONVERSATION'S LANGUAGE: if Hari answered in Kannada,
    // listen in Kannada next time — this is what makes "speak in
    // Kannada" (said in any language) actually switch the whole loop,
    // independent of location. A manual pick still overrides.
    _followReplyLanguage(reply);

    state = OrbState.speaking;
    lastReply = reply;
    partial = '';
    notifyListeners();

    // "Remind me to…" may have just created a reminder server-side —
    // resync so the phone schedules its notification immediately.
    ReminderNotifications.instance.sync();

    await _voice.speak(reply); // tap the orb to stop
  }

  List<stt.LocaleName>? _supportedLocales;

  Future<void> _followReplyLanguage(String reply) async {
    if (sttLocaleId != null) return; // user's explicit choice wins
    try {
      final lang = VoiceService.detectLanguage(reply); // e.g. kn-IN
      _supportedLocales ??= await _voice.sttLocales();
      final supported = _supportedLocales ?? const [];

      String norm(String id) => id.toLowerCase().replaceAll('-', '_');
      final want = norm(lang);
      stt.LocaleName? pick;
      for (final l in supported) {
        final id = norm(l.localeId);
        if (id == want) {
          pick = l;
          break;
        }
        pick ??=
            id.split('_').first == want.split('_').first ? l : pick;
      }
      if (pick != null && pick.localeId != autoLocaleId) {
        autoLocaleId = pick.localeId;
        autoLocaleName = pick.name;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Orb tap behaviour, mirroring the design doc.
  Future<void> tapOrb() async {
    HapticFeedback.mediumImpact();
    switch (state) {
      case OrbState.idle:
        await _pauseWake();
        ask();
      case OrbState.listening:
        await _voice.cancelCapture();
      case OrbState.speaking:
        await _voice.stopSpeaking();
      case OrbState.thinking:
        break;
    }
  }

  /// App lifecycle: with Porcupine + the foreground service the loop runs
  /// with the screen off. The STT fallback releases the mic in background.
  Future<void> onBackground() async {
    if (!onDeviceWake) await _voice.stopWatching();
  }

  Future<void> onForeground() async {
    if (state == OrbState.idle) await _startWake();
  }

  // ---------------- FOREGROUND SERVICE ----------------
  // Keeps the process + microphone alive when the screen turns off.

  Future<void> _startForegroundService() async {
    try {
      if (await FlutterForegroundTask.isRunningService) return;
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'hari_wake',
          channelName: 'Hari wake word',
          channelDescription: 'Listening for "Hey Hari"',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
        ),
        iosNotificationOptions: const IOSNotificationOptions(),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.nothing(),
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );
      await FlutterForegroundTask.requestNotificationPermission();
      await FlutterForegroundTask.startService(
        notificationTitle: 'Hari is listening',
        notificationText: 'Say "Hey Hari" — even with the screen off',
        callback: wakeServiceCallback,
      );
    } catch (_) {
      // Manifest not set up yet — wake word still works in foreground.
    }
  }

  Future<void> _stopForegroundService() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {}
  }
}

/// The service itself does no work — the main isolate runs the loop.
/// Its only job is to hold microphone-grade process priority.
@pragma('vm:entry-point')
void wakeServiceCallback() {
  FlutterForegroundTask.setTaskHandler(_KeepAliveHandler());
}

class _KeepAliveHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}
