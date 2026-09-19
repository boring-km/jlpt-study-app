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

  // n2_0001 / n2_0002 는 뜻이 같다 (동형이음어) — 오답 보기 생성 테스트에 필요.
  const words = [
    Word(id: 'n2_0001', expression: '紅葉', reading: 'こうよう', meaningKo: '단풍', type: WordType.on),
    Word(id: 'n2_0002', expression: '紅葉', reading: 'もみじ', meaningKo: '단풍', type: WordType.kun),
    Word(id: 'n2_0003', expression: '工夫', reading: 'くふう', meaningKo: '궁리', type: WordType.on, isTrap: true),
    Word(id: 'n2_0004', expression: 'こうこく', reading: 'こうこく', meaningKo: '광고'),
  ];

  Future<WordRepository> seeded(Database db) async {
    final repo = WordRepository(db);
    await repo.insertAll(words);
    return repo;
  }

  test('count returns total word count', () async {
    final db = await AppDatabase.openForTest();
    expect(await (await seeded(db)).count(), 4);
    await db.close();
  });

  test('insertAll ignores duplicate ids', () async {
    final db = await AppDatabase.openForTest();
    final repo = await seeded(db);
    await repo.insertAll([words.first]);
    expect(await repo.count(), 4);
    await db.close();
  });

  test('getAll returns every word ordered by id', () async {
    final db = await AppDatabase.openForTest();
    final all = await (await seeded(db)).getAll();
    expect(all.map((w) => w.id), ['n2_0001', 'n2_0002', 'n2_0003', 'n2_0004']);
    await db.close();
  });

  test('getById returns the word, or null when missing', () async {
    final db = await AppDatabase.openForTest();
    final repo = await seeded(db);
    final word = await repo.getById('n2_0003');
    expect(word!.expression, '工夫');
    expect(word.type, WordType.on);
    expect(word.isTrap, isTrue);
    expect(await repo.getById('missing'), isNull);
    await db.close();
  });

  test('getByIds returns matching words and tolerates an empty list', () async {
    final db = await AppDatabase.openForTest();
    final repo = await seeded(db);
    final found = await repo.getByIds(['n2_0001', 'n2_0004']);
    expect(found.map((w) => w.id).toSet(), {'n2_0001', 'n2_0004'});
    expect(await repo.getByIds([]), isEmpty);
    await db.close();
  });

  test('search finds by expression and by meaning', () async {
    final db = await AppDatabase.openForTest();
    final repo = await seeded(db);
    expect((await repo.search('工夫')).map((w) => w.id), ['n2_0003']);
    expect((await repo.search('단풍')).map((w) => w.id), ['n2_0001', 'n2_0002']);
    await db.close();
  });

  test('upsertAll updates text fields and keeps progress', () async {
    final db = await AppDatabase.openForTest();
    final repo = await seeded(db);
    await ProgressRepository(db).markCompleted('n2_0003');
    await repo.upsertAll([words[2].copyWith(meaningKo: '궁리, 고안')]);
    expect((await repo.getById('n2_0003'))!.meaningKo, '궁리, 고안');
    expect((await ProgressRepository(db).get('n2_0003'))!.isCompleted, isTrue);
    expect(await repo.count(), 4);
    await db.close();
  });

  test('insertUserWord forces source to user', () async {
    final db = await AppDatabase.openForTest();
    final repo = WordRepository(db);
    // 기본값 source='n2' 로 넘어와도 사용자 단어로 저장돼야 한다.
    await repo.insertUserWord(const Word(id: 'user_1', expression: '把握', reading: 'はあく', meaningKo: '파악'));
    expect((await repo.getById('user_1'))!.source, 'user');
    // n2 정리에서 살아남는지까지 확인
    await repo.deleteN2NotIn({});
    expect(await repo.getById('user_1'), isNotNull);
    await db.close();
  });

  test('deleteN2NotIn removes stale n2 words and their progress, keeps user words', () async {
    final db = await AppDatabase.openForTest();
    final repo = await seeded(db);
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
    final repo = await seeded(db);
    expect((await repo.findByExpression('工夫'))!.id, 'n2_0003');
    expect(await repo.findByExpression('없음'), isNull);
    expect(await repo.getReadingsByExpression('紅葉'), containsAll(['こうよう', 'もみじ']));
    await db.close();
  });

  test('getRandomReadingsStartingWith excludes given readings', () async {
    final db = await AppDatabase.openForTest();
    final repo = await seeded(db);
    final r = await repo.getRandomReadingsStartingWith('こ', limit: 5, exclude: {'こうよう'});
    expect(r, ['こうこく']);
    await db.close();
  });

  test('getRandomMeanings excludes the answer meaning, not just the word id', () async {
    final db = await AppDatabase.openForTest();
    final repo = await seeded(db);
    // n2_0001 과 n2_0002 는 뜻이 '단풍'으로 같다 — id 로만 제외하면 정답이 보기로 샌다.
    expect(await repo.getRandomMeanings(limit: 10, excludeWordId: 'n2_0001'), isNot(contains('단풍')));
    expect(await repo.getRandomMeanings(limit: 10, excludeWordId: 'n2_0002'), isNot(contains('단풍')));

    final m = await repo.getRandomMeanings(limit: 10, excludeWordId: 'n2_0003');
    expect(m, isNot(contains('궁리')));
    expect(m.toSet().length, m.length);
    await db.close();
  });
}
