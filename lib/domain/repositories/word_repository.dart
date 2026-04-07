import 'package:sqflite/sqflite.dart';
import '../models/word.dart';
import '../models/enums.dart';

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

  Future<int> count() async {
    final result = await _db.rawQuery('SELECT COUNT(*) as c FROM words');
    return result.first['c'] as int;
  }

  Future<int> countByLevel(JlptLevel level) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as c FROM words WHERE jlpt_level = ?',
      [level == JlptLevel.n3 ? 'N3' : 'N2'],
    );
    return result.first['c'] as int;
  }

  Future<List<Word>> getAll() async {
    final rows = await _db.query('words', orderBy: 'id');
    return rows.map(Word.fromDbMap).toList();
  }

  Future<List<Word>> getByLevel(JlptLevel level) async {
    final rows = await _db.query(
      'words',
      where: 'jlpt_level = ?',
      whereArgs: [level == JlptLevel.n3 ? 'N3' : 'N2'],
    );
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

  Future<List<Word>> getSimilarReading(
    String reading,
    JlptLevel level,
    int limit,
    List<String> excludeIds,
  ) async {
    final firstChar = reading.isNotEmpty ? reading[0] : '';
    final levelStr = level == JlptLevel.n3 ? 'N3' : 'N2';
    final excludePlaceholders = excludeIds.isEmpty
        ? ''
        : 'AND id NOT IN (${List.filled(excludeIds.length, '?').join(',')})';
    final rows = await _db.rawQuery(
      'SELECT * FROM words WHERE jlpt_level = ? AND reading LIKE ? $excludePlaceholders ORDER BY RANDOM() LIMIT ?',
      [levelStr, '$firstChar%', ...excludeIds, limit],
    );
    return rows.map(Word.fromDbMap).toList();
  }

  Future<List<Word>> getRandomByLevel(
    JlptLevel level,
    int limit,
    List<String> excludeIds,
  ) async {
    final levelStr = level == JlptLevel.n3 ? 'N3' : 'N2';
    final excludePlaceholders = excludeIds.isEmpty
        ? ''
        : 'AND id NOT IN (${List.filled(excludeIds.length, '?').join(',')})';
    final rows = await _db.rawQuery(
      'SELECT * FROM words WHERE jlpt_level = ? $excludePlaceholders ORDER BY RANDOM() LIMIT ?',
      [levelStr, ...excludeIds, limit],
    );
    return rows.map(Word.fromDbMap).toList();
  }
}
