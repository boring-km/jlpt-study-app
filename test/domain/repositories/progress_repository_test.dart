import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jlpt/core/db/database.dart';
import 'package:jlpt/domain/models/word.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:jlpt/domain/repositories/word_repository.dart';
import 'package:jlpt/domain/repositories/progress_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late ProgressRepository repo;

  setUp(() async {
    final db = await AppDatabase.openForTest();
    final wordRepo = WordRepository(db);
    await wordRepo.insertAll([
      const Word(id: 'n3_0001', jlptLevel: JlptLevel.n3, expression: '作法', reading: 'さほう', meaningKo: '예절'),
      const Word(id: 'n3_0002', jlptLevel: JlptLevel.n3, expression: '様々', reading: 'さまざま', meaningKo: '다양한'),
    ]);
    repo = ProgressRepository(db);
  });

  test('get returns null for unknown word', () async {
    expect(await repo.get('unknown'), isNull);
  });

  test('markCompleted and countCompleted', () async {
    await repo.markCompleted('n3_0001');
    expect(await repo.countCompleted(JlptLevel.n3), 1);
  });

  test('getCompletedWordIds returns completed ids', () async {
    await repo.markCompleted('n3_0001');
    final ids = await repo.getCompletedWordIds(JlptLevel.n3);
    expect(ids, contains('n3_0001'));
  });

  test('getUncompletedWordIds excludes completed', () async {
    await repo.markCompleted('n3_0001');
    final ids = await repo.getUncompletedWordIds(JlptLevel.n3);
    expect(ids, isNot(contains('n3_0001')));
    expect(ids, contains('n3_0002'));
  });

  test('incrementMiss creates row when missing and bumps miss_count', () async {
    await repo.incrementMiss('n3_0001');
    final p1 = await repo.get('n3_0001');
    expect(p1, isNotNull);
    expect(p1!.missCount, 1);
    await repo.incrementMiss('n3_0001');
    await repo.incrementMiss('n3_0001');
    final p2 = await repo.get('n3_0001');
    expect(p2!.missCount, 3);
  });

  test('decrementMiss floors at 0 and is no-op when row missing', () async {
    // no row yet → no-op
    await repo.decrementMiss('n3_0001');
    expect(await repo.get('n3_0001'), isNull);

    await repo.incrementMiss('n3_0001');
    await repo.decrementMiss('n3_0001');
    expect((await repo.get('n3_0001'))!.missCount, 0);
    // already 0 → stays 0
    await repo.decrementMiss('n3_0001');
    expect((await repo.get('n3_0001'))!.missCount, 0);
  });

  test('markCompleted preserves existing miss_count', () async {
    await repo.incrementMiss('n3_0001');
    await repo.incrementMiss('n3_0001');
    await repo.markCompleted('n3_0001');
    final p = await repo.get('n3_0001');
    expect(p!.isCompleted, isTrue);
    expect(p.missCount, 2);
  });

  test('getWeakWordIds returns only completed with miss > 0 at current level', () async {
    // 완료 + 약점 1
    await repo.markCompleted('n3_0001');
    await repo.incrementMiss('n3_0001');
    await repo.incrementMiss('n3_0001'); // miss=2
    // 완료인데 약점 아님
    await repo.markCompleted('n3_0002');
    final weak = await repo.getWeakWordIds(JlptLevel.n3);
    expect(weak, ['n3_0001']);
  });

  test('getWeakWordIds sorts by miss_count DESC', () async {
    await repo.markCompleted('n3_0001');
    await repo.markCompleted('n3_0002');
    await repo.incrementMiss('n3_0001'); // miss=1
    await repo.incrementMiss('n3_0002');
    await repo.incrementMiss('n3_0002');
    await repo.incrementMiss('n3_0002'); // miss=3
    final weak = await repo.getWeakWordIds(JlptLevel.n3);
    expect(weak, ['n3_0002', 'n3_0001']);
  });

  test('getWeakWordIds applies limit', () async {
    await repo.markCompleted('n3_0001');
    await repo.markCompleted('n3_0002');
    await repo.incrementMiss('n3_0001');
    await repo.incrementMiss('n3_0002');
    final weak = await repo.getWeakWordIds(JlptLevel.n3, limit: 1);
    expect(weak.length, 1);
  });

  test('getWeakWordIds excludes uncompleted words', () async {
    // 완료되지 않은 상태에서 오답만 기록
    await repo.incrementMiss('n3_0001');
    final weak = await repo.getWeakWordIds(JlptLevel.n3);
    expect(weak, isEmpty);
  });

  test('countWeak counts matching words', () async {
    await repo.markCompleted('n3_0001');
    await repo.markCompleted('n3_0002');
    await repo.incrementMiss('n3_0001');
    expect(await repo.countWeak(JlptLevel.n3), 1);
    await repo.incrementMiss('n3_0002');
    expect(await repo.countWeak(JlptLevel.n3), 2);
  });
}
