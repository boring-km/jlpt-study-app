import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jlpt/application/providers/database_provider.dart';
import 'package:jlpt/application/providers/progress_summary_provider.dart';
import 'package:jlpt/application/providers/today_study_set_provider.dart';
import 'package:jlpt/application/providers/word_catalog_provider.dart';
import 'package:jlpt/core/db/database.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:jlpt/domain/models/today_study_set.dart';
import 'package:jlpt/domain/models/word.dart';
import 'package:jlpt/domain/repositories/settings_repository.dart';
import 'package:jlpt/domain/repositories/word_repository.dart';
import 'package:jlpt/features/quiz/quiz_mode.dart';
import 'package:jlpt/features/quiz/quiz_screen.dart';
import 'quiz_test_async.dart';

/// 보기 4개(정답 1 + 오답 3)를 항상 만들 수 있는 시드.
/// 카타카나 단어는 뜻 보기 3개가 필요해서 단어가 3개면 보기가 모자란다.
const _fiveWords = [
  Word(id: 'n2_0001', expression: '生産', reading: 'せいさん', meaningKo: '생산', type: WordType.on),
  Word(id: 'n2_0002', expression: '把握', reading: 'はあく', meaningKo: '파악', type: WordType.on),
  Word(id: 'n2_0003', expression: 'コーヒー', reading: 'コーヒー', meaningKo: '커피', type: WordType.katakana),
  Word(id: 'n2_0004', expression: '果実', reading: 'かじつ', meaningKo: '과실', type: WordType.on),
  Word(id: 'n2_0005', expression: '涼しい', reading: 'すずしい', meaningKo: '시원하다', type: WordType.kun),
];

/// 카타카나 쪽 뜻 보기가 1개뿐이라 보기가 2개로 줄어드는 시드.
const _twoWords = [
  Word(id: 'n2_0002', expression: '把握', reading: 'はあく', meaningKo: '파악', type: WordType.on),
  Word(id: 'n2_0003', expression: 'コーヒー', reading: 'コーヒー', meaningKo: '커피', type: WordType.katakana),
];

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  /// dailyTarget이 시드보다 작으면 오늘 세트는 그중 일부만 담는다.
  Future<(Database, ProviderContainer)> setupWith(
    WidgetTester tester, {
    required List<Word> words,
    required int dailyTarget,
  }) async {
    late Database db;
    late ProviderContainer container;
    await tester.runAsync(() async {
      db = await AppDatabase.openForTest();
      await SettingsRepository(db).setDataVersion(AppDatabase.kDataVersion);
      await WordRepository(db).insertAll(words);
      container = ProviderContainer(overrides: [
        databaseProvider.overrideWith((ref) async => db),
        progressSummaryProvider.overrideWith((ref) async => ProgressSummary(
              completedCount: 0,
              totalCount: words.length,
              daysUntilExam: 10,
              dailyTarget: dailyTarget,
              weakCount: 0,
            )),
      ]);
      await container.read(todayStudySetProvider.notifier).createTodaySet();
    });
    return (db, container);
  }

  Future<(Database, ProviderContainer)> setup(WidgetTester tester) =>
      setupWith(tester, words: _fiveWords, dailyTarget: 3);

  Widget app(ProviderContainer c) => UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(
          routerConfig: GoRouter(routes: [
            GoRoute(path: '/', builder: (context, state) => const QuizScreen(mode: QuizMode.study)),
            GoRoute(
                path: '/quiz/complete',
                builder: (context, state) => const Scaffold(body: Text('COMPLETE'))),
          ]),
        ),
      );

  /// 현재 문제를 정답으로 맞혀 다음 문제로 넘어간다.
  Future<void> answerCorrectly(WidgetTester tester) async {
    final state = tester.state<QuizScreenState>(find.byType(QuizScreen));
    await tester.tap(find.byKey(Key('quiz-choice-${state.correctChoiceIndexForTest}')));
    await settleWithDb(tester);
    await tester.pump(const Duration(milliseconds: 1100)); // 정답 자동 넘김 타이머
    await settleWithDb(tester);
  }

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
      await answerCorrectly(tester);
    }
    expect(find.text('COMPLETE'), findsOneWidget);
    await tester.runAsync(db.close);
  });

  testWidgets('renders without crashing when fewer than 4 choices exist', (tester) async {
    final (db, c) = await setupWith(tester, words: _twoWords, dailyTarget: 2);
    await tester.pumpWidget(app(c));
    await settleWithDb(tester);

    // 카타카나 문제는 뜻 오답이 1개뿐이다. 먼저 나온 게 把握이면 맞히고 넘어간다.
    if (find.text('コーヒー').evaluate().isEmpty) {
      await answerCorrectly(tester);
    }
    expect(find.text('コーヒー'), findsOneWidget);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('quiz-choice-0')), findsOneWidget);
    expect(find.byKey(const Key('quiz-choice-1')), findsOneWidget);
    expect(find.byKey(const Key('quiz-choice-2')), findsNothing);
    expect(find.byKey(const Key('quiz-choice-3')), findsNothing);
    expect(find.text('모르겠다'), findsOneWidget);
    await tester.runAsync(db.close);
  });

  testWidgets('a DB failure shows an error state with a retry instead of a spinner',
      (tester) async {
    // 보기 로딩이 실패하면 예전에는 스피너에 영구히 머물렀다.
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) async => throw StateError('db down')),
      wordCatalogProvider.overrideWith(_StubCatalogNotifier.new),
      todayStudySetProvider.overrideWith(_StubStudySetNotifier.new),
    ]);
    addTearDown(container.dispose);
    // 화면이 뜨기 전에 세트·카탈로그를 해소해 둔다 (다른 테스트의 setup과 동일).
    await container.read(wordCatalogProvider.future);
    await container.read(todayStudySetProvider.future);

    await tester.pumpWidget(app(container));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('보기를 불러오지 못했습니다.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 재시도는 다시 시도하고(여전히 실패) 에러 상태를 유지한다.
    await tester.tap(find.text('다시 시도'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.text('보기를 불러오지 못했습니다.'), findsOneWidget);
  });

  testWidgets('모르겠다 logs a miss with the other tag', (tester) async {
    final (db, c) = await setup(tester);
    final firstWordId = c.read(todayStudySetProvider).valueOrNull!.items.first.wordId;
    await tester.pumpWidget(app(c));
    await settleWithDb(tester);
    await tester.tap(find.text('모르겠다'));
    await settleWithDb(tester);

    late List<Map<String, Object?>> rows;
    await tester.runAsync(() async {
      rows = await db.rawQuery('SELECT word_id, tag FROM miss_log');
    });
    expect(rows, hasLength(1));
    expect(rows.single['word_id'], firstWordId);
    expect(rows.single['tag'], 'other');
    await tester.runAsync(db.close);
  });
}

/// DB 없이 카탈로그를 들고 있는 stub.
class _StubCatalogNotifier extends WordCatalogNotifier {
  @override
  Future<List<Word>> build() async => _fiveWords;
}

/// DB 없이 오늘 세트를 들고 있는 stub (첫 단어만 미완료).
class _StubStudySetNotifier extends TodayStudySetNotifier {
  @override
  Future<TodayStudySet?> build() async {
    final now = DateTime(2026, 9, 20);
    return TodayStudySet(
      studyDate: '2026-09-20',
      targetCount: 1,
      status: StudyStage.quiz,
      items: [
        TodayStudyItem(
          studyDate: '2026-09-20',
          wordId: 'n2_0001',
          displayOrder: 0,
          passed: false,
          attempts: 0,
          updatedAt: now,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );
  }
}
