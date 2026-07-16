import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';
import 'api_service.dart';
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

  PorcupineManager? _porcupine;
  bool _initialized = false;

  static const _accessKey = String.fromEnvironment('PICOVOICE_ACCESS_KEY');
  static const _modelAsset = 'assets/wake/hey_hari_android.ppn';

  static const _wakePrefKey = 'wake_word_enabled';

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Respect the user's saved choice — the mic and the foreground
    // service never start if they switched the wake word off.
    try {
      final prefs = await SharedPreferences.getInstance();
      wakeEnabled = prefs.getBool(_wakePrefKey) ?? true;
    } catch (_) {}

    micReady = await _voice.init();
    await _initPorcupine();
    if (micReady && wakeEnabled) await _startWake();
    notifyListeners();
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

  void _onWake() {
    HapticFeedback.heavyImpact();
    ApiService.warm(); // wake the network path immediately
    ask();
  }

  // ---------------- THE ANSWER LOOP ----------------

  Future<void> ask() async {
    if (!micReady || state != OrbState.idle) return;
    await _pauseWake();

    state = OrbState.listening;
    partial = '';
    notifyListeners();

    final question = await _voice.captureQuestion(onPartial: (p) {
      partial = p;
      notifyListeners();
    });

    if (question.isEmpty) {
      state = OrbState.idle;
      notifyListeners();
      await _startWake();
      return;
    }

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

    state = OrbState.speaking;
    lastReply = reply;
    notifyListeners();
    await _voice.speak(reply);

    state = OrbState.idle;
    notifyListeners();
    await _startWake();
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
        foregroundTaskOptions: const ForegroundTaskOptions(
          interval: 60000,
          isOnceEvent: false,
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
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {}

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) {}

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {}
}
