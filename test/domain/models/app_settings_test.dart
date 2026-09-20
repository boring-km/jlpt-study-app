import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/domain/models/app_settings.dart';

void main() {
  group('nextJlptDate', () {
    test('before July returns first Sunday of July', () {
      expect(
        AppSettings.nextJlptDate(DateTime(2026, 3, 1)),
        DateTime(2026, 7, 5),
      );
    });
    test('between July and December returns first Sunday of December', () {
      expect(
        AppSettings.nextJlptDate(DateTime(2026, 9, 19)),
        DateTime(2026, 12, 6),
      );
    });
    test('on exam day returns that day', () {
      expect(
        AppSettings.nextJlptDate(DateTime(2026, 12, 6)),
        DateTime(2026, 12, 6),
      );
    });
    test('after December exam rolls to next July', () {
      expect(
        AppSettings.nextJlptDate(DateTime(2026, 12, 7)),
        DateTime(2027, 7, 4),
      );
    });
  });

  group('defaults', () {
    test('theme follows the system so a dark-mode user never gets flashed', () {
      expect(AppSettings.defaults.themeMode, AppThemeMode.system);
    });
    test('exam date is the next JLPT', () {
      expect(
        AppSettings.defaults.examDate,
        AppSettings.nextJlptDate(DateTime.now()),
      );
    });
  });

  group('daysUntilExam', () {
    final s = AppSettings(
      examDate: DateTime(2026, 12, 6),
      themeMode: AppThemeMode.light,
    );
    test(
      'positive before',
      () => expect(s.daysUntilExam(DateTime(2026, 9, 19)), 78),
    );
    test(
      'zero on day',
      () => expect(s.daysUntilExam(DateTime(2026, 12, 6)), 0),
    );
    test(
      'negative after',
      () => expect(s.daysUntilExam(DateTime(2026, 12, 7)), -1),
    );
  });
}
