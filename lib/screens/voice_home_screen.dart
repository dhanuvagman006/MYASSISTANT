import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/chat_message.dart';
import '../services/api_service.dart';
import '../services/voice_service.dart';
import '../theme/app_theme.dart';

/// Screen 01 — Voice Home (A1–A4, M1), now live.
///
/// Say "Hey Hari" (while this screen is open) or tap the orb, ask your
/// question, and the assistant answers on screen and out loud.
enum OrbState { idle, listening, thinking, speaking }

class VoiceHomeScreen extends StatefulWidget {
  final VoidCallback? onOpenChat;
  const VoiceHomeScreen({super.key, this.onOpenChat});

  @override
  State<VoiceHomeScreen> createState() => _VoiceHomeScreenState();
}

class _VoiceHomeScreenState extends State<VoiceHomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _voice = VoiceService.instance;
  final _history = <ChatMessage>[];

  OrbState _state = OrbState.idle;
  bool _wakeEnabled = true;
  bool _micReady = false;
  String _partial = '';
  String? _lastHeard;
  String? _lastReply;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initVoice();
  }

  Future<void> _initVoice() async {
    final ok = await _voice.init();
    if (!mounted) return;
    setState(() => _micReady = ok);
    if (ok && _wakeEnabled) _watch();
  }

  void _watch() {
    if (!_micReady || !_wakeEnabled || _state != OrbState.idle) return;
    _voice.startWatching(onWake: _onWake);
  }

  void _onWake() {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    _ask();
  }

  Future<void> _ask() async {
    if (!_micReady || _state != OrbState.idle) return;
    setState(() {
      _state = OrbState.listening;
      _partial = '';
    });

    final question = await _voice.captureQuestion(
      onPartial: (p) {
        if (mounted) setState(() => _partial = p);
      },
    );
    if (!mounted) return;

    if (question.isEmpty) {
      setState(() => _state = OrbState.idle);
      _watch();
      return;
    }

    setState(() {
      _state = OrbState.thinking;
      _lastHeard = question;
      _lastReply = null;
    });

    String reply;
    try {
      _history.add(ChatMessage(role: 'user', content: question));
      reply = await ApiService.sendChat(_history);
      _history.add(ChatMessage(role: 'assistant', content: reply));
    } catch (_) {
      reply = "I couldn't reach the assistant. Please check your connection.";
    }
    if (!mounted) return;

    setState(() {
      _state = OrbState.speaking;
      _lastReply = reply;
    });
    await _voice.speak(reply);
    if (!mounted) return;

    setState(() => _state = OrbState.idle);
    _watch();
  }

  Future<void> _tapOrb() async {
    HapticFeedback.mediumImpact();
    switch (_state) {
      case OrbState.idle:
        await _voice.stopWatching();
        _ask();
      case OrbState.listening:
        await _voice.cancelCapture();
      case OrbState.speaking:
        await _voice.stopSpeaking();
        setState(() => _state = OrbState.idle);
        _watch();
      case OrbState.thinking:
        break; // let it finish
    }
  }

  void _toggleWake(bool v) {
    HapticFeedback.selectionClick();
    setState(() => _wakeEnabled = v);
    if (v) {
      _watch();
    } else {
      _voice.stopWatching();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    // Release the mic when backgrounded; resume the watch when back.
    if (s == AppLifecycleState.paused) {
      _voice.stopWatching();
    } else if (s == AppLifecycleState.resumed && _state == OrbState.idle) {
      _watch();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _voice.stopWatching();
    _voice.stopSpeaking();
    _pulse.dispose();
    super.dispose();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _caption {
    if (!_micReady) return 'Microphone unavailable — check app permissions';
    return switch (_state) {
      OrbState.idle => _wakeEnabled
          ? 'Say "Hey Hari" or tap the orb'
          : 'Tap the orb to speak — any language',
      OrbState.listening =>
        _partial.isEmpty ? "I'm listening…" : '"$_partial"',
      OrbState.thinking => 'Thinking…',
      OrbState.speaking => 'Speaking — tap to interrupt',
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.60);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text(_greeting, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                _caption,
                key: ValueKey(_caption),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, color: muted),
              ),
            ),
            Expanded(
              child: Center(
                child: _BloomOrb(state: _state, pulse: _pulse, onTap: _tapOrb),
              ),
            ),

            // Real transcript card — only after a real exchange.
            if (_lastHeard != null) ...[
              _TranscriptCard(heard: _lastHeard!, reply: _lastReply),
              const SizedBox(height: 12),
            ],

            // Wake word switch
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.hearing_rounded,
                      size: 18, color: _wakeEnabled ? cs.primary : muted),
                  const SizedBox(width: 8),
                  Text('"Hey Hari" wake word',
                      style: const TextStyle(fontSize: 13.5)),
                  Switch(
                    value: _wakeEnabled && _micReady,
                    onChanged: _micReady ? _toggleWake : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _TranscriptCard extends StatelessWidget {
  final String heard;
  final String? reply;
  const _TranscriptCard({required this.heard, this.reply});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 170),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'HEARD',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.marigold,
              ),
            ),
            const SizedBox(height: 4),
            Text('"$heard"',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (reply != null) ...[
              const SizedBox(height: 8),
              Text(
                reply!,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: cs.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BloomOrb extends StatelessWidget {
  final OrbState state;
  final AnimationController pulse;
  final VoidCallback onTap;

  const _BloomOrb(
      {required this.state, required this.pulse, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final animate = state == OrbState.listening || state == OrbState.speaking;

    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest.shortestSide.clamp(200.0, 300.0);
        return AnimatedBuilder(
          animation: pulse,
          builder: (context, _) {
            final scale = animate ? 1 + (pulse.value * 0.07) : 1.0;
            return SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: scale,
                    child:
                        _ring(size, AppColors.marigold.withValues(alpha: 0.35)),
                  ),
                  _ring(size * 0.82, AppColors.marigold.withValues(alpha: 0.7)),
                  Transform.scale(
                    scale: scale,
                    child: GestureDetector(
                      onTap: onTap,
                      child: Container(
                        width: size * 0.62,
                        height: size * 0.62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            center: Alignment(-0.3, -0.4),
                            colors: [
                              AppColors.peacockLight,
                              AppColors.peacockDeep
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.peacock.withValues(alpha: 0.45),
                              blurRadius: 48,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Icon(
                          switch (state) {
                            OrbState.idle => Icons.mic_none_rounded,
                            OrbState.thinking => Icons.more_horiz_rounded,
                            _ => Icons.graphic_eq_rounded,
                          },
                          size: size * 0.20,
                          color: state == OrbState.speaking
                              ? AppColors.marigold
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _ring(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.5),
        ),
      );
}
