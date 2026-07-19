import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Result of an interruptible speak: either TTS finished normally, or the
/// user barged in and [question] holds what they said.
class SpeakResult {
  final bool interrupted;
  final String question;
  const SpeakResult({required this.interrupted, this.question = ''});
}

/// Voice layer for the assistant (A2 Voice, A3 Multi-language).
///
/// Jobs:
///  1. WATCH — wake-word watching via live transcripts (fallback engine).
///  2. CAPTURE — record one question in the user's chosen language.
///  3. SPEAK — read replies aloud with the most natural voice installed
///     for the reply's language (auto-detected per reply), and support
///     BARGE-IN: while speaking, keep listening; if real user speech is
///     heard (echo-filtered), stop speaking and treat it as the next
///     question.
class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  final stt.SpeechToText _stt = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _ready = false;
  bool _watching = false;
  Timer? _restartTimer;

  /// Variants the recognizer commonly hears for "Hey Hari".
  static const _wakeWords = [
    'hey hari',
    'hey harry',
    'hey hurry',
    'a hari',
    'hey hardy',
  ];

  static bool containsWakeWord(String text) {
    final t = text.toLowerCase();
    return _wakeWords.any(t.contains) ||
        t.split(RegExp(r'\s+')).any((w) => w == 'hari' || w == 'harry');
  }

  /// Session hooks: the active capture / barge-in session subscribes to
  /// recognizer status + errors so it can restart or finish immediately
  /// (the Android recognizer stops itself after a few quiet seconds).
  void Function(String status)? _sessionStatus;
  void Function()? _sessionError;

  Future<bool> init() async {
    if (_ready) return true;
    _ready = await _stt.initialize(
      onStatus: (status) {
        _sessionStatus?.call(status);
        // The platform recognizer stops itself every few seconds of
        // silence; while watching we simply start it again.
        if (_watching && (status == 'done' || status == 'notListening')) {
          _restartTimer?.cancel();
          _restartTimer = Timer(
            const Duration(milliseconds: 400),
            () {
              if (_watching) _listenForWake();
            },
          );
        }
      },
      onError: (_) {
        _sessionError?.call();
        if (_watching) {
          _restartTimer?.cancel();
          _restartTimer = Timer(
            const Duration(milliseconds: 900),
            () {
              if (_watching) _listenForWake();
            },
          );
        }
      },
    );
    await _tts.setSpeechRate(0.52);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
    await _loadVoices();
    return _ready;
  }

  bool get isReady => _ready;

  /// Languages the device recognizer can transcribe (for the picker).
  Future<List<stt.LocaleName>> sttLocales() async {
    if (!_ready) return const [];
    try {
      final l = await _stt.locales();
      l.sort((a, b) => a.name.compareTo(b.name));
      return l;
    } catch (_) {
      return const [];
    }
  }

  // ---------------- NATURAL VOICE SELECTION ----------------
  // Devices ship many voices per language; the defaults are often the
  // robotic "local" ones. Google's "network" / neural voices are far more
  // human. We index every installed voice once and pick the best match
  // for whatever language a reply is in.

  final List<Map<String, String>> _voices = [];
  final Map<String, Map<String, String>?> _bestVoiceCache = {};
  String _currentTtsLang = '';

  Future<void> _loadVoices() async {
    try {
      final raw = await _tts.getVoices;
      _voices.clear();
      if (raw is List) {
        for (final v in raw) {
          if (v is Map) {
            final name = v['name']?.toString() ?? '';
            final locale = v['locale']?.toString() ?? '';
            if (name.isNotEmpty && locale.isNotEmpty) {
              _voices.add({'name': name, 'locale': locale});
            }
          }
        }
      }
    } catch (_) {}
  }

  int _voiceScore(Map<String, String> v, String wantLocale) {
    final name = v['name']!.toLowerCase();
    final loc = v['locale']!.toLowerCase();
    final want = wantLocale.toLowerCase();
    var s = 0;
    if (loc == want || loc == want.replaceAll('-', '_')) s += 100;
    if (loc.split(RegExp('[-_]')).first == want.split('-').first) s += 40;
    // Quality tiers seen in Google/Samsung TTS voice names.
    if (name.contains('neural') || name.contains('wavenet')) s += 14;
    if (name.contains('network')) s += 10; // Google cloud-quality voices
    if (name.contains('enhanced') || name.contains('premium')) s += 8;
    if (name.contains('local')) s += 1;
    return s;
  }

  Map<String, String>? _bestVoiceFor(String locale) {
    return _bestVoiceCache.putIfAbsent(locale, () {
      Map<String, String>? best;
      var bestScore = 39; // must at least match the language
      for (final v in _voices) {
        final s = _voiceScore(v, locale);
        if (s > bestScore) {
          bestScore = s;
          best = v;
        }
      }
      return best;
    });
  }

  Future<void> _applyLanguageFor(String text) async {
    final lang = detectLanguage(text);
    if (lang == _currentTtsLang) return;
    _currentTtsLang = lang;
    try {
      await _tts.setLanguage(lang);
      final voice = _bestVoiceFor(lang);
      if (voice != null) await _tts.setVoice(voice);
    } catch (_) {}
  }

  // ---------------- LANGUAGE DETECTION (for TTS) ----------------
  // Script detection covers all Indic + major world scripts; for Latin
  // text a light stop-word check separates the big European languages.

  static const _scriptRanges = <String, List<List<int>>>{
    'hi-IN': [[0x0900, 0x097F]], // Devanagari (Hindi/Marathi)
    'bn-IN': [[0x0980, 0x09FF]],
    'pa-IN': [[0x0A00, 0x0A7F]],
    'gu-IN': [[0x0A80, 0x0AFF]],
    'or-IN': [[0x0B00, 0x0B7F]],
    'ta-IN': [[0x0B80, 0x0BFF]],
    'te-IN': [[0x0C00, 0x0C7F]],
    'kn-IN': [[0x0C80, 0x0CFF]],
    'ml-IN': [[0x0D00, 0x0D7F]],
    'si-LK': [[0x0D80, 0x0DFF]],
    'ur-PK': [[0x0600, 0x06FF], [0x0750, 0x077F]], // Arabic script
    'ru-RU': [[0x0400, 0x04FF]],
    'el-GR': [[0x0370, 0x03FF]],
    'he-IL': [[0x0590, 0x05FF]],
    'th-TH': [[0x0E00, 0x0E7F]],
    'ja-JP': [[0x3040, 0x30FF]],
    'ko-KR': [[0xAC00, 0xD7AF], [0x1100, 0x11FF]],
    'zh-CN': [[0x4E00, 0x9FFF]],
  };

  static final _latinHints = <String, Set<String>>{
    'es-ES': {'el', 'la', 'los', 'las', 'una', 'está', 'para', 'por', 'qué',
        'gracias', 'hola', 'sí', 'usted', 'cómo'},
    'fr-FR': {'le', 'la', 'les', 'une', 'est', 'vous', 'pour', 'avec', 'oui',
        'bonjour', 'merci', 'être', 'c\'est', 'je'},
    'de-DE': {'der', 'die', 'das', 'und', 'ist', 'nicht', 'ich', 'sie', 'ein',
        'mit', 'für', 'danke', 'hallo'},
    'pt-BR': {'o', 'os', 'uma', 'é', 'não', 'você', 'para', 'com', 'obrigado',
        'olá', 'sim', 'está'},
    'it-IT': {'il', 'lo', 'gli', 'una', 'è', 'non', 'per', 'con', 'grazie',
        'ciao', 'sì', 'sono'},
    'id-ID': {'yang', 'dan', 'ini', 'itu', 'tidak', 'saya', 'anda', 'untuk',
        'dengan', 'terima', 'kasih'},
  };

  /// Best-effort BCP-47 tag for the language [text] is written in.
  static String detectLanguage(String text) {
    final counts = <String, int>{};
    var latin = 0;
    for (final code in text.runes) {
      if ((code >= 0x41 && code <= 0x5A) ||
          (code >= 0x61 && code <= 0x7A) ||
          (code >= 0x00C0 && code <= 0x024F)) {
        latin++;
        continue;
      }
      for (final e in _scriptRanges.entries) {
        for (final r in e.value) {
          if (code >= r[0] && code <= r[1]) {
            counts[e.key] = (counts[e.key] ?? 0) + 1;
            break;
          }
        }
      }
    }
    if (counts.isNotEmpty) {
      final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
      if (top.value * 3 >= latin) return top.key; // mostly non-Latin script
    }
    // Latin text: quick stop-word vote, default English (Indian voice).
    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{M}\s' "'" r']', unicode: true), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    String best = 'en-IN';
    var bestHits = 2; // need at least 3 hits to leave English
    for (final e in _latinHints.entries) {
      final hits = words.where(e.value.contains).length;
      if (hits > bestHits) {
        bestHits = hits;
        best = e.key;
      }
    }
    return best;
  }

  // ---------------- WATCH MODE ----------------

  void Function()? _onWake;

  Future<void> startWatching({required void Function() onWake}) async {
    if (!_ready) return;
    _onWake = onWake;
    _watching = true;
    await _listenForWake();
  }

  Future<void> _listenForWake() async {
    if (!_watching || _stt.isListening) return;
    await _stt.listen(
      onResult: (r) {
        if (_watching && containsWakeWord(r.recognizedWords)) {
          final cb = _onWake;
          stopWatching();
          cb?.call();
        }
      },
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
        cancelOnError: false,
      ),
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 10),
    );
  }

  Future<void> stopWatching() async {
    _watching = false;
    _restartTimer?.cancel();
    if (_stt.isListening) await _stt.stop();
  }

  // ---------------- CAPTURE ONE QUESTION ----------------

  /// Listens once and completes with the final transcript
  /// ('' if nothing was heard). [localeId] selects the recognizer
  /// language (null = device default), e.g. 'kn_IN', 'hi_IN'.
  Future<String> captureQuestion({
    String? localeId,
    void Function(String partial)? onPartial,
  }) async {
    if (!_ready) return '';
    await stopWatching();

    final completer = Completer<String>();
    String last = '';

    await _stt.listen(
      localeId: localeId,
      onResult: (r) {
        last = r.recognizedWords;
        onPartial?.call(last);
        if (r.finalResult && !completer.isCompleted) {
          completer.complete(last.trim());
        }
      },
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
        cancelOnError: true,
      ),
      listenFor: const Duration(seconds: 16),
      pauseFor: const Duration(milliseconds: 2200),
    );

    // Finish the moment the recognizer session actually ends, so the UI
    // never shows "listening" while the mic is already off.
    void finishSoon() {
      Timer(const Duration(milliseconds: 350), () {
        if (!completer.isCompleted) completer.complete(last.trim());
      });
    }

    _sessionStatus = (st) {
      if (st == 'done' || st == 'notListening') finishSoon();
    };
    _sessionError = finishSoon;

    // Safety net if no status ever arrives.
    Timer(const Duration(seconds: 24), () {
      if (!completer.isCompleted) completer.complete(last.trim());
    });

    final q = await completer.future;
    _sessionStatus = null;
    _sessionError = null;
    return q;
  }

  Future<void> cancelCapture() async {
    if (_stt.isListening) await _stt.stop();
  }

  // ---------------- SPEAK ----------------

  /// Speaks [text] in a voice matching its language.
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await _applyLanguageFor(text);
    await _tts.speak(text);
  }

  /// Speaks [text] while keeping the mic open for BARGE-IN.
  ///
  /// The ear is auto-restarted whenever Android's recognizer stops itself
  /// mid-reply, so barge-in works for the WHOLE reply, not just the first
  /// few seconds. The echo filter is strict — "Hey Hari" or a clearly new
  /// sentence interrupts; the assistant's own voice does not. Tapping the
  /// orb still stops speech instantly (handled by the controller).
  Future<SpeakResult> speakInterruptible(
    String text, {
    String? localeId,
    void Function()? onInterrupted,
    void Function(String partial)? onPartial,
  }) async {
    if (text.isEmpty) return const SpeakResult(interrupted: false);
    await _applyLanguageFor(text);

    final replyNorm = _norm(text);
    final startedAt = DateTime.now();
    var interrupted = false;
    var ttsDone = false;
    var heard = '';
    final finished = Completer<SpeakResult>();
    Timer? restart;

    void completeWith(SpeakResult r) {
      if (!finished.isCompleted) finished.complete(r);
    }

    void onResult(dynamic r) {
      final words = r.recognizedWords as String;
      if (!interrupted) {
        // Grace period: right after TTS starts the mic mostly hears
        // the assistant itself — ignore that window entirely.
        if (DateTime.now().difference(startedAt).inMilliseconds < 700) return;
        if (!_looksLikeUserSpeech(words, replyNorm)) return;
        interrupted = true;
        _tts.stop(); // cut the assistant off mid-sentence
        onInterrupted?.call();
      }
      heard = words;
      onPartial?.call(words);
      if (r.finalResult as bool) {
        completeWith(SpeakResult(interrupted: true, question: heard.trim()));
      }
    }

    Future<void> openEar() async {
      if (finished.isCompleted || _stt.isListening) return;
      try {
        await _stt.listen(
          localeId: localeId,
          onResult: onResult,
          listenOptions: stt.SpeechListenOptions(
            partialResults: true,
            listenMode: stt.ListenMode.dictation,
            cancelOnError: true,
          ),
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 8),
        );
      } catch (_) {}
    }

    void onSessionEnd() {
      restart?.cancel();
      if (interrupted) {
        // The user's sentence is over (or the session died) — return
        // whatever we heard NOW instead of hanging in "listening".
        restart = Timer(const Duration(milliseconds: 350), () {
          completeWith(SpeakResult(interrupted: true, question: heard.trim()));
        });
      } else if (!ttsDone) {
        // Recognizer stopped itself while Hari is still talking —
        // reopen the ear so barge-in keeps working for the whole reply.
        restart = Timer(const Duration(milliseconds: 300), openEar);
      }
    }

    _sessionStatus = (st) {
      if (st == 'done' || st == 'notListening') onSessionEnd();
    };
    _sessionError = onSessionEnd;

    await openEar();

    // With awaitSpeakCompletion(true) this resolves when speech ends —
    // naturally, via tapOrb's stopSpeaking(), or via barge-in stop().
    await _tts.speak(text);
    ttsDone = true;

    if (!interrupted) {
      restart?.cancel();
      _sessionStatus = null;
      _sessionError = null;
      await cancelCapture();
      return const SpeakResult(interrupted: false);
    }

    // Barge-in happened: wait for the user's full sentence (bounded).
    Timer(const Duration(seconds: 15), () {
      completeWith(SpeakResult(interrupted: true, question: heard.trim()));
    });
    final r = await finished.future;
    restart?.cancel();
    _sessionStatus = null;
    _sessionError = null;
    await cancelCapture();
    return r;
  }

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Echo filter: is this transcript real user speech, or just the mic
  /// hearing the assistant's own voice?
  ///
  /// STRICT on purpose. When the recognizer language differs from the
  /// reply language it transcribes the assistant's own audio as random
  /// words, so "a couple of new words" is NOT enough evidence. Rules:
  ///   • "Hey Hari" always interrupts (any pronunciation variant).
  ///   • Otherwise we need a real sentence: 3+ words that clearly do
  ///     not come from the reply being spoken.
  /// For anything shorter, tapping the orb interrupts instantly.
  static bool _looksLikeUserSpeech(String transcript, String replyNorm) {
    final t = _norm(transcript);
    if (t.isEmpty) return false;
    if (containsWakeWord(t)) return true; // "Hey Hari" always interrupts
    if (replyNorm.contains(t)) return false; // pure echo of the reply
    final tokens = t.split(' ');
    final novel =
        tokens.where((w) => w.length > 2 && !replyNorm.contains(w)).length;
    return novel >= 3;
  }

  Future<void> stopSpeaking() => _tts.stop();
}
