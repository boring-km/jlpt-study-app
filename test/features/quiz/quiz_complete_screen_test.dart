import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jlpt/application/providers/database_provider.dart';
import 'package:jlpt/application/providers/review_session_provider.dart';
import 'package:jlpt/application/providers/today_study_set_provider.dart';
import 'package:jlpt/core/db/database.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:jlpt/domain/models/error_tag.dart';
import 'package:jlpt/domain/models/review_session.dart';
import 'package:jlpt/domain/models/today_study_set.dart';
import 'package:jlpt/domain/models/word.dart';
import 'package:jlpt/domain/repositories/miss_log_repository.dart';
import 'package:jlpt/domain/repositories/settings_repository.dart';
import 'package:jlpt/domain/repositories/word_repository.dart';
import 'package:jlpt/features/quiz/quiz_complete_screen.dart';
import 'package:jlpt/features/quiz/quiz_mode.dart';
import 'quiz_test_async.dart';

/// 학습 세트를 고정값으로 물려주고 finish()는 무해하게 만드는 테스트용 노티파이어.
class _FakeTodaySetNotifier extends TodayStudySetNotifier {
  _FakeTodaySetNotifier(this._set);
  final TodayStudySet _set;
  var finishCalls = 0;

  @override
  Future<TodayStudySet?> build() async => _set;

  @override
  Future<void> finish() async => finishCalls++;
}

class _FakeReviewNotifier extends ReviewSessionNotifier {
  _FakeReviewNotifier(this._session);
  final ReviewSession _session;
  var completeCalls = 0;

  @override
  Future<ReviewSession?> build() async => _session;

  @override
  Future<void> complete() async => completeCalls++;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final now = DateTime(2026, 9, 19);

  Future<Database> seedDb() async {
    final db = await AppDatabase.openForTest();
    await SettingsRepository(db).setDataVersion(AppDatabase.kDataVersion);
    await WordRepository(db).insertAll(const [
      Word(id: 'n2_0001', expression: '生産', reading: 'せいさん', meaningKo: '생산', type: WordType.on),
      Word(id: 'n2_0002', expression: '把握', reading: 'はあく', meaningKo: '파악', type: WordType.on),
      Word(id: 'n2_0003', expression: '果実', reading: 'かじつ', meaningKo: '과실', type: WordType.on),
    ]);
    return db;
  }

  /// 3개 중 n2_0002만 attempts=2 (= 한 번 틀림).
  TodayStudySet buildSet() => TodayStudySet(
        studyDate: '2026-09-19',
        targetCount: 3,
        status: StudyStage.quiz,
        items: [
          for (var i = 1; i <= 3; i++)
            TodayStudyItem(
              studyDate: '2026-09-19',
              wordId: 'n2_000$i',
              displayOrder: i - 1,
              passed: true,
              attempts: i == 2 ? 2 : 1,
              updatedAt: now,
            ),
        ],
        createdAt: now,
        updatedAt: now,
      );

  Widget app(ProviderContainer c, QuizMode mode) => UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(
          routerConfig: GoRouter(routes: [
            GoRoute(path: '/', builder: (context, state) => QuizCompleteScreen(mode: mode)),
          ]),
        ),
      );

  testWidgets('study mode shows totals, wrong words with tags and next-set button',
      (tester) async {
    late Database db;
    late ProviderContainer c;
    final notifier = _FakeTodaySetNotifier(buildSet());
    await tester.runAsync(() async {
      db = await seedDb();
      await MissLogRepository(db).add('n2_0002', ErrorTag.longVowel);
      c = ProviderContainer(overrides: [
        databaseProvider.overrideWith((ref) async => db),
        todayStudySetProvider.overrideWith(() => notifier),
      ]);
    });

    await tester.pumpWidget(app(c, QuizMode.study));
    await settleWithDb(tester);

    expect(find.text('오늘 학습 완료'), findsOneWidget);
    expect(find.text('정답 3 / 시도 4'), findsOneWidget);
    expect(find.text('틀린 단어 1개'), findsOneWidget);
    expect(find.text('把握  はあく'), findsOneWidget);
    expect(find.text('장음'), findsOneWidget);
    expect(find.text('다음 학습 시작'), findsOneWidget);
    expect(notifier.finishCalls, 1);

    await tester.runAsync(db.close);
  });

  testWidgets('review mode shows review title and no next-set button', (tester) async {
    final session = ReviewSession(
      id: 'review_1',
      reviewDate: '2026-09-19',
      itemCount: 2,
      status: StudyStage.quiz,
      items: const [
        ReviewSessionItem(
            sessionId: 'review_1', wordId: 'n2_0001', displayOrder: 0, passed: true, attempts: 1),
        ReviewSessionItem(
            sessionId: 'review_1', wordId: 'n2_0003', displayOrder: 1, passed: true, attempts: 1),
      ],
      startedAt: now,
    );
    final notifier = _FakeReviewNotifier(session);
    late Database db;
    late ProviderContainer c;
    await tester.runAsync(() async {
      db = await seedDb();
      c = ProviderContainer(overrides: [
        databaseProvider.overrideWith((ref) async => db),
        reviewSessionProvider.overrideWith(() => notifier),
      ]);
    });

    await tester.pumpWidget(app(c, QuizMode.review));
    await settleWithDb(tester);

    expect(find.text('복습 완료'), findsOneWidget);
    expect(find.text('정답 2 / 시도 2'), findsOneWidget);
    expect(find.text('한 번에 다 맞혔다'), findsOneWidget);
    expect(find.text('다음 학습 시작'), findsNothing);
    expect(find.text('홈으로'), findsOneWidget);
    expect(notifier.completeCalls, 1);

    await tester.runAsync(db.close);
  });
}
