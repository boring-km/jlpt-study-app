import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jlpt/core/db/database.dart';
import 'package:jlpt/domain/models/word.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:jlpt/domain/repositories/word_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late WordRepository repo;

  setUp(() async {
    final db = await AppDatabase.openForTest();
    repo = WordRepository(db);
    await repo.insertAll([
      const Word(id: 'n3_0001', jlptLevel: JlptLevel.n3, expression: '作法', reading: 'さほう', meaningKo: '예절'),
      const Word(id: 'n3_0002', jlptLevel: JlptLevel.n3, expression: '様々', reading: 'さまざま', meaningKo: '다양한'),
      const Word(id: 'n2_0001', jlptLevel: JlptLevel.n2, expression: '題名', reading: 'だいめい', meaningKo: '제목'),
    ]);
  });

  test('count returns total word count', () async {
    expect(await repo.count(), 3);
  });

  test('countByLevel returns correct count for N3', () async {
    expect(await repo.countByLevel(JlptLevel.n3), 2);
  });

  test('countByLevel returns correct count for N2', () async {
    expect(await repo.countByLevel(JlptLevel.n2), 1);
  });

  test('getAll returns all words ordered by id', () async {
    final words = await repo.getAll();
    expect(words.length, 3);
    expect(words.first.id, 'n2_0001');
  });

  test('getByLevel returns only N3 words', () async {
    final words = await repo.getByLevel(JlptLevel.n3);
    expect(words.length, 2);
    expect(words.every((w) => w.jlptLevel == JlptLevel.n3), isTrue);
  });

  test('getById returns correct word', () async {
    final word = await repo.getById('n3_0001');
    expect(word?.expression, '作法');
  });

  test('getById returns null for missing id', () async {
    expect(await repo.getById('missing'), isNull);
  });

  test('getByIds returns matching words', () async {
    final words = await repo.getByIds(['n3_0001', 'n2_0001']);
    expect(words.length, 2);
  });

  test('search finds by expression', () async {
    final results = await repo.search('作法');
    expect(results.length, 1);
    expect(results.first.id, 'n3_0001');
  });

  test('search finds by meaning_ko', () async {
    final results = await repo.search('예절');
    expect(results.length, 1);
  });

  test('getSimilarReading returns words with same first char', () async {
    final results = await repo.getSimilarReading('さほう', JlptLevel.n3, 3, ['n3_0001']);
    expect(results.every((w) => w.reading.startsWith('さ')), isTrue);
  });

  test('insertAll with duplicate ignores conflict', () async {
    await repo.insertAll([
      const Word(id: 'n3_0001', jlptLevel: JlptLevel.n3, expression: '作法', reading: 'さほう', meaningKo: '예절'),
    ]);
    expect(await repo.count(), 3);
  });
}
