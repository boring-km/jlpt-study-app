import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/application/providers/database_provider.dart';
import 'package:jlpt/application/providers/miss_tag_counts_provider.dart';
import 'package:jlpt/application/providers/progress_summary_provider.dart';
import 'package:jlpt/application/providers/review_session_provider.dart';
import 'package:jlpt/core/db/database.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:jlpt/domain/models/error_tag.dart';
import 'package:jlpt/domain/models/word.dart';
import 'package:jlpt/domain/repositories/miss_log_repository.dart';
import 'package:jlpt/domain/repositories/progress_repository.dart';
import 'package:jlpt/domain/repositories/settings_repository.dart';
import 'package:jlpt/domain/repositories/review_repository.dart';
import 'package:jlpt/domain/repositories/word_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ReviewSessionNotifier.buildBlendedSelection', () {
    test('약점 70% + 나머지 30%로 구성되고 총합은 targetSize', () async {
      final db = await AppDatabase.openForTest();
      final wordRepo = WordRepository(db);
      final progressRepo = ProgressRepository(db);

      // 20개 완료 단어 중 10개를 약점으로
      final words = List.generate(
        20,
        (i) => Word(
          id: 'n2_${(i + 1).toString().padLeft(4, '0')}',
          expression: '語$i',
          reading: 'ご$i',
          meaningKo: '말$i',
        ),
      );
      await wordRepo.insertAll(words);
      for (final w in words) {
        await progressRepo.markCompleted(w.id);
      }
      for (int i = 0; i < 10; i++) {
        await progressRepo.incrementMiss(words[i].id);
      }

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) async => db)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(reviewSessionProvider.notifier);
      final selected = await notifier.buildBlendedSelectionForTest(
        progressRepo,
        size: 10,
        weakRatio: 0.7,
      );

      expect(selected.length, 10);

      // 약점 슬롯 7개는 약점 풀에서 확정 선택. clean 슬롯 3개는 남은 완료 단어
      // (= 남은 약점 3개 + 비약점 10개)에서 랜덤 → 약점 수는 최소 7, 최대 10.
      final weakIds = words.take(10).map((w) => w.id).toSet();
      final weakInSelection = selected.where(weakIds.contains).length;
      expect(weakInSelection, greaterThanOrEqualTo(7));
      expect(weakInSelection, lessThanOrEqualTo(10));
      await db.close();
    });

    test('약점이 부족하면 clean으로 채움', () async {
      final db = await AppDatabase.openForTest();
      final wordRepo = WordRepository(db);
      final progressRepo = ProgressRepository(db);

      final words = List.generate(
        10,
        (i) => Word(
          id: 'n2_${(i + 1).toString().padLeft(4, '0')}',
          expression: '語$i',
          reading: 'ご$i',
          meaningKo: '말$i',
        ),
      );
      await wordRepo.insertAll(words);
      for (final w in words) {
        await progressRepo.markCompleted(w.id);
      }
      // 약점 2개만
      await progressRepo.incrementMiss(words[0].id);
      await progressRepo.incrementMiss(words[1].id);

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) async => db)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(reviewSessionProvider.notifier);
      final selected = await notifier.buildBlendedSelectionForTest(
        progressRepo,
        size: 10,
        weakRatio: 0.7,
      );

      expect(selected.length, 10);
      // 약점 2개 전부 포함되어야 함
      expect(selected, containsAll([words[0].id, words[1].id]));
      await db.close();
    });

    test('완료 단어가 부족하면 있는 만큼만 반환', () async {
      final db = await AppDatabase.openForTest();
      final wordRepo = WordRepository(db);
      final progressRepo = ProgressRepository(db);

      final words = List.generate(
        3,
        (i) => Word(
          id: 'n2_${(i + 1).toString().padLeft(4, '0')}',
          expression: '語$i',
          reading: 'ご$i',
          meaningKo: '말$i',
        ),
      );
      await wordRepo.insertAll(words);
      for (final w in words) {
        await progressRepo.markCompleted(w.id);
      }
      await progressRepo.incrementMiss(words[0].id);

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) async => db)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(reviewSessionProvider.notifier);
      final selected = await notifier.buildBlendedSelectionForTest(
        progressRepo,
        size: 20,
        weakRatio: 0.7,
      );

      expect(selected.length, 3);
      await db.close();
    });

    test('약점이 0개면 전부 clean에서 뽑음', () async {
      final db = await AppDatabase.openForTest();
      final wordRepo = WordRepository(db);
      final progressRepo = ProgressRepository(db);

      final words = List.generate(
        5,
        (i) => Word(
          id: 'n2_${(i + 1).toString().padLeft(4, '0')}',
          expression: '語$i',
          reading: 'ご$i',
          meaningKo: '말$i',
        ),
      );
      await wordRepo.insertAll(words);
      for (final w in words) {
        await progressRepo.markCompleted(w.id);
      }

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) async => db)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(reviewSessionProvider.notifier);
      final selected = await notifier.buildBlendedSelectionForTest(
        progressRepo,
        size: 5,
        weakRatio: 0.7,
      );

      expect(selected.length, 5);
      expect(selected.toSet(), words.map((w) => w.id).toSet());
      await db.close();
    });
  });

  group('ReviewSessionNotifier session flow', () {
    Future<(Database, ProviderContainer)> setup() async {
      final db = await AppDatabase.openForTest();
      await SettingsRepository(db).setDataVersion(AppDatabase.kDataVersion);
      await WordRepository(db).insertAll([
        for (var i = 0; i < 30; i++)
          Word(id: 'n2_$i', expression: '語$i', reading: 'ご$i', meaningKo: 'x'),
      ]);
      final progressRepo = ProgressRepository(db);
      for (var i = 0; i < 30; i++) {
        await progressRepo.markCompleted('n2_$i');
      }
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWith((ref) async => db),
        progressSummaryProvider.overrideWith((ref) async => const ProgressSummary(
              completedCount: 30,
              totalCount: 30,
              daysUntilExam: 10,
              dailyTarget: 0,
              weakCount: 0,
            )),
      ]);
      addTearDown(container.dispose);
      return (db, container);
    }

    test('startNewSession with tag uses miss_log words first', () async {
      final db = await AppDatabase.openForTest();
      await SettingsRepository(db).setDataVersion(AppDatabase.kDataVersion);
      await WordRepository(db).insertAll([
        for (var i = 0; i < 30; i++)
          Word(id: 'n2_$i', expression: '語$i', reading: 'ご$i', meaningKo: 'x'),
      ]);
      final progressRepo = ProgressRepository(db);
      for (var i = 0; i < 30; i++) {
        await progressRepo.markCompleted('n2_$i');
      }
      final missRepo = MissLogRepository(db);
      await missRepo.add('n2_3', ErrorTag.longVowel);
      await missRepo.add('n2_7', ErrorTag.longVowel);
      await missRepo.add('n2_9', ErrorTag.sokuon);

      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWith((ref) async => db),
        progressSummaryProvider.overrideWith((ref) async => const ProgressSummary(
              completedCount: 30,
              totalCount: 30,
              daysUntilExam: 10,
              dailyTarget: 0,
              weakCount: 0,
            )),
      ]);
      addTearDown(container.dispose);
      final session = await container
          .read(reviewSessionProvider.notifier)
          .startNewSession(tag: ErrorTag.longVowel);
      final ids = session.items.map((i) => i.wordId).toList();
      expect(ids, containsAll(['n2_3', 'n2_7']));
      expect(ids.length, 20); // 부족분은 블렌드로 채움
      expect(ids.toSet().length, 20);
      await db.close();
    });

    test('startNewSession without tag creates a quiz session and persists it', () async {
      final (db, c) = await setup();
      final session = await c.read(reviewSessionProvider.notifier).startNewSession();

      expect(session.status, StudyStage.quiz);
      expect(session.items.length, 20);
      expect(session.itemCount, 20);
      expect(session.items.every((i) => !i.passed && i.attempts == 0), isTrue);

      final stored = await ReviewRepository(db).getById(session.id);
      expect(stored, isNotNull);
      expect(stored!.items.length, 20);
      await db.close();
    });

    test('updateItemResult wrong: attempts+1, miss_count+1, miss_log row', () async {
      final (db, c) = await setup();
      final n = c.read(reviewSessionProvider.notifier);
      final session = await n.startNewSession();
      final id = session.items.first.wordId;

      await n.updateItemResult(id, passed: false, tag: ErrorTag.dakuten);

      final item = c
          .read(reviewSessionProvider)
          .valueOrNull!
          .items
          .firstWhere((i) => i.wordId == id);
      expect(item.passed, isFalse);
      expect(item.attempts, 1);
      expect((await ProgressRepository(db).get(id))!.missCount, 1);
      expect(await MissLogRepository(db).tagsForWord(id), [ErrorTag.dakuten]);
      await db.close();
    });

    test('updateItemResult wrong without tag logs ErrorTag.other', () async {
      final (db, c) = await setup();
      final n = c.read(reviewSessionProvider.notifier);
      final session = await n.startNewSession();
      final id = session.items.first.wordId;

      await n.updateItemResult(id, passed: false);

      expect(await MissLogRepository(db).tagsForWord(id), [ErrorTag.other]);
      await db.close();
    });

    test('updateItemResult right: passed true, miss_count decremented, no miss_log', () async {
      final (db, c) = await setup();
      final n = c.read(reviewSessionProvider.notifier);
      final session = await n.startNewSession();
      final id = session.items.first.wordId;
      await ProgressRepository(db).incrementMiss(id);

      await n.updateItemResult(id, passed: true);

      final item = c
          .read(reviewSessionProvider)
          .valueOrNull!
          .items
          .firstWhere((i) => i.wordId == id);
      expect(item.passed, isTrue);
      expect(item.attempts, 1);
      expect((await ProgressRepository(db).get(id))!.missCount, 0);
      expect(await MissLogRepository(db).tagsForWord(id), isEmpty);
      await db.close();
    });

    test('complete marks session completed in state and db', () async {
      final (db, c) = await setup();
      final n = c.read(reviewSessionProvider.notifier);
      final session = await n.startNewSession();

      await n.complete();

      final state = c.read(reviewSessionProvider).valueOrNull!;
      expect(state.status, StudyStage.completed);
      expect(state.completedAt, isNotNull);
      final stored = await ReviewRepository(db).getById(session.id);
      expect(stored!.status, StudyStage.completed);
      await db.close();
    });
  });

  group('missTagCountsProvider', () {
    test('counts distinct words per tag', () async {
      final db = await AppDatabase.openForTest();
      final missRepo = MissLogRepository(db);
      await missRepo.add('n2_1', ErrorTag.longVowel);
      await missRepo.add('n2_1', ErrorTag.longVowel);
      await missRepo.add('n2_2', ErrorTag.longVowel);
      await missRepo.add('n2_3', ErrorTag.sokuon);

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWith((ref) async => db)],
      );
      addTearDown(container.dispose);

      final counts = await container.read(missTagCountsProvider.future);
      expect(counts[ErrorTag.longVowel], 2);
      expect(counts[ErrorTag.sokuon], 1);
      expect(counts[ErrorTag.dakuten], isNull);
      await db.close();
    });
  });
}
