import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Screen 08 — Privacy, Memory & Safety (E1–E3, F1–F3).
/// Real controls only: no fake memories, no fake toggles.
/// Sections light up as their features ship.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.ink.withValues(alpha: 0.55);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Privacy & memory',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text('Trust is a feature. Everything here is yours to control.',
            style: TextStyle(color: muted)),
        const SizedBox(height: 20),
        _Section(
          title: 'WHAT I REMEMBER',
          child: _EmptyRow(
            icon: Icons.auto_awesome_outlined,
            text:
                'Nothing yet. Facts the assistant learns — like preferences '
                'or important dates — will appear here in plain language, '
                'each with its own delete button.',
          ),
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'CONNECTED SERVICES',
          child: Column(
            children: const [
              _ServiceRow(icon: Icons.mail_outline_rounded, name: 'Gmail'),
              Divider(height: 1),
              _ServiceRow(
                  icon: Icons.calendar_month_outlined, name: 'Google Calendar'),
              Divider(height: 1),
              _ServiceRow(icon: Icons.home_outlined, name: 'Google Home'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'YOUR DATA',
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Full export and permanent deletion will live here — one '
                  'screen deep, no dark patterns.',
                  style: TextStyle(color: muted, height: 1.5),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: null,
                        child: const Text('Export my data'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                        ),
                        child: const Text('Erase everything'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: AppColors.ink.withValues(alpha: 0.45),
            ),
          ),
        ),
        Card(child: child),
      ],
    );
  }
}

class _EmptyRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.peacock),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: AppColors.ink.withValues(alpha: 0.6), height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  final IconData icon;
  final String name;
  const _ServiceRow({required this.icon, required this.name});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.peacockDeep),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.mist,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('Not connected',
            style: TextStyle(
                fontSize: 12, color: AppColors.ink.withValues(alpha: 0.5))),
      ),
    );
  }
}
