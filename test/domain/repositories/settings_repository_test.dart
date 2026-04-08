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
    expect(settings.examDate, DateTime(2026, 7, 5));
    expect(settings.themeMode, AppThemeMode.light);
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

  test('legacy system theme is loaded as light mode', () async {
    await db.insert('app_settings', {
      'key': 'theme_mode',
      'value': 'system',
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    final settings = await repo.load();
    expect(settings.themeMode, AppThemeMode.light);
  });

  test('isSeeded returns false initially', () async {
    expect(await repo.isSeeded(), isFalse);
  });

  test('markSeeded then isSeeded returns true', () async {
    await repo.markSeeded();
    expect(await repo.isSeeded(), isTrue);
  });
}
