import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/domain/models/word.dart';
import 'package:jlpt/features/explore/explore_provider.dart';
import 'package:jlpt/features/explore/word_list_screen.dart';

const _words = [
  Word(
    id: 'n2_0001',
    expression: '把握',
    reading: 'はあく',
    meaningKo: '파악',
    example: WordExample(
      ja: '状況を把握する',
      reading: 'じょうきょうをはあくする',
      ko: '상황을 파악하다',
    ),
  ),
  Word(id: 'user_1', expression: '産業', reading: 'さんぎょう', meaningKo: '산업'),
];

/// DB를 타지 않고 필터 호출만 기록하는 노티파이어.
class _TestExploreNotifier extends ExploreNotifier {
  _TestExploreNotifier(this.initial);

  final ExploreState initial;
  final List<ExploreFilter> applied = [];

  @override
  Future<ExploreState> build() async => initial;

  @override
  Future<void> updateFilter(ExploreFilter filter) async {
    applied.add(filter);
    state = AsyncData((state.valueOrNull ?? initial).copyWith(filter: filter));
  }
}

void main() {
  late _TestExploreNotifier notifier;

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<Word> results = _words,
    Set<String> completed = const {'n2_0001'},
    ExploreFilter filter = const ExploreFilter(),
  }) async {
    notifier = _TestExploreNotifier(
      ExploreState(
        filter: filter,
        results: results,
        completedWordIds: completed,
        isLoading: false,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [exploreProvider.overrideWith(() => notifier)],
        child: const MaterialApp(home: WordListScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows 탐색 title and both filter groups', (tester) async {
    await pumpScreen(tester);
    expect(find.text('탐색'), findsOneWidget);
    for (final label in ['전체', '추가한 단어', '완료', '미완료']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('lists words with a check for the completed one', (tester) async {
    await pumpScreen(tester);
    expect(find.text('把握'), findsOneWidget);
    expect(find.text('파악'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('tapping a word reveals its example', (tester) async {
    await pumpScreen(tester);
    expect(find.text('状況を把握する'), findsNothing);
    await tester.tap(find.text('把握'));
    await tester.pumpAndSettle();
    expect(find.text('状況を把握する'), findsOneWidget);
  });

  testWidgets('search waits for the debounce before filtering', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(find.byType(TextField), 'はあく');
    await tester.pump(const Duration(milliseconds: 100));
    expect(notifier.applied, isEmpty);

    await tester.pump(const Duration(milliseconds: 200));
    expect(notifier.applied.single.query, 'はあく');
  });

  testWidgets('clear suffix appears with text and resets the query', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.byIcon(Icons.close), findsNothing);

    await tester.enterText(find.byType(TextField), 'はあく');
    await tester.pump();
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump(const Duration(milliseconds: 300));
    expect(notifier.applied.last.query, isEmpty);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('tapping a chip filters by source', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('추가한 단어'));
    await tester.pump();
    expect(notifier.applied.single.sourceFilter, 'user');
  });

  testWidgets('empty results offer to clear an active filter', (tester) async {
    await pumpScreen(
      tester,
      results: const [],
      filter: const ExploreFilter(query: 'zzz'),
    );
    expect(find.text('검색 결과가 없다'), findsOneWidget);

    await tester.tap(find.text('필터 지우기'));
    await tester.pump(const Duration(milliseconds: 300));
    final last = notifier.applied.last;
    expect(last.query, isEmpty);
    expect(last.sourceFilter, isNull);
    expect(last.completedFilter, isNull);
  });

  testWidgets('empty results without a filter show no reset button', (
    tester,
  ) async {
    await pumpScreen(tester, results: const []);
    expect(find.text('검색 결과가 없다'), findsOneWidget);
    expect(find.text('필터 지우기'), findsNothing);
  });
}
