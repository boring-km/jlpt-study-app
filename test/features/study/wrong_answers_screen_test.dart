import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/application/providers/today_study_set_provider.dart';
import 'package:jlpt/application/providers/word_catalog_provider.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:jlpt/domain/models/today_study_set.dart';
import 'package:jlpt/domain/models/word.dart';
import 'package:jlpt/features/study/wrong_answers/wrong_answers_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final testWord = Word(
    id: 'n3_0001',
    jlptLevel: JlptLevel.n3,
    expression: '学校',
    reading: 'がっこう',
    meaningKo: '학교',
  );

  TodayStudySet makeSet({required bool readingPassed}) => TodayStudySet(
        studyDate: '2026-04-07',
        jlptLevel: JlptLevel.n3,
        targetCount: 1,
        status: StudyStage.quizMeaning,
        items: [
          TodayStudyItem(
            studyDate: '2026-04-07',
            wordId: 'n3_0001',
            displayOrder: 0,
            readingPassed: readingPassed,
            meaningPassed: false,
            readingAttempts: 1,
            meaningAttempts: 0,
            updatedAt: DateTime(2026, 4, 7),
          ),
        ],
        createdAt: DateTime(2026, 4, 7),
        updatedAt: DateTime(2026, 4, 7),
      );

  Widget buildWidget({required String stage, required bool readingPassed}) =>
      ProviderScope(
        overrides: [
          todayStudySetProvider.overrideWith(
              () => _FixedStudySetNotifier(makeSet(readingPassed: readingPassed))),
          wordCatalogProvider
              .overrideWith(() => _FixedCatalogNotifier([testWord])),
        ],
        child: MaterialApp(
          home: WrongAnswersScreen(stage: stage),
        ),
      );

  testWidgets('renders without crash', (tester) async {
    await tester.pumpWidget(buildWidget(stage: 'reading', readingPassed: false));
    await tester.pump();
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('shows 1단계 결과 title for reading stage', (tester) async {
    await tester.pumpWidget(buildWidget(stage: 'reading', readingPassed: false));
    await tester.pump();
    expect(find.text('1단계 결과'), findsOneWidget);
  });

  testWidgets('shows wrong word in list', (tester) async {
    await tester.pumpWidget(buildWidget(stage: 'reading', readingPassed: false));
    await tester.pump();
    expect(find.text('学校'), findsOneWidget);
  });

  testWidgets('shows 모두 정답 when all passed', (tester) async {
    await tester.pumpWidget(buildWidget(stage: 'reading', readingPassed: true));
    await tester.pump();
    expect(find.text('모두 정답!'), findsOneWidget);
  });

  testWidgets('shows 다시 퀴즈 button when wrong items exist', (tester) async {
    await tester.pumpWidget(buildWidget(stage: 'reading', readingPassed: false));
    await tester.pump();
    expect(find.text('다시 퀴즈'), findsOneWidget);
  });

  testWidgets('shows 다음 단계로 button when reading all passed', (tester) async {
    await tester.pumpWidget(buildWidget(stage: 'reading', readingPassed: true));
    await tester.pump();
    expect(find.text('다음 단계로'), findsOneWidget);
  });
}

class _FixedStudySetNotifier extends TodayStudySetNotifier {
  final TodayStudySet _set;
  _FixedStudySetNotifier(this._set);
  @override
  Future<TodayStudySet?> build() async => _set;
}

class _FixedCatalogNotifier extends WordCatalogNotifier {
  final List<Word> _words;
  _FixedCatalogNotifier(this._words);
  @override
  Future<List<Word>> build() async => _words;
}
