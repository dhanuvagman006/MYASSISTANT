import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Screen 08 — Privacy, Memory & Safety (E1–E3, F1–F3). "Trust is a feature."
class Memory {
  final String fact;
  final String meta;
  const Memory(this.fact, this.meta);
}

class Service {
  final String emoji;
  final String name;
  bool connected;
  Service(this.emoji, this.name, this.connected);
}

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _appLock = true;
  final _memories = <Memory>[
    const Memory('Prefers vegetarian restaurants', 'learnt 2 May · used for bookings'),
    const Memory("Wife's birthday — 4 September", 'learnt 11 Jun · reminder set'),
    const Memory('Replies in Malayalam with family', 'learnt 20 Jun'),
  ];
  final _services = [
    Service('✉️', 'Gmail', true),
    Service('📅', 'Google Calendar', true),
    Service('🏠', 'Google Home', false),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Text('Privacy & memory',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        // App lock (F1)
        Card(
          color: AppColors.peacock.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, color: AppColors.peacock),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('App lock is ${_appLock ? "on" : "off"}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Text('Fingerprint or Face ID required to open',
                          style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                Switch(value: _appLock, onChanged: (v) => setState(() => _appLock = v)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Memory manager (E3)
        Text('WHAT I REMEMBER · ${_memories.length} ITEMS',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.ink.withValues(alpha: 0.5))),
        const SizedBox(height: 8),
        ..._memories.map((m) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.fact,
                              style: const TextStyle(fontWeight: FontWeight.w500)),
                          Text(m.meta,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.ink.withValues(alpha: 0.5))),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                      onPressed: () => setState(() => _memories.remove(m)),
                    ),
                  ],
                ),
              ),
            )),
        const SizedBox(height: 8),

        // Connected services (F2)
        Text('CONNECTED SERVICES',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.ink.withValues(alpha: 0.5))),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < _services.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Text(_services[i].emoji),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(_services[i].name,
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                      ),
                      Switch(
                        value: _services[i].connected,
                        onChanged: (v) => setState(() => _services[i].connected = v),
                      ),
                    ],
                  ),
                ),
                if (i < _services.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Export & erase (F2)
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {},
                child: const Text('Export my data'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('Erase everything'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
