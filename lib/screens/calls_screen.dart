import 'package:flutter/material.dart';
import '../widgets/coming_soon.dart';

/// Screen 05 — AI Phone Calling (G1–G3). Phase-2 flagship.
class CallsScreen extends StatelessWidget {
  const CallsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoon(
      icon: Icons.call_outlined,
      title: 'Calls made for you',
      description:
          'The assistant books tables and appointments over the phone — in '
          'your language. You approve the exact script before dialling, '
          'watch the live transcript, and can take over any time.',
      highlights: ['Approve before dialling', 'Live transcript', 'Calling rules'],
    );
  }
}
