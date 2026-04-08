import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/core/theme/app_theme.dart';

void main() {
  group('AppColors', () {
    test('primary color is correct', () {
      expect(AppColors.primary, const Color(0xFFE50914));
    });

    test('accent color is correct', () {
      expect(AppColors.accent, const Color(0xFFFF6B6B));
    });

    test('success color is correct', () {
      expect(AppColors.success, const Color(0xFF16A34A));
    });

    test('error color is correct', () {
      expect(AppColors.error, const Color(0xFFB91C1C));
    });

    test('light background color is correct', () {
      expect(AppColors.backgroundLight, const Color(0xFFFFFFFF));
    });

    test('dark background color is correct', () {
      expect(AppColors.backgroundDark, const Color(0xFF0B1220));
    });
  });

  group('AppTheme', () {
    test('light theme uses Material3', () {
      final theme = AppTheme.light();
      expect(theme.useMaterial3, isTrue);
    });

    test('dark theme uses Material3', () {
      final theme = AppTheme.dark();
      expect(theme.useMaterial3, isTrue);
    });

    test('light theme primary color matches AppColors', () {
      final theme = AppTheme.light();
      expect(theme.colorScheme.primary, AppColors.primary);
    });

    test('dark theme primary color matches AppColors', () {
      final theme = AppTheme.dark();
      expect(theme.colorScheme.primary, AppColors.primaryDark);
    });

    test('light theme scaffold background is correct', () {
      final theme = AppTheme.light();
      expect(theme.scaffoldBackgroundColor, AppColors.backgroundLight);
    });

    test('dark theme scaffold background is correct', () {
      final theme = AppTheme.dark();
      expect(theme.scaffoldBackgroundColor, AppColors.backgroundDark);
    });

    test('light theme appBar has zero elevation', () {
      final theme = AppTheme.light();
      expect(theme.appBarTheme.elevation, 0);
    });

    test('dark theme appBar has zero elevation', () {
      final theme = AppTheme.dark();
      expect(theme.appBarTheme.elevation, 0);
    });

    test('light theme textTheme has displayLarge', () {
      final theme = AppTheme.light();
      expect(theme.textTheme.displayLarge, isNotNull);
      expect(theme.textTheme.displayLarge?.fontSize, 32);
    });

    test('dark theme textTheme has displayLarge', () {
      final theme = AppTheme.dark();
      expect(theme.textTheme.displayLarge, isNotNull);
      expect(theme.textTheme.displayLarge?.fontSize, 32);
    });

    test('light theme uses Pretendard font', () {
      final theme = AppTheme.light();
      expect(theme.textTheme.bodyLarge?.fontFamily, 'Pretendard');
    });

    test('dark theme uses Pretendard font', () {
      final theme = AppTheme.dark();
      expect(theme.textTheme.bodyLarge?.fontFamily, 'Pretendard');
    });
  });
}
