import 'package:flutter/material.dart';
import '../widgets/coming_soon.dart';

/// Screen 07 — Smart Home & Routines (I1–I3, H2, H3). Phase 2.
class SmartHomeScreen extends StatelessWidget {
  const SmartHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoon(
      icon: Icons.home_outlined,
      title: 'Your home, in plain words',
      description:
          '"Is the geyser on?" answered instantly. Control every Google '
          'Home / Matter device, build routines by describing them. '
          'Appears here once Google Home is connected.',
      highlights: ['Ask in plain words', 'One-tap scenes', 'Routines'],
    );
  }
}
