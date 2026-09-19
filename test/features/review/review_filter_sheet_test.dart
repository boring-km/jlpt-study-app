import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt/application/providers/miss_tag_counts_provider.dart';
import 'package:jlpt/application/providers/review_session_provider.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:jlpt/domain/models/error_tag.dart';
import 'package:jlpt/domain/models/review_session.dart';
import 'package:jlpt/features/review/review_filter_sheet.dart';

void main() {
  Widget buildApp({
    Map<ErrorTag, int> counts = const {ErrorTag.longVowel: 3, ErrorTag.sokuon: 1},
    ReviewSessionNotifier? reviewNotifier,
  }) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => showReviewFilterSheet(ctx),
                  child: const Text('OPEN'),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/quiz',
          builder: (context, state) => const Scaffold(body: Text('QUIZ')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        missTagCountsProvider.overrideWith((ref) async => counts),
        if (reviewNotifier != null)
          reviewSessionProvider.overrideWith(() => reviewNotifier),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows 전체 and tag chips with counts', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await openSheet(tester);

    expect(find.text('전체'), findsOneWidget);
    expect(find.text('장음 3'), findsOneWidget);
    expect(find.text('촉음 1'), findsOneWidget);
    // 카운트가 0인 태그는 칩을 만들지 않는다.
    expect(find.textContaining('탁음'), findsNothing);
  });

  testWidgets('tapping a tag chip starts a tagged session and opens the quiz',
      (tester) async {
    final notifier = _StubReviewNotifier();
    await tester.pumpWidget(buildApp(reviewNotifier: notifier));
    await tester.pumpAndSettle();
    await openSheet(tester);

    await tester.tap(find.text('장음 3'));
    await tester.pumpAndSettle();

    expect(notifier.startCalls, [ErrorTag.longVowel]);
    expect(find.text('QUIZ'), findsOneWidget);
  });

  testWidgets('tapping 전체 starts an untagged session', (tester) async {
    final notifier = _StubReviewNotifier();
    await tester.pumpWidget(buildApp(reviewNotifier: notifier));
    await tester.pumpAndSettle();
    await openSheet(tester);

    await tester.tap(find.text('전체'));
    await tester.pumpAndSettle();

    expect(notifier.startCalls, [null]);
    expect(find.text('QUIZ'), findsOneWidget);
  });

  testWidgets('renders only 전체 when there are no miss logs', (tester) async {
    await tester.pumpWidget(buildApp(counts: const {}));
    await tester.pumpAndSettle();
    await openSheet(tester);

    expect(find.text('전체'), findsOneWidget);
    expect(find.byType(ActionChip), findsOneWidget);
  });
}

/// DB 없이 [startNewSession] 호출 태그만 기록한다.
class _StubReviewNotifier extends ReviewSessionNotifier {
  final List<ErrorTag?> startCalls = [];

  @override
  Future<ReviewSession?> build() async => null;

  @override
  Future<ReviewSession> startNewSession({ErrorTag? tag}) async {
    startCalls.add(tag);
    final session = ReviewSession(
      id: 'review_stub',
      reviewDate: '2026-09-20',
      itemCount: 0,
      status: StudyStage.quiz,
      items: const [],
      startedAt: DateTime(2026, 9, 20),
    );
    state = AsyncData(session);
    return session;
  }
}
