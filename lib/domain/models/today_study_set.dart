import 'package:jlpt/domain/models/enums.dart';

class TodayStudyItem {
  final String studyDate;
  final String wordId;
  final int displayOrder;
  final bool readingPassed;
  final bool meaningPassed;
  final int readingAttempts;
  final int meaningAttempts;
  final QuizResult? lastResult;
  final DateTime updatedAt;

  const TodayStudyItem({
    required this.studyDate,
    required this.wordId,
    required this.displayOrder,
    required this.readingPassed,
    required this.meaningPassed,
    required this.readingAttempts,
    required this.meaningAttempts,
    this.lastResult,
    required this.updatedAt,
  });

  bool get isFullyCompleted => readingPassed && meaningPassed;

  factory TodayStudyItem.fromDbMap(Map<String, dynamic> map) {
    final lastResultStr = map['last_result'] as String?;

    return TodayStudyItem(
      studyDate: map['study_date'] as String,
      wordId: map['word_id'] as String,
      displayOrder: map['display_order'] as int,
      readingPassed: (map['reading_passed'] as int) == 1,
      meaningPassed: (map['meaning_passed'] as int) == 1,
      readingAttempts: map['reading_attempts'] as int,
      meaningAttempts: map['meaning_attempts'] as int,
      lastResult: lastResultStr != null ? _quizResultFromString(lastResultStr) : null,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toDbMap() => {
        'study_date': studyDate,
        'word_id': wordId,
        'display_order': displayOrder,
        'reading_passed': readingPassed ? 1 : 0,
        'meaning_passed': meaningPassed ? 1 : 0,
        'reading_attempts': readingAttempts,
        'meaning_attempts': meaningAttempts,
        'last_result': lastResult != null ? _quizResultToString(lastResult!) : null,
        'updated_at': updatedAt.toIso8601String(),
      };

  TodayStudyItem copyWith({
    String? studyDate,
    String? wordId,
    int? displayOrder,
    bool? readingPassed,
    bool? meaningPassed,
    int? readingAttempts,
    int? meaningAttempts,
    QuizResult? lastResult,
    DateTime? updatedAt,
  }) {
    return TodayStudyItem(
      studyDate: studyDate ?? this.studyDate,
      wordId: wordId ?? this.wordId,
      displayOrder: displayOrder ?? this.displayOrder,
      readingPassed: readingPassed ?? this.readingPassed,
      meaningPassed: meaningPassed ?? this.meaningPassed,
      readingAttempts: readingAttempts ?? this.readingAttempts,
      meaningAttempts: meaningAttempts ?? this.meaningAttempts,
      lastResult: lastResult ?? this.lastResult,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class TodayStudySet {
  final String studyDate;
  final JlptLevel jlptLevel;
  final int targetCount;
  final StudyStage status;
  final List<TodayStudyItem> items;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TodayStudySet({
    required this.studyDate,
    required this.jlptLevel,
    required this.targetCount,
    required this.status,
    required this.items,
    this.startedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  int get completedCount => items.where((item) => item.isFullyCompleted).length;

  factory TodayStudySet.fromDbMap(
    Map<String, dynamic> map,
    List<TodayStudyItem> items,
  ) {
    final statusStr = map['status'] as String;
    final startedAtStr = map['started_at'] as String?;
    final completedAtStr = map['completed_at'] as String?;

    return TodayStudySet(
      studyDate: map['study_date'] as String,
      jlptLevel: (map['jlpt_level'] as String) == 'N3' ? JlptLevel.n3 : JlptLevel.n2,
      targetCount: map['target_count'] as int,
      status: _studyStageFromString(statusStr),
      items: items,
      startedAt: startedAtStr != null ? DateTime.parse(startedAtStr) : null,
      completedAt: completedAtStr != null ? DateTime.parse(completedAtStr) : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toDbMap() => {
        'study_date': studyDate,
        'jlpt_level': jlptLevel == JlptLevel.n3 ? 'N3' : 'N2',
        'target_count': targetCount,
        'status': _studyStageToString(status),
        'started_at': startedAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  TodayStudySet copyWith({
    String? studyDate,
    JlptLevel? jlptLevel,
    int? targetCount,
    StudyStage? status,
    List<TodayStudyItem>? items,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TodayStudySet(
      studyDate: studyDate ?? this.studyDate,
      jlptLevel: jlptLevel ?? this.jlptLevel,
      targetCount: targetCount ?? this.targetCount,
      status: status ?? this.status,
      items: items ?? this.items,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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

QuizResult _quizResultFromString(String value) {
  switch (value) {
    case 'correct':
      return QuizResult.correct;
    case 'wrong':
      return QuizResult.wrong;
    case 'unknown':
      return QuizResult.unknown;
    case 'know':
      return QuizResult.know;
    case 'dont_know':
      return QuizResult.dontKnow;
    default:
      return QuizResult.unknown;
  }
}

String _quizResultToString(QuizResult result) {
  switch (result) {
    case QuizResult.correct:
      return 'correct';
    case QuizResult.wrong:
      return 'wrong';
    case QuizResult.unknown:
      return 'unknown';
    case QuizResult.know:
      return 'know';
    case QuizResult.dontKnow:
      return 'dont_know';
  }
}
