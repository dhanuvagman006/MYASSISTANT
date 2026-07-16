import 'package:flutter/material.dart';
import '../widgets/coming_soon.dart';

/// Screen 04 — Photos, Documents & Screenshots (B1–B4).
class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoon(
      icon: Icons.description_outlined,
      title: 'Point the camera at anything',
      description:
          'A 24-page agreement becomes a plain-language summary you can '
          'question. A shared poster becomes a calendar entry awaiting '
          'one tap. Nothing is added until you approve.',
      highlights: ['Document Q&A', 'Copy as text (OCR)', 'Screenshot helper'],
    );
  }
}
