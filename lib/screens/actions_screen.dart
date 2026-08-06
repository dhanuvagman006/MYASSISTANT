import 'package:flutter/material.dart';

import '../models/action_entry.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// ACTIVITY LOG — the user-facing half of the audit trail (Phase 1 ·
/// ADR-004 "audit before autonomy"). Every order placed, call dialed,
/// event created, draft written, document saved or deleted, reminder set
/// or removed — newest first, nothing hidden. Trust is a feature.
///
/// States handled: loading, error (retry), empty, list, paging (load
/// more on scroll end), pull-to-refresh.
class ActionsScreen extends StatefulWidget {
  const ActionsScreen({super.key});

  @override
  State<ActionsScreen> createState() => _ActionsScreenState();
}

class _ActionsScreenState extends State<ActionsScreen> {
  final _scroll = ScrollController();
  final List<ActionEntry> _items = [];
  bool _loading = true; // first page
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  static const _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    _refresh();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _error = null;
      _loading = _items.isEmpty; // silent refresh when we already show data
    });
    try {
      final page = await ApiService.fetchActions(limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page);
        _hasMore = page.length == _pageSize;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_items.isEmpty) {
          _error = 'Could not load your activity. Pull down to retry.';
        }
      });
    }
  }

  void _maybeLoadMore() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scroll.position.extentAfter > 300) return;
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_items.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ApiService.fetchActions(
          before: _items.last.id, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _items.addAll(page);
        _hasMore = page.length == _pageSize;
      });
    } catch (_) {
      // Quietly stop paging; pull-to-refresh recovers.
      if (mounted) setState(() => _hasMore = false);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity log')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.60);

    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      // Inside a scrollable so pull-to-refresh works on the error state too.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Icon(Icons.cloud_off_rounded, size: 44, color: muted),
          const SizedBox(height: 12),
          Center(child: Text(_error!, style: TextStyle(color: muted))),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [
          const SizedBox(height: 96),
          Icon(Icons.verified_user_outlined, size: 44, color: muted),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Nothing yet. When Hari does something for you — sets a '
              'reminder, saves a document, places an order or a call — '
              'it will be listed here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, height: 1.5),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _items.length + (_loadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
      itemBuilder: (context, i) {
        if (i >= _items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final a = _items[i];
        return ListTile(
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: (a.isDestructive
                    ? AppColors.danger
                    : Theme.of(context).colorScheme.primary)
                .withValues(alpha: 0.12),
            child: Icon(a.icon,
                size: 19,
                color: a.isDestructive
                    ? AppColors.danger
                    : Theme.of(context).colorScheme.primary),
          ),
          title: Text(a.title,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: a.detail.isEmpty
              ? null
              : Text(a.detail, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: Text(_when(a.at), style: TextStyle(color: muted, fontSize: 12)),
        );
      },
    );
  }

  /// Compact, spoken-feeling timestamps: 'now', '5m', '3h', 'Tue', '12 Jan'.
  static String _when(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) {
      const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return wd[t.weekday - 1];
    }
    const mo = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${t.day} ${mo[t.month - 1]}';
  }
}
