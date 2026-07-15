import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Screen 06 — Inbox Summary & Smart Replies (D1, D2, H1).
/// Gmail wiring comes with Google's API verification (Month 2–3).
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  bool _autoRules = true;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Inbox digest',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.peacock.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('GMAIL ✓',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.peacockDeep)),
            ),
          ],
        ),
        Text('14 unread → 3 need you, 6 newsletters archived on your rule.',
            style: TextStyle(fontSize: 13, color: AppColors.ink.withValues(alpha: 0.6))),
        const SizedBox(height: 12),

        // Urgent email with draft reply (D2)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: AppColors.peacock,
                      child: Text('PK',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Priya K. · Landlord',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('Re: Lease renewal — asks to confirm by Friday',
                              style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE5E5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('URGENT',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.danger)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.peacock.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                      'Draft ready: “Hi Priya, yes — we\'d like to renew. Could we discuss the 7% increase? Free to talk Thu evening.”'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () {},
                        child: const Text('Approve & send'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(onPressed: () {}, child: const Text('Edit')),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Bill card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: AppColors.marigold,
                      child: Text('HD',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('HDFC Bank',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('Credit card statement · ₹23,410 due 19 July',
                              style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.marigold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('BILL',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                        onPressed: () {}, child: const Text('⏰ Remind on 18th')),
                    OutlinedButton(
                        onPressed: () {}, child: const Text('💳 Prepare UPI')),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Auto-reply rules with the master kill switch (H1)
        Card(
          color: AppColors.peacock.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Auto-reply rules',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const Text('2 active · “Driving → reply to family” sent 1 today',
                          style: TextStyle(fontSize: 13)),
                      Text('View log · Master switch ${_autoRules ? "ON" : "OFF"}',
                          style: const TextStyle(
                              color: AppColors.peacock, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Switch(
                  value: _autoRules,
                  onChanged: (v) => setState(() => _autoRules = v),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
