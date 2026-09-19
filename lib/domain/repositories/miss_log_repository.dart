import 'package:sqflite/sqflite.dart';
import '../models/error_tag.dart';

class MissLogRepository {
  final Database _db;
  const MissLogRepository(this._db);

  Future<void> add(String wordId, ErrorTag tag) async {
    await _db.insert('miss_log', {
      'word_id': wordId,
      'tag': tag.dbValue,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// 태그별 최근 오답 단어. 단어당 한 번, 최근 순.
  Future<List<String>> recentWordIdsByTag(ErrorTag tag, {int limit = 20}) async {
    final rows = await _db.rawQuery(
      '''
      SELECT word_id, MAX(created_at) AS last_at FROM miss_log
      WHERE tag = ?
      GROUP BY word_id
      ORDER BY last_at DESC
      LIMIT ?
      ''',
      [tag.dbValue, limit],
    );
    return rows.map((r) => r['word_id'] as String).toList();
  }

  /// 태그별 오답 단어 수(distinct).
  Future<Map<ErrorTag, int>> countByTag() async {
    final rows = await _db.rawQuery(
      'SELECT tag, COUNT(DISTINCT word_id) AS c FROM miss_log GROUP BY tag',
    );
    return {
      for (final r in rows) errorTagFromDb(r['tag'] as String): r['c'] as int,
    };
  }

  Future<List<ErrorTag>> tagsForWord(String wordId) async {
    final rows = await _db.rawQuery(
      'SELECT DISTINCT tag FROM miss_log WHERE word_id = ?',
      [wordId],
    );
    return rows.map((r) => errorTagFromDb(r['tag'] as String)).toList();
  }

  Future<void> clear() => _db.delete('miss_log');
}
