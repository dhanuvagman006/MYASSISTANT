import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Screen 01 — Voice Home (A1–A4, M1).
/// The bloom orb with four states: Idle / Listening / Thinking / Speaking.
/// Voice capture wires in later; tapping the orb cycles states for now.
/// No mock data: greeting is time-based, transcript appears only when real.
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

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.ink.withValues(alpha: 0.55);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text(_greeting, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(_caption,
                key: ValueKey(_state), style: TextStyle(color: muted)),
          ),
          const Spacer(),
          _BloomOrb(
            state: _state,
            pulse: _pulse,
            onTap: () => setState(() {
              _state =
                  OrbState.values[(_state.index + 1) % OrbState.values.length];
            }),
          ),
          const Spacer(),
          Text('Or type your question instead',
              style: TextStyle(fontSize: 13, color: muted)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _Suggestion('💬 Ask anything', onTap: widget.onOpenChat),
              _Suggestion('🌐 Translate', onTap: widget.onOpenChat),
              _Suggestion('✍️ Help me write', onTap: widget.onOpenChat),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Suggestion extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _Suggestion(this.label, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Colors.white,
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

    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final scale = animate ? 1 + (pulse.value * 0.08) : 1.0;
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: scale,
              child: _ring(250, AppColors.marigold.withValues(alpha: 0.35)),
            ),
            _ring(205, AppColors.marigold.withValues(alpha: 0.7)),
            Transform.scale(
              scale: scale,
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(-0.3, -0.4),
                      colors: [AppColors.peacockLight, AppColors.peacockDeep],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.peacock.withValues(alpha: 0.35),
                        blurRadius: 40,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Icon(
                    switch (state) {
                      OrbState.idle => Icons.mic_none_rounded,
                      OrbState.thinking => Icons.more_horiz_rounded,
                      _ => Icons.graphic_eq_rounded,
                    },
                    size: 54,
                    color: state == OrbState.speaking
                        ? AppColors.marigold
                        : Colors.white,
                  ),
                ),
              ),
            ),
          ],
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
