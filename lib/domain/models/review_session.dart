import 'package:jlpt/domain/models/enums.dart';

class ReviewSessionItem {
  final String sessionId;
  final String wordId;
  final int displayOrder;
  final bool passed;
  final int attempts;

  const ReviewSessionItem({
    required this.sessionId,
    required this.wordId,
    required this.displayOrder,
    required this.passed,
    required this.attempts,
  });

  factory ReviewSessionItem.fromDbMap(Map<String, dynamic> map) => ReviewSessionItem(
        sessionId: map['session_id'] as String,
        wordId: map['word_id'] as String,
        displayOrder: map['display_order'] as int,
        passed: (map['reading_passed'] as int) == 1,
        attempts: map['reading_attempts'] as int,
      );

  Map<String, dynamic> toDbMap() => {
        'session_id': sessionId,
        'word_id': wordId,
        'display_order': displayOrder,
        'reading_passed': passed ? 1 : 0,
        'meaning_passed': passed ? 1 : 0,
        'reading_attempts': attempts,
        'meaning_attempts': 0,
      };

  ReviewSessionItem copyWith({bool? passed, int? attempts}) => ReviewSessionItem(
        sessionId: sessionId,
        wordId: wordId,
        displayOrder: displayOrder,
        passed: passed ?? this.passed,
        attempts: attempts ?? this.attempts,
      );
}

class ReviewSession {
  final String id;
  final String reviewDate;
  final int itemCount;
  final StudyStage status;
  final List<ReviewSessionItem> items;
  final DateTime startedAt;
  final DateTime? completedAt;

  const ReviewSession({
    required this.id,
    required this.reviewDate,
    required this.itemCount,
    required this.status,
    required this.items,
    required this.startedAt,
    this.completedAt,
  });

  factory ReviewSession.fromDbMap(
    Map<String, dynamic> map,
    List<ReviewSessionItem> items,
  ) {
    final completedAtStr = map['completed_at'] as String?;
    return ReviewSession(
      id: map['id'] as String,
      reviewDate: map['review_date'] as String,
      itemCount: map['item_count'] as int,
      status: studyStageFromDb(map['status'] as String),
      items: items,
      startedAt: DateTime.parse(map['started_at'] as String),
      completedAt: completedAtStr != null ? DateTime.parse(completedAtStr) : null,
    );
  }

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'review_date': reviewDate,
        'item_count': itemCount,
        'status': studyStageToDb(status),
        'started_at': startedAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
      };

  ReviewSession copyWith({
    StudyStage? status,
    List<ReviewSessionItem>? items,
    DateTime? completedAt,
  }) =>
      ReviewSession(
        id: id,
        reviewDate: reviewDate,
        itemCount: itemCount,
        status: status ?? this.status,
        items: items ?? this.items,
        startedAt: startedAt,
        completedAt: completedAt ?? this.completedAt,
      );
}
