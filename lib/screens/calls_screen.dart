import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../services/call_service.dart';
import '../theme/app_theme.dart';

/// Screen — Calls (B1). LIVE:
///   • Search your contacts, tap to call (direct on Android).
///   • Starred contacts pinned on top as Favourites.
///   • Or just say: "Hey Hari, call amma."
class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  final _search = TextEditingController();
  List<Contact>? _contacts; // null = loading / no permission yet
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final ok = await CallService.instance.ensurePermission();
    if (!ok) {
      if (mounted) setState(() => _denied = true);
      return;
    }
    final all = await FlutterContacts.getContacts(withProperties: true);
    all.removeWhere((c) => c.phones.isEmpty);
    all.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    if (mounted) setState(() => _contacts = all);
  }

  Future<void> _call(Contact c) async {
    HapticFeedback.mediumImpact();
    final svc = CallService.instance;
    if (c.phones.length == 1) {
      await svc.call(c.phones.first.number);
      return;
    }
    // Several numbers: let the user pick.
    final number = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in c.phones)
              ListTile(
                leading: const Icon(Icons.call_rounded,
                    color: AppColors.peacock),
                title: Text(p.number),
                subtitle: Text(p.label.name),
                onTap: () => Navigator.pop(ctx, p.number),
              ),
          ],
        ),
      ),
    );
    if (number != null) await svc.call(number);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.6);

    if (_denied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.perm_contact_calendar_outlined,
                  size: 52, color: muted),
              const SizedBox(height: 14),
              Text(
                'Hari needs contact access to make calls.\nAllow it in '
                'system settings, then come back.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, height: 1.5),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  setState(() => _denied = false);
                  _load();
                },
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_contacts == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }

    final q = _search.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _contacts!
        : _contacts!
            .where((c) =>
                c.displayName.toLowerCase().contains(q) ||
                c.phones.any((p) => p.number.contains(q)))
            .toList();
    final favs = q.isEmpty
        ? filtered.where((c) => c.isStarred).toList()
        : const <Contact>[];

    Widget row(Contact c) => ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.peacock.withValues(alpha: 0.12),
            child: Text(
              c.displayName.isNotEmpty ? c.displayName[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: AppColors.peacock, fontWeight: FontWeight.w700),
            ),
          ),
          title: Text(c.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(c.phones.first.number,
              style: TextStyle(fontSize: 12.5, color: muted)),
          trailing: IconButton(
            icon: const Icon(Icons.call_rounded, color: AppColors.peacock),
            onPressed: () => _call(c),
          ),
          onTap: () => _call(c),
        );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Search contacts — or say "Hey Hari, call amma"',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: q.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: _search.clear)
                  : null,
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text('No contacts found',
                      style: TextStyle(color: muted)))
              : ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    if (favs.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                        child: Text('FAVOURITES',
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                                color: cs.onSurface.withValues(alpha: 0.45))),
                      ),
                      ...favs.map(row),
                      const Divider(),
                    ],
                    ...filtered.map(row),
                  ],
                ),
        ),
      ],
    );
  }
}
