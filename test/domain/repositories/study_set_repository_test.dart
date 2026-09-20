import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jlpt/core/db/database.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:jlpt/domain/models/today_study_set.dart';
import 'package:jlpt/domain/models/word.dart';
import 'package:jlpt/domain/repositories/study_set_repository.dart';
import 'package:jlpt/domain/repositories/word_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final now = DateTime(2026, 4, 7, 12, 0);
  const date = '2026-04-07';

  TodayStudyItem item(String wordId, int order) => TodayStudyItem(
        studyDate: date,
        wordId: wordId,
        displayOrder: order,
        passed: false,
        attempts: 0,
        updatedAt: now,
      );

  Future<StudySetRepository> seed(Database db) async {
    await WordRepository(db).insertAll(const [
      Word(id: 'n2_0001', expression: 'a', reading: 'あ', meaningKo: 'x'),
      Word(id: 'n2_0002', expression: 'b', reading: 'い', meaningKo: 'y'),
      Word(id: 'n2_0003', expression: 'c', reading: 'う', meaningKo: 'z'),
    ]);
    final repo = StudySetRepository(db);
    await repo.createSet(TodayStudySet(
      studyDate: date,
      targetCount: 2,
      status: StudyStage.completed,
      items: [item('n2_0001', 0), item('n2_0002', 1)],
      completedAt: now,
      createdAt: now,
      updatedAt: now,
    ));
    return repo;
  }

  test('appendItems counts existing items once and reopens the set', () async {
    final db = await AppDatabase.openForTest();
    final repo = await seed(db);

    await repo.appendItems(date, [item('n2_0003', 2)]);

    final set = (await repo.getByDate(date))!;
    expect(set.items.length, 3);
    expect(set.targetCount, 3);
    expect(set.status, StudyStage.quiz);
    expect(set.completedAt, isNull);
    await db.close();
  });

  test('appendItems throws and writes nothing when the parent set is missing',
      () async {
    final db = await AppDatabase.openForTest();
    final repo = await seed(db);

    await expectLater(
      repo.appendItems('2026-04-08', [item('n2_0003', 0)]),
      throwsA(isA<StateError>()),
    );
    expect(
      await db.query('daily_study_set_items', where: "study_date = '2026-04-08'"),
      isEmpty,
    );
    await db.close();
  });

  test('deleteAll removes every set and its items', () async {
    final db = await AppDatabase.openForTest();
    final repo = await seed(db);

    await repo.deleteAll();

    expect(await repo.getByDate(date), isNull);
    expect(await db.query('daily_study_set_items'), isEmpty);
    await db.close();
  });
}
