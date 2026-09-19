import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt/application/providers/miss_tag_counts_provider.dart';
import 'package:jlpt/application/providers/progress_summary_provider.dart';
import 'package:jlpt/application/providers/today_study_set_provider.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:jlpt/domain/models/error_tag.dart';
import 'package:jlpt/domain/models/today_study_set.dart';
import 'package:jlpt/features/home/home_screen.dart';

void main() {
  const testSummary = ProgressSummary(
    completedCount: 10,
    totalCount: 100,
    daysUntilExam: 30,
    dailyTarget: 5,
    weakCount: 0,
  );

  /// [itemCount]개 중 앞 [passedCount]개가 passed인 오늘 세트.
  TodayStudySet buildSet({
    required StudyStage status,
    required int itemCount,
    required int passedCount,
  }) {
    final now = DateTime(2026, 9, 19);
    return TodayStudySet(
      studyDate: '2026-09-19',
      targetCount: itemCount,
      status: status,
      items: [
        for (var i = 0; i < itemCount; i++)
          TodayStudyItem(
            studyDate: '2026-09-19',
            wordId: 'n2_000$i',
            displayOrder: i,
            passed: i < passedCount,
            attempts: 1,
            updatedAt: now,
          ),
      ],
      createdAt: now,
      updatedAt: now,
    );
  }

  Widget buildHomeScreen({
    ProgressSummary? summary,
    TodayStudySetNotifier? notifier,
  }) {
    final s = summary ?? testSummary;
    final n = notifier ?? _NullStudySetNotifier();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/quiz',
          builder: (context, state) => const Scaffold(body: Text('QUIZ')),
        ),
      ],
    );
    // 바텀시트는 MaterialApp의 Navigator 아래 뜨므로 ProviderScope가
    // 라우트가 아니라 앱 바깥에 있어야 오버라이드를 본다.
    return ProviderScope(
      overrides: [
        progressSummaryProvider.overrideWith((ref) async => s),
        todayStudySetProvider.overrideWith(() => n),
        // 복습 시트가 DB를 건드리지 않도록 빈 태그 카운트로 고정.
        missTagCountsProvider.overrideWith((ref) async => const <ErrorTag, int>{}),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('shows D-Day text', (tester) async {
    await tester.pumpWidget(buildHomeScreen());
    await tester.pumpAndSettle();
    expect(find.text('D-30'), findsOneWidget);
  });

  testWidgets('shows progress line', (tester) async {
    await tester.pumpWidget(buildHomeScreen());
    await tester.pumpAndSettle();
    expect(find.text('N2 10 / 100'), findsOneWidget);
  });

  testWidgets('shows today progress text', (tester) async {
    await tester.pumpWidget(buildHomeScreen());
    await tester.pumpAndSettle();
    expect(find.textContaining('오늘'), findsWidgets);
  });

  testWidgets('shows study button when no set', (tester) async {
    await tester.pumpWidget(buildHomeScreen());
    await tester.pumpAndSettle();
    expect(find.text('학습 시작'), findsOneWidget);
  });

  testWidgets('exam passed still shows study button', (tester) async {
    const pastSummary = ProgressSummary(
      completedCount: 0,
      totalCount: 100,
      daysUntilExam: -5,
      dailyTarget: 10,
      weakCount: 0,
    );
    await tester.pumpWidget(buildHomeScreen(summary: pastSummary));
    await tester.pumpAndSettle();
    expect(find.text('D+5'), findsOneWidget);
    expect(find.text('학습 시작'), findsOneWidget);
  });

  testWidgets('shows review card with weak count', (tester) async {
    const weakSummary = ProgressSummary(
      completedCount: 10,
      totalCount: 100,
      daysUntilExam: 30,
      dailyTarget: 5,
      weakCount: 3,
    );
    await tester.pumpWidget(buildHomeScreen(summary: weakSummary));
    await tester.pumpAndSettle();
    expect(find.text('복습'), findsOneWidget);
    expect(find.text('약점 3개'), findsOneWidget);
  });

  testWidgets('shows add word card', (tester) async {
    await tester.pumpWidget(buildHomeScreen());
    await tester.pumpAndSettle();
    expect(find.text('단어 추가'), findsOneWidget);
  });

  testWidgets('in-progress set shows 이어하기 and today progress', (tester) async {
    final notifier = _StubStudySetNotifier(
      buildSet(status: StudyStage.quiz, itemCount: 3, passedCount: 1),
    );
    await tester.pumpWidget(buildHomeScreen(notifier: notifier));
    await tester.pumpAndSettle();

    expect(find.text('이어하기'), findsOneWidget);
    expect(find.text('오늘 1 / 3 완료'), findsOneWidget);
    expect(find.text('다음 학습 시작'), findsNothing);
    expect(find.text('학습 시작'), findsNothing);
  });

  testWidgets('completed set disables the main button and offers the next set',
      (tester) async {
    final notifier = _StubStudySetNotifier(
      buildSet(status: StudyStage.completed, itemCount: 3, passedCount: 3),
    );
    await tester.pumpWidget(buildHomeScreen(notifier: notifier));
    await tester.pumpAndSettle();

    expect(find.text('오늘 학습 완료 ✓'), findsOneWidget);
    expect(find.text('오늘 3 / 3 완료'), findsOneWidget);

    final button = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('오늘 학습 완료 ✓'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(button.onPressed, isNull);

    expect(find.text('다음 학습 시작'), findsOneWidget);
  });

  testWidgets('tapping 다음 학습 시작 appends a set and opens the quiz',
      (tester) async {
    final notifier = _StubStudySetNotifier(
      buildSet(status: StudyStage.completed, itemCount: 3, passedCount: 3),
    );
    await tester.pumpWidget(buildHomeScreen(notifier: notifier));
    await tester.pumpAndSettle();

    await tester.tap(find.text('다음 학습 시작'));
    await tester.pumpAndSettle();

    expect(notifier.appendNextSetCalls, 1);
    expect(find.text('QUIZ'), findsOneWidget);
  });

  testWidgets('tapping 복습 opens the review filter sheet', (tester) async {
    await tester.pumpWidget(buildHomeScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('복습'));
    await tester.pumpAndSettle();

    expect(find.text('전체'), findsOneWidget);
    // 시트를 여는 것만으로 복습 세션이 만들어지면 안 된다.
    expect(find.text('QUIZ'), findsNothing);
  });
}

class _NullStudySetNotifier extends TodayStudySetNotifier {
  @override
  Future<TodayStudySet?> build() async => null;
}

/// 미리 만들어 둔 세트를 그대로 돌려주고 [appendNextSet] 호출 횟수를 센다.
class _StubStudySetNotifier extends TodayStudySetNotifier {
  _StubStudySetNotifier(this.set);

  final TodayStudySet set;
  int appendNextSetCalls = 0;

  @override
  Future<TodayStudySet?> build() async => set;

  @override
  Future<TodayStudySet> appendNextSet() async {
    appendNextSetCalls++;
    return set;
  }
}
