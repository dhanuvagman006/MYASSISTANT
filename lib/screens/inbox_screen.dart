import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Screen — Inbox (Gmail, read-only). Two states:
///   • Not connected → one-tap "Connect Gmail & Calendar" (Google OAuth,
///     read-only scopes; the backend keeps the tokens, never the app).
///   • Connected → recent primary-inbox emails; unread bolded with a
///     marigold dot. Ask Hari "any new emails?" for the spoken version.
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  List<Map<String, dynamic>>? _emails; // null = not linked
  bool _loading = true;
  bool _linking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final emails = await ApiService.fetchGmailInbox();
      if (mounted) {
        setState(() {
          _emails = emails;
          _loading = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load your inbox. Pull down to retry.';
        });
      }
    }
  }

  Future<void> _connect() async {
    HapticFeedback.selectionClick();
    setState(() => _linking = true);
    try {
      await AuthService.instance.linkGoogleData();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  Future<void> _disconnect() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect Google?'),
        content: const Text(
            'Hari will lose access to your Gmail and Calendar. You can '
            'reconnect any time.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ApiService.disconnectGoogle();
    if (mounted) setState(() => _emails = null);
  }

  String _when(Map<String, dynamic> e) {
    final ms = (e['date'] as num?)?.toInt();
    if (ms == null) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    if (d.day == now.day && d.month == now.month && d.year == now.year) {
      return TimeOfDay.fromDateTime(d).format(context);
    }
    return '${d.day}/${d.month}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.6);

    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }

    // ---------- NOT CONNECTED ----------
    if (_emails == null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 32),
          Icon(Icons.mark_email_unread_outlined,
              size: 56, color: AppColors.peacock),
          const SizedBox(height: 16),
          Text('Your inbox, spoken',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            _error ??
                'Connect Gmail and Calendar (read-only) and Hari can tell '
                    'you about new emails and today\'s meetings — just ask '
                    '"any new emails?" or "what\'s on my calendar?"',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, height: 1.5),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _linking ? null : _connect,
            icon: _linking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.link_rounded),
            label: const Text('Connect Gmail & Calendar'),
          ),
          const SizedBox(height: 10),
          Text(
            'Read-only. Tokens stay on your server — never in the app. '
            'Disconnect any time.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ],
      );
    }

    // ---------- CONNECTED ----------
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text('RECENT · PRIMARY',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: cs.onSurface.withValues(alpha: 0.45))),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Disconnect Google',
                icon: Icon(Icons.link_off_rounded, size: 19, color: muted),
                onPressed: _disconnect,
              ),
            ],
          ),
          if (_emails!.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No emails in the last 3 days. Peace! 🌿',
                    style: TextStyle(color: muted)),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < _emails!.length; i++) ...[
                    ListTile(
                      leading: (_emails![i]['unread'] == true)
                          ? const Icon(Icons.circle,
                              size: 10, color: AppColors.marigold)
                          : Icon(Icons.circle_outlined,
                              size: 10,
                              color: cs.onSurface.withValues(alpha: 0.25)),
                      title: Text(
                        _emails![i]['from']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: (_emails![i]['unread'] == true)
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _emails![i]['subject']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            _emails![i]['snippet']?.toString() ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12.5, color: muted, height: 1.35),
                          ),
                        ],
                      ),
                      trailing: Text(_when(_emails![i]),
                          style: TextStyle(fontSize: 11.5, color: muted)),
                    ),
                    if (i < _emails!.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
