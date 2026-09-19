import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:jlpt/domain/models/review_session.dart';

void main() {
  final startedAt = DateTime(2026, 4, 7, 12, 0);

  test('ReviewSessionItem fromDbMap/toDbMap round-trip', () {
    final parsed = ReviewSessionItem.fromDbMap({
      'session_id': 's1',
      'word_id': 'n2_0001',
      'display_order': 0,
      'reading_passed': 1,
      'meaning_passed': 0,
      'reading_attempts': 2,
      'meaning_attempts': 0,
    });
    expect(parsed.passed, isTrue);
    expect(parsed.attempts, 2);

    final map = parsed.toDbMap();
    expect(map['reading_passed'], 1);
    expect(map['meaning_passed'], 1);
    expect(map['reading_attempts'], 2);
  });

  test('ReviewSessionItem copyWith updates passed/attempts', () {
    const item = ReviewSessionItem(
      sessionId: 's1',
      wordId: 'n2_0001',
      displayOrder: 0,
      passed: false,
      attempts: 0,
    );
    final updated = item.copyWith(passed: true, attempts: 1);
    expect(updated.wordId, 'n2_0001');
    expect(updated.passed, isTrue);
    expect(updated.attempts, 1);
  });

  test('fromDbMap maps legacy quiz_reading status to quiz', () {
    final session = ReviewSession.fromDbMap({
      'id': 's1',
      'review_date': '2026-04-07',
      'item_count': 0,
      'status': 'quiz_reading',
      'started_at': '2026-04-07T12:00:00.000',
      'completed_at': null,
    }, const []);
    expect(session.status, StudyStage.quiz);
  });

  test('toDbMap serializes status and timestamps', () {
    final map = ReviewSession(
      id: 's1',
      reviewDate: '2026-04-07',
      itemCount: 0,
      status: StudyStage.completed,
      items: const [],
      startedAt: startedAt,
      completedAt: startedAt,
    ).toDbMap();
    expect(map['status'], 'completed');
    expect(map['started_at'], startedAt.toIso8601String());
    expect(map['completed_at'], startedAt.toIso8601String());
  });
}
