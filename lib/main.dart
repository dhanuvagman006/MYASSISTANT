import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design/neon_tokens.dart';
import 'design/neon_widgets.dart';
import 'features/assistant/assistant_screen.dart';
import 'models/remote_config.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/calls_screen.dart';
import 'screens/daily_screen.dart';
import 'screens/documents_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/interview_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/privacy_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'services/app_strings.dart';
import 'services/app_lock.dart';
import 'services/auth_service.dart';
import 'services/style_prefs.dart';
import 'widgets/style_settings_sheet.dart';
import 'theme/app_theme.dart';
import 'widgets/update_button.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Neon V2 is dark-first: paint the system bars to match the backdrop.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Neon.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  // Style + language prefs load in parallel with the first frame; every
  // later read is a plain field access (no disk on hot paths).
  StylePrefs.instance.load();
  AppLock.instance.init(); // F1 — resolves before AuthGate finishes restoring
  runApp(const MyAssistantApp());
}

class MyAssistantApp extends StatelessWidget {
  const MyAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyAssistant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark, // dark-first, always
      home: const AuthGate(),
    );
  }
}

/// Decides the first screen: splash while restoring the session, then
/// AuthScreen (signed out) or HomeShell (signed in). Listens to
/// AuthService so sign-in and sign-out swap screens automatically.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  bool _restoring = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // F1 — relock on background
    AppLock.instance.addListener(_onAuthChanged);
    AuthService.instance.addListener(_onAuthChanged);
    AuthService.instance.init().whenComplete(() {
      if (mounted) setState(() => _restoring = false);
    });
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_onAuthChanged);
    AppLock.instance.removeListener(_onAuthChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Ask again whenever the app leaves the foreground (F1).
    if (state == AppLifecycleState.paused) AppLock.instance.relock();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_restoring) return const SplashScreen();
    final auth = AuthService.instance;
    if (!auth.isSignedIn) return const AuthScreen();
    // F1 — optional fingerprint/PIN wall in front of everything.
    if (AppLock.instance.shouldLock) return const LockScreen();
    // Brand-new account → one-time interview so Hari learns the basics
    // (skippable), THEN the home shell.
    if (auth.lastSignInWasNew) {
      return InterviewScreen(
        onDone: () => setState(() => auth.lastSignInWasNew = false),
      );
    }
    return const HomeShell();
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
    // A3 — re-render menus instantly when the app language changes.
    StylePrefs.instance.addListener(_onPrefs);
  }

  void _onPrefs() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    StylePrefs.instance.removeListener(_onPrefs);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const AssistantScreen(),
      const TodayHub(),
      const CallsScreen(),
      const PrivacyScreen(),
    ];

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Row(
          children: [
            // Brand mark — signature sweep-gradient orb ring
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: Neon.gOrb,
                boxShadow: Neon.glow(Neon.violet, blur: 12, alpha: 0.5),
              ),
              padding: const EdgeInsets.all(2),
              child: const DecoratedBox(
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: Neon.bg),
              ),
            ),
            const SizedBox(width: 10),
            GradientText(
              'MyAssistant',
              style: Theme.of(context).textTheme.titleLarge!,
              gradient: Neon.gVioletCyan,
            ),
          ],
        ),
        actions: [
          UpdateButton(config: _config),
          IconButton(
            tooltip: S.t('settings'),
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => showStyleSettingsSheet(context),
          ),
          IconButton(
            tooltip: S.t('sign_out'),
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(S.t('sign_out_q')),
                  content: Text(S.t('sign_out_body')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(S.t('cancel'))),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(S.t('sign_out'))),
                  ],
                ),
              );
              if (ok == true) await AuthService.instance.signOut();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: NeonBackdrop(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Server-pushed announcement — appears with no app release
              if (_config.announcement != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Neon.s4, Neon.s1, Neon.s4, Neon.s2),
                  child: GlassCard(
                    tint: Neon.warning,
                    child: Row(
                      children: [
                        const Icon(Icons.campaign_outlined,
                            color: Neon.warning, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_config.announcement!)),
                      ],
                    ),
                  ),
                ),
              Expanded(child: pages[_tab]),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          HapticFeedback.selectionClick();
          setState(() => _tab = i);
        },
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.adjust_rounded),
              label: S.t('tab_assistant')),
          NavigationDestination(
              icon: const Icon(Icons.wb_sunny_outlined),
              label: S.t('tab_today')),
          NavigationDestination(
              icon: const Icon(Icons.call_outlined), label: S.t('tab_calls')),
          NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              label: S.t('tab_you')),
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
    // Smart Home's "coming soon" placeholder was RETIRED (it promised a
    // feature that doesn't exist yet — dead weight in the hub). The screen
    // returns as a real tab when Google Home / Matter lands (Phase 2);
    // restore from git history: screens/smart_home_screen.dart.
    const pages = [DailyScreen(), InboxScreen(), DocumentsScreen()];

    return Column(
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: Neon.s4, vertical: Neon.s2),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Daily')),
              ButtonSegment(value: 1, label: Text('Inbox')),
              ButtonSegment(value: 2, label: Text('Docs')),
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
