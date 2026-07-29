import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

/// PLAN & USAGE — free/Pro/Family status, today's allowances, Razorpay
/// checkout (opens the hosted payment page in the browser; the backend
/// webhook activates the plan, so "I've paid" just refreshes), and the
/// Family invite/join flow ("Hari for amma").
class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  Map<String, dynamic>? _billing;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final b = await ApiService.fetchBilling();
      if (mounted) setState(() => _billing = b);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not load your plan. Pull to retry.');
      }
    }
  }

  Future<void> _checkout(String plan) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final url = await ApiService.startCheckout(plan);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Complete the payment in your browser, then tap "I\'ve paid".')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _invite() async {
    try {
      final code = await ApiService.familyInvite();
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: code));
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Family invite code'),
          content: Text(
              '$code\n\nCopied to clipboard. Share it — family members enter '
              'it below on their phones. Up to 5 people share your plan.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Done'))
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _join() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join a family'),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: '6-letter code'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Join')),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty) return;
    try {
      await ApiService.familyJoin(code.trim());
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Welcome to the family — Pro features unlocked!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  String _rupees(int paise) => '₹${(paise / 100).toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    final b = _billing;
    return Scaffold(
      appBar: AppBar(title: const Text('Plan & usage')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
              ),
            if (b == null && _error == null)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator())),
            if (b != null) ...[
              _CurrentPlanCard(billing: b, onRefresh: _load),
              const SizedBox(height: 16),
              _UsageCard(usage: (b['usage'] as Map<String, dynamic>? ?? {})),
              const SizedBox(height: 24),
              if (b['plan'] == 'free') ...[
                Text('Upgrade',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _PlanCard(
                  title: 'Pro',
                  price:
                      '${_rupees((b['prices']?['pro'] as int?) ?? 24900)} / month',
                  perks: const [
                    'Unlimited voice questions',
                    '30 agent-call minutes — Hari calls people for you',
                    '100 saved documents',
                  ],
                  busy: _busy,
                  onTap: () => _checkout('pro'),
                ),
                const SizedBox(height: 12),
                _PlanCard(
                  title: 'Family',
                  price:
                      '${_rupees((b['prices']?['family'] as int?) ?? 49900)} / month',
                  perks: const [
                    'Everything in Pro, for up to 5 people',
                    '60 pooled agent-call minutes',
                    'Perfect for parents — Hari speaks their language',
                  ],
                  busy: _busy,
                  onTap: () => _checkout('family'),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: _join,
                    child: const Text('Have a family invite code?'),
                  ),
                ),
              ],
              if (b['plan'] == 'family' && b['via'] == 'own')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FilledButton.icon(
                    onPressed: _invite,
                    icon: const Icon(Icons.group_add_outlined),
                    label: const Text('Invite family members'),
                  ),
                ),
              if (b['plan'] != 'free' &&
                  (b['paymentsConfigured'] as bool? ?? false))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _checkout(b['plan'] == 'family' &&
                                b['via'] == 'own'
                            ? 'family'
                            : 'pro'),
                    child: const Text('Renew now'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.billing, required this.onRefresh});
  final Map<String, dynamic> billing;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final plan = billing['plan'] as String? ?? 'free';
    final end = billing['periodEnd'] as int?;
    final via = billing['via'] as String?;
    String subtitle;
    if (plan == 'free') {
      subtitle = 'Daily allowances reset at midnight.';
    } else {
      final days = end == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(end)
              .difference(DateTime.now())
              .inDays;
      subtitle = via == 'family'
          ? 'Shared with you on a Family plan.'
          : 'Active — ${days ?? '?'} days left.';
    }
    return Card(
      child: ListTile(
        leading: Icon(plan == 'free'
            ? Icons.workspace_premium_outlined
            : Icons.workspace_premium),
        title: Text(plan == 'free'
            ? 'Free plan'
            : plan == 'pro'
                ? 'Pro'
                : 'Family'),
        subtitle: Text(subtitle),
        trailing: TextButton(
          onPressed: onRefresh,
          child: const Text("I've paid"),
        ),
      ),
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.usage});
  final Map<String, dynamic> usage;

  String _fmt(Map<String, dynamic>? u) {
    if (u == null) return '—';
    final limit = u['limit'] as int? ?? 0;
    final left = u['left'] as int? ?? 0;
    if (limit < 0 || left < 0) return 'Unlimited';
    return '$left of $limit left';
  }

  @override
  Widget build(BuildContext context) {
    Widget row(IconData i, String name, String key) => ListTile(
          dense: true,
          leading: Icon(i, size: 20),
          title: Text(name),
          trailing: Text(_fmt(usage[key] as Map<String, dynamic>?)),
        );
    return Card(
      child: Column(children: [
        row(Icons.chat_bubble_outline, 'Voice questions today', 'chat'),
        const Divider(height: 1),
        row(Icons.mic_none, 'Transcriptions today', 'stt'),
        const Divider(height: 1),
        row(Icons.photo_camera_outlined, 'Photo questions today', 'vision'),
        const Divider(height: 1),
        row(Icons.phone_in_talk_outlined, 'Agent-call minutes this month',
            'agent_min'),
      ]),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.perks,
    required this.onTap,
    required this.busy,
  });
  final String title, price;
  final List<String> perks;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                Text(price, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            for (final p in perks)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  const Icon(Icons.check_rounded, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p)),
                ]),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : onTap,
                child: Text('Get $title'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
