import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Screen 07 — Smart Home & Routines (I1–I3, H2, H3).
/// Google Home / Matter wiring is Phase 2, Month 7.
class DeviceTile {
  final String emoji;
  final String name;
  String status;
  bool on;
  DeviceTile(this.emoji, this.name, this.status, this.on);
}

class SmartHomeScreen extends StatefulWidget {
  const SmartHomeScreen({super.key});

  @override
  State<SmartHomeScreen> createState() => _SmartHomeScreenState();
}

class _SmartHomeScreenState extends State<SmartHomeScreen> {
  final _devices = [
    DeviceTile('💡', 'Hall lights', 'On · 60%', true),
    DeviceTile('❄️', 'Bedroom AC', '24° · Cooling', true),
    DeviceTile('🚿', 'Geyser', 'On · 18 min', true),
    DeviceTile('🌀', 'Fan · Study', 'Off', false),
  ];
  String _scene = 'Movie night';

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Home',
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
              child: const Text('12 DEVICES ONLINE',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.peacockDeep)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Plain-language status (I3)
        Card(
          color: AppColors.peacock.withValues(alpha: 0.08),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Text('🎙 “Is the geyser on?” — Yes, on for 18 min. Turn it off?'),
          ),
        ),
        const SizedBox(height: 12),

        // Scenes (I2)
        Wrap(
          spacing: 8,
          children: ['🎬 Movie night', '🌅 Good morning', '🛏 Sleep'].map((label) {
            final name = label.substring(label.indexOf(' ') + 1);
            return ChoiceChip(
              label: Text(label),
              selected: _scene == name,
              selectedColor: AppColors.peacockDeep,
              labelStyle: TextStyle(
                  color: _scene == name ? Colors.white : AppColors.ink),
              onSelected: (_) => setState(() => _scene = name),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),

        // Device tiles (I1)
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.5,
          ),
          itemCount: _devices.length,
          itemBuilder: (context, i) {
            final d = _devices[i];
            return Card(
              color: d.on
                  ? AppColors.marigold.withValues(alpha: 0.15)
                  : Colors.white,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() {
                  d.on = !d.on;
                  d.status = d.on ? 'On' : 'Off';
                }),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(d.emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(height: 8),
                      Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(d.status,
                          style: TextStyle(
                              fontSize: 13,
                              color: d.on
                                  ? AppColors.marigold
                                  : AppColors.ink.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),

        // Routines (H2, H3)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ROUTINES',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink.withValues(alpha: 0.5))),
                const SizedBox(height: 8),
                const _RoutineRow('🛒', 'Friday shopping list',
                    'Fri 6 PM · pantry notes → grocery app', 'FRI'),
                const SizedBox(height: 8),
                const _RoutineRow('🏠', 'Leaving office',
                    'Location · navigation + message family', 'ON'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RoutineRow extends StatelessWidget {
  final String emoji, title, subtitle, badge;
  const _RoutineRow(this.emoji, this.title, this.subtitle, this.badge);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji),
        const SizedBox(width: 10),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.peacock.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(badge,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.peacockDeep)),
        ),
      ],
    );
  }
}
