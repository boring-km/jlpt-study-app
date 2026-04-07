enum AppThemeMode { system, light, dark }

class AppSettings {
  final DateTime examDate;
  final AppThemeMode themeMode;
  final DateTime? seededAt;

  const AppSettings({
    required this.examDate,
    required this.themeMode,
    this.seededAt,
  });

  static AppSettings get defaults => AppSettings(
        examDate: DateTime(2026, 7, 5),
        themeMode: AppThemeMode.system,
      );

  int daysUntilExam(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final exam = DateTime(examDate.year, examDate.month, examDate.day);
    return exam.difference(today).inDays;
  }
}
