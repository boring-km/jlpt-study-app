import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jlpt/core/db/database.dart';
import 'package:jlpt/application/providers/database_provider.dart';
import 'package:jlpt/application/providers/progress_summary_provider.dart';
import 'package:jlpt/domain/models/word.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:jlpt/domain/repositories/word_repository.dart';
import 'package:jlpt/domain/repositories/progress_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('progressSummaryProvider returns correct currentLevel and counts', () async {
    final db = await AppDatabase.openForTest();
    final wordRepo = WordRepository(db);
    final progressRepo = ProgressRepository(db);

    // N3 단어 2개 삽입, 1개 완료
    await wordRepo.insertAll([
      const Word(id: 'n3_0001', jlptLevel: JlptLevel.n3, expression: '作法', reading: 'さほう', meaningKo: '예절'),
      const Word(id: 'n3_0002', jlptLevel: JlptLevel.n3, expression: '様々', reading: 'さまざま', meaningKo: '다양한'),
    ]);
    await progressRepo.markCompleted('n3_0001');

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) async => db),
      ],
    );
    addTearDown(container.dispose);

    final summary = await container.read(progressSummaryProvider.future);
    expect(summary.currentLevel, JlptLevel.n3); // N3 미완료이므로
    expect(summary.completedCount, 1);
    expect(summary.totalCount, 2);
    expect(summary.daysUntilExam, greaterThan(0)); // 2026-07-05 기준
  });
}
