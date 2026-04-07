import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/domain/models/app_settings.dart';

void main() {
  group('AppSettings', () {
    test('daysUntilExam returns positive when exam is in future', () {
      final settings = AppSettings(
        examDate: DateTime(2026, 7, 5),
        themeMode: AppThemeMode.system,
      );
      final days = settings.daysUntilExam(DateTime(2026, 4, 7));
      expect(days, 89);
    });

    test('daysUntilExam returns 0 on exam day', () {
      final settings = AppSettings(
        examDate: DateTime(2026, 7, 5),
        themeMode: AppThemeMode.system,
      );
      expect(settings.daysUntilExam(DateTime(2026, 7, 5)), 0);
    });

    test('daysUntilExam returns negative after exam', () {
      final settings = AppSettings(
        examDate: DateTime(2026, 7, 5),
        themeMode: AppThemeMode.system,
      );
      expect(settings.daysUntilExam(DateTime(2026, 7, 6)), -1);
    });

    test('defaults has exam date 2026-07-05', () {
      expect(AppSettings.defaults.examDate, DateTime(2026, 7, 5));
    });
  });
}
