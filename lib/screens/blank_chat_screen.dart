import 'package:flutter/material.dart';

/// Screen 02 — PLACEHOLDER.
///
/// The old AI text-chat page (chat_screen.dart) has been unmounted from
/// the Chat tab on request: this tab is intentionally blank while a new
/// experience is designed for it. chat_screen.dart is kept in the repo
/// untouched, so restoring it is a one-line change in main.dart.
class BlankChatScreen extends StatelessWidget {
  const BlankChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Intentionally empty — inherits the app's scaffold background.
    return const Scaffold(body: SizedBox.expand());
  }
}
