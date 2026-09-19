import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/domain/models/error_tag.dart';
import 'package:jlpt/features/stats/stats_screen.dart';
import 'package:jlpt/features/stats/stats_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const testStats = StatsState(
    completed: 10,
    total: 100,
    weak: 4,
    missByTag: {
      ErrorTag.longVowel: 3,
      ErrorTag.sokuon: 1,
      ErrorTag.dakuten: 0,
    },
  );

  ProviderScope buildWidget(StatsState stats) => ProviderScope(
        overrides: [
          statsProvider.overrideWith((ref) async => stats),
        ],
        child: const MaterialApp(home: StatsScreen()),
      );

  testWidgets('renders without crash', (tester) async {
    await tester.pumpWidget(buildWidget(testStats));
    await tester.pump();
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('shows 통계 title', (tester) async {
    await tester.pumpWidget(buildWidget(testStats));
    await tester.pump();
    expect(find.text('통계'), findsOneWidget);
  });

  testWidgets('shows a single N2 progress card', (tester) async {
    await tester.pumpWidget(buildWidget(testStats));
    await tester.pump();
    expect(find.text('N2'), findsOneWidget);
    expect(find.text('N3'), findsNothing);
    expect(find.text('10 / 100'), findsOneWidget);
  });

  testWidgets('shows weak count', (tester) async {
    await tester.pumpWidget(buildWidget(testStats));
    await tester.pump();
    expect(find.text('약점 4개'), findsOneWidget);
  });

  testWidgets('shows miss counts per tag, omitting zeros', (tester) async {
    await tester.pumpWidget(buildWidget(testStats));
    await tester.pump();
    expect(find.text('장음 3 · 촉음 1'), findsOneWidget);
  });

  testWidgets('omits the tag row when there are no misses', (tester) async {
    const clean = StatsState(
      completed: 10,
      total: 100,
      weak: 0,
      missByTag: {},
    );
    await tester.pumpWidget(buildWidget(clean));
    await tester.pump();
    expect(find.text('약점 0개'), findsOneWidget);
    expect(find.textContaining(' · '), findsNothing);
  });

  test('percent is completed over total, zero-safe', () {
    expect(testStats.percent, 0.1);
    expect(
      const StatsState(completed: 0, total: 0, weak: 0, missByTag: {}).percent,
      0.0,
    );
  });
}
