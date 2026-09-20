import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jlpt/core/db/database.dart';
import 'package:jlpt/application/providers/database_provider.dart';
import 'package:jlpt/application/providers/settings_provider.dart';
import 'package:jlpt/domain/models/app_settings.dart';
import 'package:jlpt/domain/models/word.dart';
import 'package:jlpt/domain/repositories/progress_repository.dart';
import 'package:jlpt/domain/repositories/settings_repository.dart';
import 'package:jlpt/domain/repositories/word_repository.dart';
import 'package:jlpt/features/explore/explore_provider.dart';

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
    expect(settings.examDate, AppSettings.nextJlptDate(DateTime.now()));
    expect(settings.themeMode, AppThemeMode.system);
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

  test('resetProgress clears word_progress rows', () async {
    final db = await AppDatabase.openForTest();
    await ProgressRepository(db).markCompleted('n2_0001');
    final before = await db.query('word_progress');
    expect(before, isNotEmpty);

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWith((ref) async => db)],
    );
    addTearDown(container.dispose);

    await container.read(settingsProvider.future); // initialize
    await container.read(settingsProvider.notifier).resetProgress();

    final after = await db.query('word_progress');
    expect(after, isEmpty);
  });

  test(
    'resetProgress invalidates exploreProvider so completedWordIds clears',
    () async {
      final db = await AppDatabase.openForTest();
      await SettingsRepository(db).setDataVersion(AppDatabase.kDataVersion);
      await WordRepository(db).upsertAll([
        const Word(
          id: 'n2_0001',
          expression: '語',
          reading: 'ご',
          meaningKo: '뜻',
        ),
      ]);
      await ProgressRepository(db).markCompleted('n2_0001');

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) async => db)],
      );
      addTearDown(container.dispose);

      await container.read(settingsProvider.future); // initialize
      final beforeExplore = await container.read(exploreProvider.future);
      expect(beforeExplore.completedWordIds, contains('n2_0001'));

      await container.read(settingsProvider.notifier).resetProgress();

      final afterExplore = await container.read(exploreProvider.future);
      expect(afterExplore.completedWordIds, isEmpty);
    },
  );
}
