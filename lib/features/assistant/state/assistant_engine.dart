import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/network/assistant_api.dart';
import '../../../services/call_service.dart';
import '../../../services/voice_service.dart';
import 'assistant_state.dart';

/// The assistant experience's single source of truth (ChangeNotifier — the
/// state-management style used across this codebase; the UI observes it
/// with AnimatedBuilder/ListenableBuilder).
///
/// Owns: session lifecycle, mic capture, backend event stream, the phase
/// state machine, transcript, tool/search/contact/call cards, confirmation
/// flow, cancellation, and speaking replies out loud.
class AssistantEngine extends ChangeNotifier {
  AssistantEngine._();
  static final AssistantEngine instance = AssistantEngine._();

  final _api = AssistantApi.instance;
  final _voice = VoiceService.instance;

  // ---------------- observable state ----------------

  AssistantPhase phase = AssistantPhase.idle;
  bool connected = false;
  String? errorMessage;

  /// Live mic loudness 0..1 while listening — drives the hero animation.
  double micLevel = 0;

  /// Interim transcript while the user is still speaking (device-side).
  String partial = '';

  final List<TranscriptEntry> transcript = [];
  final List<ToolActivity> activities = [];

  String? searchQuery;
  List<SearchResult> searchResults = const [];

  ContactMatch? foundContact;
  List<ContactMatch> ambiguousContacts = const [];
  PendingConfirmation? pendingConfirmation;
  CallStatusInfo? callStatus;
  String? readyAudioUrl; // cloned-voice preview from audio_ready
  bool usedClonedVoice = false;

  bool get micBusy => phase == AssistantPhase.listening;

