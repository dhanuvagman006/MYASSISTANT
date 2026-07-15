import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Screen 03 — Daily & Morning Briefing (C1, C2, D3, D4). Mock data for now.
class DailyScreen extends StatelessWidget {
  const DailyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text('MONDAY 13 JULY · 3 EVENTS · 2 REMINDERS',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.ink.withValues(alpha: 0.5))),
              ],
            ),
            FilledButton.tonalIcon(
              onPressed: () {}, // text-to-speech briefing wires in later
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Play briefing'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Weather
        Card(
          color: AppColors.marigold.withValues(alpha: 0.15),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Text('⛅', style: TextStyle(fontSize: 32)),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('29° Partly cloudy',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('Light rain after 6 pm — leave early for badminton',
                          style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Next meeting + prep card (D4)
        Card(
          color: AppColors.peacock.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('NEXT · 11:00 AM',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.peacock)),
                    Text('Google Meet',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.ink.withValues(alpha: 0.5))),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Design review — MYASSISTANT',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Text('with Priya, Suresh · 45 min',
                    style: TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MEETING PREP',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.peacock)),
                      Text(
                          'Priya sent revised flows on Fri; Suresh asked about the call-preview screen. 2 emails attached →',
                          style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Reminders (C1)
        Card(
          child: Column(
            children: const [
              _ReminderRow('Pay electricity bill', 'Today · ₹2,140 due', '6 PM'),
              Divider(height: 1),
              _ReminderRow('Call Amma', 'Tomorrow · 8:00 AM', null),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Headlines (C2)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HEADLINES FOR YOU',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink.withValues(alpha: 0.5))),
                const SizedBox(height: 8),
                const Text('Kerala monsoon arrives early this year',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('UPI adds cross-border payments to UAE',
                    style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppColors.ink.withValues(alpha: 0.7))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReminderRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? badge;
  const _ReminderRow(this.title, this.subtitle, this.badge);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.notifications_none, color: AppColors.peacock),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 13, color: AppColors.ink.withValues(alpha: 0.6))),
              ],
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.marigold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(badge!,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}
