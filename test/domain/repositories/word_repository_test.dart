import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jlpt/core/db/database.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:jlpt/domain/models/word.dart';
import 'package:jlpt/domain/repositories/progress_repository.dart';
import 'package:jlpt/domain/repositories/word_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const words = [
    Word(id: 'n2_0001', expression: '紅葉', reading: 'こうよう', meaningKo: '단풍', type: WordType.on),
    Word(id: 'n2_0002', expression: '紅葉', reading: 'もみじ', meaningKo: '단풍', type: WordType.kun),
    Word(id: 'n2_0003', expression: '工夫', reading: 'くふう', meaningKo: '궁리', type: WordType.on, isTrap: true),
    Word(id: 'n2_0004', expression: 'こうこく', reading: 'こうこく', meaningKo: '광고'),
  ];

  test('upsertAll updates text fields and keeps progress', () async {
    final db = await AppDatabase.openForTest();
    final repo = WordRepository(db);
    await repo.insertAll(words);
    await ProgressRepository(db).markCompleted('n2_0003');
    await repo.upsertAll([words[2].copyWith(meaningKo: '궁리, 고안')]);
    expect((await repo.getById('n2_0003'))!.meaningKo, '궁리, 고안');
    expect((await ProgressRepository(db).get('n2_0003'))!.isCompleted, isTrue);
    expect(await repo.count(), 4);
    await db.close();
  });

  test('deleteN2NotIn removes stale n2 words and their progress, keeps user words', () async {
    final db = await AppDatabase.openForTest();
    final repo = WordRepository(db);
    await repo.insertAll(words);
    await repo.insertUserWord(const Word(id: 'user_1', expression: '把握', reading: 'はあく', meaningKo: '파악', source: 'user'));
    await ProgressRepository(db).markCompleted('n2_0004');
    await repo.deleteN2NotIn({'n2_0001', 'n2_0002', 'n2_0003'});
    expect(await repo.getById('n2_0004'), isNull);
    expect(await ProgressRepository(db).get('n2_0004'), isNull);
    expect(await repo.getById('user_1'), isNotNull);
    await db.close();
  });

  test('findByExpression / getReadingsByExpression', () async {
    final db = await AppDatabase.openForTest();
    final repo = WordRepository(db);
    await repo.insertAll(words);
    expect((await repo.findByExpression('工夫'))!.id, 'n2_0003');
    expect(await repo.findByExpression('없음'), isNull);
    expect(await repo.getReadingsByExpression('紅葉'), containsAll(['こうよう', 'もみじ']));
    await db.close();
  });

  test('getRandomReadingsStartingWith excludes given readings', () async {
    final db = await AppDatabase.openForTest();
    final repo = WordRepository(db);
    await repo.insertAll(words);
    final r = await repo.getRandomReadingsStartingWith('こ', limit: 5, exclude: {'こうよう'});
    expect(r, ['こうこく']);
    await db.close();
  });

  test('getRandomMeanings excludes the word itself', () async {
    final db = await AppDatabase.openForTest();
    final repo = WordRepository(db);
    await repo.insertAll(words);
    final m = await repo.getRandomMeanings(limit: 10, excludeWordId: 'n2_0003');
    expect(m, isNot(contains('궁리')));
    expect(m.toSet().length, m.length);
    await db.close();
  });
}