  // ---------------- lifecycle ----------------

  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _connect();
  }

  Future<void> _connect() async {
    try {
      await _api.connect(
        onEvent: _onEvent,
        onDisconnect: () {
          connected = false;
          notifyListeners();
        },
      );
      connected = true;
      errorMessage = null;
    } catch (e) {
      connected = false;
      errorMessage = 'Could not reach the assistant service.';
      // Retry quietly — the screen shows the offline banner meanwhile.
      Future.delayed(const Duration(seconds: 4), () {
        if (_started && !connected) _connect();
      });
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  // ---------------- user input ----------------

  /// Mic button: record until silence, then hand the clip to the backend
  /// (STT + the whole turn run server-side; results stream back).
  Future<void> pressMic() async {
    if (phase == AssistantPhase.listening) {
      _voice.stopSpeaking();
      return; // recorder stops itself on silence; tap again does nothing
    }
    if (phase.busy && phase != AssistantPhase.completed) return;
    await _voice.stopSpeaking();

    if (!await _voice.canRecord()) {
      _setLocalError('Microphone permission is needed. Enable it in Settings.');
      return;
    }

    _resetTurn();
    _setPhase(AssistantPhase.listening);
    HapticFeedback.mediumImpact();

    final path = await _voice.recordUntilSilence(
      onLevel: (l) {
        micLevel = l;
        notifyListeners();
      },
    );
    micLevel = 0;

    if (path == null) {
      _setPhase(AssistantPhase.idle);
      return;
    }
    _setPhase(AssistantPhase.transcribing);
    try {
      final bytes = await File(path).readAsBytes();
      await _api.sendAudio(bytes);
      // Backend takes over: transcribing → thinking → … via SSE.
    } catch (_) {
      _setLocalError("I couldn't upload your audio. Check your connection.");
    }
  }

  /// Text fallback from the bottom input bar.
  Future<void> sendText(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await _voice.stopSpeaking();
    _resetTurn();
    _setPhase(AssistantPhase.thinking);
    try {
      await _api.sendText(t);
    } catch (_) {
      _setLocalError("I couldn't send that. Check your connection.");
    }
  }

  /// Confirmation card buttons.
  Future<void> confirm(bool approved) async {
    pendingConfirmation = null;
    notifyListeners();
    HapticFeedback.selectionClick();
    try {
      await _api.confirm(approved);
    } catch (_) {
      _setLocalError('That action could not be sent.');
    }
  }

  /// Ambiguous-contact card selection.
  Future<void> chooseContact(ContactMatch m) async {
    ambiguousContacts = const [];
    notifyListeners();
    try {
      await _api.chooseContact(m.id);
    } catch (_) {
      _setLocalError('That choice could not be sent.');
    }
  }

  /// Cancel whatever is in flight.
  Future<void> cancelAction() async {
    _voice.stopSpeaking();
    try {
      await _api.cancel();
    } catch (_) {}
    pendingConfirmation = null;
    ambiguousContacts = const [];
    _setPhase(AssistantPhase.idle);
  }

  void dismissError() {
    errorMessage = null;
    if (phase == AssistantPhase.error) phase = AssistantPhase.idle;
    notifyListeners();
  }

  // ---------------- backend events ----------------

  void _onEvent(Map<String, dynamic> e) {
    switch (e['type']) {
      case 'assistant_state':
        final p = AssistantPhase.fromWire(e['state'] as String? ?? '');
        // Never let a server 'idle' stomp on local listening/recording.
        if (p == AssistantPhase.idle && phase == AssistantPhase.listening) break;
        _setPhase(p, silent: true);
        if (p == AssistantPhase.error) {
          errorMessage = e['message'] as String? ?? 'Something went wrong.';
        }
        _haptic(p);
        break;

      case 'user_transcript':
        partial = '';
        transcript.add(TranscriptEntry(TranscriptRole.user, e['text'] as String? ?? ''));
        break;

      case 'assistant_message':
        final text = e['text'] as String? ?? '';
        transcript.add(TranscriptEntry(TranscriptRole.assistant, text));
        _voice.speak(text); // spoken reply — the core voice loop
        break;

      case 'tool_started':
        activities.add(ToolActivity(
          tool: e['tool'] as String? ?? '',
          label: e['label'] as String? ?? 'Working…',
        ));
        break;

      case 'tool_completed':
        for (final a in activities) {
          if (a.tool == e['tool'] && !a.completed) a.completed = true;
        }
        break;

      case 'search_results':
        searchQuery = e['query'] as String?;
        searchResults = ((e['results'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(SearchResult.fromJson)
            .toList();
        break;

      case 'contact_lookup':
        // Contacts live on THIS device — resolve the name here and post
        // the matches back so the backend can continue the flow.
        _resolveContacts(e['name'] as String? ?? '');
        break;

      case 'contact_found':
        foundContact =
            ContactMatch.fromJson((e['contact'] as Map).cast<String, dynamic>());
        ambiguousContacts = const [];
        break;

      case 'contacts_ambiguous':
        ambiguousContacts = ((e['matches'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ContactMatch.fromJson)
            .toList();
        break;

      case 'contact_not_found':
        foundContact = null;
        ambiguousContacts = const [];
        break;

      case 'confirmation_request':
        pendingConfirmation = PendingConfirmation(
          action: e['action'] as String? ?? 'generic',
          question: e['question'] as String?,
          contact: e['contact'] is Map
              ? ContactMatch.fromJson((e['contact'] as Map).cast<String, dynamic>())
              : null,
          message: e['message'] as String?,
          spokenPreview: e['spoken_preview'] as String?,
        );
        HapticFeedback.mediumImpact();
        break;

      case 'call_status':
        callStatus = CallStatusInfo(
          status: e['status'] as String? ?? '',
          contactName: e['contact_name'] as String? ?? '',
        );
        break;

      case 'audio_ready':
        readyAudioUrl = e['url'] as String?;
        usedClonedVoice = e['cloned_voice'] == true;
        break;

      case 'error':
        errorMessage = e['message'] as String? ?? 'Something went wrong.';
        break;
    }
    notifyListeners();
  }

  Future<void> _resolveContacts(String name) async {
    try {
      final found = await CallService.instance.findContacts(name);
      final matches = <Map<String, dynamic>>[];
      for (final c in found) {
        if (c.phones.isEmpty) continue;
        final phone = CallService.instance.bestNumber(c);
        if (phone.isEmpty) continue;
        matches.add({'id': c.id, 'name': c.displayName, 'phone': phone});
      }
      await _api.sendContactMatches(matches);
    } catch (_) {
      await _api.sendContactMatches(const []);
    }
  }

  // ---------------- helpers ----------------

  void _resetTurn() {
    errorMessage = null;
    searchQuery = null;
    searchResults = const [];
    foundContact = null;
    ambiguousContacts = const [];
    pendingConfirmation = null;
    callStatus = null;
    readyAudioUrl = null;
    activities.clear();
    notifyListeners();
  }

  void _setPhase(AssistantPhase p, {bool silent = false}) {
    phase = p;
    notifyListeners();
    if (!silent) _haptic(p);
  }

  void _setLocalError(String message) {
    errorMessage = message;
    phase = AssistantPhase.error;
    notifyListeners();
  }

  void _haptic(AssistantPhase p) {
    switch (p) {
      case AssistantPhase.waitingForConfirmation:
      case AssistantPhase.inCall:
        HapticFeedback.mediumImpact();
      case AssistantPhase.completed:
        HapticFeedback.lightImpact();
      case AssistantPhase.error:
        HapticFeedback.heavyImpact();
      default:
        break;
    }
  }
}
