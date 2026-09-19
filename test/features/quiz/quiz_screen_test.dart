import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jlpt/application/providers/database_provider.dart';
import 'package:jlpt/application/providers/progress_summary_provider.dart';
import 'package:jlpt/application/providers/today_study_set_provider.dart';
import 'package:jlpt/core/db/database.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:jlpt/domain/models/word.dart';
import 'package:jlpt/domain/repositories/settings_repository.dart';
import 'package:jlpt/domain/repositories/word_repository.dart';
import 'package:jlpt/features/quiz/quiz_mode.dart';
import 'package:jlpt/features/quiz/quiz_screen.dart';
import 'quiz_test_async.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // 보기 4개(정답 1 + 오답 3)를 항상 만들 수 있도록 5단어를 시드한다.
  // 카타카나 단어는 뜻 보기 3개가 필요해서 단어가 3개면 보기가 모자란다.
  // dailyTarget이 3이라 오늘 세트는 그중 3개만 담긴다.
  Future<(Database, ProviderContainer)> setup(WidgetTester tester) async {
    late Database db;
    late ProviderContainer container;
    await tester.runAsync(() async {
      db = await AppDatabase.openForTest();
      await SettingsRepository(db).setDataVersion(AppDatabase.kDataVersion);
      await WordRepository(db).insertAll(const [
        Word(id: 'n2_0001', expression: '生産', reading: 'せいさん', meaningKo: '생산', type: WordType.on),
        Word(id: 'n2_0002', expression: '把握', reading: 'はあく', meaningKo: '파악', type: WordType.on),
        Word(id: 'n2_0003', expression: 'コーヒー', reading: 'コーヒー', meaningKo: '커피', type: WordType.katakana),
        Word(id: 'n2_0004', expression: '果実', reading: 'かじつ', meaningKo: '과실', type: WordType.on),
        Word(id: 'n2_0005', expression: '涼しい', reading: 'すずしい', meaningKo: '시원하다', type: WordType.kun),
      ]);
      container = ProviderContainer(overrides: [
        databaseProvider.overrideWith((ref) async => db),
        progressSummaryProvider.overrideWith((ref) async => const ProgressSummary(
              completedCount: 0, totalCount: 5, daysUntilExam: 10, dailyTarget: 3, weakCount: 0,
            )),
      ]);
      await container.read(todayStudySetProvider.notifier).createTodaySet();
    });
    return (db, container);
  }

  Widget app(ProviderContainer c) => UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(
          routerConfig: GoRouter(routes: [
            GoRoute(path: '/', builder: (context, state) => const QuizScreen(mode: QuizMode.study)),
            GoRoute(path: '/quiz/complete', builder: (context, state) => const Scaffold(body: Text('COMPLETE'))),
          ]),
        ),
      );

  testWidgets('shows expression, 4 choices and dont-know button', (tester) async {
    final (db, c) = await setup(tester);
    await tester.pumpWidget(app(c));
    await settleWithDb(tester);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.byKey(const Key('quiz-choice-0')), findsOneWidget);
    expect(find.byKey(const Key('quiz-choice-3')), findsOneWidget);
    expect(find.text('모르겠다'), findsOneWidget);
    await tester.runAsync(db.close);
  });

  testWidgets('wrong answer reveals card, requeues, and waits for 다음', (tester) async {
    final (db, c) = await setup(tester);
    await tester.pumpWidget(app(c));
    await settleWithDb(tester);
    await tester.tap(find.text('모르겠다'));
    await settleWithDb(tester);
    expect(find.text('다음'), findsOneWidget);
    await tester.tap(find.text('다음'));
    await settleWithDb(tester);
    expect(find.text('2 / 4'), findsOneWidget); // 큐 길이 +1
    await tester.runAsync(db.close);
  });

  testWidgets('finishing all items navigates to complete', (tester) async {
    final (db, c) = await setup(tester);
    await tester.pumpWidget(app(c));
    await settleWithDb(tester);
    for (var i = 0; i < 3; i++) {
      final state = tester.state<QuizScreenState>(find.byType(QuizScreen));
      await tester.tap(find.byKey(Key('quiz-choice-${state.correctChoiceIndexForTest}')));
      await settleWithDb(tester);
      await tester.pump(const Duration(milliseconds: 1100)); // 정답 자동 넘김 타이머
      await settleWithDb(tester);
    }
    expect(find.text('COMPLETE'), findsOneWidget);
    await tester.runAsync(db.close);
  });
}
