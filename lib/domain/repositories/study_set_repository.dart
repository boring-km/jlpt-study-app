import 'package:sqflite/sqflite.dart';
import '../models/today_study_set.dart';
import '../models/enums.dart';

class StudySetRepository {
  final Database _db;
  const StudySetRepository(this._db);

  Future<TodayStudySet?> getByDate(String date) async {
    final rows = await _db.query('daily_study_sets', where: 'study_date = ?', whereArgs: [date]);
    if (rows.isEmpty) return null;
    final itemRows = await _db.query(
      'daily_study_set_items',
      where: 'study_date = ?',
      whereArgs: [date],
      orderBy: 'display_order ASC',
    );
    return TodayStudySet.fromDbMap(
      rows.first,
      itemRows.map(TodayStudyItem.fromDbMap).toList(),
    );
  }

  Future<void> createSet(TodayStudySet set) async {
    await _db.insert('daily_study_sets', set.toDbMap());
    final batch = _db.batch();
    for (final item in set.items) {
      batch.insert('daily_study_set_items', item.toDbMap());
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateSetStatus(
    String date,
    StudyStage status, {
    DateTime? completedAt,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _db.update(
      'daily_study_sets',
      {
        'status': _studyStageToSnake(status),
        'completed_at': completedAt?.toIso8601String(),
        'updated_at': now,
      },
      where: 'study_date = ?',
      whereArgs: [date],
    );
  }

  Future<void> updateItem(TodayStudyItem item) async {
    await _db.update(
      'daily_study_set_items',
      item.toDbMap(),
      where: 'study_date = ? AND word_id = ?',
      whereArgs: [item.studyDate, item.wordId],
    );
  }

  Future<void> deleteSet(String date) async {
    await _db.delete('daily_study_set_items', where: 'study_date = ?', whereArgs: [date]);
    await _db.delete('daily_study_sets', where: 'study_date = ?', whereArgs: [date]);
  }

  Future<List<String>> getCompletedDates() async {
    final rows = await _db.query(
      'daily_study_sets',
      where: 'completed_at IS NOT NULL',
      orderBy: 'study_date DESC',
    );
    return rows.map((r) => r['study_date'] as String).toList();
  }

  Future<int> currentStreak() async {
    final dates = await getCompletedDates();
    if (dates.isEmpty) return 0;
    int streak = 0;
    DateTime check = DateTime.now();
    for (final d in dates) {
      final date = DateTime.parse(d);
      final diff = DateTime(check.year, check.month, check.day)
          .difference(DateTime(date.year, date.month, date.day))
          .inDays;
      if (diff == 0 || diff == 1) {
        streak++;
        check = date;
      } else {
        break;
      }
    }
    return streak;
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
