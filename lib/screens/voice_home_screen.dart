import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Screen 01 — Voice Home (A1–A4, M1).
/// The bloom orb with four states: Idle / Listening / Thinking / Speaking.
/// Voice capture wires in later; tapping the orb cycles states for now.
enum OrbState { idle, listening, thinking, speaking }

class VoiceHomeScreen extends StatefulWidget {
  const VoiceHomeScreen({super.key});

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

  String get _caption => switch (_state) {
        OrbState.idle => 'Tap the orb or say "Hey Assistant"',
        OrbState.listening => "I'm listening — speak in any language",
        OrbState.thinking => 'Thinking…',
        OrbState.speaking => 'Speaking — tap to interrupt',
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          Text('Good morning, Arjun',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(_caption,
              style: TextStyle(color: AppColors.ink.withValues(alpha: 0.6))),
          const Spacer(),
          _BloomOrb(
            state: _state,
            pulse: _pulse,
            onTap: () => setState(() {
              _state = OrbState.values[(_state.index + 1) % OrbState.values.length];
            }),
          ),
          const Spacer(),

          // Live transcript card (the Malayalam example from the design)
          Card(
            color: AppColors.peacock.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('HEARD · MALAYALAM',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.marigold)),
                  const SizedBox(height: 4),
                  const Text('“ഇന്ന് വൈകുന്നേരം മഴ പെയ്യുമോ?”',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(
                    'Will it rain this evening? — Yes, light rain is likely in Thiruvananthapuram after 6 pm. Carry an umbrella…',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.ink.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 8,
            children: [
              _Suggestion('☀️ Morning briefing'),
              _Suggestion('📞 Book a table'),
              _Suggestion('✉️ Read inbox'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Suggestion extends StatelessWidget {
  final String label;
  const _Suggestion(this.label);

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: AppColors.ink.withValues(alpha: 0.15)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _BloomOrb extends StatelessWidget {
  final OrbState state;
  final AnimationController pulse;
  final VoidCallback onTap;

  const _BloomOrb({required this.state, required this.pulse, required this.onTap});

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
              child: _ring(230, AppColors.marigold.withValues(alpha: 0.4)),
            ),
            _ring(190, AppColors.marigold.withValues(alpha: 0.7)),
            Transform.scale(
              scale: scale,
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0xFF1A9E96), AppColors.peacockDeep],
                    ),
                  ),
                  child: Icon(
                    state == OrbState.idle ? Icons.mic : Icons.graphic_eq,
                    size: 48,
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
          border: Border.all(color: color),
        ),
      );
}
