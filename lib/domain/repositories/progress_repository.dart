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

  /// 단어가 이미 진행 row로 존재하면 is_completed만 true로 갱신하고 miss_count는 보존.
  /// 새 row일 경우 miss_count=0으로 시작.
  Future<void> markCompleted(String wordId) async {
    final now = DateTime.now().toIso8601String();
    await _db.rawInsert(
      '''
      INSERT INTO word_progress (word_id, is_completed, completed_at, review_count, miss_count, updated_at)
      VALUES (?, 1, ?, 0, 0, ?)
      ON CONFLICT(word_id) DO UPDATE SET
        is_completed = 1,
        completed_at = COALESCE(word_progress.completed_at, excluded.completed_at),
        updated_at = excluded.updated_at
      ''',
      [wordId, now, now],
    );
  }

  /// 오답 시 miss_count += 1. 해당 row가 없으면 생성.
  Future<void> incrementMiss(String wordId) async {
    final now = DateTime.now().toIso8601String();
    await _db.rawInsert(
      '''
      INSERT INTO word_progress (word_id, is_completed, review_count, miss_count, updated_at)
      VALUES (?, 0, 0, 1, ?)
      ON CONFLICT(word_id) DO UPDATE SET
        miss_count = word_progress.miss_count + 1,
        updated_at = excluded.updated_at
      ''',
      [wordId, now],
    );
  }

  /// 정답 시 miss_count -= 1 (0 floor). row가 없으면 아무 것도 안 함.
  Future<void> decrementMiss(String wordId) async {
    final now = DateTime.now().toIso8601String();
    await _db.rawUpdate(
      '''
      UPDATE word_progress
      SET miss_count = MAX(0, miss_count - 1),
          updated_at = ?
      WHERE word_id = ?
      ''',
      [now, wordId],
    );
  }

  /// 약점 단어 ID 목록. is_completed=1 + miss_count>0 + 레벨 필터.
  /// miss_count DESC, 동점이면 updated_at DESC (최근 오답 우선).
  Future<List<String>> getWeakWordIds(JlptLevel level, {int? limit}) async {
    final levelStr = level == JlptLevel.n3 ? 'N3' : 'N2';
    final limitClause = limit != null ? 'LIMIT $limit' : '';
    final rows = await _db.rawQuery(
      '''
      SELECT wp.word_id
      FROM word_progress wp
      JOIN words w ON wp.word_id = w.id
      WHERE wp.is_completed = 1 AND wp.miss_count > 0 AND w.jlpt_level = ?
      ORDER BY wp.miss_count DESC, wp.updated_at DESC
      $limitClause
      ''',
      [levelStr],
    );
    return rows.map((r) => r['word_id'] as String).toList();
  }

  /// 약점 단어 수 (레벨별).
  Future<int> countWeak(JlptLevel level) async {
    final levelStr = level == JlptLevel.n3 ? 'N3' : 'N2';
    final result = await _db.rawQuery(
      '''
      SELECT COUNT(*) as c
      FROM word_progress wp
      JOIN words w ON wp.word_id = w.id
      WHERE wp.is_completed = 1 AND wp.miss_count > 0 AND w.jlpt_level = ?
      ''',
      [levelStr],
    );
    return result.first['c'] as int;
  }
}
