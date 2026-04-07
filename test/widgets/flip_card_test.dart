import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/widgets/flip_card.dart';

void main() {
  group('FlipCard', () {
    testWidgets('shows front when isFlipped is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlipCard(
              front: const Text('앞면'),
              back: const Text('뒷면'),
              isFlipped: false,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('앞면'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlipCard(
              front: const Text('앞면'),
              back: const Text('뒷면'),
              isFlipped: false,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(FlipCard));
      expect(tapped, isTrue);
    });

    testWidgets('starts animation when isFlipped changes to true',
        (tester) async {
      bool flipped = false;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  FlipCard(
                    front: const Text('앞면'),
                    back: const Text('뒷면'),
                    isFlipped: flipped,
                    onTap: () => setState(() => flipped = !flipped),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(FlipCard));
      await tester.pumpAndSettle();
      // 애니메이션 완료 후 뒷면 표시
      expect(find.text('뒷면'), findsOneWidget);
    });
  });
}
