import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// MEETING COPILOT — paste any meeting transcript or rough notes; the
/// backend returns decisions, action items and a follow-up email draft.
/// Action items with dates can be filed as reminders (opt-in). The draft
/// is copy-only here — nothing is ever sent automatically.
class MeetingNotesScreen extends StatefulWidget {
  const MeetingNotesScreen({super.key});

  @override
  State<MeetingNotesScreen> createState() => _MeetingNotesScreenState();
}

class _MeetingNotesScreenState extends State<MeetingNotesScreen> {
  final _input = TextEditingController();
  bool _stageReminders = true;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _process() async {
    final text = _input.text.trim();
    if (text.length < 40) {
      setState(() => _error = 'Paste at least a few sentences of the meeting.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final out = await ApiService.processTranscript(text,
          stageReminders: _stageReminders);
      if (!mounted) return;
      setState(() => _result = out);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.6);
    final r = _result;
    final decisions = (r?['decisions'] as List?) ?? const [];
    final actions = (r?['actions'] as List?) ?? const [];
    final draft = r?['followUpDraft'] as Map<String, dynamic>?;
    final staged = (r?['stagedReminders'] as List?) ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Meeting notes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          TextField(
            controller: _input,
            minLines: 5,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText:
                  'Paste the transcript or your rough notes here —\nHari will pull out decisions, tasks and a follow-up email.',
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _stageReminders,
            onChanged: (v) => setState(() => _stageReminders = v),
            title: const Text('Add dated tasks to my reminders'),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _process,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome_rounded, size: 18),
            label: Text(_busy ? 'Reading the meeting…' : 'Extract'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error!,
                  style: TextStyle(color: cs.error, fontSize: 13)),
            ),

          // ---------------- RESULTS ----------------
          if (decisions.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionLabel(context, 'DECISIONS'),
            Card(
              child: Column(
                children: [
                  for (final d in decisions)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.gavel_rounded,
                          size: 20, color: AppColors.peacock),
                      title: Text(d.toString()),
                    ),
                ],
              ),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionLabel(context, 'ACTION ITEMS'),
            Card(
              child: Column(
                children: [
                  for (final a in actions.cast<Map<String, dynamic>>())
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.task_alt_rounded,
                          size: 20, color: AppColors.marigold),
                      title: Text(a['task']?.toString() ?? ''),
                      subtitle: Text(
                        [
                          if ((a['owner'] ?? 'unassigned') != 'unassigned')
                            a['owner'],
                          if (a['due'] != null) 'due ${a['due']}',
                        ].join(' · '),
                        style: TextStyle(fontSize: 12.5, color: muted),
                      ),
                    ),
                ],
              ),
            ),
            if (staged.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                    '${staged.length} dated task(s) added to your reminders ✓',
                    style: TextStyle(fontSize: 12.5, color: muted)),
              ),
          ],
          if (draft != null) ...[
            const SizedBox(height: 16),
            _sectionLabel(context, 'FOLLOW-UP EMAIL DRAFT'),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(draft['subject']?.toString() ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(draft['body']?.toString() ?? '',
                        style: const TextStyle(fontSize: 14, height: 1.4)),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(
                              text:
                                  '${draft['subject']}\n\n${draft['body']}'));
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Draft copied — review '
                                      'before you send it')));
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.45))),
      );
}
