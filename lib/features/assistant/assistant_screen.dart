
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../design/neon_tokens.dart';
import '../../design/neon_widgets.dart';
import '../../models/remote_config.dart';
import '../../screens/calls_screen.dart';
import '../../screens/daily_screen.dart';
import '../../screens/documents_screen.dart';
import '../../screens/inbox_screen.dart';
import '../../screens/interview_screen.dart';
import '../../screens/privacy_screen.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/style_settings_sheet.dart';
import 'state/assistant_engine.dart';
import 'state/assistant_state.dart';
import 'widgets/action_cards.dart';
import 'widgets/assistant_hero_widget.dart';

/// THE app — one page, one control.
///
/// Quiet-luxury layout:
///   • "Hi <name>" in a serif with a champagne-gold finish, top center
///   • the gold orb, centered — tap to talk; that's the whole interface
///   • while a conversation is live, the transcript/cards slide in below
///     the orb and disappear again when it's over
///   • LONG-PRESS the orb for the concierge menu (Your day / Calls /
///     Profile / Settings) — nothing visible on screen, ever
///
/// No top bar. No bottom bar. No chips. No hints.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final engine = AssistantEngine.instance;
  final _scroll = ScrollController();
  RemoteConfig _config = const RemoteConfig();

  @override
  void initState() {
    super.initState();
    engine.start();
    engine.addListener(_autoScroll);
    ApiService.refreshConfig().then((c) {
      if (mounted) setState(() => _config = c);
    });
    // First sign-in → offer the get-to-know-you interview (skippable sheet).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = AuthService.instance;
      if (auth.lastSignInWasNew && mounted) {
        auth.lastSignInWasNew = false;
        showGlassSheet(
          context,
          heightFactor: 0.92,
          child: InterviewScreen(
            onDone: () => Navigator.of(context).pop(),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    engine.removeListener(_autoScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _autoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool get _inConversation =>
      engine.transcript.isNotEmpty ||
      engine.activities.isNotEmpty ||
      engine.pendingConfirmation != null;

  String get _firstName {
    final n = AuthService.instance.user?.name?.trim();
    if (n == null || n.isEmpty) return '';
    return n.split(RegExp(r'\s+')).first;
  }

  // ── Hidden concierge menu — long-press the orb ─────────────────────────

  void _openConcierge() {
    HapticFeedback.mediumImpact();
    showGlassSheet(
      context,
      heightFactor: 0.42,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _conciergeRow(Icons.wb_sunny_outlined, 'Your day', () {
            Navigator.of(context).pop();
            showGlassSheet(context,
                title: 'Your day', child: const _HubSheet());
          }),
          _conciergeRow(Icons.call_outlined, 'Calls', () {
            Navigator.of(context).pop();
            showGlassSheet(context, title: 'Calls', child: const CallsScreen());
          }),
          _conciergeRow(Icons.person_outline_rounded, 'You', () {
            Navigator.of(context).pop();
            showGlassSheet(context, title: 'You', child: const PrivacyScreen());
          }),
          _conciergeRow(Icons.tune_rounded, 'Assistant settings', () {
            Navigator.of(context).pop();
            showStyleSettingsSheet(context);
          }),
        ],
      ),
    );
  }

  Widget _conciergeRow(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Neon.gold, size: 22),
      title: Text(label,
          style: const TextStyle(color: Neon.textHi, fontSize: 15.5)),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: engine,
      builder: (context, _) {
        final talking = _inConversation;
        return Scaffold(
          backgroundColor: Neon.luxeBg,
          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 40),
                _greeting(),
                if (_config.announcement != null) _announcementLine(),
                // The orb — centered when idle, docked high when talking.
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  height: talking ? 168 : 300,
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: GestureDetector(
                      onLongPress: _openConcierge,
                      child: AssistantHeroWidget(
                        phase: engine.phase,
                        micLevel: engine.micLevel,
                        onTap: engine.pressMic,
                      ),
                    ),
                  ),
                ),
                // Status shows only when there is something to say.
                if (engine.phase != AssistantPhase.idle || !engine.connected)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: AssistantStatusPill(
                      phase: engine.phase,
                      connected: engine.connected,
                      onCancel: engine.cancelAction,
                    ),
                  ),
                if (engine.errorMessage != null) _errorLine(),
                // Conversation surface — empty and invisible when idle.
                Expanded(child: talking ? _feed() : const SizedBox.shrink()),
              ],
            ),
          ),
        );
      },
    );
  }

  /// "Hi Dhanush" — serif, champagne gold, nothing else.
  Widget _greeting() {
    final name = _firstName;
    return ShaderMask(
      shaderCallback: (r) => Neon.gGoldText.createShader(r),
      child: Text(
        name.isEmpty ? 'Hi' : 'Hi $name',
        style: GoogleFonts.playfairDisplay(
          fontSize: 34,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: Colors.white, // masked by the gold shader
        ),
      ),
    );
  }

  /// Remote announcements shrink to one quiet line under the greeting.
  Widget _announcementLine() => Padding(
        padding: const EdgeInsets.fromLTRB(32, 10, 32, 0),
        child: Text(
          _config.announcement!,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Neon.textDim, fontSize: 12.5),
        ),
      );

  /// Errors as a single understated line — no loud red banner.
  Widget _errorLine() => Padding(
        padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
        child: GestureDetector(
          onTap: engine.dismissError,
          child: Text(
            engine.errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Neon.error.withValues(alpha: 0.85),
              fontSize: 12.5,
            ),
          ),
        ),
      );

  /// Transcript + dynamic action cards, only while a conversation is live.
  Widget _feed() {
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        for (final t in engine.transcript) TranscriptBubble(entry: t),
        for (final a in engine.activities) ToolCard(activity: a),
        if (engine.searchResults.isNotEmpty) ...[
          _sectionLabel('Results for "${engine.searchQuery}"'),
          for (final r in engine.searchResults) SearchResultCard(result: r),
        ],
        if (engine.ambiguousContacts.isNotEmpty) ...[
          _sectionLabel('Which one did you mean?'),
          for (final c in engine.ambiguousContacts)
            ContactCard(contact: c, onTap: () => engine.chooseContact(c)),
        ],
        if (engine.foundContact != null &&
            engine.pendingConfirmation == null &&
            engine.callStatus == null)
          ContactCard(contact: engine.foundContact!),
        if (engine.pendingConfirmation != null)
          ConfirmationCard(
            pending: engine.pendingConfirmation!,
            onDecision: engine.confirm,
          ),
        if (engine.callStatus != null) CallStatusCard(status: engine.callStatus!),
        if (engine.usedClonedVoice)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Message prepared in your enrolled voice',
              textAlign: TextAlign.center,
              style: TextStyle(color: Neon.textDim, fontSize: 12),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
        child: Text(
          text,
          style: const TextStyle(
            color: Neon.textLo,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      );
}

/// Daily / Inbox / Docs — lives inside the concierge sheet.
class _HubSheet extends StatefulWidget {
  const _HubSheet();

  @override
  State<_HubSheet> createState() => _HubSheetState();
}

class _HubSheetState extends State<_HubSheet> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    const pages = [DailyScreen(), InboxScreen(), DocumentsScreen()];
    return Column(
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: Neon.s4, vertical: Neon.s2),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Daily')),
              ButtonSegment(value: 1, label: Text('Inbox')),
              ButtonSegment(value: 2, label: Text('Docs')),
            ],
            selected: {_segment},
            onSelectionChanged: (s) {
              HapticFeedback.selectionClick();
              setState(() => _segment = s.first);
            },
          ),
        ),
        Expanded(child: pages[_segment]),
      ],
    );
  }
}
