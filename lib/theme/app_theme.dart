import 'package:flutter/material.dart';

/// Brand palette — MYASSISTANT UI Design V1.0
class AppColors {
  static const peacock = Color(0xFF0F6B66); // primary actions
  static const peacockDeep = Color(0xFF0A4744); // emphasis
  static const marigold = Color(0xFFF6A21E); // voice & alerts
  static const ink = Color(0xFF0E1B1D); // text, dark surfaces
  static const mist = Color(0xFFF2F6F5); // cards, surfaces
  static const danger = Color(0xFFC62828);
}

class AppTheme {
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
      cardTheme: CardTheme(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.peacockDeep,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.peacock,
      primary: AppColors.peacock,
      onPrimary: Colors.white,
      secondary: AppColors.marigold,
      surface: AppColors.peacockDeep,
      onSurface: AppColors.mist,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.ink,
    );
  }
}
