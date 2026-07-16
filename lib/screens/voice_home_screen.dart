import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Screen 01 — Voice Home (A1–A4, M1).
/// The bloom orb with four states: Idle / Listening / Thinking / Speaking.
/// Voice capture wires in later; tapping the orb cycles states for now.
/// Theme-aware (light + dark), balanced layout, haptic feedback.
enum OrbState { idle, listening, thinking, speaking }

class VoiceHomeScreen extends StatefulWidget {
  final VoidCallback? onOpenChat;
  const VoiceHomeScreen({super.key, this.onOpenChat});

  @override
  State<VoiceHomeScreen> createState() => _VoiceHomeScreenState();
}

class _VoiceHomeScreenState extends State<VoiceHomeScreen>
    with SingleTickerProviderStateMixin {
  OrbState _state = OrbState.idle;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _caption => switch (_state) {
        OrbState.idle => 'Tap the orb to speak — any language',
        OrbState.listening => "I'm listening…",
        OrbState.thinking => 'Thinking…',
        OrbState.speaking => 'Speaking — tap to interrupt',
      };

  void _tapOrb() {
    HapticFeedback.mediumImpact();
    setState(() {
      _state = OrbState.values[(_state.index + 1) % OrbState.values.length];
    });
  }

  void _tapChip() {
    HapticFeedback.selectionClick();
    widget.onOpenChat?.call();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.60);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(_greeting, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                _caption,
                key: ValueKey(_state),
                style: TextStyle(fontSize: 15, color: muted),
              ),
            ),

            // Orb owns the middle of the screen, always centred
            Expanded(
              child: Center(
                child: _BloomOrb(state: _state, pulse: _pulse, onTap: _tapOrb),
              ),
            ),

            Text('Or type your question instead',
                style: TextStyle(fontSize: 13, color: muted)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final s in const [
                  '💬 Ask anything',
                  '🌐 Translate',
                  '✍️ Help me write',
                ])
                  ActionChip(label: Text(s), onPressed: _tapChip),
              ],
            ),
            const SizedBox(height: 20),
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

    // Scale the whole orb assembly to the space available so rings
    // never crowd small screens or float tiny on large ones.
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest.shortestSide.clamp(220.0, 320.0);
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
                    child: _ring(
                        size, AppColors.marigold.withValues(alpha: 0.35)),
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
