class WordProgress {
  final String wordId;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime? lastReviewedAt;
  final int reviewCount;
  final int missCount;
  final DateTime updatedAt;

  const WordProgress({
    required this.wordId,
    required this.isCompleted,
    this.completedAt,
    this.lastReviewedAt,
    required this.reviewCount,
    required this.missCount,
    required this.updatedAt,
  });

  factory WordProgress.fromDbMap(Map<String, dynamic> map) {
    final completedAtStr = map['completed_at'] as String?;
    final lastReviewedAtStr = map['last_reviewed_at'] as String?;

    return WordProgress(
      wordId: map['word_id'] as String,
      isCompleted: (map['is_completed'] as int) == 1,
      completedAt: completedAtStr != null ? DateTime.parse(completedAtStr) : null,
      lastReviewedAt: lastReviewedAtStr != null ? DateTime.parse(lastReviewedAtStr) : null,
      reviewCount: map['review_count'] as int,
      missCount: (map['miss_count'] as int?) ?? 0,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toDbMap() => {
        'word_id': wordId,
        'is_completed': isCompleted ? 1 : 0,
        'completed_at': completedAt?.toIso8601String(),
        'last_reviewed_at': lastReviewedAt?.toIso8601String(),
        'review_count': reviewCount,
        'miss_count': missCount,
        'updated_at': updatedAt.toIso8601String(),
      };

  WordProgress copyWith({
    String? wordId,
    bool? isCompleted,
    DateTime? completedAt,
    DateTime? lastReviewedAt,
    int? reviewCount,
    int? missCount,
    DateTime? updatedAt,
  }) {
    return WordProgress(
      wordId: wordId ?? this.wordId,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      reviewCount: reviewCount ?? this.reviewCount,
      missCount: missCount ?? this.missCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
