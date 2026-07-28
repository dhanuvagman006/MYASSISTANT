import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/chat_message.dart';
import '../models/user_document.dart';
import '../models/vision_result.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'call_service.dart';
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
/// NOTE: the microphone foreground service (screen-off listening) was
/// removed for now — flutter_foreground_task broke AGP 9 builds. Wake
/// word works while the app is open; screen-off returns later.
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

  /// Documents Hari recalled for the LAST spoken answer — the voice screen
  /// shows them as tappable cards while the reply is being spoken, so
  /// "show me the report from my last hospital visit" really pops it up.
  List<UserDocument> lastDocuments = const [];

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

  // ---------------- VOICE-DRIVEN CAMERA (Group B x voice) ----------------

  /// While set, the current conversation is ABOUT this photo: every
  /// follow-up question routes to /vision with the photo re-attached,
  /// so "what's the dosage?" after "help me understand this" just works.
  /// Cleared when the conversation ends, on "close camera", or replaced
  /// by "take another photo".
  List<int>? _visionBytes;
  final List<ChatMessage> _visionThread = [];

  /// Camera words across the languages Hari hears most, script + Latin
  /// (covers "camera open madu", "photo tegi", "कैमरा खोलो"…).
  static final _cameraWord = RegExp(
      r'camera|kamera|ಕ್ಯಾಮ|कैमर|ക്യാമ|கேமர|కెమె|ਕੈਮਰ|ক্যামে',
      caseSensitive: false);
  static final _photoTake = RegExp(
      r'\btake (a |another |one more )?(photo|picture|pic)\b|\bclick (a )?(photo|pic)\b|'
      r'\b(photo|pic|picture|snap)\b\s*\b(tegi|le lo|lo|khinch|eduk|edu)\b|'
      r'ಫೋಟೋ|फोटो (लो|खींच)|ഫോട്ടോ എടു|புகைப்படம்|ఫోటో తీ',
      caseSensitive: false);
  static final _cameraClose = RegExp(
      r'close (the )?camera|stop (the )?camera|forget (the )?(photo|picture)|'
      r'ಕ್ಯಾಮೆರಾ (ಕ್ಲೋಸ್|ಮುಚ್ಚು)|कैमरा बंद|ക്യാമറ അടയ',
      caseSensitive: false);

  static bool wantsCamera(String q) =>
      _cameraWord.hasMatch(q) || _photoTake.hasMatch(q);

  // ------------- VOICE "SAVE THIS RECEIPT" (Group B x voice x memory) ----

  /// Save/remember verbs, script + Latin transliteration
  /// ("save madu", "yaad rakho", "ಸೇವ್ ಮಾಡು", "सेव करो"…).
  static final _saveVerb = RegExp(
      r'\b(save|remember|keep|store|file)\b|save (ma+du|karo)|yaad rakh|'
      r'ಸೇವ್|ನೆನಪ|ಇಟ್ಟುಕೊ|सेव|सहेज|याद रख|സേവ്|ഓർത്ത|சேமி|ஞாபக|సేవ్|గుర్తు',
      caseSensitive: false);

  /// Things people photograph to keep: receipts, bills, prescriptions…
  static final _docNoun = RegExp(
      r'receipt|reciept|bill\b|invoice|prescription|document|report|'
      r'warranty|slip|voucher|statement|ticket|'
      r'ರಸೀದಿ|ಬಿಲ್|ದಾಖಲೆ|रसीद|बिल|पर्च|दस्तावेज|രസീത|ബില്‍|ரசீது|பில்|రసీదు|బిల',
      caseSensitive: false);

  static final _thisPhoto = RegExp(
      r'\b(this|it|that)\b|photo|picture|pic\b|ಇದ|इस|ये|यह|ഇത|இத|ఇద',
      caseSensitive: false);

  /// "Save this receipt" → camera opens, the shot is filed into Hari's
  /// document memory (/docs analyzes it in the background), and the
  /// conversation carries on. If a photo is already on the table
  /// ("what's this?" … "save it") that photo is saved without reopening
  /// the camera. Returns null when [question] wasn't a save request.
  Future<bool?> _maybeHandleSaveDocument(String question) async {
    if (!_saveVerb.hasMatch(question)) return null;
    final photoOnTable =
        _visionBytes != null && _thisPhoto.hasMatch(question);
    // Plain "remember that mom's birthday is in May" is a memory fact for
    // the backend, NOT a document — require a document word (or an active
    // photo being referred to).
    if (!_docNoun.hasMatch(question) && !photoOnTable) return null;

    List<int>? bytes = photoOnTable ? _visionBytes : null;
    if (bytes == null) {
      await _sayLocal('Sure — show it to the camera.');
      final XFile? shot;
      try {
        shot = await ImagePicker().pickImage(
          source: ImageSource.camera,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 82,
        );
      } catch (_) {
        await _sayLocal("I couldn't open the camera.");
        return true;
      }
      if (shot == null) {
        await _sayLocal('Okay, nothing saved.');
        return true; // user backed out; keep talking
      }
      bytes = await shot.readAsBytes();
    }

    state = OrbState.thinking;
    lastHeard = question;
    notifyListeners();
    try {
      // note = the user's own words — recited back on recall, which makes
      // "the receipt I saved after the Apollo visit" findable.
      await ApiService.uploadDocument(
        bytes: bytes,
        filename:
            'voice_save_${DateTime.now().millisecondsSinceEpoch}.jpg',
        mimeType: 'image/jpeg',
        note: question,
      );
      await _sayLocal(
          "Saved. Ask me for it anytime — I'll remember what's on it.");
    } catch (_) {
      await _sayLocal(
          "I couldn't save that — please check your connection and try once more.");
    }
    return true; // conversation continues either way
  }

  /// Opens the camera, captures, and speaks an answer grounded in the
  /// photo. Returns null when [question] wasn't a camera request.
  Future<bool?> _maybeHandleCamera(String question) async {
    if (_cameraClose.hasMatch(question)) {
      if (_visionBytes == null) return null;
      _clearVision();
      await _sayLocal('Okay, done with the photo.');
      return true; // conversation continues, back to normal chat
    }
    if (!wantsCamera(question)) return null;

    _clearVision();
    await _sayLocal('Opening the camera.');
    final XFile? shot;
    try {
      shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 82, // ~1 MB uploads — fast on mobile data
      );
    } catch (_) {
      await _sayLocal("I couldn't open the camera.");
      return true;
    }
    if (shot == null) {
      await _sayLocal('Okay.');
      return true; // user backed out; keep the conversation alive
    }
    _visionBytes = await shot.readAsBytes();
    return _askVision(question);
  }

  /// One /vision turn about the captured photo (first ask or follow-up).
  Future<bool> _askVision(String question) async {
    state = OrbState.thinking;
    lastHeard = question;
    lastReply = null;
    lastDocuments = const [];
    notifyListeners();

    String answer;
    try {
      final r = await ApiService.visionAsk(
        bytes: _visionBytes!,
        filename: 'voice_capture.jpg',
        mimeType: 'image/jpeg',
        mode: 'ask',
        question:
            '$question (Answer for VOICE: short, conversational, and in the '
            'same language the question was asked in.)',
        history: _visionThread,
      );
      answer = r.answer;
      _visionThread
        ..add(ChatMessage(role: 'user', content: question))
        ..add(ChatMessage(role: 'assistant', content: answer));
      // The photo exchange also lands in normal history, so if the user
      // drifts to other topics the AI still knows what was discussed.
      _history
        ..add(ChatMessage(role: 'user', content: question))
        ..add(ChatMessage(role: 'assistant', content: answer));
    } catch (_) {
      answer = "I couldn't analyze that. Please check your connection.";
    }

    _followReplyLanguage(answer);
    state = OrbState.speaking;
    lastReply = answer;
    partial = '';
    notifyListeners();
    await _voice.speak(answer);
    return !_speechAborted; // orb tap while speaking ends the conversation
  }

  void _clearVision() {
    _visionBytes = null;
    _visionThread.clear();
  }

  // ---------------- THE ANSWER LOOP ----------------

  /// Text-initiated spoken turn (e.g. the Daily tab's briefing button):
  /// Hari answers aloud, then listens for follow-ups like any conversation.
  Future<void> runText(String question) => ask(text: question);

  Future<void> ask({String? text}) async {
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

    // CONTINUOUS CONVERSATION: after Hari finishes speaking, the mic
    // reopens automatically for a follow-up — no wake word, no tap.
    // The conversation ends when the user simply stays quiet (~6 s),
    // taps the orb, or the turn was a device action (e.g. a phone call).
    var followUp = false;
    var pendingText = text;
    while (true) {
      String question;
      if (pendingText != null) {
        question = pendingText; // first turn came typed, not spoken
        pendingText = null;
      } else {
        state = OrbState.listening;
        partial = '';
        notifyListeners();
        question = await _captureAnyLanguage(followUp: followUp);
      }
      if (question.trim().isEmpty) break; // silence or cancel → done

      final keepGoing = await _answerOnce(question);
      if (!keepGoing) break;
      followUp = true;
      // Tiny beat so the mic isn't grabbed while TTS audio is tailing off.
      await Future.delayed(const Duration(milliseconds: 150));
    }

    _clearVision(); // photo context lives only within one conversation
    state = OrbState.idle;
    notifyListeners();
    await _startWake();
  }

  /// Capture path, best first:
  ///  1. CLOUD (Whisper via backend /stt) — record m4a, auto language
  ///     detection: Kannada, Hindi, English, mixed — no locale needed.
  ///  2. Device recognizer with the effective locale, if recording or
  ///     transcription fails (offline, permission, server down).
  Future<String> _captureAnyLanguage({bool followUp = false}) async {
    // 1) Cloud path (preferred).
    if (await _voice.canRecord()) {
      final path = await _voice.recordUntilSilence(
        // Follow-up turn: wait ~6 s for the user to keep talking, then
        // end the conversation gracefully instead of listening forever.
        noSpeechTimeoutMs: followUp ? 6000 : 8000,
        onLevel: (l) {
          micLevel = l;
          notifyListeners();
        },
      );
      micLevel = 0;
      if (path == null) {
        // User cancelled (orb tap) → genuinely stop.
        if (_voice.lastRecordingCancelled) return '';
        // Follow-up + silence = the user is done talking. Ending here is
        // the feature, not a failure — don't fall to the device recognizer.
        if (followUp) return '';
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

  /// Sentence boundaries across scripts (., !, ?, …, Devanagari danda).
  /// Whitespace-terminated so "3.5" or a sentence still being typed is
  /// never cut early — the final flush handles the reply's last sentence.
  static final _sentenceEnd = RegExp('[.!?…।॥]+["\')\\]]?\\s');

  /// True while the user has tapped the orb to cut Hari off mid-answer —
  /// stops the queued sentences, not just the one currently playing.
  bool _speechAborted = false;

  /// question -> STREAMED reply -> speak sentence-by-sentence.
  /// Hari starts SPEAKING the first sentence while the rest of the answer
  /// is still being generated (Gemini-Live-style time-to-first-audio).
  /// Returns false when the conversation should end (device action /
  /// user interrupt), true to keep listening for a follow-up.
  Future<bool> _answerOnce(String question) async {
    question = question.trim();
    if (question.isEmpty) return false;

    // DEVICE ACTIONS FIRST: "call amma" is handled entirely on-device
    // (contacts + dialer) — private, instant, works offline.
    if (await _handleCallIntent(question)) return false;

    // SAVE A DOCUMENT: "save this receipt" — must run BEFORE the camera
    // handler ("take a photo of the bill and save it" contains photo
    // words) and before photo follow-ups ("save it" about the current
    // photo files it instead of asking vision about it).
    final saved = await _maybeHandleSaveDocument(question);
    if (saved != null) return saved;

    // CAMERA: "open camera and help me understand this" — opens the
    // camera, then answers grounded in the photo. "Take another photo"
    // recaptures; "close camera" returns to normal chat.
    final cam = await _maybeHandleCamera(question);
    if (cam != null) return cam;
    // Active photo context → this follow-up is about the photo.
    if (_visionBytes != null) return _askVision(question);

    state = OrbState.thinking;
    lastHeard = question;
    lastReply = null;
    lastDocuments = const [];
    _speechAborted = false;
    notifyListeners();

    _history.add(ChatMessage(role: 'user', content: question));
    // Keep the payload small for latency; backend trims further.
    final window = _history.length > 12
        ? _history.sublist(_history.length - 12)
        : _history;

    // Sentences are spoken strictly in order on this chain while the
    // stream keeps filling the buffer behind them.
    var speakChain = Future<void>.value();
    var pending = '';
    void enqueue(String sentence) {
      final say = sentence.trim();
      if (say.isEmpty) return;
      speakChain = speakChain.then((_) async {
        if (_speechAborted) return;
        if (state != OrbState.speaking) {
          state = OrbState.speaking;
          notifyListeners();
        }
        await _voice.speak(say);
      });
    }

    void onDelta(String d) {
      if (_speechAborted) return;
      pending += d;
      lastReply = (lastReply ?? '') + d; // live transcript in the UI
      notifyListeners();
      // Flush every completed sentence to TTS immediately.
      int idx;
      while ((idx = pending.indexOf(_sentenceEnd)) >= 0) {
        final m = _sentenceEnd.firstMatch(pending.substring(idx))!;
        final cut = idx + m.end;
        enqueue(pending.substring(0, cut));
        pending = pending.substring(cut);
      }
    }

    ChatMessage answer;
    try {
      answer = await ApiService.sendChatStream(window, onDelta: onDelta);
    } catch (_) {
      // Streaming unavailable → classic one-shot request.
      try {
        answer = await ApiService.sendChat(window);
        lastReply = answer.content;
      } catch (_) {
        answer = const ChatMessage(
            role: 'assistant',
            content:
                "I couldn't reach the assistant. Please check your connection.");
        lastReply = answer.content;
      }
      pending = answer.content;
    }
    _history.add(answer);
    lastDocuments = answer.documents;
    final reply = answer.content;

    // FOLLOW THE CONVERSATION'S LANGUAGE: if Hari answered in Kannada,
    // listen in Kannada next time — this is what makes "speak in
    // Kannada" (said in any language) actually switch the whole loop,
    // independent of location. A manual pick still overrides.
    _followReplyLanguage(reply);

    lastReply = reply;
    partial = '';
    notifyListeners();

    // "Remind me to…" may have just created a reminder server-side —
    // resync so the phone schedules its notification immediately.
    ReminderNotifications.instance.sync();

    enqueue(pending); // whatever remained after the last sentence mark
    await speakChain; // wait until every queued sentence has been spoken

    if (_speechAborted) return false; // user cut Hari off → end conversation
    state = OrbState.thinking; // brief neutral state while mic reopens
    notifyListeners();
    return true;
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

  // ---------------- VOICE CALLING ----------------

  /// Set while Hari has asked "which one?" — the next heard phrase picks
  /// from these contacts instead of going to the AI.
  List<Contact>? _pendingCallOptions;

  Future<void> _sayLocal(String text) async {
    state = OrbState.speaking;
    lastReply = text;
    notifyListeners();
    await _voice.speak(text);
  }

  /// Returns true when [question] was a call request (handled here).
  Future<bool> _handleCallIntent(String question) async {
    final svc = CallService.instance;

    // A "which one?" follow-up is pending: interpret this as the choice.
    if (_pendingCallOptions != null) {
      final options = _pendingCallOptions!;
      _pendingCallOptions = null;
      if (svc.isCancel(question)) {
        lastHeard = question;
        await _sayLocal('Okay, cancelled.');
        return true;
      }
      final chosen = svc.chooseFrom(options, question);
      if (chosen != null) {
        lastHeard = question;
        await _placeCall(chosen);
        return true;
      }
      return false; // not a choice — treat as a normal question
    }

    final name = svc.parseCallIntent(question);
    if (name == null) return false;
    lastHeard = question;
    lastReply = null;
    lastDocuments = const [];
    notifyListeners();

    final matches = await svc.findContacts(name);
    if (matches.isEmpty) {
      final hasPerm = await svc.ensurePermission();
      await _sayLocal(hasPerm
          ? "I couldn't find $name in your contacts."
          : 'I need contact access to make calls — you can allow it in settings.');
      return true;
    }
    if (matches.length == 1) {
      await _placeCall(matches.first);
      return true;
    }

    // Several close matches: ask, then listen for the answer.
    final names = matches.map((c) => c.displayName).toList();
    final listed = names.length == 2
        ? '${names[0]} or ${names[1]}'
        : '${names.sublist(0, names.length - 1).join(', ')}, or ${names.last}';
    _pendingCallOptions = matches;
    await _sayLocal('I found ${matches.length}: $listed. Which one?');
    state = OrbState.idle;
    notifyListeners();
    await ask(); // opens the mic; the reply routes back through here
    return true;
  }

  Future<void> _placeCall(Contact c) async {
    final svc = CallService.instance;
    final number = svc.bestNumber(c);
    await _sayLocal('Calling ${c.displayName}…');
    final ok = await svc.call(number);
    if (!ok) {
      await _sayLocal("Sorry, I couldn't start the call.");
    }
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
        _speechAborted = true; // stop queued sentences too, not just this one
        await _voice.stopSpeaking();
      case OrbState.thinking:
        break;
    }
  }

  /// App lifecycle: without the foreground service, listening pauses in
  /// the background and resumes when the app returns to the foreground.
  Future<void> onBackground() async {
    if (!onDeviceWake) await _voice.stopWatching();
  }

  Future<void> onForeground() async {
    if (state == OrbState.idle) await _startWake();
  }

}
