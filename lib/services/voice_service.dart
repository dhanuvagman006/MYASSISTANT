import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Voice layer for the assistant (A2 Voice, A3 Multi-language).
///
/// Two jobs:
///  1. WATCH — keep the mic open and look for the wake word ("Hey Hari")
///     in live partial transcripts. Works while the app is in the
///     foreground. True screen-off wake word needs an on-device engine
///     (e.g. Porcupine) + a foreground service — planned separately.
///  2. CAPTURE + SPEAK — record one question, hand it to the caller,
///     then read the assistant's reply aloud.
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

  Future<bool> init() async {
    if (_ready) return true;
    _ready = await _stt.initialize(
      onStatus: (status) {
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
    await _tts.awaitSpeakCompletion(true);
    return _ready;
  }

  bool get isReady => _ready;

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
  /// ('' if nothing was heard).
  Future<String> captureQuestion({
    void Function(String partial)? onPartial,
  }) async {
    if (!_ready) return '';
    await stopWatching();

    final completer = Completer<String>();
    String last = '';

    await _stt.listen(
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
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 3),
    );

    // Safety net if the recognizer ends without a final result.
    Timer(const Duration(seconds: 24), () {
      if (!completer.isCompleted) completer.complete(last.trim());
    });

    return completer.future;
  }

  Future<void> cancelCapture() async {
    if (_stt.isListening) await _stt.stop();
  }

  // ---------------- SPEAK ----------------

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await _tts.speak(text);
  }

  Future<void> stopSpeaking() => _tts.stop();
}
