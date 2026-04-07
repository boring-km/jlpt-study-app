import 'package:sqflite/sqflite.dart';
import '../models/review_session.dart';
import '../models/enums.dart';

class ReviewRepository {
  final Database _db;
  const ReviewRepository(this._db);

  Future<ReviewSession?> getById(String id) async {
    final rows = await _db.query('review_sessions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final itemRows = await _db.query(
      'review_session_items',
      where: 'session_id = ?',
      whereArgs: [id],
      orderBy: 'display_order ASC',
    );
    return ReviewSession.fromDbMap(
      rows.first,
      itemRows.map(ReviewSessionItem.fromDbMap).toList(),
    );
  }

  Future<void> createSession(ReviewSession session) async {
    await _db.insert('review_sessions', session.toDbMap());
    final batch = _db.batch();
    for (final item in session.items) {
      batch.insert('review_session_items', item.toDbMap());
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateSessionStatus(
    String id,
    StudyStage status, {
    DateTime? completedAt,
  }) async {
    await _db.update(
      'review_sessions',
      {
        'status': _studyStageToSnake(status),
        'completed_at': completedAt?.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateItem(ReviewSessionItem item) async {
    await _db.update(
      'review_session_items',
      item.toDbMap(),
      where: 'session_id = ? AND word_id = ?',
      whereArgs: [item.sessionId, item.wordId],
    );
  }
}

String _studyStageToSnake(StudyStage stage) {
  switch (stage) {
    case StudyStage.flashcard:
      return 'flashcard';
    case StudyStage.quizReading:
      return 'quiz_reading';
    case StudyStage.quizMeaning:
      return 'quiz_meaning';
    case StudyStage.completed:
      return 'completed';
  }
}
