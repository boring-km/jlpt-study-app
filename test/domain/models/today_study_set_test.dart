import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/domain/models/today_study_set.dart';
import 'package:jlpt/domain/models/enums.dart';

void main() {
  final now = DateTime(2026, 4, 7, 12, 0);

  group('TodayStudyItem', () {
    test('isFullyCompleted is true when both passed', () {
      final item = TodayStudyItem(
        studyDate: '2026-04-07',
        wordId: 'n3_0001',
        displayOrder: 0,
        readingPassed: true,
        meaningPassed: true,
        readingAttempts: 1,
        meaningAttempts: 1,
        updatedAt: now,
      );
      expect(item.isFullyCompleted, isTrue);
    });

    test('isFullyCompleted is false when only reading passed', () {
      final item = TodayStudyItem(
        studyDate: '2026-04-07',
        wordId: 'n3_0001',
        displayOrder: 0,
        readingPassed: true,
        meaningPassed: false,
        readingAttempts: 1,
        meaningAttempts: 0,
        updatedAt: now,
      );
      expect(item.isFullyCompleted, isFalse);
    });

    test('fromDbMap / toDbMap round-trip', () {
      final map = {
        'study_date': '2026-04-07',
        'word_id': 'n3_0001',
        'display_order': 0,
        'reading_passed': 1,
        'meaning_passed': 0,
        'reading_attempts': 2,
        'meaning_attempts': 0,
        'last_result': 'correct',
        'updated_at': '2026-04-07T12:00:00.000',
      };
      final item = TodayStudyItem.fromDbMap(map);
      expect(item.readingPassed, isTrue);
      expect(item.meaningPassed, isFalse);
      expect(item.lastResult, QuizResult.correct);
    });
  });

  group('TodayStudySet', () {
    test('completedCount counts fully completed items', () {
      final items = [
        TodayStudyItem(studyDate: '2026-04-07', wordId: 'n3_0001', displayOrder: 0, readingPassed: true, meaningPassed: true, readingAttempts: 1, meaningAttempts: 1, updatedAt: now),
        TodayStudyItem(studyDate: '2026-04-07', wordId: 'n3_0002', displayOrder: 1, readingPassed: true, meaningPassed: false, readingAttempts: 1, meaningAttempts: 0, updatedAt: now),
        TodayStudyItem(studyDate: '2026-04-07', wordId: 'n3_0003', displayOrder: 2, readingPassed: false, meaningPassed: false, readingAttempts: 0, meaningAttempts: 0, updatedAt: now),
      ];
      final set = TodayStudySet(
        studyDate: '2026-04-07',
        jlptLevel: JlptLevel.n3,
        targetCount: 3,
        status: StudyStage.quizReading,
        items: items,
        createdAt: now,
        updatedAt: now,
      );
      expect(set.completedCount, 1);
    });
  });
}
