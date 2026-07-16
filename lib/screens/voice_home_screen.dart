import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/assistant_controller.dart';
import '../theme/app_theme.dart';

/// Screen 01 — Voice Home (A1–A4, M1).
/// A thin view over AssistantController: the wake/answer loop keeps
/// running even when this screen isn't visible or the display is off.
class VoiceHomeScreen extends StatefulWidget {
  final VoidCallback? onOpenChat;
  const VoiceHomeScreen({super.key, this.onOpenChat});

  @override
  State<VoiceHomeScreen> createState() => _VoiceHomeScreenState();
}

class _VoiceHomeScreenState extends State<VoiceHomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _assistant = AssistantController.instance;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _assistant.init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) {
      _assistant.onBackground();
    } else if (s == AppLifecycleState.resumed) {
      _assistant.onForeground();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulse.dispose();
    super.dispose();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _caption(AssistantController a) {
    if (!a.micReady) return 'Microphone unavailable — check app permissions';
    return switch (a.state) {
      OrbState.idle => a.wakeEnabled
          ? 'Say "Hey Hari" or tap the orb'
          : 'Tap the orb to speak — any language',
      OrbState.listening =>
        a.partial.isEmpty ? "I'm listening…" : '"${a.partial}"',
      OrbState.thinking => 'Thinking…',
      OrbState.speaking => 'Speaking — tap to interrupt',
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.60);

    return ListenableBuilder(
      listenable: _assistant,
      builder: (context, _) {
        final a = _assistant;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Text(_greeting,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    _caption(a),
                    key: ValueKey(_caption(a)),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, color: muted),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _BloomOrb(
                      state: a.state,
                      pulse: _pulse,
                      onTap: a.tapOrb,
                    ),
                  ),
                ),
                if (a.lastHeard != null) ...[
                  _TranscriptCard(heard: a.lastHeard!, reply: a.lastReply),
                  const SizedBox(height: 12),
                ],
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hearing_rounded,
                          size: 18,
                          color: a.wakeEnabled ? cs.primary : muted),
                      const SizedBox(width: 8),
                      const Text('"Hey Hari" wake word',
                          style: TextStyle(fontSize: 13.5)),
                      Switch(
                        value: a.wakeEnabled && a.micReady,
                        onChanged: a.micReady
                            ? (v) {
                                HapticFeedback.selectionClick();
                                a.setWakeEnabled(v);
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  a.wakeEnabled
                      ? (a.onDeviceWake
                          ? 'On-device wake word · works with screen off'
                          : 'Basic wake word · app must be open')
                      : 'Wake word off · microphone released, saves battery',
                  style: TextStyle(fontSize: 11.5, color: muted),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TranscriptCard extends StatelessWidget {
  final String heard;
  final String? reply;
  const _TranscriptCard({required this.heard, this.reply});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 160),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'HEARD',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.marigold,
              ),
            ),
            const SizedBox(height: 4),
            Text('"$heard"',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (reply != null) ...[
              const SizedBox(height: 8),
              Text(
                reply!,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: cs.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BloomOrb extends StatelessWidget {
  final OrbState state;
  final AnimationController pulse;
  final VoidCallback onTap;

  const _BloomOrb(
      {required this.state, required this.pulse, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final animate = state == OrbState.listening || state == OrbState.speaking;

    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest.shortestSide.clamp(190.0, 290.0);
        return AnimatedBuilder(
          animation: pulse,
          builder: (context, _) {
            final scale = animate ? 1 + (pulse.value * 0.07) : 1.0;
            return SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: scale,
                    child:
                        _ring(size, AppColors.marigold.withValues(alpha: 0.35)),
                  ),
                  _ring(size * 0.82, AppColors.marigold.withValues(alpha: 0.7)),
                  Transform.scale(
                    scale: scale,
                    child: GestureDetector(
                      onTap: onTap,
                      child: Container(
                        width: size * 0.62,
                        height: size * 0.62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            center: Alignment(-0.3, -0.4),
                            colors: [
                              AppColors.peacockLight,
                              AppColors.peacockDeep
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.peacock.withValues(alpha: 0.45),
                              blurRadius: 48,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Icon(
                          switch (state) {
                            OrbState.idle => Icons.mic_none_rounded,
                            OrbState.thinking => Icons.more_horiz_rounded,
                            _ => Icons.graphic_eq_rounded,
                          },
                          size: size * 0.20,
                          color: state == OrbState.speaking
                              ? AppColors.marigold
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _ring(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.5),
        ),
      );
}
