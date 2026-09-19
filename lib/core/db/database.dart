import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static const int kVersion = 3;

  /// 에셋 단어 데이터 버전. 올리면 다음 실행 시 카탈로그 upsert.
  static const int kDataVersion = 2;

  static Database? _db;

  static Future<Database> get instance async {
    _db ??= await _open();
    return _db!;
  }

  static Future<String> get filePath async =>
      join(await getDatabasesPath(), 'jlpt.db');

  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// 테스트 전용: 고유 이름의 인메모리 DB 반환 (테스트 간 격리 보장)
  static Future<Database> openForTest({String? name}) async {
    final dbName = name ?? 'test_${DateTime.now().microsecondsSinceEpoch}';
    return openAtPath(':memory:$dbName');
  }

  static Future<Database> openAtPath(String path) => openDatabase(
        path,
        version: kVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );

  static Future<Database> _open() async => openAtPath(await filePath);

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE words (
        id TEXT PRIMARY KEY,
        jlpt_level TEXT NOT NULL,
        expression TEXT,
        reading TEXT NOT NULL,
        meaning_ko TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'other',
        is_trap INTEGER NOT NULL DEFAULT 0,
        source TEXT NOT NULL DEFAULT 'n2',
        example_ja TEXT,
        example_reading TEXT,
        example_ko TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_words_reading ON words (reading)');
    await db.execute('CREATE INDEX idx_words_type ON words (type)');
    await db.execute('CREATE INDEX idx_words_expression ON words (expression)');

    await db.execute('''
      CREATE TABLE word_progress (
        word_id TEXT PRIMARY KEY REFERENCES words(id),
        is_completed INTEGER NOT NULL DEFAULT 0,
        completed_at TEXT,
        last_reviewed_at TEXT,
        review_count INTEGER NOT NULL DEFAULT 0,
        miss_count INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_word_progress_completed ON word_progress (is_completed, completed_at)',
    );
    await db.execute(
      'CREATE INDEX idx_word_progress_miss ON word_progress (miss_count, is_completed)',
    );

    await db.execute('''
      CREATE TABLE daily_study_sets (
        study_date TEXT PRIMARY KEY,
        jlpt_level TEXT NOT NULL,
        target_count INTEGER NOT NULL,
        status TEXT NOT NULL,
        started_at TEXT,
        completed_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE daily_study_set_items (
        study_date TEXT NOT NULL REFERENCES daily_study_sets(study_date),
        word_id TEXT NOT NULL REFERENCES words(id),
        display_order INTEGER NOT NULL,
        reading_passed INTEGER NOT NULL DEFAULT 0,
        meaning_passed INTEGER NOT NULL DEFAULT 0,
        reading_attempts INTEGER NOT NULL DEFAULT 0,
        meaning_attempts INTEGER NOT NULL DEFAULT 0,
        last_result TEXT,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (study_date, word_id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_daily_items_order ON daily_study_set_items (study_date, display_order)',
    );

    await db.execute('''
      CREATE TABLE review_sessions (
        id TEXT PRIMARY KEY,
        review_date TEXT NOT NULL,
        item_count INTEGER NOT NULL,
        status TEXT NOT NULL,
        started_at TEXT NOT NULL,
        completed_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE review_session_items (
        session_id TEXT NOT NULL REFERENCES review_sessions(id),
        word_id TEXT NOT NULL REFERENCES words(id),
        display_order INTEGER NOT NULL,
        reading_passed INTEGER NOT NULL DEFAULT 0,
        meaning_passed INTEGER NOT NULL DEFAULT 0,
        reading_attempts INTEGER NOT NULL DEFAULT 0,
        meaning_attempts INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (session_id, word_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await _createMissLog(db);
  }

  static Future<void> _createMissLog(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS miss_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word_id TEXT NOT NULL REFERENCES words(id),
        tag TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_miss_log_tag ON miss_log (tag, created_at)',
    );
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE word_progress ADD COLUMN miss_count INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'UPDATE word_progress SET miss_count = 1 WHERE is_completed = 1',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_word_progress_miss ON word_progress (miss_count, is_completed)',
      );
    }
    if (oldVersion < 3) {
      await _upgradeToV3(db);
    }
  }

  /// v3: N3 제거, 단어 분류 컬럼, miss_log, 데이터 재시딩 트리거.
  static Future<void> _upgradeToV3(Database db) async {
    await db.execute("ALTER TABLE words ADD COLUMN type TEXT NOT NULL DEFAULT 'other'");
    await db.execute('ALTER TABLE words ADD COLUMN is_trap INTEGER NOT NULL DEFAULT 0');
    await db.execute("ALTER TABLE words ADD COLUMN source TEXT NOT NULL DEFAULT 'n2'");
    await db.execute('CREATE INDEX IF NOT EXISTS idx_words_type ON words (type)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_words_expression ON words (expression)');

    const n3 = "SELECT id FROM words WHERE jlpt_level = 'N3'";
    await db.execute('DELETE FROM review_session_items WHERE word_id IN ($n3)');
    await db.execute('DELETE FROM daily_study_set_items WHERE word_id IN ($n3)');
    await db.execute('DELETE FROM word_progress WHERE word_id IN ($n3)');
    await db.execute("DELETE FROM daily_study_sets WHERE jlpt_level = 'N3'");
    await db.execute("DELETE FROM words WHERE jlpt_level = 'N3'");

    await _createMissLog(db);

    // 구 시딩 플래그 제거 → 카탈로그 프로바이더가 data_version 기준으로 재시딩
    await db.execute("DELETE FROM app_settings WHERE key IN ('seeded_at', 'data_version')");
  }
}
