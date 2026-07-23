import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ink = Color(0xFF171815);
  static const cream = Color(0xFFF4EFE4);
  static const paper = Color(0xFFFFFBF2);
  static const yellow = Color(0xFFF4B900);
  static const green = Color(0xFF536044);
  static const successLime = Color(0xFFC8D86B);
  static const lindenGreen = Color(0xFF829653);
  static const navy = Color(0xFF081622);
  static const muted = Color(0xFF6E6B61);
  static const line = Color(0xFFD8D0C1);
  static const rust = Color(0xFF9B4E32);
}

abstract final class AppBreakpoints {
  static const desktop = 900.0;
}

abstract final class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.yellow,
      brightness: Brightness.light,
      surface: AppColors.paper,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        primary: AppColors.ink,
        secondary: AppColors.yellow,
        surface: AppColors.paper,
        outline: AppColors.line,
      ),
      scaffoldBackgroundColor: AppColors.cream,
      fontFamily: 'Atkinson Hyperlegible Next',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Literata',
          fontSize: 64,
          height: 1,
          fontWeight: FontWeight.w800,
          letterSpacing: -2,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Literata',
          fontSize: 44,
          height: 1.06,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.3,
        ),
        headlineLarge: TextStyle(
          fontFamily: 'Literata',
          fontSize: 32,
          height: 1.15,
          fontWeight: FontWeight.w700,
          letterSpacing: -.6,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Literata',
          fontSize: 24,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: -.35,
        ),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(fontSize: 17, height: 1.55),
        bodyMedium: TextStyle(fontSize: 14, height: 1.5),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: .2,
        ),
      ).apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
      cardTheme: const CardThemeData(
        color: AppColors.paper,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(22)),
          side: BorderSide(color: AppColors.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.paper,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.ink, width: 1.5),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.paper,
        side: BorderSide(color: AppColors.line),
        shape: StadiumBorder(),
        labelStyle: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
