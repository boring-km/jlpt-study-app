import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jlpt/core/db/database.dart';
import 'package:jlpt/application/providers/database_provider.dart';
import 'package:jlpt/application/providers/progress_summary_provider.dart';
import 'package:jlpt/domain/models/word.dart';
import 'package:jlpt/domain/repositories/settings_repository.dart';
import 'package:jlpt/domain/repositories/word_repository.dart';
import 'package:jlpt/domain/repositories/progress_repository.dart';
import 'package:jlpt/domain/services/study_set_builder.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  /// 에셋 시딩을 건너뛰고 단어 [count]개를 넣은 테스트 DB.
  Future<Database> seedDb(int count) async {
    final db = await AppDatabase.openForTest();
    await SettingsRepository(db).setDataVersion(AppDatabase.kDataVersion);
    await WordRepository(db).upsertAll([
      for (var i = 1; i <= count; i++)
        Word(
          id: 'n2_${i.toString().padLeft(4, '0')}',
          expression: '語$i',
          reading: 'ご$i',
          meaningKo: '뜻$i',
        ),
    ]);
    return db;
  }

  test('counts words/progress and spreads remaining over days until exam', () async {
    final db = await seedDb(25);
    final progressRepo = ProgressRepository(db);
    for (var i = 1; i <= 5; i++) {
      await progressRepo.markCompleted('n2_${i.toString().padLeft(4, '0')}');
    }
    // 완료 단어 1개를 약점으로 만든다.
    await progressRepo.incrementMiss('n2_0001');
    await SettingsRepository(db)
        .saveExamDate(DateTime.now().add(const Duration(days: 3)));

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWith((ref) async => db)],
    );
    addTearDown(container.dispose);

    final summary = await container.read(progressSummaryProvider.future);
    expect(summary.totalCount, 25);
    expect(summary.completedCount, 5);
    expect(summary.remainingCount, 20);
    expect(summary.daysUntilExam, 3);
    expect(summary.dailyTarget, 7); // ceil(20 / 3)
    expect(summary.weakCount, 1);
    expect(summary.isExamPassed, isFalse);
    await db.close();
  });

  test('targets everything that is left on the exam day itself', () async {
    final db = await seedDb(7);
    await SettingsRepository(db).saveExamDate(DateTime.now());

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWith((ref) async => db)],
    );
    addTearDown(container.dispose);

    final summary = await container.read(progressSummaryProvider.future);
    expect(summary.daysUntilExam, 0);
    expect(summary.isExamPassed, isFalse);
    expect(summary.remainingCount, 7);
    expect(summary.dailyTarget, 7); // ceil(7 / 1)
    await db.close();
  });

  test('caps the daily target when the catch-up formula explodes', () async {
    // D-1에 1,000개가 남으면 산식은 1,000을 내놓는다 — 하루에 끝낼 수 없는
    // 세트가 만들어지지 않도록 kMaxDailyTarget으로 자른다.
    final db = await seedDb(1000);
    await SettingsRepository(db)
        .saveExamDate(DateTime.now().add(const Duration(days: 1)));

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWith((ref) async => db)],
    );
    addTearDown(container.dispose);

    final summary = await container.read(progressSummaryProvider.future);
    expect(summary.daysUntilExam, 1);
    expect(summary.remainingCount, 1000);
    expect(summary.dailyTarget, kMaxDailyTarget);
    expect(summary.dailyTarget, 40);
    await db.close();
  });

  test('falls back to post-exam daily target once the exam date has passed', () async {
    final db = await seedDb(25);
    await SettingsRepository(db)
        .saveExamDate(DateTime.now().subtract(const Duration(days: 1)));

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWith((ref) async => db)],
    );
    addTearDown(container.dispose);

    final summary = await container.read(progressSummaryProvider.future);
    expect(summary.daysUntilExam, -1);
    expect(summary.isExamPassed, isTrue);
    expect(summary.dailyTarget, kPostExamDailyTarget);
    expect(summary.dailyTarget, 10);
    await db.close();
  });

  test('daily target is zero when everything is completed after the exam', () async {
    final db = await seedDb(2);
    final progressRepo = ProgressRepository(db);
    await progressRepo.markCompleted('n2_0001');
    await progressRepo.markCompleted('n2_0002');
    await SettingsRepository(db)
        .saveExamDate(DateTime.now().subtract(const Duration(days: 1)));

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWith((ref) async => db)],
    );
    addTearDown(container.dispose);

    final summary = await container.read(progressSummaryProvider.future);
    expect(summary.remainingCount, 0);
    expect(summary.dailyTarget, 0);
    await db.close();
  });
}
