import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand palette — MYASSISTANT UI Design V1.0
class AppColors {
  static const peacock = Color(0xFF0F6B66); // primary actions
  static const peacockDeep = Color(0xFF0A4744); // emphasis
  static const peacockLight = Color(0xFF1A9E96); // orb highlight
  static const marigold = Color(0xFFF6A21E); // voice & alerts
  static const ink = Color(0xFF0E1B1D); // text, dark surfaces
  static const mist = Color(0xFFF2F6F5); // cards, surfaces
  static const danger = Color(0xFFC62828);
}

class AppTheme {
  /// Sora for headlines, Inter for everything else — per the design doc.
  static TextTheme _text(TextTheme base, Color color) {
    final inter = GoogleFonts.interTextTheme(base).apply(
      bodyColor: color,
      displayColor: color,
    );
    TextStyle sora(TextStyle? s) =>
        GoogleFonts.sora(textStyle: s, fontWeight: FontWeight.w700);
    return inter.copyWith(
      displayLarge: sora(inter.displayLarge),
      displayMedium: sora(inter.displayMedium),
      displaySmall: sora(inter.displaySmall),
      headlineLarge: sora(inter.headlineLarge),
      headlineMedium: sora(inter.headlineMedium),
      headlineSmall: sora(inter.headlineSmall),
      titleLarge: sora(inter.titleLarge),
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.peacock,
      primary: AppColors.peacock,
      onPrimary: Colors.white,
      secondary: AppColors.marigold,
      onSecondary: AppColors.ink,
      surface: Colors.white,
      onSurface: AppColors.ink,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.mist,
      textTheme: _text(ThemeData.light().textTheme, AppColors.ink),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.mist,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.sora(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.peacockDeep,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.peacockDeep,
          side: BorderSide(color: AppColors.ink.withValues(alpha: 0.12)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        side: BorderSide(color: AppColors.ink.withValues(alpha: 0.10)),
        labelStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.peacock.withValues(alpha: 0.12),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.peacockDeep
                : AppColors.ink.withValues(alpha: 0.55),
          ),
        ),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: GoogleFonts.inter(color: AppColors.ink.withValues(alpha: 0.4)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.peacock,
      primary: AppColors.peacockLight,
      onPrimary: Colors.white,
      secondary: AppColors.marigold,
      surface: const Color(0xFF122726),
      onSurface: AppColors.mist,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.ink,
      textTheme: _text(ThemeData.dark().textTheme, AppColors.mist),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.ink,
        elevation: 0,
        titleTextStyle: GoogleFonts.sora(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.mist,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF122726),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
