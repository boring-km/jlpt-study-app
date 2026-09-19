enum AppThemeMode { light, dark }

class AppSettings {
  final DateTime examDate;
  final AppThemeMode themeMode;

  const AppSettings({required this.examDate, required this.themeMode});

  static AppSettings get defaults => AppSettings(
        examDate: nextJlptDate(DateTime.now()),
        themeMode: AppThemeMode.light,
      );

  /// JLPT는 7월·12월 첫째 일요일. 오늘 이후(당일 포함) 가장 가까운 시험일.
  static DateTime nextJlptDate(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    for (var year = today.year; year <= today.year + 1; year++) {
      for (final month in [7, 12]) {
        final candidate = _firstSunday(year, month);
        if (!candidate.isBefore(today)) return candidate;
      }
    }
    return _firstSunday(today.year + 1, 7);
  }

  static DateTime _firstSunday(int year, int month) {
    final first = DateTime(year, month, 1);
    final offset = (DateTime.sunday - first.weekday) % 7;
    return DateTime(year, month, 1 + offset);
  }

  int daysUntilExam(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final exam = DateTime(examDate.year, examDate.month, examDate.day);
    return exam.difference(today).inDays;
  }

  AppSettings copyWith({DateTime? examDate, AppThemeMode? themeMode}) =>
      AppSettings(
        examDate: examDate ?? this.examDate,
        themeMode: themeMode ?? this.themeMode,
      );
}
