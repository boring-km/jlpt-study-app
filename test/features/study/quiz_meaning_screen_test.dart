import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/application/providers/today_study_set_provider.dart';
import 'package:jlpt/application/providers/word_catalog_provider.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:jlpt/domain/models/today_study_set.dart';
import 'package:jlpt/domain/models/word.dart';
import 'package:jlpt/features/study/quiz_meaning/quiz_meaning_screen.dart';
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

  final testSet = TodayStudySet(
    studyDate: '2026-04-07',
    jlptLevel: JlptLevel.n3,
    targetCount: 1,
    status: StudyStage.quizMeaning,
    items: [
      TodayStudyItem(
        studyDate: '2026-04-07',
        wordId: 'n3_0001',
        displayOrder: 0,
        readingPassed: true,
        meaningPassed: false,
        readingAttempts: 1,
        meaningAttempts: 0,
        updatedAt: DateTime(2026, 4, 7),
      ),
    ],
    createdAt: DateTime(2026, 4, 7),
    updatedAt: DateTime(2026, 4, 7),
  );

  Widget buildWidget() => ProviderScope(
        overrides: [
          todayStudySetProvider
              .overrideWith(() => _FixedStudySetNotifier(testSet)),
          wordCatalogProvider
              .overrideWith(() => _FixedCatalogNotifier([testWord])),
        ],
        child: const MaterialApp(home: QuizMeaningScreen()),
      );

  testWidgets('renders without crash', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pump();
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('shows word expression', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pump();
    await tester.pump();
    expect(find.text('学校'), findsOneWidget);
  });

  testWidgets('shows 뜻 확인 button initially', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pump();
    await tester.pump();
    expect(find.text('뜻 확인'), findsOneWidget);
  });

  testWidgets('tapping 뜻 확인 reveals meaning and 알아/몰라 buttons',
      (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pump();
    await tester.pump(); // second pump for didChangeDependencies + setState

    await tester.tap(find.text('뜻 확인'));
    await tester.pump();

    expect(find.text('학교'), findsOneWidget);
    expect(find.text('알아'), findsOneWidget);
    expect(find.text('몰라'), findsOneWidget);
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
