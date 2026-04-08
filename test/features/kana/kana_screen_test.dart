import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/features/kana/kana_screen.dart';

void main() {
  testWidgets('renders without crash', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: KanaScreen())),
    );
    await tester.pump();
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('shows 가나 표 title', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: KanaScreen())),
    );
    await tester.pump();
    expect(find.text('가나 표'), findsOneWidget);
  });

  testWidgets('shows hiragana and katakana tabs', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: KanaScreen())),
    );
    await tester.pump();
    expect(find.text('ひらがな'), findsOneWidget);
    expect(find.text('カタカナ'), findsOneWidget);
  });

  testWidgets('shows あ in hiragana tab', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: KanaScreen())),
    );
    await tester.pump();
    expect(find.text('あ'), findsOneWidget);
  });
}
