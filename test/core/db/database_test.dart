import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jlpt/core/db/database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('creates all 8 tables', () async {
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
      'miss_log',
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
      'meaning_ko', 'type', 'is_trap', 'source',
      'example_ja', 'example_reading', 'example_ko', 'created_at',
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

  test('word_progress has miss_count column on fresh install', () async {
    final db = await AppDatabase.openForTest();
    final info = await db.rawQuery('PRAGMA table_info(word_progress)');
    final cols = info.map((r) => r['name'] as String).toList();
    expect(cols, contains('miss_count'));
    await db.close();
  });

  test('v1 → v2 upgrade adds miss_count and backfills completed rows to 1',
      () async {
    final tmpDir = await Directory.systemTemp.createTemp('jlpt_db_test_');
    final path = p.join(tmpDir.path, 'jlpt_upgrade.db');

    // 1) v1 스키마로 오픈해서 데이터 주입
    final v1 = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE words (
              id TEXT PRIMARY KEY,
              jlpt_level TEXT NOT NULL,
              expression TEXT,
              reading TEXT NOT NULL,
              meaning_ko TEXT NOT NULL,
              example_ja TEXT,
              example_reading TEXT,
              example_ko TEXT,
              created_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE word_progress (
              word_id TEXT PRIMARY KEY REFERENCES words(id),
              is_completed INTEGER NOT NULL DEFAULT 0,
              completed_at TEXT,
              last_reviewed_at TEXT,
              review_count INTEGER NOT NULL DEFAULT 0,
              updated_at TEXT NOT NULL
            )
          ''');
          // 다른 테이블들은 이 테스트에서 쓰지 않음 (onUpgrade도 word_progress만 건드림)
        },
      ),
    );
    await v1.insert('words', {
      'id': 'n3_0001',
      'jlpt_level': 'N3',
      'reading': 'あ',
      'meaning_ko': 'a',
      'created_at': '2026-04-01T00:00:00.000',
    });
    await v1.insert('words', {
      'id': 'n3_0002',
      'jlpt_level': 'N3',
      'reading': 'い',
      'meaning_ko': 'i',
      'created_at': '2026-04-01T00:00:00.000',
    });
    await v1.insert('word_progress', {
      'word_id': 'n3_0001',
      'is_completed': 1,
      'completed_at': '2026-04-01T00:00:00.000',
      'review_count': 0,
      'updated_at': '2026-04-01T00:00:00.000',
    });
    await v1.insert('word_progress', {
      'word_id': 'n3_0002',
      'is_completed': 0,
      'review_count': 0,
      'updated_at': '2026-04-01T00:00:00.000',
    });
    await v1.close();

    // 2) v2로 재오픈 → onUpgrade 실행
    final v2 = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onUpgrade: (db, oldVersion, newVersion) async {
          // 운영 로직과 동일: miss_count 컬럼 추가 후 완료 row만 1로 백필
          await db.execute(
            'ALTER TABLE word_progress ADD COLUMN miss_count INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'UPDATE word_progress SET miss_count = 1 WHERE is_completed = 1',
          );
        },
      ),
    );

    final info = await v2.rawQuery('PRAGMA table_info(word_progress)');
    final cols = info.map((r) => r['name'] as String).toList();
    expect(cols, contains('miss_count'));

    final completedRow = (await v2.query(
      'word_progress',
      where: 'word_id = ?',
      whereArgs: ['n3_0001'],
    )).first;
    expect(completedRow['miss_count'], 1);

    final uncompletedRow = (await v2.query(
      'word_progress',
      where: 'word_id = ?',
      whereArgs: ['n3_0002'],
    )).first;
    expect(uncompletedRow['miss_count'], 0);

    await v2.close();
    await tmpDir.delete(recursive: true);
  });

  test('upgrade from v2 removes N3 rows, adds columns and miss_log', () async {
    final dir = await Directory.systemTemp.createTemp('jlpt_mig');
    final path = p.join(dir.path, 'v2.db');
    // v2 스키마 수동 생성
    final v2 = await openDatabase(path, version: 2, onCreate: (db, _) async {
      await db.execute('CREATE TABLE words (id TEXT PRIMARY KEY, jlpt_level TEXT NOT NULL, expression TEXT, reading TEXT NOT NULL, meaning_ko TEXT NOT NULL, example_ja TEXT, example_reading TEXT, example_ko TEXT, created_at TEXT NOT NULL)');
      await db.execute('CREATE TABLE word_progress (word_id TEXT PRIMARY KEY, is_completed INTEGER NOT NULL DEFAULT 0, completed_at TEXT, last_reviewed_at TEXT, review_count INTEGER NOT NULL DEFAULT 0, miss_count INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL)');
      await db.execute('CREATE TABLE daily_study_sets (study_date TEXT PRIMARY KEY, jlpt_level TEXT NOT NULL, target_count INTEGER NOT NULL, status TEXT NOT NULL, started_at TEXT, completed_at TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)');
      await db.execute('CREATE TABLE daily_study_set_items (study_date TEXT NOT NULL, word_id TEXT NOT NULL, display_order INTEGER NOT NULL, reading_passed INTEGER NOT NULL DEFAULT 0, meaning_passed INTEGER NOT NULL DEFAULT 0, reading_attempts INTEGER NOT NULL DEFAULT 0, meaning_attempts INTEGER NOT NULL DEFAULT 0, last_result TEXT, updated_at TEXT NOT NULL, PRIMARY KEY (study_date, word_id))');
      await db.execute('CREATE TABLE review_sessions (id TEXT PRIMARY KEY, review_date TEXT NOT NULL, item_count INTEGER NOT NULL, status TEXT NOT NULL, started_at TEXT NOT NULL, completed_at TEXT)');
      await db.execute('CREATE TABLE review_session_items (session_id TEXT NOT NULL, word_id TEXT NOT NULL, display_order INTEGER NOT NULL, reading_passed INTEGER NOT NULL DEFAULT 0, meaning_passed INTEGER NOT NULL DEFAULT 0, reading_attempts INTEGER NOT NULL DEFAULT 0, meaning_attempts INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (session_id, word_id))');
      await db.execute('CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at TEXT NOT NULL)');
      await db.insert('words', {'id': 'n3_0001', 'jlpt_level': 'N3', 'expression': 'a', 'reading': 'あ', 'meaning_ko': 'x', 'created_at': 't'});
      await db.insert('words', {'id': 'n2_0001', 'jlpt_level': 'N2', 'expression': 'b', 'reading': 'い', 'meaning_ko': 'y', 'created_at': 't'});
      await db.insert('words', {'id': 'n2_0002', 'jlpt_level': 'N2', 'expression': 'c', 'reading': 'う', 'meaning_ko': 'z', 'created_at': 't'});
      await db.insert('word_progress', {'word_id': 'n3_0001', 'is_completed': 1, 'updated_at': 't'});
      await db.insert('word_progress', {'word_id': 'n2_0001', 'is_completed': 1, 'updated_at': 't'});
      await db.insert('word_progress', {'word_id': 'n2_0002', 'is_completed': 0, 'updated_at': 't'});
      // N3 세트(통째로 삭제 대상)와 N2 세트(N3 항목만 빠지고 살아남아야 함).
      await db.insert('daily_study_sets', {'study_date': '2026-01-01', 'jlpt_level': 'N3', 'target_count': 1, 'status': 'flashcard', 'created_at': 't', 'updated_at': 't'});
      await db.insert('daily_study_set_items', {'study_date': '2026-01-01', 'word_id': 'n3_0001', 'display_order': 0, 'updated_at': 't'});
      await db.insert('daily_study_sets', {'study_date': '2026-01-02', 'jlpt_level': 'N2', 'target_count': 3, 'status': 'quiz', 'created_at': 't', 'updated_at': 't'});
      await db.insert('daily_study_set_items', {'study_date': '2026-01-02', 'word_id': 'n2_0001', 'display_order': 0, 'updated_at': 't'});
      await db.insert('daily_study_set_items', {'study_date': '2026-01-02', 'word_id': 'n2_0002', 'display_order': 1, 'updated_at': 't'});
      await db.insert('daily_study_set_items', {'study_date': '2026-01-02', 'word_id': 'n3_0001', 'display_order': 2, 'updated_at': 't'});
      // 복습 세션도 N3 항목만 빠져야 한다.
      await db.insert('review_sessions', {'id': 'review_1', 'review_date': '2026-01-02', 'item_count': 2, 'status': 'quiz', 'started_at': 't'});
      await db.insert('review_session_items', {'session_id': 'review_1', 'word_id': 'n2_0001', 'display_order': 0});
      await db.insert('review_session_items', {'session_id': 'review_1', 'word_id': 'n3_0001', 'display_order': 1});
      await db.insert('app_settings', {'key': 'seeded_at', 'value': 't', 'updated_at': 't'});
    });
    await v2.close();

    final v3 = await AppDatabase.openAtPath(path);
    expect((await v3.query('words')).map((r) => r['id']), ['n2_0001', 'n2_0002']);
    expect(
      (await v3.query('word_progress')).map((r) => r['word_id']),
      ['n2_0001', 'n2_0002'],
    );
    // N3 세트만 사라지고 N2 세트는 남는다.
    expect(
      (await v3.query('daily_study_sets')).map((r) => r['study_date']),
      ['2026-01-02'],
    );
    expect(
      (await v3.query('daily_study_set_items', orderBy: 'display_order'))
          .map((r) => r['word_id']),
      ['n2_0001', 'n2_0002'],
    );
    expect((await v3.query('review_sessions')).length, 1);
    expect(
      (await v3.query('review_session_items')).map((r) => r['word_id']),
      ['n2_0001'],
    );
    final cols = (await v3.rawQuery('PRAGMA table_info(words)')).map((r) => r['name']).toList();
    expect(cols, containsAll(['type', 'is_trap', 'source']));
    final tables = (await v3.rawQuery("SELECT name FROM sqlite_master WHERE type='table'")).map((r) => r['name']).toList();
    expect(tables, contains('miss_log'));
    expect(await v3.query('app_settings', where: "key = 'data_version'"), isEmpty);
    await v3.close();
    await dir.delete(recursive: true);
  });
}
