import 'package:sqflite/sqflite.dart';
import '../models/app_settings.dart';

class SettingsRepository {
  final Database _db;
  const SettingsRepository(this._db);

  Future<String?> _get(String key) async {
    final rows = await _db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  Future<void> _set(String key, String value) async {
    final now = DateTime.now().toIso8601String();
    await _db.insert('app_settings', {
      'key': key,
      'value': value,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<AppSettings> load() async {
    final examDateStr = await _get('exam_date');
    final themeModeStr = await _get('theme_mode');
    final themeMode = switch (themeModeStr) {
      'dark' => AppThemeMode.dark,
      'light' => AppThemeMode.light,
      _ => AppThemeMode.system,
    };
    return AppSettings(
      examDate: examDateStr != null
          ? DateTime.parse(examDateStr)
          : AppSettings.defaults.examDate,
      themeMode: themeMode,
    );
  }

  Future<void> saveExamDate(DateTime date) =>
      _set('exam_date', date.toIso8601String());
  Future<void> saveThemeMode(AppThemeMode mode) =>
      _set('theme_mode', mode.name);

  /// 에셋 카탈로그 시딩 버전. 미설정이면 0.
  Future<int> dataVersion() async {
    final v = await _get('data_version');
    return v != null ? int.tryParse(v) ?? 0 : 0;
  }

  Future<void> setDataVersion(int version) =>
      _set('data_version', version.toString());
}
