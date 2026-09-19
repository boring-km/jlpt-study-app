import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jlpt/core/db/database.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:jlpt/domain/models/word.dart';
import 'package:jlpt/domain/repositories/progress_repository.dart';
import 'package:jlpt/domain/repositories/word_repository.dart';
import 'package:jlpt/domain/services/study_set_builder.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<Database> seed() async {
    final db = await AppDatabase.openForTest();
    final words = <Word>[
      for (var i = 0; i < 20; i++)
        Word(id: 'n2_on$i', expression: '音$i', reading: 'おん$i', meaningKo: 'x', type: WordType.on),
      for (var i = 0; i < 10; i++)
        Word(id: 'n2_kun$i', expression: '訓$i', reading: 'くん$i', meaningKo: 'x', type: WordType.kun),
      for (var i = 0; i < 2; i++)
        Word(id: 'user_$i', expression: '유$i', reading: 'ゆ$i', meaningKo: 'x', source: 'user'),
    ];
    await WordRepository(db).insertAll(words);
    return db;
  }

  test('user words first, at least 6 kun, rest random', () async {
    final db = await seed();
    final builder = StudySetBuilder(ProgressRepository(db), random: Random(1));
    final ids = await builder.pickNewWordIds(15);
    expect(ids.length, 15);
    expect(ids.toSet().length, 15);
    expect(ids.where((id) => id.startsWith('user_')).length, 2);
    expect(ids.where((id) => id.startsWith('n2_kun')).length, greaterThanOrEqualTo(6));
    await db.close();
  });

  test('target smaller than kun minimum still respects target', () async {
    final db = await seed();
    final builder = StudySetBuilder(ProgressRepository(db), random: Random(1));
    final ids = await builder.pickNewWordIds(3);
    expect(ids.length, 3);
    await db.close();
  });

  test('excludes given ids and completed words', () async {
    final db = await seed();
    final repo = ProgressRepository(db);
    for (var i = 0; i < 20; i++) {
      await repo.markCompleted('n2_on$i');
    }
    final builder = StudySetBuilder(repo, random: Random(1));
    final ids = await builder.pickNewWordIds(50, exclude: {'user_0'});
    expect(ids, isNot(contains('user_0')));
    expect(ids.any((id) => id.startsWith('n2_on')), isFalse);
    expect(ids.length, 11); // 10 kun + user_1
    await db.close();
  });

  test('pickWeakWordIds returns up to kWeakPerDay weak words', () async {
    final db = await seed();
    final repo = ProgressRepository(db);
    for (var i = 0; i < 8; i++) {
      await repo.markCompleted('n2_on$i');
      await repo.incrementMiss('n2_on$i');
    }
    final builder = StudySetBuilder(repo, random: Random(1));
    final weak = await builder.pickWeakWordIds();
    expect(weak.length, kWeakPerDay);
    await db.close();
  });
}
