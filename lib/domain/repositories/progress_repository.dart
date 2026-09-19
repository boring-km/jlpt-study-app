import 'package:sqflite/sqflite.dart';
import '../models/enums.dart';
import '../models/word_progress.dart';

class ProgressRepository {
  final Database _db;
  const ProgressRepository(this._db);

  Future<WordProgress?> get(String wordId) async {
    final rows = await _db.query('word_progress', where: 'word_id = ?', whereArgs: [wordId]);
    if (rows.isEmpty) return null;
    return WordProgress.fromDbMap(rows.first);
  }

  Future<void> upsert(WordProgress progress) async {
    await _db.insert('word_progress', progress.toDbMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> countCompleted() async {
    final result = await _db.rawQuery('SELECT COUNT(*) as c FROM word_progress WHERE is_completed = 1');
    return result.first['c'] as int;
  }

  Future<List<String>> getCompletedWordIds() async {
    final rows = await _db.rawQuery(
      'SELECT word_id FROM word_progress WHERE is_completed = 1 ORDER BY completed_at DESC',
    );
    return rows.map((r) => r['word_id'] as String).toList();
  }

  Future<List<String>> getUncompletedWordIds({WordType? type, String? source}) async {
    final where = <String>['(wp.is_completed IS NULL OR wp.is_completed = 0)'];
    final args = <Object>[];
    if (type != null) {
      where.add('w.type = ?');
      args.add(wordTypeToDb(type));
    }
    if (source != null) {
      where.add('w.source = ?');
      args.add(source);
    }
    final rows = await _db.rawQuery(
      'SELECT w.id FROM words w LEFT JOIN word_progress wp ON w.id = wp.word_id WHERE ${where.join(' AND ')} ORDER BY w.id',
      args,
    );
    return rows.map((r) => r['id'] as String).toList();
  }

  /// 단어가 이미 진행 row로 존재하면 is_completed만 true로 갱신하고 miss_count는 보존.
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
      'UPDATE word_progress SET miss_count = MAX(0, miss_count - 1), updated_at = ? WHERE word_id = ?',
      [now, wordId],
    );
  }

  /// 약점 단어 ID. is_completed=1 + miss_count>0, miss_count DESC → updated_at DESC.
  Future<List<String>> getWeakWordIds({int? limit}) async {
    final limitClause = limit != null ? 'LIMIT $limit' : '';
    final rows = await _db.rawQuery(
      '''
      SELECT word_id FROM word_progress
      WHERE is_completed = 1 AND miss_count > 0
      ORDER BY miss_count DESC, updated_at DESC
      $limitClause
      ''',
    );
    return rows.map((r) => r['word_id'] as String).toList();
  }

  Future<int> countWeak() async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as c FROM word_progress WHERE is_completed = 1 AND miss_count > 0',
    );
    return result.first['c'] as int;
  }

  /// 진도·세트·세션·오답 로그 전부 삭제. 단어는 유지.
  Future<void> resetAllProgress() async {
    final batch = _db.batch();
    batch.delete('miss_log');
    batch.delete('review_session_items');
    batch.delete('review_sessions');
    batch.delete('daily_study_set_items');
    batch.delete('daily_study_sets');
    batch.delete('word_progress');
    await batch.commit(noResult: true);
  }
}
