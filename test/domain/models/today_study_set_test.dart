import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:jlpt/domain/models/today_study_set.dart';

void main() {
  final now = DateTime(2026, 4, 7, 12, 0);

  TodayStudyItem item(String wordId, int order, {required bool passed, int attempts = 0}) =>
      TodayStudyItem(
        studyDate: '2026-04-07',
        wordId: wordId,
        displayOrder: order,
        passed: passed,
        attempts: attempts,
        updatedAt: now,
      );

  group('TodayStudyItem', () {
    test('fromDbMap reads reading_passed/reading_attempts', () {
      final parsed = TodayStudyItem.fromDbMap({
        'study_date': '2026-04-07',
        'word_id': 'n2_0001',
        'display_order': 0,
        'reading_passed': 1,
        'meaning_passed': 0,
        'reading_attempts': 2,
        'meaning_attempts': 0,
        'last_result': null,
        'updated_at': '2026-04-07T12:00:00.000',
      });
      expect(parsed.passed, isTrue);
      expect(parsed.attempts, 2);
    });

    test('toDbMap mirrors passed into both legacy columns', () {
      final map = item('n2_0001', 0, passed: true, attempts: 3).toDbMap();
      expect(map['reading_passed'], 1);
      expect(map['meaning_passed'], 1);
      expect(map['reading_attempts'], 3);
      expect(map['meaning_attempts'], 0);
    });

    test('copyWith overrides passed and attempts only', () {
      final updated = item('n2_0001', 0, passed: false).copyWith(passed: true, attempts: 1);
      expect(updated.wordId, 'n2_0001');
      expect(updated.displayOrder, 0);
      expect(updated.passed, isTrue);
      expect(updated.attempts, 1);
    });
  });

  group('TodayStudySet', () {
    test('completedCount counts passed items', () {
      final set = TodayStudySet(
        studyDate: '2026-04-07',
        targetCount: 3,
        status: StudyStage.quiz,
        items: [
          item('n2_0001', 0, passed: true, attempts: 1),
          item('n2_0002', 1, passed: false),
          item('n2_0003', 2, passed: true, attempts: 2),
        ],
        createdAt: now,
        updatedAt: now,
      );
      expect(set.completedCount, 2);
    });

    test('fromDbMap maps legacy quiz_reading status to quiz', () {
      final set = TodayStudySet.fromDbMap({
        'study_date': '2026-04-07',
        'jlpt_level': 'N2',
        'target_count': 1,
        'status': 'quiz_reading',
        'started_at': null,
        'completed_at': null,
        'created_at': '2026-04-07T12:00:00.000',
        'updated_at': '2026-04-07T12:00:00.000',
      }, const []);
      expect(set.status, StudyStage.quiz);
    });

    test('toDbMap always writes N2 level and snake-free status', () {
      final map = TodayStudySet(
        studyDate: '2026-04-07',
        targetCount: 1,
        status: StudyStage.completed,
        items: const [],
        createdAt: now,
        updatedAt: now,
      ).toDbMap();
      expect(map['jlpt_level'], 'N2');
      expect(map['status'], 'completed');
    });
  });
}
