import 'package:sqflite/sqflite.dart';
import '../models/word.dart';

class WordRepository {
  final Database _db;
  const WordRepository(this._db);

  Future<void> insertAll(List<Word> words) async {
    final batch = _db.batch();
    for (final word in words) {
      batch.insert('words', word.toDbMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  /// id 충돌 시 텍스트·분류 필드만 갱신. created_at·진도 보존.
  Future<void> upsertAll(List<Word> words) async {
    final batch = _db.batch();
    for (final w in words) {
      final m = w.toDbMap();
      batch.rawInsert(
        '''
        INSERT INTO words (id, jlpt_level, expression, reading, meaning_ko, type, is_trap, source,
                           example_ja, example_reading, example_ko, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          expression = excluded.expression,
          reading = excluded.reading,
          meaning_ko = excluded.meaning_ko,
          type = excluded.type,
          is_trap = excluded.is_trap,
          example_ja = excluded.example_ja,
          example_reading = excluded.example_reading,
          example_ko = excluded.example_ko
        ''',
        [
          m['id'], m['jlpt_level'], m['expression'], m['reading'], m['meaning_ko'],
          m['type'], m['is_trap'], m['source'],
          m['example_ja'], m['example_reading'], m['example_ko'], m['created_at'],
        ],
      );
    }
    await batch.commit(noResult: true);
  }

  /// 에셋에서 사라진 n2 단어와 그 진도·로그 삭제. 사용자 단어는 건드리지 않음.
  Future<void> deleteN2NotIn(Set<String> keepIds) async {
    final rows = await _db.query('words', columns: ['id'], where: "source = 'n2'");
    final stale = rows.map((r) => r['id'] as String).where((id) => !keepIds.contains(id)).toList();
    if (stale.isEmpty) return;
    final batch = _db.batch();
    for (final id in stale) {
      batch.delete('miss_log', where: 'word_id = ?', whereArgs: [id]);
      batch.delete('review_session_items', where: 'word_id = ?', whereArgs: [id]);
      batch.delete('daily_study_set_items', where: 'word_id = ?', whereArgs: [id]);
      batch.delete('word_progress', where: 'word_id = ?', whereArgs: [id]);
      batch.delete('words', where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  Future<void> insertUserWord(Word word) async {
    await _db.insert('words', word.toDbMap(), conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<int> count() async {
    final result = await _db.rawQuery('SELECT COUNT(*) as c FROM words');
    return result.first['c'] as int;
  }

  Future<List<Word>> getAll() async {
    final rows = await _db.query('words', orderBy: 'id');
    return rows.map(Word.fromDbMap).toList();
  }

  Future<Word?> getById(String id) async {
    final rows = await _db.query('words', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Word.fromDbMap(rows.first);
  }

  Future<List<Word>> getByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await _db.rawQuery('SELECT * FROM words WHERE id IN ($placeholders)', ids);
    return rows.map(Word.fromDbMap).toList();
  }

  Future<List<Word>> search(String query) async {
    final q = '%$query%';
    final rows = await _db.rawQuery(
      'SELECT * FROM words WHERE expression LIKE ? OR reading LIKE ? OR meaning_ko LIKE ? ORDER BY id',
      [q, q, q],
    );
    return rows.map(Word.fromDbMap).toList();
  }

  Future<Word?> findByExpression(String expression) async {
    final rows = await _db.query('words', where: 'expression = ?', whereArgs: [expression], limit: 1);
    if (rows.isEmpty) return null;
    return Word.fromDbMap(rows.first);
  }

  Future<List<String>> getReadingsByExpression(String expression) async {
    final rows = await _db.query('words', columns: ['reading'], where: 'expression = ?', whereArgs: [expression]);
    return rows.map((r) => r['reading'] as String).toList();
  }

  Future<List<String>> getRandomReadingsStartingWith(
    String firstChar, {
    required int limit,
    required Set<String> exclude,
  }) async {
    final rows = await _db.rawQuery(
      'SELECT DISTINCT reading FROM words WHERE reading LIKE ? ORDER BY RANDOM() LIMIT ?',
      ['$firstChar%', limit + exclude.length],
    );
    return rows
        .map((r) => r['reading'] as String)
        .where((r) => !exclude.contains(r))
        .take(limit)
        .toList();
  }

  Future<List<String>> getRandomMeanings({
    required int limit,
    required String excludeWordId,
  }) async {
    final rows = await _db.rawQuery(
      'SELECT DISTINCT meaning_ko FROM words WHERE id != ? ORDER BY RANDOM() LIMIT ?',
      [excludeWordId, limit],
    );
    return rows.map((r) => r['meaning_ko'] as String).toList();
  }
}
