import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/core/theme/app_theme.dart';

void main() {
  group('AppColors — 종이와 먹 팔레트', () {
    test('primary is the vermilion ink accent', () {
      expect(AppColors.primary, const Color(0xFFB5371F));
      expect(AppColors.primaryDark, const Color(0xFFEC7A63));
    });

    test('accent aliases primary', () {
      expect(AppColors.accent, AppColors.primary);
    });

    test('success is moss', () {
      expect(AppColors.success, const Color(0xFF2A6236));
      expect(AppColors.successDark, const Color(0xFF7CBF8A));
    });

    test('error is the darker vermilion', () {
      expect(AppColors.error, const Color(0xFFA83A26));
      expect(AppColors.errorDark, const Color(0xFFE88A78));
    });

    test('light background is paper', () {
      expect(AppColors.backgroundLight, const Color(0xFFFAF8F3));
    });

    test('dark background is ink', () {
      expect(AppColors.backgroundDark, const Color(0xFF151311));
    });
  });

  group('AppTheme', () {
    test('light theme uses Material3', () {
      expect(AppTheme.light().useMaterial3, isTrue);
    });

    test('dark theme uses Material3', () {
      expect(AppTheme.dark().useMaterial3, isTrue);
    });

    test('light theme primary color matches AppColors', () {
      expect(AppTheme.light().colorScheme.primary, AppColors.primary);
    });

    test('dark theme primary color matches AppColors', () {
      expect(AppTheme.dark().colorScheme.primary, AppColors.primaryDark);
    });

    test('light theme scaffold background is correct', () {
      expect(
        AppTheme.light().scaffoldBackgroundColor,
        AppColors.backgroundLight,
      );
    });

    test('dark theme scaffold background is correct', () {
      expect(AppTheme.dark().scaffoldBackgroundColor, AppColors.backgroundDark);
    });

    test('light theme appBar has zero elevation', () {
      expect(AppTheme.light().appBarTheme.elevation, 0);
    });

    test('dark theme appBar has zero elevation', () {
      expect(AppTheme.dark().appBarTheme.elevation, 0);
    });

    test('light theme textTheme has displayLarge at 34', () {
      final theme = AppTheme.light();
      expect(theme.textTheme.displayLarge, isNotNull);
      expect(theme.textTheme.displayLarge?.fontSize, 34);
    });

    test('dark theme textTheme has displayLarge at 34', () {
      final theme = AppTheme.dark();
      expect(theme.textTheme.displayLarge, isNotNull);
      expect(theme.textTheme.displayLarge?.fontSize, 34);
    });

    test('light theme uses Pretendard font', () {
      expect(AppTheme.light().textTheme.bodyLarge?.fontFamily, 'Pretendard');
    });

    test('dark theme uses Pretendard font', () {
      expect(AppTheme.dark().textTheme.bodyLarge?.fontFamily, 'Pretendard');
    });

    test('light divider is the hairline border color', () {
      expect(AppTheme.light().dividerColor, AppColors.borderLight);
    });

    test('dark divider is the hairline border color', () {
      expect(AppTheme.dark().dividerColor, AppColors.borderDark);
    });

    test(
      'progress track is distinct from the hairline so the bar reads as a bar',
      () {
        for (final theme in [AppTheme.light(), AppTheme.dark()]) {
          expect(
            theme.progressIndicatorTheme.linearTrackColor,
            isNot(theme.dividerColor),
          );
        }
      },
    );

    test('progress fill is the accent', () {
      expect(AppTheme.light().progressIndicatorTheme.color, AppColors.primary);
      expect(
        AppTheme.dark().progressIndicatorTheme.color,
        AppColors.primaryDark,
      );
    });

    test('primary button is filled with ink, not with the accent', () {
      final light = AppTheme.light();
      expect(
        light.elevatedButtonTheme.style?.backgroundColor?.resolve(const {}),
        AppColors.textPrimaryLight,
      );
      expect(
        light.elevatedButtonTheme.style?.foregroundColor?.resolve(const {}),
        AppColors.backgroundLight,
      );

      final dark = AppTheme.dark();
      expect(
        dark.elevatedButtonTheme.style?.backgroundColor?.resolve(const {}),
        AppColors.textPrimaryDark,
      );
    });

    test('cards are separated by surface, not by an outline', () {
      final theme = AppTheme.light();
      expect(
        theme.colorScheme.surfaceContainer,
        AppColors.surfaceContainerLight,
      );
      expect(theme.colorScheme.surface, AppColors.backgroundLight);
      expect(
        theme.colorScheme.surfaceContainer,
        isNot(theme.colorScheme.surface),
      );
    });

    test('nav bar indicator is transparent', () {
      expect(
        AppTheme.light().navigationBarTheme.indicatorColor,
        Colors.transparent,
      );
    });
  });
}
