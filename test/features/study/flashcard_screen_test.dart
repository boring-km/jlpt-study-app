import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt/application/providers/today_study_set_provider.dart';
import 'package:jlpt/application/providers/word_catalog_provider.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:jlpt/domain/models/today_study_set.dart';
import 'package:jlpt/domain/models/word.dart';
import 'package:jlpt/features/study/flashcard/flashcard_screen.dart';
import 'package:jlpt/widgets/flip_card.dart';
import 'package:jlpt/widgets/flashcard_page_view.dart';

void main() {
  final testWords = [
    Word(
      id: 'n3_0001',
      jlptLevel: JlptLevel.n3,
      expression: '学校',
      reading: 'がっこう',
      meaningKo: '학교',
    ),
    Word(
      id: 'n3_0002',
      jlptLevel: JlptLevel.n3,
      expression: '先生',
      reading: 'せんせい',
      meaningKo: '선생님',
    ),
  ];

  final testSet = TodayStudySet(
    studyDate: '2026-04-07',
    jlptLevel: JlptLevel.n3,
    targetCount: 2,
    status: StudyStage.flashcard,
    items: [
      TodayStudyItem(
        studyDate: '2026-04-07',
        wordId: 'n3_0001',
        displayOrder: 0,
        readingPassed: false,
        meaningPassed: false,
        readingAttempts: 0,
        meaningAttempts: 0,
        updatedAt: DateTime(2026, 4, 7),
      ),
      TodayStudyItem(
        studyDate: '2026-04-07',
        wordId: 'n3_0002',
        displayOrder: 1,
        readingPassed: false,
        meaningPassed: false,
        readingAttempts: 0,
        meaningAttempts: 0,
        updatedAt: DateTime(2026, 4, 7),
      ),
    ],
    createdAt: DateTime(2026, 4, 7),
    updatedAt: DateTime(2026, 4, 7),
  );

  Widget buildFlashcardScreen() {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => ProviderScope(
            overrides: [
              todayStudySetProvider.overrideWith(
                () => _FixedStudySetNotifier(testSet),
              ),
              wordCatalogProvider.overrideWith(
                () => _FixedCatalogNotifier(testWords),
              ),
            ],
            child: const FlashcardScreen(),
          ),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  testWidgets('shows word expression on front card', (tester) async {
    await tester.pumpWidget(buildFlashcardScreen());
    await tester.pumpAndSettle();
    expect(find.text('学校'), findsOneWidget);
  });

  testWidgets('shows card index in app bar', (tester) async {
    await tester.pumpWidget(buildFlashcardScreen());
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('FlipCard widget is present', (tester) async {
    await tester.pumpWidget(buildFlashcardScreen());
    await tester.pumpAndSettle();
    expect(find.byType(FlipCard), findsOneWidget);
  });

  testWidgets('tapping FlipCard flips the card', (tester) async {
    await tester.pumpWidget(buildFlashcardScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FlipCard));
    await tester.pumpAndSettle();

    expect(find.text('がっこう'), findsOneWidget);
    expect(find.text('학교'), findsOneWidget);
  });

  testWidgets('swiping left advances to next card', (tester) async {
    await tester.pumpWidget(buildFlashcardScreen());
    await tester.pumpAndSettle();

    // Swipe left on the PageView to go to the next card
    await tester.fling(
      find.byType(FlashcardPageView),
      const Offset(-300, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('swiping right goes back to previous card', (tester) async {
    await tester.pumpWidget(buildFlashcardScreen());
    await tester.pumpAndSettle();

    // Go to second card
    await tester.fling(
      find.byType(FlashcardPageView),
      const Offset(-300, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);

    // Swipe right to go back
    await tester.fling(
      find.byType(FlashcardPageView),
      const Offset(300, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
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
