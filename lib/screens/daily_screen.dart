import 'package:flutter/material.dart';
import '../widgets/coming_soon.dart';

/// Screen 03 — Daily & Morning Briefing (C1, C2, D3, D4).
/// Shows real calendar, weather, reminders and headlines once those
/// data sources are connected. No mock data.
class DailyScreen extends StatelessWidget {
  const DailyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoon(
      icon: Icons.wb_sunny_outlined,
      title: 'Your day, in one glance',
      description:
          'Calendar with meeting prep, weather, reminders and headlines — '
          'read aloud in your language on request. Appears here once '
          'Google Calendar is connected.',
      highlights: ['Play briefing', 'Meeting prep', 'Voice reminders'],
    );
  }
}
