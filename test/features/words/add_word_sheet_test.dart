import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/application/providers/database_provider.dart';
import 'package:jlpt/application/providers/word_catalog_provider.dart';
import 'package:jlpt/core/db/database.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:jlpt/domain/models/word.dart';
import 'package:jlpt/domain/repositories/settings_repository.dart';
import 'package:jlpt/domain/repositories/word_repository.dart';
import 'package:jlpt/features/words/add_word_sheet.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../quiz/quiz_test_async.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  /// 시딩을 건너뛴 빈 DB + 카탈로그가 준비된 컨테이너.
  Future<(Database, ProviderContainer)> setup(
    WidgetTester tester, {
    List<Word> words = const [],
  }) async {
    late Database db;
    late ProviderContainer container;
    await tester.runAsync(() async {
      db = await AppDatabase.openForTest();
      await SettingsRepository(db).setDataVersion(AppDatabase.kDataVersion);
      if (words.isNotEmpty) await WordRepository(db).insertAll(words);
      container = ProviderContainer(overrides: [
        databaseProvider.overrideWith((ref) async => db),
      ]);
      await container.read(wordCatalogProvider.future);
    });
    return (db, container);
  }

  Widget app(ProviderContainer container) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => showAddWordSheet(ctx),
                  child: const Text('OPEN'),
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('OPEN'));
    await settleWithDb(tester);
  }

  test('looksJapanese', () {
    expect(looksJapanese('把握'), isTrue);
    expect(looksJapanese('おぎなう'), isTrue);
    expect(looksJapanese('コーヒー'), isTrue);
    expect(looksJapanese('hello'), isFalse);
    expect(looksJapanese(''), isFalse);
    expect(looksJapanese('   '), isFalse);
    expect(looksJapanese('把握\n生産'), isFalse);
    expect(looksJapanese('あ' * 21), isFalse);
    expect(looksJapanese('あ' * 20), isTrue);
  });

  testWidgets('saves user word with reading required for kanji',
      (tester) async {
    final (db, container) = await setup(tester);
    addTearDown(container.dispose);
    await tester.pumpWidget(app(container));
    await settleWithDb(tester);
    await openSheet(tester);

    await tester.enterText(find.byKey(const Key('add-expression')), '把握');
    await settleWithDb(tester);

    await tester.tap(find.byKey(const Key('add-save')));
    await settleWithDb(tester);
    expect(find.text('읽기를 입력하세요'), findsOneWidget);
    expect(find.byKey(const Key('add-expression')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('add-reading')), 'はあく');
    await tester.enterText(find.byKey(const Key('add-meaning')), '파악');
    await settleWithDb(tester);
    await tester.tap(find.byKey(const Key('add-save')));
    await settleWithDb(tester);

    expect(find.byKey(const Key('add-expression')), findsNothing);
    final saved = container.read(wordCatalogProvider).valueOrNull ?? [];
    final userWords = saved.where((w) => w.source == 'user').toList();
    expect(userWords, hasLength(1));
    expect(userWords.single.expression, '把握');
    expect(userWords.single.reading, 'はあく');
    expect(userWords.single.meaningKo, '파악');
    await tester.runAsync(db.close);
  });

  testWidgets('existing expression shows 이미 있는 단어 and disables save',
      (tester) async {
    final (db, container) = await setup(tester, words: const [
      Word(
        id: 'n2_0001',
        expression: '生産',
        reading: 'せいさん',
        meaningKo: '생산',
        type: WordType.on,
      ),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(app(container));
    await settleWithDb(tester);
    await openSheet(tester);

    await tester.enterText(find.byKey(const Key('add-expression')), '生産');
    await settleWithDb(tester);

    expect(find.text('이미 있는 단어'), findsOneWidget);
    final save = tester.widget<ElevatedButton>(
      find.byKey(const Key('add-save')),
    );
    expect(save.onPressed, isNull);
    await tester.runAsync(db.close);
  });

  testWidgets('empty expression shows 표기를 입력하세요', (tester) async {
    final (db, container) = await setup(tester);
    addTearDown(container.dispose);
    await tester.pumpWidget(app(container));
    await settleWithDb(tester);
    await openSheet(tester);

    await tester.tap(find.byKey(const Key('add-save')));
    await settleWithDb(tester);

    expect(find.text('표기를 입력하세요'), findsOneWidget);
    await tester.runAsync(db.close);
  });

  testWidgets('katakana word without kanji falls back to expression as reading',
      (tester) async {
    final (db, container) = await setup(tester);
    addTearDown(container.dispose);
    await tester.pumpWidget(app(container));
    await settleWithDb(tester);
    await openSheet(tester);

    await tester.enterText(find.byKey(const Key('add-expression')), 'コーヒー');
    await settleWithDb(tester);
    await tester.tap(find.byKey(const Key('add-save')));
    await settleWithDb(tester);

    final saved = container.read(wordCatalogProvider).valueOrNull ?? [];
    final word = saved.singleWhere((w) => w.source == 'user');
    expect(word.expression, 'コーヒー');
    expect(word.reading, 'コーヒー');
    expect(word.type, WordType.katakana);
    await tester.runAsync(db.close);
  });

  testWidgets('initialExpression prefills the expression field', (tester) async {
    final (db, container) = await setup(tester);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () =>
                      showAddWordSheet(ctx, initialExpression: '把握'),
                  child: const Text('OPEN'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await settleWithDb(tester);
    await openSheet(tester);

    final field = tester.widget<TextField>(
      find.byKey(const Key('add-expression')),
    );
    expect(field.controller?.text, '把握');
    await tester.runAsync(db.close);
  });
}
