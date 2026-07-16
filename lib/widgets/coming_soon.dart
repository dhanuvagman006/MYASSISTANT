import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Polished empty state used by screens whose data sources aren't wired yet.
/// No mock data anywhere — each screen states what it will do, honestly.
class ComingSoon extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<String> highlights;

  const ComingSoon({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.highlights = const [],
  });

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.60);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [AppColors.peacockLight, AppColors.peacockDeep],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.peacock.withValues(alpha: 0.30),
                    blurRadius: 32,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 42),
            ),
            const SizedBox(height: 24),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(description,
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, height: 1.5)),
            if (highlights.isNotEmpty) ...[
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final h in highlights)
                    Chip(label: Text(h)),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.marigold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'COMING SOON',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Color(0xFFB27107),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
