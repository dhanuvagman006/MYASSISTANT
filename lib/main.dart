import 'package:flutter/material.dart';

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
      const VoiceHomeScreen(),
      const ChatScreen(),
      const TodayHub(),
      const CallsScreen(),
      const PrivacyScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('MyAssistant',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [UpdateButton(config: _config)],
      ),
      body: Column(
        children: [
          // Server-pushed announcement — appears with no app release
          if (_config.announcement != null)
            Card(
              margin: const EdgeInsets.all(12),
              color: AppColors.marigold.withValues(alpha: 0.15),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_config.announcement!),
              ),
            ),
          Expanded(child: pages[_tab]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.adjust), label: 'Assistant'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.wb_sunny_outlined), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.call), label: 'Calls'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'You'),
        ],
      ),
    );
  }
}

/// The designs show Daily, Inbox and Smart Home all under the sun tab —
/// so it's a hub with segments.
class TodayHub extends StatefulWidget {
  const TodayHub({super.key});

  @override
  State<TodayHub> createState() => _TodayHubState();
}

class _TodayHubState extends State<TodayHub> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    const pages = [DailyScreen(), InboxScreen(), SmartHomeScreen(), DocumentsScreen()];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Daily')),
              ButtonSegment(value: 1, label: Text('Inbox')),
              ButtonSegment(value: 2, label: Text('Home')),
              ButtonSegment(value: 3, label: Text('Docs')),
            ],
            selected: {_segment},
            onSelectionChanged: (s) => setState(() => _segment = s.first),
          ),
        ),
        Expanded(child: pages[_segment]),
      ],
    );
  }
}
