import 'package:sqflite/sqflite.dart';
import '../models/word_progress.dart';
import '../models/enums.dart';

class ProgressRepository {
  final Database _db;
  const ProgressRepository(this._db);

  Future<WordProgress?> get(String wordId) async {
    final rows = await _db.query('word_progress', where: 'word_id = ?', whereArgs: [wordId]);
    if (rows.isEmpty) return null;
    return WordProgress.fromDbMap(rows.first);
  }

  Future<void> upsert(WordProgress progress) async {
    await _db.insert(
      'word_progress',
      progress.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> countCompleted(JlptLevel level) async {
    final levelStr = level == JlptLevel.n3 ? 'N3' : 'N2';
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as c FROM word_progress wp JOIN words w ON wp.word_id = w.id WHERE wp.is_completed = 1 AND w.jlpt_level = ?',
      [levelStr],
    );
    return result.first['c'] as int;
  }

  Future<List<String>> getCompletedWordIds(JlptLevel level) async {
    final levelStr = level == JlptLevel.n3 ? 'N3' : 'N2';
    final rows = await _db.rawQuery(
      'SELECT wp.word_id FROM word_progress wp JOIN words w ON wp.word_id = w.id WHERE wp.is_completed = 1 AND w.jlpt_level = ? ORDER BY wp.completed_at DESC',
      [levelStr],
    );
    return rows.map((r) => r['word_id'] as String).toList();
  }

  Future<List<String>> getUncompletedWordIds(JlptLevel level) async {
    final levelStr = level == JlptLevel.n3 ? 'N3' : 'N2';
    final rows = await _db.rawQuery(
      'SELECT w.id FROM words w LEFT JOIN word_progress wp ON w.id = wp.word_id WHERE w.jlpt_level = ? AND (wp.is_completed IS NULL OR wp.is_completed = 0) ORDER BY w.id',
      [levelStr],
    );
    return rows.map((r) => r['id'] as String).toList();
  }

  Future<void> markCompleted(String wordId) async {
    final now = DateTime.now().toIso8601String();
    await _db.insert(
      'word_progress',
      {
        'word_id': wordId,
        'is_completed': 1,
        'completed_at': now,
        'review_count': 0,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
