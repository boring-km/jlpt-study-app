import 'package:jlpt/domain/models/enums.dart';

class TodayStudyItem {
  final String studyDate;
  final String wordId;
  final int displayOrder;
  final bool passed;
  final int attempts;
  final DateTime updatedAt;

  const TodayStudyItem({
    required this.studyDate,
    required this.wordId,
    required this.displayOrder,
    required this.passed,
    required this.attempts,
    required this.updatedAt,
  });

  factory TodayStudyItem.fromDbMap(Map<String, dynamic> map) => TodayStudyItem(
        studyDate: map['study_date'] as String,
        wordId: map['word_id'] as String,
        displayOrder: map['display_order'] as int,
        passed: (map['reading_passed'] as int) == 1,
        attempts: map['reading_attempts'] as int,
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toDbMap() => {
        'study_date': studyDate,
        'word_id': wordId,
        'display_order': displayOrder,
        'reading_passed': passed ? 1 : 0,
        'meaning_passed': passed ? 1 : 0,
        'reading_attempts': attempts,
        'meaning_attempts': 0,
        'last_result': null,
        'updated_at': updatedAt.toIso8601String(),
      };

  TodayStudyItem copyWith({bool? passed, int? attempts, DateTime? updatedAt}) =>
      TodayStudyItem(
        studyDate: studyDate,
        wordId: wordId,
        displayOrder: displayOrder,
        passed: passed ?? this.passed,
        attempts: attempts ?? this.attempts,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class TodayStudySet {
  final String studyDate;
  final int targetCount;
  final StudyStage status;
  final List<TodayStudyItem> items;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TodayStudySet({
    required this.studyDate,
    required this.targetCount,
    required this.status,
    required this.items,
    this.startedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  int get completedCount => items.where((i) => i.passed).length;

  factory TodayStudySet.fromDbMap(
    Map<String, dynamic> map,
    List<TodayStudyItem> items,
  ) {
    final startedAtStr = map['started_at'] as String?;
    final completedAtStr = map['completed_at'] as String?;
    return TodayStudySet(
      studyDate: map['study_date'] as String,
      targetCount: map['target_count'] as int,
      status: studyStageFromDb(map['status'] as String),
      items: items,
      startedAt: startedAtStr != null ? DateTime.parse(startedAtStr) : null,
      completedAt: completedAtStr != null ? DateTime.parse(completedAtStr) : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toDbMap() => {
        'study_date': studyDate,
        'jlpt_level': 'N2',
        'target_count': targetCount,
        'status': studyStageToDb(status),
        'started_at': startedAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  TodayStudySet copyWith({
    int? targetCount,
    StudyStage? status,
    List<TodayStudyItem>? items,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? updatedAt,
  }) =>
      TodayStudySet(
        studyDate: studyDate,
        targetCount: targetCount ?? this.targetCount,
        status: status ?? this.status,
        items: items ?? this.items,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt ?? this.completedAt,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
