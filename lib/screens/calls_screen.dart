import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Screen 05 — AI Phone Calling (G1–G3), Phase 2.
/// The approval surface: goal, script, AI disclosure and calling rules —
/// nothing dials without the user's tap.
class CallsScreen extends StatelessWidget {
  const CallsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Call preview',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.marigold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('NEEDS APPROVAL',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Callee
        Card(
          color: AppColors.peacock.withValues(alpha: 0.08),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.peacock,
                  child: Text('VR',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Villa Maya Restaurant',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('+91 471 24x xxxx · open now', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Goal + script
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('GOAL',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.peacock)),
                const Text('Book a table for 4 · Saturday 8:00 PM',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Fallback: 7:30 PM or Sunday 8:00 PM',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.ink.withValues(alpha: 0.6))),
                const SizedBox(height: 12),
                const Text("WHAT I'LL SAY",
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.peacock)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.peacock.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                      "“Namaskaram! I'm an AI assistant calling on behalf of Arjun. I'd like to book a table for four this Saturday at 8 PM…”"),
                ),
                const SizedBox(height: 8),
                const Wrap(
                  spacing: 8,
                  children: [
                    _Tag('SPEAKS MALAYALAM'),
                    _Tag('DISCLOSES AI IDENTITY'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Calling rules (G2)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Your calling rules',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Edit',
                        style: TextStyle(
                            color: AppColors.peacock, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _Pill('2 OF 3 CALLS LEFT TODAY'),
                    _Pill('9 AM – 8 PM'),
                    _Pill('BOOKINGS ✓'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Edit script'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: () {}, // telephony wires in Phase 2, Month 6
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                icon: const Icon(Icons.call, size: 18),
                label: const Text('Approve & call'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.peacock.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.peacockDeep)),
      );
}

class _Pill extends StatelessWidget {
  final String label;
  const _Pill(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.mist,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
      );
}
