import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/remote_config.dart';
import 'screens/calls_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/daily_screen.dart';
import 'screens/documents_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/privacy_screen.dart';
import 'screens/smart_home_screen.dart';
import 'screens/voice_home_screen.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';
import 'widgets/update_button.dart';

void main() => runApp(const MyAssistantApp());

class MyAssistantApp extends StatelessWidget {
  const MyAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyAssistant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  RemoteConfig _config = const RemoteConfig();

  @override
  void initState() {
    super.initState();
    // Fetch the update switchboard on every launch
    ApiService.refreshConfig().then((c) {
      if (mounted) setState(() => _config = c);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      VoiceHomeScreen(onOpenChat: () => setState(() => _tab = 1)),
      const ChatScreen(),
      const TodayHub(),
      const CallsScreen(),
      const PrivacyScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // Brand mark — marigold ring around a peacock dot
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.marigold, width: 2.5),
              ),
              child: Center(
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.peacock,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text('MyAssistant'),
          ],
        ),
        actions: [UpdateButton(config: _config), const SizedBox(width: 8)],
      ),
      body: Column(
        children: [
          // Server-pushed announcement — appears with no app release
          if (_config.announcement != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.marigold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.campaign_outlined,
                        color: Color(0xFFB27107), size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_config.announcement!)),
                  ],
                ),
              ),
            ),
          Expanded(child: pages[_tab]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          HapticFeedback.selectionClick();
          setState(() => _tab = i);
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.adjust_rounded), label: 'Assistant'),
          NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded), label: 'Chat'),
          NavigationDestination(
              icon: Icon(Icons.wb_sunny_outlined), label: 'Today'),
          NavigationDestination(
              icon: Icon(Icons.call_outlined), label: 'Calls'),
          NavigationDestination(
              icon: Icon(Icons.person_outline_rounded), label: 'You'),
        ],
      ),
    );
  }
}

/// Daily, Inbox, Home and Docs live under the sun tab as a hub.
class TodayHub extends StatefulWidget {
  const TodayHub({super.key});

  @override
  State<TodayHub> createState() => _TodayHubState();
}

class _TodayHubState extends State<TodayHub> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    const pages = [
      DailyScreen(),
      InboxScreen(),
      SmartHomeScreen(),
      DocumentsScreen()
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SegmentedButton<int>(
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
              selectedForegroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
              side: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.12)),
            ),
            segments: const [
              ButtonSegment(value: 0, label: Text('Daily')),
              ButtonSegment(value: 1, label: Text('Inbox')),
              ButtonSegment(value: 2, label: Text('Home')),
              ButtonSegment(value: 3, label: Text('Docs')),
            ],
            selected: {_segment},
            onSelectionChanged: (s) {
              HapticFeedback.selectionClick();
              setState(() => _segment = s.first);
            },
          ),
        ),
        Expanded(child: pages[_segment]),
      ],
    );
  }
}
