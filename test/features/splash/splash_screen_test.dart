import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/application/providers/word_catalog_provider.dart';
import 'package:jlpt/domain/models/word.dart';
import 'package:jlpt/features/splash/splash_screen.dart';

void main() {
  group('SplashScreen', () {
    testWidgets('shows loading message while catalog is loading',
        (WidgetTester tester) async {
      final completer = Completer<List<Word>>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wordCatalogProvider.overrideWith(
              () => _CompleterCatalogNotifier(completer.future),
            ),
          ],
          child: const MaterialApp(home: SplashScreen()),
        ),
      );

      await tester.pump();
      expect(find.text('단어 데이터 로딩 중...'), findsOneWidget);

      completer.complete([]);
    });

    testWidgets('shows error message on catalog error',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wordCatalogProvider.overrideWith(() => _ErrorCatalogNotifier()),
          ],
          child: const MaterialApp(home: SplashScreen()),
        ),
      );

      await tester.pump();
      await tester.pump();
      expect(find.textContaining('로딩 실패'), findsOneWidget);
    });

    testWidgets('shows JLPT title text', (WidgetTester tester) async {
      final completer = Completer<List<Word>>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wordCatalogProvider.overrideWith(
              () => _CompleterCatalogNotifier(completer.future),
            ),
          ],
          child: const MaterialApp(home: SplashScreen()),
        ),
      );

      await tester.pump();
      expect(find.text('JLPT'), findsOneWidget);

      completer.complete([]);
    });
  });
}

class _CompleterCatalogNotifier extends WordCatalogNotifier {
  final Future<List<Word>> _future;
  _CompleterCatalogNotifier(this._future);

  @override
  Future<List<Word>> build() => _future;
}

class _ErrorCatalogNotifier extends WordCatalogNotifier {
  @override
  Future<List<Word>> build() async {
    throw Exception('테스트 에러');
  }
}
