import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/application/providers/progress_summary_provider.dart';
import 'package:jlpt/application/providers/today_study_set_provider.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:jlpt/domain/models/today_study_set.dart';
import 'package:jlpt/features/study/complete/complete_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final testSet = TodayStudySet(
    studyDate: '2026-04-07',
    jlptLevel: JlptLevel.n3,
    targetCount: 1,
    status: StudyStage.completed,
    items: [
      TodayStudyItem(
        studyDate: '2026-04-07',
        wordId: 'n3_0001',
        displayOrder: 0,
        readingPassed: true,
        meaningPassed: true,
        readingAttempts: 1,
        meaningAttempts: 1,
        updatedAt: DateTime(2026, 4, 7),
      ),
    ],
    createdAt: DateTime(2026, 4, 7),
    updatedAt: DateTime(2026, 4, 7),
  );

  final testSummary = ProgressSummary(
    currentLevel: JlptLevel.n3,
    completedCount: 10,
    totalCount: 100,
    n3Completed: 10,
    n3Total: 100,
    n2Completed: 0,
    n2Total: 100,
    daysUntilExam: 30,
    dailyTarget: 5,
    isReviewOnlyMode: false,
    weakCount: 0,
  );

  Widget buildWidget() => ProviderScope(
        overrides: [
          todayStudySetProvider
              .overrideWith(() => _FixedStudySetNotifier(testSet)),
          progressSummaryProvider
              .overrideWith((ref) async => testSummary),
        ],
        child: const MaterialApp(home: CompleteScreen()),
      );

  testWidgets('renders without crash', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pump();
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('shows 오늘 학습 완료 text', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pump();
    expect(find.text('오늘 학습 완료!'), findsOneWidget);
  });

  testWidgets('shows 홈으로 button', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pump();
    expect(find.text('홈으로'), findsOneWidget);
  });

  testWidgets('shows 복습하기 button', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pump();
    expect(find.text('복습하기'), findsOneWidget);
  });
}

class _FixedStudySetNotifier extends TodayStudySetNotifier {
  final TodayStudySet _set;
  _FixedStudySetNotifier(this._set);
  @override
  Future<TodayStudySet?> build() async => _set;
}
