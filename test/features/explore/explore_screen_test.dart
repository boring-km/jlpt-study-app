import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/features/explore/explore_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('renders without crash', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ExploreScreen()),
      ),
    );
    await tester.pump();
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('shows 탐색 title', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ExploreScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('탐색'), findsOneWidget);
  });

  testWidgets('shows 단어 리스트 and 플래시카드 mode cards', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ExploreScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('단어 리스트'), findsOneWidget);
    expect(find.text('플래시카드'), findsOneWidget);
  });
}
