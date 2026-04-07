import 'package:sqflite/sqflite.dart';
import '../models/app_settings.dart';

class SettingsRepository {
  final Database _db;
  const SettingsRepository(this._db);

  Future<String?> _get(String key) async {
    final rows = await _db.query('app_settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  Future<void> _set(String key, String value) async {
    final now = DateTime.now().toIso8601String();
    await _db.insert(
      'app_settings',
      {'key': key, 'value': value, 'updated_at': now},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<AppSettings> load() async {
    final examDateStr = await _get('exam_date');
    final themeModeStr = await _get('theme_mode');
    final seededAtStr = await _get('seeded_at');
    return AppSettings(
      examDate: examDateStr != null ? DateTime.parse(examDateStr) : AppSettings.defaults.examDate,
      themeMode: AppThemeMode.values.firstWhere(
        (e) => e.name == (themeModeStr ?? 'system'),
        orElse: () => AppThemeMode.system,
      ),
      seededAt: seededAtStr != null ? DateTime.parse(seededAtStr) : null,
    );
  }

  Future<void> saveExamDate(DateTime date) => _set('exam_date', date.toIso8601String());
  Future<void> saveThemeMode(AppThemeMode mode) => _set('theme_mode', mode.name);
  Future<void> markSeeded() => _set('seeded_at', DateTime.now().toIso8601String());
  Future<bool> isSeeded() async => (await _get('seeded_at')) != null;
}
