import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jlpt/core/db/database.dart';
import 'package:jlpt/application/providers/database_provider.dart';
import 'package:jlpt/application/providers/settings_provider.dart';
import 'package:jlpt/domain/models/app_settings.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('settingsProvider returns defaults on fresh DB', () async {
    final db = await AppDatabase.openForTest();
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWith((ref) async => db)],
    );
    addTearDown(container.dispose);

    final settings = await container.read(settingsProvider.future);
    expect(settings.examDate, DateTime(2026, 7, 5));
    expect(settings.themeMode, AppThemeMode.light);
  });

  test('updateExamDate persists via SettingsNotifier', () async {
    final db = await AppDatabase.openForTest();
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWith((ref) async => db)],
    );
    addTearDown(container.dispose);

    await container.read(settingsProvider.future); // initialize
    await container
        .read(settingsProvider.notifier)
        .updateExamDate(DateTime(2027, 1, 1));

    final updated = await container.read(settingsProvider.future);
    expect(updated.examDate.year, 2027);
  });
}
