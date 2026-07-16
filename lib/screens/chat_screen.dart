import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/chat_message.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Screen 02 — Chat & Live Information (A1, A5, C4, C5).
/// This screen is live: it talks to the backend for real.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messages = <ChatMessage>[];
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _thinking = false;
  String? _error;

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _thinking) return;
    HapticFeedback.lightImpact();

    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _controller.clear();
      _thinking = true;
      _error = null;
    });
    _scrollToBottom();

    try {
      final reply = await ApiService.sendChat(_messages);
      setState(
          () => _messages.add(ChatMessage(role: 'assistant', content: reply)));
    } catch (_) {
      setState(
          () => _error = "Couldn't reach the assistant. Check your connection.");
    } finally {
      setState(() => _thinking = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty && !_thinking
              ? _Welcome(onSuggestion: _send)
              : ListView.builder(
                  controller: _scroll,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _messages.length +
                      (_thinking ? 1 : 0) +
                      (_error != null ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i < _messages.length) return _Bubble(_messages[i]);
                    if (_thinking && i == _messages.length) {
                      return const _TypingIndicator();
                    }
                    return Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(_error!,
                          style: const TextStyle(color: AppColors.danger)),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _send(),
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: 'Ask anything — any language…',
                      suffixIcon: Icon(Icons.mic_none_rounded,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.35)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: AppColors.marigold,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _send,
                    child: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Icon(Icons.arrow_upward_rounded,
                          color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Welcome extends StatelessWidget {
  final void Function(String) onSuggestion;
  const _Welcome({required this.onSuggestion});

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.60);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(-0.3, -0.4),
                  colors: [AppColors.peacockLight, AppColors.peacockDeep],
                ),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  color: Colors.white, size: 30),
            ),
            const SizedBox(height: 20),
            Text('What can I help with?',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Questions, writing help, translations — in English, हिन्दी, മലയാളം and 50+ languages.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, height: 1.5),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final s in const [
                  'Draft a polite email',
                  'Translate to Hindi',
                  'Explain simply',
                ])
                  ActionChip(
                    label: Text(s),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      onSuggestion(s);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: SizedBox(
          width: 32,
          child: LinearProgressIndicator(
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
            color: AppColors.peacock,
            backgroundColor: AppColors.peacock.withValues(alpha: 0.15),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage msg;
  const _Bubble(this.msg);

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser
              ? AppColors.peacockDeep
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 18),
          ),
        ),
        child: Text(
          msg.content,
          style: TextStyle(
            color: isUser ? Colors.white : Theme.of(context).colorScheme.onSurface,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}
