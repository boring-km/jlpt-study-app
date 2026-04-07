import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/application/providers/database_provider.dart';
import 'package:jlpt/application/providers/today_study_set_provider.dart';
import 'package:jlpt/application/providers/word_catalog_provider.dart';
import 'package:jlpt/core/db/database.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:jlpt/domain/models/today_study_set.dart';
import 'package:jlpt/domain/models/word.dart';
import 'package:jlpt/domain/repositories/word_repository.dart';
import 'package:jlpt/features/study/quiz_reading/quiz_reading_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final testWord = Word(
    id: 'n3_0001',
    jlptLevel: JlptLevel.n3,
    expression: '学校',
    reading: 'がっこう',
    meaningKo: '학교',
  );

  final testSet = TodayStudySet(
    studyDate: '2026-04-07',
    jlptLevel: JlptLevel.n3,
    targetCount: 1,
    status: StudyStage.quizReading,
    items: [
      TodayStudyItem(
        studyDate: '2026-04-07',
        wordId: 'n3_0001',
        displayOrder: 0,
        readingPassed: false,
        meaningPassed: false,
        readingAttempts: 0,
        meaningAttempts: 0,
        updatedAt: DateTime(2026, 4, 7),
      ),
    ],
    createdAt: DateTime(2026, 4, 7),
    updatedAt: DateTime(2026, 4, 7),
  );

  testWidgets('renders without crash', (tester) async {
    final db = await AppDatabase.openForTest();
    final wordRepo = WordRepository(db);
    await wordRepo.insertAll([testWord]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          todayStudySetProvider
              .overrideWith(() => _FixedStudySetNotifier(testSet)),
          wordCatalogProvider
              .overrideWith(() => _FixedCatalogNotifier([testWord])),
          databaseProvider.overrideWith((ref) async => db),
        ],
        child: const MaterialApp(home: QuizReadingScreen()),
      ),
    );

    // Initial frame: loading spinner expected
    await tester.pump();
    expect(find.byType(Scaffold), findsOneWidget);
  });
}

class _FixedStudySetNotifier extends TodayStudySetNotifier {
  final TodayStudySet _set;
  _FixedStudySetNotifier(this._set);
  @override
  Future<TodayStudySet?> build() async => _set;
}

class _FixedCatalogNotifier extends WordCatalogNotifier {
  final List<Word> _words;
  _FixedCatalogNotifier(this._words);
  @override
  Future<List<Word>> build() async => _words;
}
