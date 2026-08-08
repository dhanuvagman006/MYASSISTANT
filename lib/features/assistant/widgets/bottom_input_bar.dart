import 'package:flutter/material.dart';

import '../../../design/neon_tokens.dart';
import '../state/assistant_state.dart';

/// Bottom bar: big mic button + always-available text fallback.
class BottomInputBar extends StatefulWidget {
  final AssistantPhase phase;
  final VoidCallback onMic;
  final ValueChanged<String> onSendText;
  const BottomInputBar({
    super.key,
    required this.phase,
    required this.onMic,
    required this.onSendText,
  });

  @override
  State<BottomInputBar> createState() => _BottomInputBarState();
}

class _BottomInputBarState extends State<BottomInputBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final t = _controller.text.trim();
    if (t.isEmpty) return;
    widget.onSendText(t);
    _controller.clear();
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final listening = widget.phase == AssistantPhase.listening;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(26),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Type instead…',
                    hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4)),
                    border: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 13),
                    suffixIcon: _hasText
                        ? IconButton(
                            icon: const Icon(Icons.send_rounded,
                                color: Neon.cyan, size: 20),
                            onPressed: _send,
                          )
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Big mic button
            GestureDetector(
              onTap: widget.onMic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient:
                      listening ? Neon.gCyanLime : Neon.gVioletPink,
                  boxShadow: [
                    BoxShadow(
                      color: (listening ? Neon.cyan : Neon.violet)
                          .withValues(alpha: 0.45),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  listening ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
