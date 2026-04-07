import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static Database? _db;

  static Future<Database> get instance async {
    _db ??= await _open();
    return _db!;
  }

  /// 테스트 전용: 고유 이름의 인메모리 DB 반환 (테스트 간 격리 보장)
  static Future<Database> openForTest({String? name}) async {
    final dbName = name ?? 'test_${DateTime.now().microsecondsSinceEpoch}';
    return openDatabase(
      ':memory:$dbName',
      version: 1,
      onCreate: _onCreate,
    );
  }

  static Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'jlpt.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
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
    await db.execute('CREATE INDEX idx_words_level ON words (jlpt_level)');
    await db.execute('CREATE INDEX idx_words_reading ON words (reading)');

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
    await db.execute(
      'CREATE INDEX idx_word_progress_completed ON word_progress (is_completed, completed_at)',
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
  }
}
