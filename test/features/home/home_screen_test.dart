import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt/application/providers/progress_summary_provider.dart';
import 'package:jlpt/application/providers/today_study_set_provider.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:jlpt/domain/models/today_study_set.dart';
import 'package:jlpt/features/home/home_screen.dart';

void main() {
  final testSummary = ProgressSummary(
    currentLevel: JlptLevel.n3,
    completedCount: 10,
    totalCount: 100,
    daysUntilExam: 30,
    dailyTarget: 5,
    isReviewOnlyMode: false,
  );

  Widget buildHomeScreen({
    ProgressSummary? summary,
    AsyncValue<dynamic>? setAsyncValue,
  }) {
    final s = summary ?? testSummary;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => ProviderScope(
            overrides: [
              progressSummaryProvider.overrideWith((ref) async => s),
              todayStudySetProvider.overrideWith(() => _NullStudySetNotifier()),
            ],
            child: const HomeScreen(),
          ),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  testWidgets('shows D-Day text', (tester) async {
    await tester.pumpWidget(buildHomeScreen());
    await tester.pumpAndSettle();
    expect(find.text('D-30'), findsOneWidget);
  });

  testWidgets('shows current level badge', (tester) async {
    await tester.pumpWidget(buildHomeScreen());
    await tester.pumpAndSettle();
    expect(find.text('N3'), findsOneWidget);
  });

  testWidgets('shows today progress text', (tester) async {
    await tester.pumpWidget(buildHomeScreen());
    await tester.pumpAndSettle();
    expect(find.textContaining('오늘'), findsWidgets);
  });

  testWidgets('shows start study button when no set', (tester) async {
    await tester.pumpWidget(buildHomeScreen());
    await tester.pumpAndSettle();
    expect(find.text('오늘 학습 시작'), findsOneWidget);
  });

  testWidgets('shows D+ when exam has passed', (tester) async {
    final pastSummary = ProgressSummary(
      currentLevel: JlptLevel.n3,
      completedCount: 0,
      totalCount: 100,
      daysUntilExam: -5,
      dailyTarget: 5,
      isReviewOnlyMode: false,
    );
    await tester.pumpWidget(buildHomeScreen(summary: pastSummary));
    await tester.pumpAndSettle();
    expect(find.text('D+5'), findsOneWidget);
  });

  testWidgets('shows 복습 시작 button when in review-only mode', (tester) async {
    final reviewSummary = ProgressSummary(
      currentLevel: JlptLevel.n3,
      completedCount: 100,
      totalCount: 100,
      daysUntilExam: 10,
      dailyTarget: 0,
      isReviewOnlyMode: true,
    );
    await tester.pumpWidget(buildHomeScreen(summary: reviewSummary));
    await tester.pumpAndSettle();
    expect(find.text('복습 시작'), findsOneWidget);
  });
}

class _NullStudySetNotifier extends TodayStudySetNotifier {
  @override
  Future<TodayStudySet?> build() async => null;
}
