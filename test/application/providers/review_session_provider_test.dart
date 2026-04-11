import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/application/providers/database_provider.dart';
import 'package:jlpt/application/providers/review_session_provider.dart';
import 'package:jlpt/core/db/database.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:jlpt/domain/models/word.dart';
import 'package:jlpt/domain/repositories/progress_repository.dart';
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
          id: 'n3_${(i + 1).toString().padLeft(4, '0')}',
          jlptLevel: JlptLevel.n3,
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
        JlptLevel.n3,
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
    });

    test('약점이 부족하면 clean으로 채움', () async {
      final db = await AppDatabase.openForTest();
      final wordRepo = WordRepository(db);
      final progressRepo = ProgressRepository(db);

      final words = List.generate(
        10,
        (i) => Word(
          id: 'n3_${(i + 1).toString().padLeft(4, '0')}',
          jlptLevel: JlptLevel.n3,
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
        JlptLevel.n3,
        size: 10,
        weakRatio: 0.7,
      );

      expect(selected.length, 10);
      // 약점 2개 전부 포함되어야 함
      expect(selected, containsAll([words[0].id, words[1].id]));
    });

    test('완료 단어가 부족하면 있는 만큼만 반환', () async {
      final db = await AppDatabase.openForTest();
      final wordRepo = WordRepository(db);
      final progressRepo = ProgressRepository(db);

      final words = List.generate(
        3,
        (i) => Word(
          id: 'n3_${(i + 1).toString().padLeft(4, '0')}',
          jlptLevel: JlptLevel.n3,
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
        JlptLevel.n3,
        size: 20,
        weakRatio: 0.7,
      );

      expect(selected.length, 3);
    });

    test('약점이 0개면 전부 clean에서 뽑음', () async {
      final db = await AppDatabase.openForTest();
      final wordRepo = WordRepository(db);
      final progressRepo = ProgressRepository(db);

      final words = List.generate(
        5,
        (i) => Word(
          id: 'n3_${(i + 1).toString().padLeft(4, '0')}',
          jlptLevel: JlptLevel.n3,
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
        JlptLevel.n3,
        size: 5,
        weakRatio: 0.7,
      );

      expect(selected.length, 5);
      expect(selected.toSet(), words.map((w) => w.id).toSet());
    });
  });
}
