import 'package:jlpt/domain/models/enums.dart';

class ReviewSessionItem {
  final String sessionId;
  final String wordId;
  final int displayOrder;
  final bool readingPassed;
  final bool meaningPassed;
  final int readingAttempts;
  final int meaningAttempts;

  const ReviewSessionItem({
    required this.sessionId,
    required this.wordId,
    required this.displayOrder,
    required this.readingPassed,
    required this.meaningPassed,
    required this.readingAttempts,
    required this.meaningAttempts,
  });

  factory ReviewSessionItem.fromDbMap(Map<String, dynamic> map) {
    return ReviewSessionItem(
      sessionId: map['session_id'] as String,
      wordId: map['word_id'] as String,
      displayOrder: map['display_order'] as int,
      readingPassed: (map['reading_passed'] as int) == 1,
      meaningPassed: (map['meaning_passed'] as int) == 1,
      readingAttempts: map['reading_attempts'] as int,
      meaningAttempts: map['meaning_attempts'] as int,
    );
  }

  Map<String, dynamic> toDbMap() => {
        'session_id': sessionId,
        'word_id': wordId,
        'display_order': displayOrder,
        'reading_passed': readingPassed ? 1 : 0,
        'meaning_passed': meaningPassed ? 1 : 0,
        'reading_attempts': readingAttempts,
        'meaning_attempts': meaningAttempts,
      };

  ReviewSessionItem copyWith({
    String? sessionId,
    String? wordId,
    int? displayOrder,
    bool? readingPassed,
    bool? meaningPassed,
    int? readingAttempts,
    int? meaningAttempts,
  }) {
    return ReviewSessionItem(
      sessionId: sessionId ?? this.sessionId,
      wordId: wordId ?? this.wordId,
      displayOrder: displayOrder ?? this.displayOrder,
      readingPassed: readingPassed ?? this.readingPassed,
      meaningPassed: meaningPassed ?? this.meaningPassed,
      readingAttempts: readingAttempts ?? this.readingAttempts,
      meaningAttempts: meaningAttempts ?? this.meaningAttempts,
    );
  }
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
    final statusStr = map['status'] as String;

    return ReviewSession(
      id: map['id'] as String,
      reviewDate: map['review_date'] as String,
      itemCount: map['item_count'] as int,
      status: _studyStageFromString(statusStr),
      items: items,
      startedAt: DateTime.parse(map['started_at'] as String),
      completedAt: completedAtStr != null ? DateTime.parse(completedAtStr) : null,
    );
  }

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'review_date': reviewDate,
        'item_count': itemCount,
        'status': _studyStageToString(status),
        'started_at': startedAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
      };

  ReviewSession copyWith({
    String? id,
    String? reviewDate,
    int? itemCount,
    StudyStage? status,
    List<ReviewSessionItem>? items,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return ReviewSession(
      id: id ?? this.id,
      reviewDate: reviewDate ?? this.reviewDate,
      itemCount: itemCount ?? this.itemCount,
      status: status ?? this.status,
      items: items ?? this.items,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

StudyStage _studyStageFromString(String value) {
  switch (value) {
    case 'flashcard':
      return StudyStage.flashcard;
    case 'quiz_reading':
      return StudyStage.quizReading;
    case 'quiz_meaning':
      return StudyStage.quizMeaning;
    case 'completed':
      return StudyStage.completed;
    default:
      return StudyStage.flashcard;
  }
}

String _studyStageToString(StudyStage stage) {
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
