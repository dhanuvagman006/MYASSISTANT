import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/reminder.dart';
import '../services/api_service.dart';
import '../services/assistant_controller.dart';
import '../services/notification_service.dart';
import '../widgets/nearby_section.dart';
import '../widgets/focus_guard_card.dart';
import '../theme/app_theme.dart';
import 'upgrade_screen.dart';
import 'meeting_notes_screen.dart';
import 'package:video_player/video_player.dart';

/// Screen 03 — Daily briefing (C1, C2, D3, D4). Now LIVE:
///   • Weather card (Open-Meteo via backend, last GPS fix or memory city)
///   • Reminders — synced with the backend; the same list Hari fills when
///     you say "remind me to…". Add, complete, delete; notifications
///     re-schedule on every change.
///   • Top headlines (Google News via backend).
class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  Map<String, dynamic>? _weather;
  List<Reminder>? _reminders;
  List<Map<String, dynamic>> _news = const [];
  List<Map<String, dynamic>>? _events; // null = Calendar not linked
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      ApiService.fetchWeather(),
      ReminderNotifications.instance.sync(),
      ApiService.fetchNews(),
      ApiService.fetchCalendarEvents(days: 2),
    ]);
    if (!mounted) return;
    setState(() {
      _weather = results[0] as Map<String, dynamic>?;
      _reminders = results[1] as List<Reminder>;
      _news = results[2] as List<Map<String, dynamic>>;
      _events = results[3] as List<Map<String, dynamic>>?;
      _loading = false;
    });
  }

  Future<void> _toggle(Reminder r, bool done) async {
    setState(() {
      _reminders = _reminders!
          .map((x) => x.id == r.id
              ? Reminder(id: x.id, text: x.text, dueAt: x.dueAt, done: done)
              : x)
          .toList();
    });
    try {
      await ApiService.setReminderDone(r.id, done);
    } catch (_) {}
    ReminderNotifications.instance.sync();
  }

  Future<void> _delete(Reminder r) async {
    setState(() => _reminders = _reminders!.where((x) => x.id != r.id).toList());
    try {
      await ApiService.deleteReminder(r.id);
    } catch (_) {}
    ReminderNotifications.instance.sync();
  }

  Future<void> _add() async {
    HapticFeedback.selectionClick();
    final controller = TextEditingController();
    DateTime? due;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 4,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('New reminder',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 200,
                decoration:
                    const InputDecoration(hintText: 'e.g. Pay electricity bill'),
              ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                icon: const Icon(Icons.schedule_rounded, size: 18),
                label: Text(due == null
                    ? 'Add a time (optional)'
                    : '${due!.day}/${due!.month} at ${TimeOfDay.fromDateTime(due!).format(ctx)}'),
                onPressed: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: now,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 365)),
                  );
                  if (d == null || !ctx.mounted) return;
                  final t = await showTimePicker(
                      context: ctx, initialTime: TimeOfDay.now());
                  if (t == null) return;
                  setSheet(() =>
                      due = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                },
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save reminder'),
              ),
            ],
          ),
        ),
      ),
    );
    final text = controller.text.trim();
    if (saved != true || text.isEmpty) return;
    try {
      final r = await ApiService.createReminder(text, due);
      if (mounted) setState(() => _reminders = [..._reminders ?? [], r]);
      ReminderNotifications.instance.sync();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save — are you signed in?')));
      }
    }
  }

  String _eventWhen(Map<String, dynamic> e) {
    final start = e['start']?.toString();
    if (start == null) return '';
    if (e['allDay'] == true || !start.contains('T')) return 'All day · $start';
    final d = DateTime.tryParse(start)?.toLocal();
    if (d == null) return '';
    final now = DateTime.now();
    final day = (d.day == now.day && d.month == now.month)
        ? 'Today'
        : 'Tomorrow';
    final loc = e['location']?.toString() ?? '';
    return '$day · ${TimeOfDay.fromDateTime(d).format(context)}'
        '${loc.isNotEmpty ? ' · $loc' : ''}';
  }

  String _due(Reminder r) {
    if (r.dueAt == null) return 'No set time';
    final d = r.dueAt!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final time = TimeOfDay.fromDateTime(d).format(context);
    if (that == today) return 'Today · $time';
    if (that == today.add(const Duration(days: 1))) return 'Tomorrow · $time';
    return '${d.day}/${d.month} · $time';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.6);

    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }

    final open = (_reminders ?? []).where((r) => !r.done).toList();
    final doneList = (_reminders ?? []).where((r) => r.done).toList();
    final all = [...open, ...doneList];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          // ---------------- VIDEO BRIEFING (D-ID, Pro) ----------------
          // Hari's face reads your morning summary — rendered server-side
          // once a day; this card generates, polls, then plays it.
          const _VideoBriefingCard(),
          const SizedBox(height: 16),

          // ---------------- MORNING BRIEFING (C2) ----------------
          Card(
            color: AppColors.peacock.withValues(alpha: 0.08),
            child: ListTile(
              leading:
                  const Icon(Icons.wb_twilight_rounded, color: AppColors.peacock),
              title: const Text('Morning briefing'),
              subtitle: const Text(
                  'Weather, calendar, reminders and headlines — spoken.'),
              trailing: const Icon(Icons.play_circle_fill_rounded,
                  color: AppColors.peacock, size: 34),
              onTap: () =>
                  AssistantController.instance.runText('Give me my daily briefing'),
            ),
          ),
          const SizedBox(height: 16),

          // ---------------- FOCUS GUARD ----------------
          // Renders only when a >3h back-to-back stretch is detected.
          const FocusGuardCard(),

          // ---------------- MEETING COPILOT ----------------
          Card(
            child: ListTile(
              leading: const Icon(Icons.record_voice_over_rounded,
                  color: AppColors.peacock),
              title: const Text('Meeting notes'),
              subtitle: const Text(
                  'Paste a transcript — get decisions, tasks and a draft.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const MeetingNotesScreen())),
            ),
          ),
          const SizedBox(height: 16),

          // ---------------- NEARBY (C3) ----------------
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: NearbySection(),
          ),

          // ---------------- WEATHER ----------------
          if (_weather != null)
            _WeatherCard(weather: _weather!)
          else
            Card(
              child: ListTile(
                leading: Icon(Icons.cloud_off_rounded, color: muted),
                title: const Text('Weather unavailable'),
                subtitle: Text(
                    'Allow location, or ask Hari: "what\'s the weather in Mysuru"',
                    style: TextStyle(color: muted, fontSize: 13)),
              ),
            ),
          const SizedBox(height: 16),

          // ---------------- CALENDAR (next 2 days) ----------------
          if (_events != null && _events!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('CALENDAR',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: cs.onSurface.withValues(alpha: 0.45))),
            ),
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < _events!.length && i < 5; i++) ...[
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.event_rounded,
                          size: 20, color: AppColors.peacock),
                      title: Text(_events![i]['title']?.toString() ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text(_eventWhen(_events![i]),
                          style: TextStyle(fontSize: 12, color: muted)),
                    ),
                    if (i < _events!.length - 1 && i < 4)
                      const Divider(height: 1),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ---------------- REMINDERS ----------------
          Row(
            children: [
              Text('REMINDERS',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: cs.onSurface.withValues(alpha: 0.45))),
              const Spacer(),
              IconButton(
                tooltip: 'Add reminder',
                onPressed: _add,
                icon: const Icon(Icons.add_circle_outline_rounded,
                    color: AppColors.peacock),
              ),
            ],
          ),
          Card(
            child: all.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Nothing yet. Tap + or just say: "Hey Hari, remind me '
                      'to pay the electricity bill tomorrow at 10."',
                      style: TextStyle(color: muted, height: 1.5),
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < all.length; i++) ...[
                        ListTile(
                          dense: true,
                          leading: Checkbox(
                            value: all[i].done,
                            onChanged: (v) => _toggle(all[i], v ?? false),
                          ),
                          title: Text(
                            all[i].text,
                            style: TextStyle(
                              fontSize: 14.5,
                              decoration: all[i].done
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: all[i].done ? muted : null,
                            ),
                          ),
                          subtitle: Text(_due(all[i]),
                              style: TextStyle(fontSize: 12, color: muted)),
                          trailing: IconButton(
                            icon: Icon(Icons.close_rounded,
                                size: 18, color: muted),
                            onPressed: () => _delete(all[i]),
                          ),
                        ),
                        if (i < all.length - 1) const Divider(height: 1),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 16),

          // ---------------- HEADLINES ----------------
          if (_news.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('TOP HEADLINES',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: cs.onSurface.withValues(alpha: 0.45))),
            ),
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < _news.length && i < 5; i++) ...[
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.circle,
                          size: 7, color: AppColors.marigold),
                      title: Text(_news[i]['title']?.toString() ?? '',
                          style: const TextStyle(fontSize: 14, height: 1.35)),
                      subtitle:
                          (_news[i]['source']?.toString().isNotEmpty ?? false)
                              ? Text(_news[i]['source'].toString(),
                                  style:
                                      TextStyle(fontSize: 11.5, color: muted))
                              : null,
                    ),
                    if (i < _news.length - 1 && i < 4) const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeatherCard extends StatelessWidget {
  final Map<String, dynamic> weather;
  const _WeatherCard({required this.weather});

  IconData _icon(String c) {
    if (c.contains('clear')) return Icons.wb_sunny_rounded;
    if (c.contains('cloud') || c.contains('overcast')) return Icons.cloud_rounded;
    if (c.contains('rain') || c.contains('drizzle') || c.contains('shower')) {
      return Icons.water_drop_rounded;
    }
    if (c.contains('thunder')) return Icons.thunderstorm_rounded;
    if (c.contains('snow')) return Icons.ac_unit_rounded;
    if (c.contains('fog')) return Icons.foggy;
    return Icons.wb_cloudy_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final cur = (weather['current'] as Map?) ?? {};
    final days = (weather['days'] as List?) ?? [];
    final cond = cur['condition']?.toString() ?? '';
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icon(cond), size: 40, color: AppColors.marigold),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${cur['tempC']}°C',
                        style: Theme.of(context).textTheme.headlineMedium),
                    Text('$cond · feels like ${cur['feelsC']}°',
                        style: TextStyle(fontSize: 13, color: muted)),
                  ],
                ),
                const Spacer(),
                Text(
                  weather['label']?.toString().split(',').first ?? '',
                  style:
                      const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (days.length > 1) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  for (var i = 0; i < days.length && i < 3; i++)
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            i == 0 ? 'Today' : (i == 1 ? 'Tmrw' : 'Next'),
                            style: TextStyle(fontSize: 11.5, color: muted),
                          ),
                          const SizedBox(height: 2),
                          Text('${days[i]['minC']}–${days[i]['maxC']}°',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          Text('${days[i]['rainChance']}% rain',
                              style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}


/// VIDEO BRIEFING — one avatar video per day, generated on the server
/// (weather + reminders + headlines, spoken by Hari's face). States:
///   none       → "Create today's video" button (Pro; 402 → upgrade page)
///   processing → progress row, polls every 5 s
///   done       → inline player with play/pause
/// Hidden entirely while the server has D-ID switched off.
class _VideoBriefingCard extends StatefulWidget {
  const _VideoBriefingCard();

  @override
  State<_VideoBriefingCard> createState() => _VideoBriefingCardState();
}

class _VideoBriefingCardState extends State<_VideoBriefingCard> {
  String _status = 'loading';
  String? _url;
  VideoPlayerController? _player;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final b = await ApiService.fetchVideoBriefing();
      if (!mounted) return;
      setState(() {
        _status = b.status;
        _url = b.url;
      });
      if (b.status == 'done' && b.url != null) {
        _attachPlayer(b.url!);
      } else if (b.status == 'processing' || b.status == 'creating') {
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) _refresh();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _status = 'unavailable');
    }
  }

  Future<void> _attachPlayer(String url) async {
    if (_player != null) return;
    final p = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await p.initialize();
      if (!mounted) {
        p.dispose();
        return;
      }
      setState(() => _player = p);
    } catch (_) {
      p.dispose();
    }
  }

  Future<void> _generate() async {
    HapticFeedback.selectionClick();
    setState(() => _busy = true);
    try {
      final b = await ApiService.generateVideoBriefing();
      if (!mounted) return;
      setState(() {
        _status = b.status;
        _url = b.url;
        _busy = false;
      });
      if (b.status == 'processing' || b.status == 'creating') {
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) _refresh();
        });
      } else if (b.status == 'done' && b.url != null) {
        _attachPlayer(b.url!);
      }
    } on ProRequired {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Video briefings are a Pro feature — Hari reads your morning, on camera.')));
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const UpgradeScreen()));
    } catch (_) {
      if (mounted) setState(() {
        _busy = false;
        _status = 'error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Server has the feature off (no D-ID key) → take no space at all.
    if (_status == 'unavailable') return const SizedBox.shrink();

    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    if (_status == 'done' && _player != null && _player!.value.isInitialized) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: _player!.value.aspectRatio == 0
                  ? 16 / 9
                  : _player!.value.aspectRatio,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _player!.value.isPlaying
                      ? _player!.pause()
                      : _player!.play());
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_player!),
                    if (!_player!.value.isPlaying)
                      Container(
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: Colors.black38),
                        padding: const EdgeInsets.all(6),
                        child: const Icon(Icons.play_arrow_rounded,
                            size: 46, color: Colors.white),
                      ),
                  ],
                ),
              ),
            ),
            ListTile(
              dense: true,
              leading:
                  const Icon(Icons.auto_awesome, color: AppColors.marigold),
              title: const Text("Today's briefing from Hari"),
              subtitle: Text('Fresh every morning',
                  style: TextStyle(fontSize: 12.5, color: muted)),
            ),
          ],
        ),
      );
    }

    if (_status == 'processing' || _status == 'creating') {
      return Card(
        child: ListTile(
          leading: const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.6)),
          title: const Text('Hari is recording your briefing…'),
          subtitle: Text('Usually ready in under a minute',
              style: TextStyle(fontSize: 12.5, color: muted)),
        ),
      );
    }

    // none / error / loading → offer to create.
    return Card(
      color: AppColors.marigold.withValues(alpha: 0.10),
      child: ListTile(
        leading: const Icon(Icons.smart_display_rounded,
            color: Color(0xFFB27107), size: 30),
        title: Text(_status == 'error'
            ? 'Briefing hit a snag — try again'
            : "Today's video briefing"),
        subtitle: Text('Hari reads your morning, on camera',
            style: TextStyle(fontSize: 12.5, color: muted)),
        trailing: _busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4))
            : FilledButton(
                onPressed: _status == 'loading' ? null : _generate,
                child: const Text('Create')),
      ),
    );
  }
}
