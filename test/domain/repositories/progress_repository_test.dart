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

  late ProgressRepository repo;

  setUp(() async {
    final db = await AppDatabase.openForTest();
    await WordRepository(db).insertAll([
      const Word(id: 'n2_0001', expression: '作法', reading: 'さほう', meaningKo: '예절'),
      const Word(id: 'n2_0002', expression: '様々', reading: 'さまざま', meaningKo: '다양한'),
    ]);
    repo = ProgressRepository(db);
  });

  test('get returns null for unknown word', () async {
    expect(await repo.get('unknown'), isNull);
  });

  test('markCompleted and countCompleted', () async {
    await repo.markCompleted('n2_0001');
    expect(await repo.countCompleted(), 1);
  });

  test('getCompletedWordIds returns completed ids', () async {
    await repo.markCompleted('n2_0001');
    expect(await repo.getCompletedWordIds(), contains('n2_0001'));
  });

  test('getUncompletedWordIds excludes completed', () async {
    await repo.markCompleted('n2_0001');
    final ids = await repo.getUncompletedWordIds();
    expect(ids, isNot(contains('n2_0001')));
    expect(ids, contains('n2_0002'));
  });

  test('incrementMiss creates row when missing and bumps miss_count', () async {
    await repo.incrementMiss('n2_0001');
    final p1 = await repo.get('n2_0001');
    expect(p1, isNotNull);
    expect(p1!.missCount, 1);
    await repo.incrementMiss('n2_0001');
    await repo.incrementMiss('n2_0001');
    final p2 = await repo.get('n2_0001');
    expect(p2!.missCount, 3);
  });

  test('decrementMiss floors at 0 and is no-op when row missing', () async {
    // no row yet → no-op
    await repo.decrementMiss('n2_0001');
    expect(await repo.get('n2_0001'), isNull);

    await repo.incrementMiss('n2_0001');
    await repo.decrementMiss('n2_0001');
    expect((await repo.get('n2_0001'))!.missCount, 0);
    // already 0 → stays 0
    await repo.decrementMiss('n2_0001');
    expect((await repo.get('n2_0001'))!.missCount, 0);
  });

  test('markCompleted preserves existing miss_count', () async {
    await repo.incrementMiss('n2_0001');
    await repo.incrementMiss('n2_0001');
    await repo.markCompleted('n2_0001');
    final p = await repo.get('n2_0001');
    expect(p!.isCompleted, isTrue);
    expect(p.missCount, 2);
  });

  test('getWeakWordIds returns only completed words with miss > 0', () async {
    // 완료 + 약점
    await repo.markCompleted('n2_0001');
    await repo.incrementMiss('n2_0001');
    await repo.incrementMiss('n2_0001'); // miss=2
    // 완료인데 약점 아님
    await repo.markCompleted('n2_0002');
    expect(await repo.getWeakWordIds(), ['n2_0001']);
  });

  test('getWeakWordIds sorts by miss_count DESC', () async {
    await repo.markCompleted('n2_0001');
    await repo.markCompleted('n2_0002');
    await repo.incrementMiss('n2_0001'); // miss=1
    await repo.incrementMiss('n2_0002');
    await repo.incrementMiss('n2_0002');
    await repo.incrementMiss('n2_0002'); // miss=3
    expect(await repo.getWeakWordIds(), ['n2_0002', 'n2_0001']);
  });

  test('getWeakWordIds applies limit', () async {
    await repo.markCompleted('n2_0001');
    await repo.markCompleted('n2_0002');
    await repo.incrementMiss('n2_0001');
    await repo.incrementMiss('n2_0002');
    expect((await repo.getWeakWordIds(limit: 1)).length, 1);
  });

  test('getWeakWordIds excludes uncompleted words', () async {
    // 완료되지 않은 상태에서 오답만 기록
    await repo.incrementMiss('n2_0001');
    expect(await repo.getWeakWordIds(), isEmpty);
  });

  test('countWeak counts matching words', () async {
    await repo.markCompleted('n2_0001');
    await repo.markCompleted('n2_0002');
    await repo.incrementMiss('n2_0001');
    expect(await repo.countWeak(), 1);
    await repo.incrementMiss('n2_0002');
    expect(await repo.countWeak(), 2);
  });

  test('getUncompletedWordIds filters by type and source', () async {
    final db = await AppDatabase.openForTest();
    await WordRepository(db).insertAll(const [
      Word(id: 'n2_0001', expression: '補う', reading: 'おぎなう', meaningKo: 'x', type: WordType.kun),
      Word(id: 'n2_0002', expression: '生産', reading: 'せいさん', meaningKo: 'y', type: WordType.on),
      Word(id: 'user_1', expression: '把握', reading: 'はあく', meaningKo: 'z', source: 'user'),
    ]);
    final repo = ProgressRepository(db);
    await repo.markCompleted('n2_0002');
    expect(await repo.getUncompletedWordIds(), containsAll(['n2_0001', 'user_1']));
    expect(await repo.getUncompletedWordIds(type: WordType.kun), ['n2_0001']);
    expect(await repo.getUncompletedWordIds(source: 'user'), ['user_1']);
    await db.close();
  });

  test('resetAllProgress clears progress, sets, sessions, miss_log', () async {
    final db = await AppDatabase.openForTest();
    await WordRepository(db).insertAll(const [
      Word(id: 'n2_0001', expression: 'a', reading: 'あ', meaningKo: 'x'),
    ]);
    final repo = ProgressRepository(db);
    await repo.markCompleted('n2_0001');
    await db.insert('miss_log', {'word_id': 'n2_0001', 'tag': 'other', 'created_at': 't'});
    await repo.resetAllProgress();
    expect(await repo.countCompleted(), 0);
    expect(await db.query('miss_log'), isEmpty);
    expect(await WordRepository(db).count(), 1);
    await db.close();
  });
}
