import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/memory_item.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'upgrade_screen.dart';

/// Screen 08 — Privacy, Memory & Safety (E1–E3, F1–F3).
/// Real controls only: no fake memories, no fake toggles.
/// Sections light up as their features ship.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.60);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Privacy & memory',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text('Trust is a feature. Everything here is yours to control.',
            style: TextStyle(color: muted)),
        const SizedBox(height: 20),
        // Plan & usage — the money screen: current tier, allowances,
        // Razorpay upgrade, family invite/join.
        Card(
          child: ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Plan & usage'),
            subtitle: const Text('Your allowances, Pro & Family upgrades'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const UpgradeScreen())),
          ),
        ),
        const SizedBox(height: 16),
        const _MemorySection(),
        const SizedBox(height: 16),
        _Section(
          title: 'CONNECTED SERVICES',
          child: Column(
            children: const [
              _SwiggyRow(),
              Divider(height: 1),
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

/// LIVE "WHAT I REMEMBER" — every fact Hari knows about this account,
/// in plain language, each with its own delete button, plus "teach me
/// something" and "forget everything". No hidden state: this list IS
/// the memory the AI reads on every reply.
class _MemorySection extends StatefulWidget {
  const _MemorySection();

  @override
  State<_MemorySection> createState() => _MemorySectionState();
}

class _MemorySectionState extends State<_MemorySection> {
  List<MemoryItem>? _items; // null = loading
  String? _error;

  static const _categoryIcons = {
    'profile': Icons.person_outline_rounded,
    'preference': Icons.favorite_outline_rounded,
    'fact': Icons.auto_awesome_outlined,
    'context': Icons.push_pin_outlined,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await ApiService.fetchMemories();
      if (mounted) setState(() { _items = items; _error = null; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _items = [];
          _error = ApiService.sessionToken == null
              ? 'Sign in to see what Hari remembers about you.'
              : 'Could not load memories. Pull to retry later.';
        });
      }
    }
  }

  Future<void> _forget(MemoryItem m) async {
    setState(() => _items!.removeWhere((x) => x.id == m.id));
    try {
      await ApiService.deleteMemory(m.id);
    } catch (_) {
      _load(); // restore truth from the server on failure
    }
  }

  Future<void> _forgetAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forget everything?'),
        content: const Text(
            'Hari will permanently delete every remembered fact and start '
            'fresh. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Forget everything'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _items = []);
    try {
      await ApiService.clearMemories();
    } catch (_) {
      _load();
    }
  }

  Future<void> _teach() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Teach Hari something'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 200,
          decoration: const InputDecoration(
            hintText: 'e.g. I am vegetarian, my sister is Ananya…',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Remember'),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;
    try {
      // Key from the first few words; the value is the full sentence.
      final key = text.split(RegExp(r'\s+')).take(4).join('_');
      await ApiService.addMemory(key, text, category: 'fact');
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save — are you signed in?')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.60);

    Widget body;
    if (_items == null) {
      body = const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    } else if (_error != null) {
      body = _EmptyRow(icon: Icons.cloud_off_rounded, text: _error!);
    } else if (_items!.isEmpty) {
      body = const _EmptyRow(
        icon: Icons.auto_awesome_outlined,
        text: 'Nothing yet. Facts Hari learns — like preferences or '
            'important dates — will appear here in plain language, each '
            'with its own delete button.',
      );
    } else {
      body = Column(
        children: [
          for (final m in _items!) ...[
            ListTile(
              dense: true,
              leading: Icon(
                  _categoryIcons[m.category] ?? Icons.auto_awesome_outlined,
                  size: 20,
                  color: AppColors.peacock),
              title: Text(m.title,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600)),
              subtitle: Text(m.value,
                  style: TextStyle(fontSize: 13, color: muted, height: 1.35)),
              trailing: IconButton(
                tooltip: 'Forget this',
                icon: Icon(Icons.close_rounded, size: 18, color: muted),
                onPressed: () => _forget(m),
              ),
            ),
            if (m != _items!.last) const Divider(height: 1),
          ],
        ],
      );
    }

    return _Section(
      title: 'WHAT I REMEMBER',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          body,
          if (_items != null && _error == null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _teach,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Teach Hari something'),
                  ),
                  const Spacer(),
                  if (_items!.isNotEmpty)
                    TextButton(
                      onPressed: _forgetAll,
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger),
                      child: const Text('Forget all'),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
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
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
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
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                    height: 1.5)),
          ),
        ],
      ),
    );
  }
}

/// LIVE Swiggy row — connect once, then "Hey Hari, order a pizza" works.
/// The link happens in the BROWSER (Swiggy phone + OTP via OAuth); when the
/// user comes back to the app we re-check status automatically.
class _SwiggyRow extends StatefulWidget {
  const _SwiggyRow();

  @override
  State<_SwiggyRow> createState() => _SwiggyRowState();
}

class _SwiggyRowState extends State<_SwiggyRow> with WidgetsBindingObserver {
  bool? _linked; // null = loading
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Returning from the browser after OTP → status may have changed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final linked = await ApiService.swiggyLinked();
    if (mounted) setState(() => _linked = linked);
  }

  Future<void> _connect() async {
    setState(() => _busy = true);
    try {
      final url = await ApiService.swiggyConnectUrl();
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Swiggy link is unavailable right now — '
                  'please try again in a moment.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Disconnect Swiggy?'),
        content: const Text(
            'Hari will no longer be able to order food for you by voice.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Disconnect')),
        ],
      ),
    );
    if (sure != true) return;
    setState(() => _busy = true);
    await ApiService.disconnectSwiggy();
    if (mounted) setState(() => _busy = false);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Widget trailing;
    if (_linked == null || _busy) {
      trailing = const SizedBox(
          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2));
    } else if (_linked == true) {
      trailing = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.peacock.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('Connected',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.peacock)),
      );
    } else {
      trailing = FilledButton.tonal(
        onPressed: _connect,
        style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 14)),
        child: const Text('Connect'),
      );
    }
    return ListTile(
      leading: Icon(Icons.lunch_dining_outlined, color: scheme.primary),
      title: const Text('Swiggy',
          style: TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        _linked == true
            ? 'Say "order a pizza" and Hari handles it'
            : 'Let Hari order food by voice',
        style: TextStyle(
            fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.55)),
      ),
      trailing: trailing,
      onTap: _linked == true ? _disconnect : null,
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
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('Not connected',
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5))),
      ),
    );
  }
}
