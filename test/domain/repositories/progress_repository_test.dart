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
}
