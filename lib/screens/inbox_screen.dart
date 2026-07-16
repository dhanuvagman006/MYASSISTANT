import 'package:flutter/material.dart';
import '../widgets/coming_soon.dart';

/// Screen 06 — Inbox Summary & Smart Replies (D1, D2, H1).
class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoon(
      icon: Icons.mail_outline_rounded,
      title: 'Your inbox, digested',
      description:
          'Important emails first, each with a reply drafted for one-tap '
          'review. Nothing is ever sent without your approval. Appears '
          'here once Gmail is connected.',
      highlights: ['Digest, not a list', 'Draft replies', 'Kill switch for auto-rules'],
    );
  }
}
