import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/features/stats/stats_screen.dart';
import 'package:jlpt/features/stats/stats_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  ProviderScope buildWidget(StatsState stats) => ProviderScope(
        overrides: [
          statsProvider.overrideWith((ref) async => stats),
        ],
        child: const MaterialApp(home: StatsScreen()),
      );

  testWidgets('renders without crash', (tester) async {
    final stats = StatsState(
        n3Completed: 10, n3Total: 100, n2Completed: 5, n2Total: 200);
    await tester.pumpWidget(buildWidget(stats));
    await tester.pump();
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('shows 통계 title', (tester) async {
    final stats = StatsState(
        n3Completed: 10, n3Total: 100, n2Completed: 5, n2Total: 200);
    await tester.pumpWidget(buildWidget(stats));
    await tester.pump();
    expect(find.text('통계'), findsOneWidget);
  });

  testWidgets('shows N3 and N2 progress', (tester) async {
    final stats = StatsState(
        n3Completed: 10, n3Total: 100, n2Completed: 5, n2Total: 200);
    await tester.pumpWidget(buildWidget(stats));
    await tester.pump();
    expect(find.text('N3'), findsOneWidget);
    expect(find.text('N2'), findsOneWidget);
  });

  testWidgets('shows correct completion counts', (tester) async {
    final stats = StatsState(
        n3Completed: 10, n3Total: 100, n2Completed: 5, n2Total: 200);
    await tester.pumpWidget(buildWidget(stats));
    await tester.pump();
    expect(find.text('10 / 100'), findsOneWidget);
    expect(find.text('5 / 200'), findsOneWidget);
  });
}
