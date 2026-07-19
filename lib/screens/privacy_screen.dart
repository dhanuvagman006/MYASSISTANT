import 'package:flutter/material.dart';
import '../models/memory_item.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

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
        const _MemorySection(),
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
