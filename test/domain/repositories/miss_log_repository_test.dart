import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jlpt/core/db/database.dart';
import 'package:jlpt/domain/models/error_tag.dart';
import 'package:jlpt/domain/models/word.dart';
import 'package:jlpt/domain/repositories/miss_log_repository.dart';
import 'package:jlpt/domain/repositories/word_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('add, recentWordIdsByTag (distinct, recent first), countByTag', () async {
    final db = await AppDatabase.openForTest();
    await WordRepository(db).insertAll([
      const Word(id: 'w1', expression: 'a', reading: 'あ', meaningKo: 'x'),
      const Word(id: 'w2', expression: 'b', reading: 'い', meaningKo: 'y'),
    ]);
    final repo = MissLogRepository(db);
    await repo.add('w1', ErrorTag.longVowel);
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await repo.add('w2', ErrorTag.longVowel);
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await repo.add('w1', ErrorTag.longVowel);
    await repo.add('w2', ErrorTag.sokuon);

    expect(await repo.recentWordIdsByTag(ErrorTag.longVowel), ['w1', 'w2']);
    expect(await repo.recentWordIdsByTag(ErrorTag.dakuten), isEmpty);
    final counts = await repo.countByTag();
    expect(counts[ErrorTag.longVowel], 2); // distinct words
    expect(counts[ErrorTag.sokuon], 1);
    expect(await repo.tagsForWord('w2'), containsAll([ErrorTag.longVowel, ErrorTag.sokuon]));
    await repo.clear();
    expect(await repo.countByTag(), isEmpty);
    await db.close();
  });
}
