import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jlpt/core/db/database.dart';
import 'package:jlpt/application/providers/database_provider.dart';
import 'package:jlpt/application/providers/today_study_set_provider.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:jlpt/domain/models/word.dart';
import 'package:jlpt/domain/repositories/word_repository.dart';
import 'package:jlpt/domain/repositories/settings_repository.dart';
import 'package:jlpt/domain/models/word_progress.dart';
import 'package:jlpt/domain/repositories/progress_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('todayStudySetProvider returns null on fresh DB (no set today)', () async {
    final db = await AppDatabase.openForTest();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) async => db),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(todayStudySetProvider.future);
    expect(result, isNull);
  });

  test('createTodaySet creates a set with correct level and items', () async {
    final db = await AppDatabase.openForTest();

    final wordRepo = WordRepository(db);
    final settingsRepo = SettingsRepository(db);
    final progressRepo = ProgressRepository(db);

    final words = List.generate(
      10,
      (i) => Word(
        id: 'n3_${(i + 1).toString().padLeft(4, '0')}',
        jlptLevel: JlptLevel.n3,
        reading: 'たんご$i',
        meaningKo: '단어$i',
      ),
    );
    await wordRepo.insertAll(words);
    await settingsRepo.markSeeded();
    for (final w in words) {
      await progressRepo.upsert(WordProgress(
        wordId: w.id,
        isCompleted: false,
        reviewCount: 0,
        missCount: 0,
        updatedAt: DateTime.now(),
      ));
    }

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) async => db),
      ],
    );
    addTearDown(container.dispose);

    final set = await container.read(todayStudySetProvider.notifier).createTodaySet();
    expect(set.jlptLevel, JlptLevel.n3);
    expect(set.items, isNotEmpty);
    expect(set.status, StudyStage.flashcard);
  });

  test('advanceStage updates the set status', () async {
    final db = await AppDatabase.openForTest();

    final wordRepo = WordRepository(db);
    final settingsRepo = SettingsRepository(db);
    final progressRepo = ProgressRepository(db);

    final words = List.generate(
      5,
      (i) => Word(
        id: 'n3_${(i + 1).toString().padLeft(4, '0')}',
        jlptLevel: JlptLevel.n3,
        reading: 'ご$i',
        meaningKo: '어$i',
      ),
    );
    await wordRepo.insertAll(words);
    await settingsRepo.markSeeded();
    for (final w in words) {
      await progressRepo.upsert(WordProgress(
        wordId: w.id,
        isCompleted: false,
        reviewCount: 0,
        missCount: 0,
        updatedAt: DateTime.now(),
      ));
    }

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) async => db),
      ],
    );
    addTearDown(container.dispose);

    await container.read(todayStudySetProvider.notifier).createTodaySet();
    await container.read(todayStudySetProvider.notifier).advanceStage(StudyStage.quizReading);

    final updated = container.read(todayStudySetProvider).valueOrNull;
    expect(updated?.status, StudyStage.quizReading);
  });
}
