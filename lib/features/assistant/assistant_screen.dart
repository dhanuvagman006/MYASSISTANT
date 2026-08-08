import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
import '../../widgets/update_button.dart';
import 'state/assistant_engine.dart';
import 'state/assistant_state.dart';
import 'widgets/action_cards.dart';
import 'widgets/assistant_hero_widget.dart';
import 'widgets/bottom_input_bar.dart';

/// THE app — a single-page liquid-glass AI agent experience.
///
/// Layout (top → bottom):
///   • frosted glass bar: brand orb + Hari + hub / calls / profile / settings
///   • animated hero orb (state-driven) + live status pill
///   • live transcript + dynamic action cards
///   • quick-action glass chips (first launch) → tap to run
///   • frosted bottom bar: mic + text fallback
///
/// There is NO other page. Daily/Inbox/Docs, Calls, Profile & Privacy and
/// the first-run interview all open as frosted glass bottom sheets.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final engine = AssistantEngine.instance;
  final _scroll = ScrollController();
  RemoteConfig _config = const RemoteConfig();
  bool _announcementDismissed = false;

  @override
  void initState() {
    super.initState();
    engine.start();
    engine.addListener(_autoScroll);
    ApiService.refreshConfig().then((c) {
      if (mounted) setState(() => _config = c);
    });
    // First sign-in → offer the get-to-know-you interview in a sheet
    // (skippable). The single page stays underneath the whole time.
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

  // ── Glass sheets — the only "navigation" in the app ──────────────────────

  void _openHub() =>
      showGlassSheet(context, title: 'Your day', child: const _HubSheet());

  void _openCalls() =>
      showGlassSheet(context, title: 'Calls', child: const CallsScreen());

  void _openProfile() =>
      showGlassSheet(context, title: 'You', child: const PrivacyScreen());

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: engine,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: AuroraBackdrop(
            child: SafeArea(
              child: Column(
                children: [
                  _frostedBar(context),
                  if (_config.announcement != null && !_announcementDismissed)
                    _announcement(),
                  const SizedBox(height: 4),
                  // Hero shrinks once a conversation is underway so the
                  // transcript/cards get the room.
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    height: engine.transcript.isEmpty ? 236 : 148,
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
                  _frostedInput(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Frosted glass top bar — brand + the three glass entry points.
  Widget _frostedBar(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 8, 6, 8),
          decoration: BoxDecoration(
            color: Neon.bg.withValues(alpha: 0.35),
            border: Border(bottom: BorderSide(color: Neon.line)),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: Neon.gOrb,
                  boxShadow: Neon.glow(Neon.violet, blur: 12, alpha: 0.5),
                ),
                padding: const EdgeInsets.all(2),
                child: const DecoratedBox(
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: Neon.bg),
                ),
              ),
              const SizedBox(width: 10),
              GradientText('Hari',
                  style: Theme.of(context).textTheme.titleLarge!),
              const SizedBox(width: 8),
              // Live status dot — online when the engine has a connection.
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: engine.connected ? Neon.success : Neon.textDim,
                  boxShadow: engine.connected
                      ? Neon.glow(Neon.success, blur: 8, alpha: 0.8)
                      : null,
                ),
              ),
              const Spacer(),
              UpdateButton(config: _config),
              _barIcon(Icons.dashboard_customize_rounded, 'Your day', _openHub),
              _barIcon(Icons.call_outlined, 'Calls', _openCalls),
              _barIcon(Icons.person_outline_rounded, 'You', _openProfile),
              _barIcon(Icons.tune_rounded, 'Assistant settings',
                  () => showStyleSettingsSheet(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barIcon(IconData icon, String tip, VoidCallback onTap) => IconButton(
        tooltip: tip,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, size: 22, color: Neon.textHi.withValues(alpha: 0.85)),
        onPressed: () {
          HapticFeedback.selectionClick();
          onTap();
        },
      );

  Widget _announcement() => Padding(
        padding: const EdgeInsets.fromLTRB(Neon.s4, Neon.s2, Neon.s4, 0),
        child: GlassCard(
          tint: Neon.warning,
          child: Row(
            children: [
              const Icon(Icons.campaign_outlined,
                  color: Neon.warning, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(_config.announcement!)),
              GestureDetector(
                onTap: () => setState(() => _announcementDismissed = true),
                child: const Icon(Icons.close_rounded,
                    size: 18, color: Neon.textLo),
              ),
            ],
          ),
        ),
      );

  Widget _errorBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Neon.error.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Neon.error.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Neon.error, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(engine.errorMessage!,
                  style: const TextStyle(color: Neon.textHi, fontSize: 13)),
            ),
            GestureDetector(
              onTap: engine.dismissError,
              child: const Icon(Icons.close_rounded,
                  size: 18, color: Neon.textLo),
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
        if (engine.callStatus != null)
          CallStatusCard(status: engine.callStatus!),
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

  /// First-launch empty state — greeting + tappable quick-action chips.
  Widget _emptyState() {
    final name = AuthService.instance.user?.name;
    final actions = <(IconData, String, String)>[
      (Icons.waving_hand_rounded, 'Say hello', 'Hello'),
      (
        Icons.travel_explore_rounded,
        "Today's gold price",
        "Search for today's gold price"
      ),
      (
        Icons.phone_forwarded_rounded,
        'Call & inform someone',
        'Call Alan and inform him I will not be coming today'
      ),
      (Icons.wb_sunny_outlined, 'Plan my day', 'What should I focus on today?'),
    ];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: Neon.s7),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GradientText(
              name == null ? 'Hi, I\'m Hari' : 'Hi $name',
              style: Theme.of(context).textTheme.headlineSmall!,
              gradient: Neon.gVioletPink,
            ),
            const SizedBox(height: Neon.s3),
            // Quiet, single-tone helper line — luxury UIs keep secondary
            // text neutral so the orb + greeting stay the only color heroes.
            Text(
              'Tap the orb, hold the mic, or try one of these',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Neon.textDim,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: Neon.s6),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: Neon.s3,
              runSpacing: Neon.s3,
              children: [
                for (final (icon, label, prompt) in actions)
                  _PressScale(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      engine.sendText(prompt);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(Neon.rPill),
                        border: Border.all(color: Neon.line),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Monochrome icons: one accent family on screen at
                          // a time reads premium; four competing hues do not.
                          Icon(icon,
                              size: 15,
                              color: Neon.textLo.withValues(alpha: 0.9)),
                          const SizedBox(width: 8),
                          Text(label,
                              style: const TextStyle(
                                  color: Neon.textHi,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.1)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Frosted wrapper around the mic + text input bar.
  Widget _frostedInput() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Neon.bg.withValues(alpha: 0.35),
            border: Border(top: BorderSide(color: Neon.line)),
          ),
          child: BottomInputBar(
            phase: engine.phase,
            onMic: engine.pressMic,
            onSendText: engine.sendText,
          ),
        ),
      ),
    );
  }
}

/// Tactile press feedback — the micro-interaction that separates premium
/// from generic: the chip settles 4% smaller under the finger, then springs
/// back. Cheap UIs have no press state; luxury UIs always respond to touch.
class _PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _PressScale({required this.child, required this.onTap});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Daily / Inbox / Docs — the old "Today" tab, now living inside one sheet.
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
