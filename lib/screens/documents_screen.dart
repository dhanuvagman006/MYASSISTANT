import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Screen 04 — Photos, Documents & Screenshots (B1–B4).
/// Document AI wires in during Month 2.
class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Text('Rental_Agreement.pdf',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            _Badge('24 PAGES', AppColors.peacock.withValues(alpha: 0.12)),
            const SizedBox(width: 8),
            _Badge('SUMMARISED', AppColors.marigold.withValues(alpha: 0.2)),
            const Spacer(),
            OutlinedButton(
              onPressed: () {},
              child: const Text('⧉ Copy as text', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Summary (B2)
        Card(
          color: AppColors.peacock.withValues(alpha: 0.08),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SUMMARY',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.peacock)),
                SizedBox(height: 4),
                Text(
                    '11-month agreement for a 2BHK in Kowdiar. Rent ₹18,500/month, due by the 5th. Deposit ₹55,500, refundable in 30 days.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Clauses to watch
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WATCH THESE CLAUSES',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink.withValues(alpha: 0.5))),
                const SizedBox(height: 8),
                const _Clause('§9', 'Rent increases 7% on renewal — above the usual 5%.'),
                const _Clause('§14', 'Notice period is 2 months, both sides.'),
                const _Clause('§17', 'Painting charges deducted from deposit at exit.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Q&A exchange
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.peacockDeep,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('Can I terminate early without penalty?',
                style: TextStyle(color: Colors.white)),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
                "Yes — after the 6th month with 2 months' written notice (§14). Before that, one month's rent applies as penalty (§15, page 11)."),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bg;
  const _Badge(this.label, this.bg);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.peacockDeep)),
      );
}

class _Clause extends StatelessWidget {
  final String section;
  final String text;
  const _Clause(this.section, this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.marigold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(section,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );
}
