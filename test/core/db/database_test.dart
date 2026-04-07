import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jlpt/core/db/database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('creates all 7 tables', () async {
    final db = await AppDatabase.openForTest();
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
    );
    final names = tables.map((r) => r['name'] as String).toList();
    expect(names, containsAll([
      'app_settings',
      'daily_study_set_items',
      'daily_study_sets',
      'review_session_items',
      'review_sessions',
      'word_progress',
      'words',
    ]));
    await db.close();
  });

  test('words table has required columns', () async {
    final db = await AppDatabase.openForTest();
    final info = await db.rawQuery('PRAGMA table_info(words)');
    final cols = info.map((r) => r['name'] as String).toList();
    expect(cols, containsAll([
      'id', 'jlpt_level', 'expression', 'reading',
      'meaning_ko', 'example_ja', 'example_reading', 'example_ko', 'created_at',
    ]));
    await db.close();
  });

  test('daily_study_set_items has composite primary key columns', () async {
    final db = await AppDatabase.openForTest();
    final info = await db.rawQuery('PRAGMA table_info(daily_study_set_items)');
    final cols = info.map((r) => r['name'] as String).toList();
    expect(cols, containsAll(['study_date', 'word_id', 'display_order',
      'reading_passed', 'meaning_passed', 'reading_attempts', 'meaning_attempts',
      'last_result', 'updated_at']));
    await db.close();
  });

  test('app_settings table has key/value/updated_at columns', () async {
    final db = await AppDatabase.openForTest();
    final info = await db.rawQuery('PRAGMA table_info(app_settings)');
    final cols = info.map((r) => r['name'] as String).toList();
    expect(cols, containsAll(['key', 'value', 'updated_at']));
    await db.close();
  });
}
