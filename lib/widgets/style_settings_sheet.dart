import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_strings.dart';
import '../services/style_prefs.dart';
import '../services/voice_service.dart';
import '../theme/app_theme.dart';

/// A4 — Assistant style settings: tone, answer length, voice speed;
/// plus A3 — app menu language (English / हिन्दी / മലയാളം).
/// Everything applies instantly and persists via StylePrefs.
Future<void> showStyleSettingsSheet(BuildContext context) {
  HapticFeedback.selectionClick();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _StyleSheet(),
  );
}

class _StyleSheet extends StatefulWidget {
  const _StyleSheet();

  @override
  State<_StyleSheet> createState() => _StyleSheetState();
}

class _StyleSheetState extends State<_StyleSheet> {
  final _prefs = StylePrefs.instance;

  Widget _chips({
    required List<String> options,
    required String selected,
    required String Function(String) label,
    required void Function(String) onPick,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(label(o)),
            selected: o == selected,
            onSelected: (_) {
              HapticFeedback.selectionClick();
              onPick(o);
              setState(() {});
            },
          ),
      ],
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Text(title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.55),
            )),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 4, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(S.t('style_title'),
                style: Theme.of(context).textTheme.headlineSmall),

            // ---- Tone ----
            _section(context, S.t('style_tone')),
            _chips(
              options: StylePrefs.tones,
              selected: _prefs.tone,
              label: (o) => S.t('tone_$o'),
              onPick: _prefs.setTone,
            ),

            // ---- Answer length ----
            _section(context, S.t('style_length')),
            _chips(
              options: StylePrefs.lengths,
              selected: _prefs.answerLength,
              label: (o) => S.t('len_$o'),
              onPick: _prefs.setAnswerLength,
            ),

            // ---- Voice speed ----
            _section(context, S.t('style_voice_speed')),
            Row(
              children: [
                const Icon(Icons.slow_motion_video_rounded, size: 20),
                Expanded(
                  child: Slider(
                    value: _prefs.speechRate,
                    min: 0.3,
                    max: 0.9,
                    divisions: 12,
                    activeColor: AppColors.peacock,
                    onChanged: (v) =>
                        setState(() => _prefs.speechRate = v),
                    onChangeEnd: (v) async {
                      await _prefs.setSpeechRate(v);
                      // Applies live to the TTS engine + a short preview.
                      await VoiceService.instance.applySpeechRate(v);
                    },
                  ),
                ),
                const Icon(Icons.speed_rounded, size: 20),
              ],
            ),

            // ---- App language (A3) ----
            _section(context, S.t('style_app_language')),
            _chips(
              options: StylePrefs.uiLanguages,
              selected: _prefs.uiLanguage,
              label: (o) => S.t('lang_$o'),
              onPick: _prefs.setUiLanguage,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
