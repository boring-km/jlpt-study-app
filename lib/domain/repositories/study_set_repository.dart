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
        'status': studyStageToDb(status),
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

  /// 오늘 세트에 단어를 추가하고 다시 풀이 상태로 되돌린다.
  ///
  /// [date]의 부모 세트가 없으면 항목만 남는 고아 row가 되므로 아무것도 쓰지
  /// 않고 [StateError]를 던진다 (null 단언의 불투명한 크래시 대신).
  Future<void> appendItems(String date, List<TodayStudyItem> items) async {
    final parent = await getByDate(date);
    if (parent == null) {
      throw StateError('append 대상 세트가 없습니다: study_date=$date');
    }
    final existingCount = parent.items.length;
    final batch = _db.batch();
    for (final item in items) {
      batch.insert('daily_study_set_items', item.toDbMap());
    }
    await batch.commit(noResult: true);
    await _db.update(
      'daily_study_sets',
      {
        'status': studyStageToDb(StudyStage.quiz),
        'completed_at': null,
        'target_count': existingCount + items.length,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'study_date = ?',
      whereArgs: [date],
    );
  }

  Future<void> deleteAll() async {
    await _db.delete('daily_study_set_items');
    await _db.delete('daily_study_sets');
  }
}
