import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/style_settings_sheet.dart';
import 'state/assistant_engine.dart';
import 'state/assistant_state.dart';
import 'widgets/action_cards.dart';
import 'widgets/assistant_hero_widget.dart';
import 'widgets/bottom_input_bar.dart';

/// The redesigned primary assistant experience — dark, premium, alive.
///
/// Layout (top → bottom):
///   • top bar: assistant name + settings
///   • animated hero orb (state-driven) + live status pill
///   • live transcript + dynamic action cards (tools, search results,
///     contacts, confirmation, call status)
///   • bottom bar: mic + text fallback
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final engine = AssistantEngine.instance;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    engine.start();
    engine.addListener(_autoScroll);
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: engine,
      builder: (context, _) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0B1A1C), Color(0xFF0E1B1D), Color(0xFF102325)],
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Column(
                children: [
                  _topBar(context),
                  const SizedBox(height: 4),
                  // Hero shrinks once a conversation is underway so the
                  // transcript/cards get the room.
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    height: engine.transcript.isEmpty ? 240 : 150,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: AssistantHeroWidget(
                        phase: engine.phase,
                        micLevel: engine.micLevel,
                        onTap: engine.pressMic,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  AssistantStatusPill(
                    phase: engine.phase,
                    connected: engine.connected,
                    onCancel: engine.cancelAction,
                  ),
                  const SizedBox(height: 8),
                  if (engine.errorMessage != null) _errorBanner(),
                  Expanded(child: _feed()),
                  BottomInputBar(
                    phase: engine.phase,
                    onMic: engine.pressMic,
                    onSendText: engine.sendText,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.marigold, width: 2.5),
            ),
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: AppColors.peacockLight),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Hari',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Assistant settings',
            icon: Icon(Icons.tune_rounded,
                color: Colors.white.withValues(alpha: 0.8)),
            onPressed: () => showStyleSettingsSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _errorBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.danger, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(engine.errorMessage!,
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
            GestureDetector(
              onTap: engine.dismissError,
              child: Icon(Icons.close_rounded,
                  size: 18, color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }

  /// Transcript + all dynamic action cards, in conversational order.
  Widget _feed() {
    final empty = engine.transcript.isEmpty &&
        engine.activities.isEmpty &&
        engine.pendingConfirmation == null;
    if (empty) return _emptyState();

    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
        if (engine.callStatus != null)
          CallStatusCard(status: engine.callStatus!),
        if (engine.usedClonedVoice)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Message prepared in your enrolled voice',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
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
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      );

  Widget _emptyState() {
    final suggestions = [
      '“Hello”',
      '“Search for today’s gold price”',
      '“Call Alan and inform him I will not be coming today”',
    ];
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Tap the mic and try',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
            ),
            const SizedBox(height: 12),
            for (final s in suggestions)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Text(
                    s,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
