import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/core/theme/app_theme.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:jlpt/widgets/word_badge.dart';

void main() {
  group('WordBadge', () {
    testWidgets('shows N3 label for N3 level', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: WordBadge(level: JlptLevel.n3)),
        ),
      );
      expect(find.text('N3'), findsOneWidget);
    });

    testWidgets('shows N2 label for N2 level', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: WordBadge(level: JlptLevel.n2)),
        ),
      );
      expect(find.text('N2'), findsOneWidget);
    });

    testWidgets('uses primary color for text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: WordBadge(level: JlptLevel.n3)),
        ),
      );
      final text = tester.widget<Text>(find.text('N3'));
      expect(text.style?.color, AppColors.primary);
    });
  });
}
