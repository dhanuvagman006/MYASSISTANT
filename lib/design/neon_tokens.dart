import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  MYASSISTANT · Neon Design System V2.0
///  Single source of truth for color, gradient, spacing, radius and glow.
///  Nothing outside lib/design + lib/theme should hardcode a hex value.
/// ─────────────────────────────────────────────────────────────────────────
class Neon {
  Neon._();

  // Core palette
  static const violet = Color(0xFF7C3AED); // primary
  static const cyan = Color(0xFF06B6D4); // secondary
  static const pink = Color(0xFFEC4899); // accent
  static const lime = Color(0xFFA3E635); // highlight
  static const bg = Color(0xFF0B0F1A); // app background
  static const surface = Color(0xFF111827); // cards, sheets
  static const surfaceHigh = Color(0xFF1A2336); // raised cards, inputs
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);

  // Text
  static const textHi = Color(0xFFF3F4F8); // headings, primary text
  static const textLo = Color(0xFF9CA3B8); // secondary text
  static const textDim = Color(0xFF5B6478); // hints, disabled

  // Hairlines on glass
  static Color get line => Colors.white.withValues(alpha: 0.08);
  static Color get lineBright => Colors.white.withValues(alpha: 0.16);

  // Gradients
  static const gVioletCyan = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [violet, cyan]);
  static const gPinkViolet = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [pink, violet]);
  static const gCyanLime = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [cyan, lime]);
  static const gVioletPink = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [violet, pink]);

  /// Tri-color sweep used by the assistant orb — the app's signature.
  static const gOrb = SweepGradient(
    colors: [violet, cyan, pink, violet],
    stops: [0.0, 0.4, 0.75, 1.0],
  );

  // Spacing scale
  static const s1 = 4.0, s2 = 8.0, s3 = 12.0, s4 = 16.0;
  static const s5 = 20.0, s6 = 24.0, s7 = 32.0, s8 = 40.0;

  // Radius scale
  static const rSm = 12.0, rMd = 16.0, rLg = 20.0, rXl = 28.0, rPill = 100.0;

  // Motion
  static const fast = Duration(milliseconds: 180);
  static const med = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 600);

  /// Soft neon glow behind buttons / orbs / FABs.
  static List<BoxShadow> glow(Color c,
          {double blur = 24, double spread = 0, double alpha = 0.45}) =>
      [
        BoxShadow(
            color: c.withValues(alpha: alpha),
            blurRadius: blur,
            spreadRadius: spread),
      ];

  /// Two-tone glow for gradient elements.
  static List<BoxShadow> glow2(Color a, Color b, {double blur = 26}) => [
        BoxShadow(
            color: a.withValues(alpha: 0.35),
            blurRadius: blur,
            offset: const Offset(-4, 4)),
        BoxShadow(
            color: b.withValues(alpha: 0.35),
            blurRadius: blur,
            offset: const Offset(4, -4)),
      ];
}
