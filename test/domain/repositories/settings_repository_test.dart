import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jlpt/core/db/database.dart';
import 'package:jlpt/domain/models/app_settings.dart';
import 'package:jlpt/domain/repositories/settings_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late SettingsRepository repo;
  late Database db;

  setUp(() async {
    db = await AppDatabase.openForTest();
    repo = SettingsRepository(db);
  });

  test('load returns defaults when no settings stored', () async {
    final settings = await repo.load();
    expect(settings.examDate, AppSettings.nextJlptDate(DateTime.now()));
    expect(settings.themeMode, AppThemeMode.system);
  });

  test('saveExamDate persists and load returns it', () async {
    await repo.saveExamDate(DateTime(2026, 12, 1));
    final settings = await repo.load();
    expect(settings.examDate.year, 2026);
    expect(settings.examDate.month, 12);
  });

  test('saveThemeMode persists dark mode', () async {
    await repo.saveThemeMode(AppThemeMode.dark);
    final settings = await repo.load();
    expect(settings.themeMode, AppThemeMode.dark);
  });

  test('saveThemeMode persists system mode', () async {
    await repo.saveThemeMode(AppThemeMode.system);
    final settings = await repo.load();
    expect(settings.themeMode, AppThemeMode.system);
  });

  test('an unknown stored theme value falls back to system', () async {
    await db.insert('app_settings', {
      'key': 'theme_mode',
      'value': 'sepia',
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    final settings = await repo.load();
    expect(settings.themeMode, AppThemeMode.system);
  });

  test('dataVersion defaults to 0 and persists', () async {
    final db = await AppDatabase.openForTest();
    final repo = SettingsRepository(db);
    expect(await repo.dataVersion(), 0);
    await repo.setDataVersion(2);
    expect(await repo.dataVersion(), 2);
    await db.close();
  });
}
