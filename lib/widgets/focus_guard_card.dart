import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// FOCUS GUARD — "Smart Calendar & Energy Defender".
/// Shows only when today/tomorrow has a back-to-back meeting stretch
/// over 3 hours. One tap previews a 30-min focus/rest buffer; the event
/// is created ONLY after the user approves (D3 rule). Silent when the
/// calendar isn't linked, the day is light, or the request fails.
class FocusGuardCard extends StatefulWidget {
  const FocusGuardCard({super.key});

  @override
  State<FocusGuardCard> createState() => _FocusGuardCardState();
}

class _FocusGuardCardState extends State<FocusGuardCard> {
  Map<String, dynamic>? _plan;
  bool _booked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final plan = await ApiService.fetchFocusPlan(days: 2);
    if (!mounted) return;
    setState(() => _plan = plan);
  }

  String _hhmm(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final ap = d.hour >= 12 ? 'PM' : 'AM';
    return '$h:${d.minute.toString().padLeft(2, '0')} $ap';
  }

  Future<void> _bookBuffer(Map<String, dynamic> buffer) async {
    final startMs = (buffer['startMs'] as num).toInt();
    final endMs = (buffer['endMs'] as num).toInt();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block a break?'),
        content: Text(
            'Add a 30-minute focus/rest buffer to your calendar at '
            '${_hhmm(startMs)}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add it')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await ApiService.createCalendarEvent(
        title: 'Focus buffer — held by Hari',
        startMs: startMs,
        endMs: endMs,
        description:
            'Added after a long back-to-back meeting stretch. Breathe.',
      );
      if (!mounted) return;
      setState(() => _booked = true);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Break added to your calendar')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final runs = (plan?['runs'] as List?) ?? const [];
    if (plan == null || runs.isEmpty) return const SizedBox.shrink();

    final run = runs.first as Map<String, dynamic>;
    final buffers = (plan['buffers'] as List?) ?? const [];
    final resched = (plan['reschedule'] as List?) ?? const [];
    final hours = ((run['totalMin'] as num) / 60).toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: AppColors.marigold.withValues(alpha: 0.10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.battery_alert_rounded,
                      color: AppColors.marigold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$hours hrs back-to-back — ${run['meetings']} meetings '
                      'from ${_hhmm((run['startMs'] as num).toInt())}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              if (resched.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Lightest to move: "${(resched.first as Map)['title']}" '
                    '(${(resched.first as Map)['reason']})',
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.65)),
                  ),
                ),
              if (buffers.isNotEmpty && !_booked)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () =>
                        _bookBuffer(buffers.first as Map<String, dynamic>),
                    icon: const Icon(Icons.free_breakfast_rounded, size: 18),
                    label: Text(
                        'Block 30 min at '
                        '${_hhmm(((buffers.first as Map)['startMs'] as num).toInt())}'),
                  ),
                ),
              if (_booked)
                const Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('Break booked ✓',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
