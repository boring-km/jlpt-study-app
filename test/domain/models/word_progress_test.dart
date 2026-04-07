import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/domain/models/word_progress.dart';

void main() {
  group('WordProgress', () {
    final now = DateTime(2026, 4, 7, 12, 0);

    test('fromDbMap parses isCompleted=1 as true', () {
      final map = {
        'word_id': 'n3_0001',
        'is_completed': 1,
        'completed_at': '2026-04-07T12:00:00.000',
        'last_reviewed_at': null,
        'review_count': 2,
        'updated_at': '2026-04-07T12:00:00.000',
      };
      final p = WordProgress.fromDbMap(map);
      expect(p.isCompleted, isTrue);
      expect(p.reviewCount, 2);
    });

    test('fromDbMap parses isCompleted=0 as false', () {
      final map = {
        'word_id': 'n3_0001',
        'is_completed': 0,
        'completed_at': null,
        'last_reviewed_at': null,
        'review_count': 0,
        'updated_at': '2026-04-07T12:00:00.000',
      };
      final p = WordProgress.fromDbMap(map);
      expect(p.isCompleted, isFalse);
    });

    test('copyWith preserves unchanged fields', () {
      final p = WordProgress(
        wordId: 'n3_0001',
        isCompleted: false,
        reviewCount: 0,
        updatedAt: now,
      );
      final updated = p.copyWith(isCompleted: true, updatedAt: now);
      expect(updated.wordId, 'n3_0001');
      expect(updated.isCompleted, isTrue);
      expect(updated.reviewCount, 0);
    });

    test('toDbMap serializes isCompleted as int', () {
      final p = WordProgress(
        wordId: 'n3_0001',
        isCompleted: true,
        reviewCount: 1,
        updatedAt: now,
      );
      final map = p.toDbMap();
      expect(map['is_completed'], 1);
      expect(map['word_id'], 'n3_0001');
    });
  });
}
