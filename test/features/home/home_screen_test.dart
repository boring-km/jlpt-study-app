import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt/application/providers/progress_summary_provider.dart';
import 'package:jlpt/application/providers/today_study_set_provider.dart';
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

  Widget buildHomeScreen({ProgressSummary? summary}) {
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
}

class _NullStudySetNotifier extends TodayStudySetNotifier {
  @override
  Future<TodayStudySet?> build() async => null;
}
