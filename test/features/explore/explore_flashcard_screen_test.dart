import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/features/explore/explore_flashcard_screen.dart';
import 'package:jlpt/features/explore/explore_provider.dart';
import 'package:jlpt/domain/models/word.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// 테스트 단어 목록
final testWords = [
  Word(id: '1', expression: '食べる', reading: 'たべる', meaningKo: '먹다', jlptLevel: JlptLevel.n3, example: null),
  Word(id: '2', expression: '飲む', reading: 'のむ', meaningKo: '마시다', jlptLevel: JlptLevel.n3, example: null),
];

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // exploreProvider를 testWords로 오버라이드
  ProviderScope buildWidget() => ProviderScope(
    overrides: [
      exploreProvider.overrideWith(() => _TestExploreNotifier()),
    ],
    child: const MaterialApp(home: ExploreFlashcardScreen()),
  );

  testWidgets('renders without crash', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pump();
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('shows word count in app bar', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pump();
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('shows first word expression on front', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pump();
    expect(find.text('食べる'), findsAtLeastNWidgets(1));
  });

  testWidgets('tapping next advances to second card', (tester) async {
    await tester.pumpWidget(buildWidget());
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_forward_ios));
    await tester.pump();
    expect(find.text('2 / 2'), findsOneWidget);
  });
}

// 테스트용 ExploreNotifier — testWords를 미리 채워줌
class _TestExploreNotifier extends ExploreNotifier {
  @override
  Future<ExploreState> build() async {
    return ExploreState(
      filter: const ExploreFilter(),
      results: testWords,
      completedWordIds: {},
      isLoading: false,
    );
  }
}
