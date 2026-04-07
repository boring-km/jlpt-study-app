import 'package:flutter/material.dart';

class AppColors {
  // Light mode — red keypoint
  static const primary = Color(0xFFE50914);
  static const primaryDark = Color(0xFFFAE100);
  static const accent = Color(0xFFFF6B6B);
  static const success = Color(0xFF16A34A);
  static const error = Color(0xFFB91C1C);

  static const backgroundLight = Color(0xFFFFF5F5);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const textPrimaryLight = Color(0xFF1A0A0A);
  static const textSecondaryLight = Color(0xFF6B3A3A);
  static const borderLight = Color(0xFFF5C6C6);

  static const backgroundDark = Color(0xFF0B1220);
  static const surfaceDark = Color(0xFF1C2333);
  static const textPrimaryDark = Color(0xFFE5E7EB);
  static const textSecondaryDark = Color(0xFF94A3B8);
  static const borderDark = Color(0xFFFAE100);
}

class AppTheme {
  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.accent,
          error: AppColors.error,
          surface: AppColors.surfaceLight,
        ),
        scaffoldBackgroundColor: AppColors.backgroundLight,
        cardColor: AppColors.surfaceLight,
        dividerColor: AppColors.borderLight,
        shadowColor: Colors.black,
        textTheme: _textTheme(AppColors.textPrimaryLight, AppColors.textSecondaryLight),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.backgroundLight,
          foregroundColor: AppColors.textPrimaryLight,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surfaceLight,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondaryLight,
          type: BottomNavigationBarType.fixed,
        ),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: AppColors.primaryDark,
          secondary: AppColors.accent,
          error: AppColors.error,
          surface: AppColors.surfaceDark,
        ),
        scaffoldBackgroundColor: AppColors.backgroundDark,
        cardColor: AppColors.surfaceDark,
        dividerColor: AppColors.borderDark,
        shadowColor: Colors.white,
        textTheme: _textTheme(AppColors.textPrimaryDark, AppColors.textSecondaryDark),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.backgroundDark,
          foregroundColor: AppColors.textPrimaryDark,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surfaceDark,
          selectedItemColor: AppColors.primaryDark,
          unselectedItemColor: AppColors.textSecondaryDark,
          type: BottomNavigationBarType.fixed,
        ),
      );

  static TextTheme _textTheme(Color primary, Color secondary) => TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
        titleLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: primary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: secondary,
        ),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: secondary,
        ),
      );
}
