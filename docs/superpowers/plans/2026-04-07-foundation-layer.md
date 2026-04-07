# Foundation Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 앱의 기반이 되는 도메인 모델, SQLite DB, 리포지토리, Riverpod 프로바이더, 라우팅, 테마를 구축한다.

**Architecture:** JSON 단어 데이터를 앱 시작 시 메모리에 로드하고 SQLite에 시드한다. 모든 DB 접근은 Repository 계층에서만 수행하며, Riverpod Provider가 UI와 Repository 사이를 연결한다. 화면 이동은 go_router가 담당한다.

**Tech Stack:** Flutter, Riverpod 2.x, sqflite, go_router, intl

---

## File Structure

```
lib/
  main.dart                          # 앱 진입점, ProviderScope
  core/
    theme/
      app_theme.dart                 # 라이트/다크 테마 정의 (디자인 토큰 적용)
    router/
      app_router.dart                # go_router 라우트 정의
    db/
      database.dart                  # SQLite 초기화, 마이그레이션
  domain/
    models/
      word.dart                      # Word 도메인 모델
      word_progress.dart             # WordProgress 모델
      today_study_set.dart           # TodayStudySet, TodayStudyItem 모델
      review_session.dart            # ReviewSession, ReviewSessionItem 모델
      app_settings.dart              # AppSettings 모델
      enums.dart                     # JlptLevel, StudyStage, QuizResult enum
    repositories/
      word_repository.dart           # 단어 CRUD 인터페이스 + sqflite 구현
      progress_repository.dart       # word_progress CRUD
      study_set_repository.dart      # daily_study_sets + items CRUD
      review_repository.dart         # review_sessions + items CRUD
      settings_repository.dart       # app_settings CRUD
  application/
    providers/
      database_provider.dart         # DB 인스턴스 Provider
      word_catalog_provider.dart     # AsyncNotifier: JSON→DB 시드, 메모리 캐시
      settings_provider.dart         # AsyncNotifier: AppSettings
      progress_summary_provider.dart # Provider: ProgressSummary (D-Day, 진도)
```

---

### Task 1: 프로젝트 구조 생성 및 pubspec 업데이트

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/main.dart`

- [ ] **Step 1: pubspec.yaml에 riverpod_annotation, build_runner 추가 및 폰트 설정**

```yaml
# pubspec.yaml dependencies 섹션에 추가
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1
  go_router: ^16.2.1
  sqflite: ^2.4.2
  path: ^1.9.1
  intl: ^0.20.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  build_runner: ^2.4.0
  riverpod_generator: ^2.6.1

flutter:
  uses-material-design: true
  assets:
    - assets/data/n2_words.json
    - assets/data/n3_words.json
```

- [ ] **Step 2: 디렉토리 구조 생성**

```bash
mkdir -p lib/core/theme lib/core/router lib/core/db
mkdir -p lib/domain/models lib/domain/repositories
mkdir -p lib/application/providers
```

- [ ] **Step 3: flutter pub get 실행**

```bash
flutter pub get
```

Expected: 패키지 다운로드 성공, 에러 없음

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add riverpod_annotation, build_runner, riverpod_generator"
```

---

### Task 2: Enum 및 도메인 모델 정의

**Files:**
- Create: `lib/domain/models/enums.dart`
- Create: `lib/domain/models/word.dart`
- Create: `lib/domain/models/word_progress.dart`
- Create: `lib/domain/models/today_study_set.dart`
- Create: `lib/domain/models/review_session.dart`
- Create: `lib/domain/models/app_settings.dart`

- [ ] **Step 1: enums.dart 작성**

```dart
// lib/domain/models/enums.dart
enum JlptLevel { n2, n3 }

enum StudyStage { flashcard, quizReading, quizMeaning, completed }

enum QuizResult { correct, wrong, unknown, know, dontKnow }

enum ThemeMode { system, light, dark }
```

- [ ] **Step 2: word.dart 작성**

```dart
// lib/domain/models/word.dart
import 'enums.dart';

class WordExample {
  final String ja;
  final String reading;
  final String ko;

  const WordExample({
    required this.ja,
    required this.reading,
    required this.ko,
  });

  factory WordExample.fromJson(Map<String, dynamic> json) => WordExample(
        ja: json['ja'] as String,
        reading: json['reading'] as String,
        ko: json['ko'] as String,
      );

  Map<String, dynamic> toJson() => {
        'ja': ja,
        'reading': reading,
        'ko': ko,
      };
}

class Word {
  final String id;
  final JlptLevel jlptLevel;
  final String expression;
  final String reading;
  final String meaningKo;
  final WordExample? example;

  const Word({
    required this.id,
    required this.jlptLevel,
    required this.expression,
    required this.reading,
    required this.meaningKo,
    this.example,
  });

  bool get hasKanji => expression != reading;

  /// JSON asset에서 파싱 (n2_words.json / n3_words.json)
  factory Word.fromAssetJson(Map<String, dynamic> json, JlptLevel level) {
    final rawId = json['id'];
    final prefix = level == JlptLevel.n3 ? 'n3' : 'n2';
    final id = '$prefix\_${rawId.toString().padLeft(4, '0')}';
    return Word(
      id: id,
      jlptLevel: level,
      expression: json['expression'] as String? ?? '',
      reading: json['reading'] as String,
      meaningKo: json['meaning_ko'] as String,
      example: json['example'] != null
          ? WordExample.fromJson(json['example'] as Map<String, dynamic>)
          : null,
    );
  }

  /// DB Row에서 파싱
  factory Word.fromDbMap(Map<String, dynamic> map) => Word(
        id: map['id'] as String,
        jlptLevel: map['jlpt_level'] == 'N3' ? JlptLevel.n3 : JlptLevel.n2,
        expression: map['expression'] as String? ?? '',
        reading: map['reading'] as String,
        meaningKo: map['meaning_ko'] as String,
        example: map['example_ja'] != null
            ? WordExample(
                ja: map['example_ja'] as String,
                reading: map['example_reading'] as String? ?? '',
                ko: map['example_ko'] as String? ?? '',
              )
            : null,
      );

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'jlpt_level': jlptLevel == JlptLevel.n3 ? 'N3' : 'N2',
        'expression': expression,
        'reading': reading,
        'meaning_ko': meaningKo,
        'example_ja': example?.ja,
        'example_reading': example?.reading,
        'example_ko': example?.ko,
        'created_at': DateTime.now().toIso8601String(),
      };
}
```

- [ ] **Step 3: word_progress.dart 작성**

```dart
// lib/domain/models/word_progress.dart

class WordProgress {
  final String wordId;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime? lastReviewedAt;
  final int reviewCount;
  final DateTime updatedAt;

  const WordProgress({
    required this.wordId,
    required this.isCompleted,
    this.completedAt,
    this.lastReviewedAt,
    required this.reviewCount,
    required this.updatedAt,
  });

  factory WordProgress.fromDbMap(Map<String, dynamic> map) => WordProgress(
        wordId: map['word_id'] as String,
        isCompleted: (map['is_completed'] as int) == 1,
        completedAt: map['completed_at'] != null
            ? DateTime.parse(map['completed_at'] as String)
            : null,
        lastReviewedAt: map['last_reviewed_at'] != null
            ? DateTime.parse(map['last_reviewed_at'] as String)
            : null,
        reviewCount: map['review_count'] as int,
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toDbMap() => {
        'word_id': wordId,
        'is_completed': isCompleted ? 1 : 0,
        'completed_at': completedAt?.toIso8601String(),
        'last_reviewed_at': lastReviewedAt?.toIso8601String(),
        'review_count': reviewCount,
        'updated_at': updatedAt.toIso8601String(),
      };

  WordProgress copyWith({
    bool? isCompleted,
    DateTime? completedAt,
    DateTime? lastReviewedAt,
    int? reviewCount,
    DateTime? updatedAt,
  }) =>
      WordProgress(
        wordId: wordId,
        isCompleted: isCompleted ?? this.isCompleted,
        completedAt: completedAt ?? this.completedAt,
        lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
        reviewCount: reviewCount ?? this.reviewCount,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
```

- [ ] **Step 4: today_study_set.dart 작성**

```dart
// lib/domain/models/today_study_set.dart
import 'enums.dart';

class TodayStudyItem {
  final String studyDate;
  final String wordId;
  final int displayOrder;
  final bool readingPassed;
  final bool meaningPassed;
  final int readingAttempts;
  final int meaningAttempts;
  final QuizResult? lastResult;
  final DateTime updatedAt;

  const TodayStudyItem({
    required this.studyDate,
    required this.wordId,
    required this.displayOrder,
    required this.readingPassed,
    required this.meaningPassed,
    required this.readingAttempts,
    required this.meaningAttempts,
    this.lastResult,
    required this.updatedAt,
  });

  bool get isFullyCompleted => readingPassed && meaningPassed;

  factory TodayStudyItem.fromDbMap(Map<String, dynamic> map) {
    QuizResult? lastResult;
    final raw = map['last_result'] as String?;
    if (raw != null) {
      lastResult = QuizResult.values.firstWhere(
        (e) => e.name == _snakeToCamel(raw),
        orElse: () => QuizResult.wrong,
      );
    }
    return TodayStudyItem(
      studyDate: map['study_date'] as String,
      wordId: map['word_id'] as String,
      displayOrder: map['display_order'] as int,
      readingPassed: (map['reading_passed'] as int) == 1,
      meaningPassed: (map['meaning_passed'] as int) == 1,
      readingAttempts: map['reading_attempts'] as int,
      meaningAttempts: map['meaning_attempts'] as int,
      lastResult: lastResult,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toDbMap() => {
        'study_date': studyDate,
        'word_id': wordId,
        'display_order': displayOrder,
        'reading_passed': readingPassed ? 1 : 0,
        'meaning_passed': meaningPassed ? 1 : 0,
        'reading_attempts': readingAttempts,
        'meaning_attempts': meaningAttempts,
        'last_result': lastResult != null ? _camelToSnake(lastResult!.name) : null,
        'updated_at': updatedAt.toIso8601String(),
      };

  TodayStudyItem copyWith({
    bool? readingPassed,
    bool? meaningPassed,
    int? readingAttempts,
    int? meaningAttempts,
    QuizResult? lastResult,
    DateTime? updatedAt,
  }) =>
      TodayStudyItem(
        studyDate: studyDate,
        wordId: wordId,
        displayOrder: displayOrder,
        readingPassed: readingPassed ?? this.readingPassed,
        meaningPassed: meaningPassed ?? this.meaningPassed,
        readingAttempts: readingAttempts ?? this.readingAttempts,
        meaningAttempts: meaningAttempts ?? this.meaningAttempts,
        lastResult: lastResult ?? this.lastResult,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

String _snakeToCamel(String s) {
  final parts = s.split('_');
  return parts[0] +
      parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}

String _camelToSnake(String s) {
  return s.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (m) => '_${m.group(0)!.toLowerCase()}',
  );
}

class TodayStudySet {
  final String studyDate;
  final JlptLevel jlptLevel;
  final int targetCount;
  final StudyStage status;
  final List<TodayStudyItem> items;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TodayStudySet({
    required this.studyDate,
    required this.jlptLevel,
    required this.targetCount,
    required this.status,
    required this.items,
    this.startedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  int get completedCount =>
      items.where((i) => i.isFullyCompleted).length;

  factory TodayStudySet.fromDbMap(
    Map<String, dynamic> map,
    List<TodayStudyItem> items,
  ) =>
      TodayStudySet(
        studyDate: map['study_date'] as String,
        jlptLevel: map['jlpt_level'] == 'N3' ? JlptLevel.n3 : JlptLevel.n2,
        targetCount: map['target_count'] as int,
        status: StudyStage.values.firstWhere(
          (e) => e.name == _snakeToCamel(map['status'] as String),
        ),
        items: items,
        startedAt: map['started_at'] != null
            ? DateTime.parse(map['started_at'] as String)
            : null,
        completedAt: map['completed_at'] != null
            ? DateTime.parse(map['completed_at'] as String)
            : null,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toDbMap() => {
        'study_date': studyDate,
        'jlpt_level': jlptLevel == JlptLevel.n3 ? 'N3' : 'N2',
        'target_count': targetCount,
        'status': _camelToSnake(status.name),
        'started_at': startedAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  TodayStudySet copyWith({
    StudyStage? status,
    List<TodayStudyItem>? items,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? updatedAt,
  }) =>
      TodayStudySet(
        studyDate: studyDate,
        jlptLevel: jlptLevel,
        targetCount: targetCount,
        status: status ?? this.status,
        items: items ?? this.items,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt ?? this.completedAt,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
```

- [ ] **Step 5: review_session.dart 작성**

```dart
// lib/domain/models/review_session.dart
import 'enums.dart';

class ReviewSessionItem {
  final String sessionId;
  final String wordId;
  final int displayOrder;
  final bool readingPassed;
  final bool meaningPassed;
  final int readingAttempts;
  final int meaningAttempts;

  const ReviewSessionItem({
    required this.sessionId,
    required this.wordId,
    required this.displayOrder,
    required this.readingPassed,
    required this.meaningPassed,
    required this.readingAttempts,
    required this.meaningAttempts,
  });

  factory ReviewSessionItem.fromDbMap(Map<String, dynamic> map) =>
      ReviewSessionItem(
        sessionId: map['session_id'] as String,
        wordId: map['word_id'] as String,
        displayOrder: map['display_order'] as int,
        readingPassed: (map['reading_passed'] as int) == 1,
        meaningPassed: (map['meaning_passed'] as int) == 1,
        readingAttempts: map['reading_attempts'] as int,
        meaningAttempts: map['meaning_attempts'] as int,
      );

  Map<String, dynamic> toDbMap() => {
        'session_id': sessionId,
        'word_id': wordId,
        'display_order': displayOrder,
        'reading_passed': readingPassed ? 1 : 0,
        'meaning_passed': meaningPassed ? 1 : 0,
        'reading_attempts': readingAttempts,
        'meaning_attempts': meaningAttempts,
      };

  ReviewSessionItem copyWith({
    bool? readingPassed,
    bool? meaningPassed,
    int? readingAttempts,
    int? meaningAttempts,
  }) =>
      ReviewSessionItem(
        sessionId: sessionId,
        wordId: wordId,
        displayOrder: displayOrder,
        readingPassed: readingPassed ?? this.readingPassed,
        meaningPassed: meaningPassed ?? this.meaningPassed,
        readingAttempts: readingAttempts ?? this.readingAttempts,
        meaningAttempts: meaningAttempts ?? this.meaningAttempts,
      );
}

class ReviewSession {
  final String id;
  final String reviewDate;
  final int itemCount;
  final StudyStage status;
  final List<ReviewSessionItem> items;
  final DateTime startedAt;
  final DateTime? completedAt;

  const ReviewSession({
    required this.id,
    required this.reviewDate,
    required this.itemCount,
    required this.status,
    required this.items,
    required this.startedAt,
    this.completedAt,
  });

  factory ReviewSession.fromDbMap(
    Map<String, dynamic> map,
    List<ReviewSessionItem> items,
  ) =>
      ReviewSession(
        id: map['id'] as String,
        reviewDate: map['review_date'] as String,
        itemCount: map['item_count'] as int,
        status: StudyStage.values.firstWhere(
          (e) => e.name == _snakeToCamel(map['status'] as String),
        ),
        items: items,
        startedAt: DateTime.parse(map['started_at'] as String),
        completedAt: map['completed_at'] != null
            ? DateTime.parse(map['completed_at'] as String)
            : null,
      );

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'review_date': reviewDate,
        'item_count': itemCount,
        'status': _camelToSnake(status.name),
        'started_at': startedAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
      };

  ReviewSession copyWith({
    StudyStage? status,
    List<ReviewSessionItem>? items,
    DateTime? completedAt,
  }) =>
      ReviewSession(
        id: id,
        reviewDate: reviewDate,
        itemCount: itemCount,
        status: status ?? this.status,
        items: items ?? this.items,
        startedAt: startedAt,
        completedAt: completedAt ?? this.completedAt,
      );
}

String _snakeToCamel(String s) {
  final parts = s.split('_');
  return parts[0] +
      parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}

String _camelToSnake(String s) {
  return s.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (m) => '_${m.group(0)!.toLowerCase()}',
  );
}
```

- [ ] **Step 6: app_settings.dart 작성**

```dart
// lib/domain/models/app_settings.dart
import 'enums.dart';

class AppSettings {
  final DateTime examDate;
  final AppThemeMode themeMode;
  final DateTime? seededAt;

  const AppSettings({
    required this.examDate,
    required this.themeMode,
    this.seededAt,
  });

  static AppSettings get defaults => AppSettings(
        examDate: DateTime(2026, 7, 5),
        themeMode: AppThemeMode.system,
      );

  int daysUntilExam(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final exam = DateTime(examDate.year, examDate.month, examDate.day);
    return exam.difference(today).inDays;
  }
}

enum AppThemeMode { system, light, dark }
```

- [ ] **Step 7: Commit**

```bash
git add lib/domain/models/
git commit -m "feat: add domain models (Word, WordProgress, TodayStudySet, ReviewSession, AppSettings)"
```

---

### Task 3: SQLite 데이터베이스 초기화

**Files:**
- Create: `lib/core/db/database.dart`

- [ ] **Step 1: database.dart 작성**

```dart
// lib/core/db/database.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static Database? _db;

  static Future<Database> get instance async {
    _db ??= await _open();
    return _db!;
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
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/db/database.dart
git commit -m "feat: add SQLite database schema (7 tables)"
```

---

### Task 4: Repository 구현

**Files:**
- Create: `lib/domain/repositories/word_repository.dart`
- Create: `lib/domain/repositories/progress_repository.dart`
- Create: `lib/domain/repositories/study_set_repository.dart`
- Create: `lib/domain/repositories/review_repository.dart`
- Create: `lib/domain/repositories/settings_repository.dart`

- [ ] **Step 1: word_repository.dart 작성**

```dart
// lib/domain/repositories/word_repository.dart
import 'package:sqflite/sqflite.dart';
import '../models/word.dart';
import '../models/enums.dart';

class WordRepository {
  final Database _db;

  const WordRepository(this._db);

  Future<void> insertAll(List<Word> words) async {
    final batch = _db.batch();
    for (final word in words) {
      batch.insert(
        'words',
        word.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<int> count() async {
    final result = await _db.rawQuery('SELECT COUNT(*) as c FROM words');
    return result.first['c'] as int;
  }

  Future<int> countByLevel(JlptLevel level) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as c FROM words WHERE jlpt_level = ?',
      [level == JlptLevel.n3 ? 'N3' : 'N2'],
    );
    return result.first['c'] as int;
  }

  Future<List<Word>> getAll() async {
    final rows = await _db.query('words', orderBy: 'id');
    return rows.map(Word.fromDbMap).toList();
  }

  Future<List<Word>> getByLevel(JlptLevel level) async {
    final rows = await _db.query(
      'words',
      where: 'jlpt_level = ?',
      whereArgs: [level == JlptLevel.n3 ? 'N3' : 'N2'],
    );
    return rows.map(Word.fromDbMap).toList();
  }

  Future<Word?> getById(String id) async {
    final rows = await _db.query('words', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Word.fromDbMap(rows.first);
  }

  Future<List<Word>> getByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await _db.rawQuery(
      'SELECT * FROM words WHERE id IN ($placeholders)',
      ids,
    );
    return rows.map(Word.fromDbMap).toList();
  }

  Future<List<Word>> search(String query) async {
    final q = '%$query%';
    final rows = await _db.rawQuery(
      '''SELECT * FROM words
         WHERE expression LIKE ? OR reading LIKE ? OR meaning_ko LIKE ?
         ORDER BY id''',
      [q, q, q],
    );
    return rows.map(Word.fromDbMap).toList();
  }

  /// reading의 첫 음절이 유사한 단어 (오답 선택지용)
  Future<List<Word>> getSimilarReading(
    String reading,
    JlptLevel level,
    int limit,
    List<String> excludeIds,
  ) async {
    final firstChar = reading.isNotEmpty ? reading[0] : '';
    final levelStr = level == JlptLevel.n3 ? 'N3' : 'N2';
    final excludePlaceholders =
        excludeIds.isEmpty ? '' : 'AND id NOT IN (${List.filled(excludeIds.length, '?').join(',')})';
    final rows = await _db.rawQuery(
      '''SELECT * FROM words
         WHERE jlpt_level = ? AND reading LIKE ? $excludePlaceholders
         ORDER BY RANDOM() LIMIT ?''',
      [levelStr, '$firstChar%', ...excludeIds, limit],
    );
    return rows.map(Word.fromDbMap).toList();
  }
}
```

- [ ] **Step 2: progress_repository.dart 작성**

```dart
// lib/domain/repositories/progress_repository.dart
import 'package:sqflite/sqflite.dart';
import '../models/word_progress.dart';
import '../models/enums.dart';

class ProgressRepository {
  final Database _db;

  const ProgressRepository(this._db);

  Future<WordProgress?> get(String wordId) async {
    final rows = await _db.query(
      'word_progress',
      where: 'word_id = ?',
      whereArgs: [wordId],
    );
    if (rows.isEmpty) return null;
    return WordProgress.fromDbMap(rows.first);
  }

  Future<void> upsert(WordProgress progress) async {
    await _db.insert(
      'word_progress',
      progress.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> countCompleted(JlptLevel level) async {
    final levelStr = level == JlptLevel.n3 ? 'N3' : 'N2';
    final result = await _db.rawQuery(
      '''SELECT COUNT(*) as c FROM word_progress wp
         JOIN words w ON wp.word_id = w.id
         WHERE wp.is_completed = 1 AND w.jlpt_level = ?''',
      [levelStr],
    );
    return result.first['c'] as int;
  }

  Future<List<String>> getCompletedWordIds(JlptLevel level) async {
    final levelStr = level == JlptLevel.n3 ? 'N3' : 'N2';
    final rows = await _db.rawQuery(
      '''SELECT wp.word_id FROM word_progress wp
         JOIN words w ON wp.word_id = w.id
         WHERE wp.is_completed = 1 AND w.jlpt_level = ?
         ORDER BY wp.completed_at DESC''',
      [levelStr],
    );
    return rows.map((r) => r['word_id'] as String).toList();
  }

  Future<List<String>> getUncompletedWordIds(JlptLevel level) async {
    final levelStr = level == JlptLevel.n3 ? 'N3' : 'N2';
    final rows = await _db.rawQuery(
      '''SELECT w.id FROM words w
         LEFT JOIN word_progress wp ON w.id = wp.word_id
         WHERE w.jlpt_level = ? AND (wp.is_completed IS NULL OR wp.is_completed = 0)
         ORDER BY w.id''',
      [levelStr],
    );
    return rows.map((r) => r['id'] as String).toList();
  }

  Future<void> markCompleted(String wordId) async {
    final now = DateTime.now().toIso8601String();
    await _db.insert(
      'word_progress',
      {
        'word_id': wordId,
        'is_completed': 1,
        'completed_at': now,
        'review_count': 0,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
```

- [ ] **Step 3: study_set_repository.dart 작성**

```dart
// lib/domain/repositories/study_set_repository.dart
import 'package:sqflite/sqflite.dart';
import '../models/today_study_set.dart';
import '../models/enums.dart';

class StudySetRepository {
  final Database _db;

  const StudySetRepository(this._db);

  Future<TodayStudySet?> getByDate(String date) async {
    final rows = await _db.query(
      'daily_study_sets',
      where: 'study_date = ?',
      whereArgs: [date],
    );
    if (rows.isEmpty) return null;
    final itemRows = await _db.query(
      'daily_study_set_items',
      where: 'study_date = ?',
      whereArgs: [date],
      orderBy: 'display_order ASC',
    );
    final items = itemRows.map(TodayStudyItem.fromDbMap).toList();
    return TodayStudySet.fromDbMap(rows.first, items);
  }

  Future<void> createSet(TodayStudySet set) async {
    await _db.insert('daily_study_sets', set.toDbMap());
    final batch = _db.batch();
    for (final item in set.items) {
      batch.insert('daily_study_set_items', item.toDbMap());
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateSetStatus(String date, StudyStage status, {DateTime? completedAt}) async {
    final now = DateTime.now().toIso8601String();
    await _db.update(
      'daily_study_sets',
      {
        'status': _camelToSnake(status.name),
        'completed_at': completedAt?.toIso8601String(),
        'updated_at': now,
      },
      where: 'study_date = ?',
      whereArgs: [date],
    );
  }

  Future<void> updateItem(TodayStudyItem item) async {
    await _db.update(
      'daily_study_set_items',
      item.toDbMap(),
      where: 'study_date = ? AND word_id = ?',
      whereArgs: [item.studyDate, item.wordId],
    );
  }

  Future<List<String>> getCompletedDates() async {
    final rows = await _db.query(
      'daily_study_sets',
      where: 'completed_at IS NOT NULL',
      orderBy: 'study_date DESC',
    );
    return rows.map((r) => r['study_date'] as String).toList();
  }

  /// 연속 학습일 계산
  Future<int> currentStreak() async {
    final dates = await getCompletedDates();
    if (dates.isEmpty) return 0;
    int streak = 0;
    DateTime check = DateTime.now();
    for (final d in dates) {
      final date = DateTime.parse(d);
      final diff = DateTime(check.year, check.month, check.day)
          .difference(DateTime(date.year, date.month, date.day))
          .inDays;
      if (diff == 0 || diff == 1) {
        streak++;
        check = date;
      } else {
        break;
      }
    }
    return streak;
  }
}

String _camelToSnake(String s) {
  return s.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (m) => '_${m.group(0)!.toLowerCase()}',
  );
}
```

- [ ] **Step 4: review_repository.dart 작성**

```dart
// lib/domain/repositories/review_repository.dart
import 'package:sqflite/sqflite.dart';
import '../models/review_session.dart';
import '../models/enums.dart';

class ReviewRepository {
  final Database _db;

  const ReviewRepository(this._db);

  Future<ReviewSession?> getById(String id) async {
    final rows = await _db.query(
      'review_sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    final itemRows = await _db.query(
      'review_session_items',
      where: 'session_id = ?',
      whereArgs: [id],
      orderBy: 'display_order ASC',
    );
    final items = itemRows.map(ReviewSessionItem.fromDbMap).toList();
    return ReviewSession.fromDbMap(rows.first, items);
  }

  Future<void> createSession(ReviewSession session) async {
    await _db.insert('review_sessions', session.toDbMap());
    final batch = _db.batch();
    for (final item in session.items) {
      batch.insert('review_session_items', item.toDbMap());
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateSessionStatus(
    String id,
    StudyStage status, {
    DateTime? completedAt,
  }) async {
    await _db.update(
      'review_sessions',
      {
        'status': _camelToSnake(status.name),
        'completed_at': completedAt?.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateItem(ReviewSessionItem item) async {
    await _db.update(
      'review_session_items',
      item.toDbMap(),
      where: 'session_id = ? AND word_id = ?',
      whereArgs: [item.sessionId, item.wordId],
    );
  }
}

String _camelToSnake(String s) {
  return s.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (m) => '_${m.group(0)!.toLowerCase()}',
  );
}
```

- [ ] **Step 5: settings_repository.dart 작성**

```dart
// lib/domain/repositories/settings_repository.dart
import 'package:sqflite/sqflite.dart';
import '../models/app_settings.dart';

class SettingsRepository {
  final Database _db;

  const SettingsRepository(this._db);

  Future<String?> _get(String key) async {
    final rows = await _db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  Future<void> _set(String key, String value) async {
    final now = DateTime.now().toIso8601String();
    await _db.insert(
      'app_settings',
      {'key': key, 'value': value, 'updated_at': now},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<AppSettings> load() async {
    final examDateStr = await _get('exam_date');
    final themeModeStr = await _get('theme_mode');
    final seededAtStr = await _get('seeded_at');

    return AppSettings(
      examDate: examDateStr != null
          ? DateTime.parse(examDateStr)
          : AppSettings.defaults.examDate,
      themeMode: AppThemeMode.values.firstWhere(
        (e) => e.name == (themeModeStr ?? 'system'),
        orElse: () => AppThemeMode.system,
      ),
      seededAt: seededAtStr != null ? DateTime.parse(seededAtStr) : null,
    );
  }

  Future<void> saveExamDate(DateTime date) => _set('exam_date', date.toIso8601String());
  Future<void> saveThemeMode(AppThemeMode mode) => _set('theme_mode', mode.name);
  Future<void> markSeeded() => _set('seeded_at', DateTime.now().toIso8601String());
  Future<bool> isSeeded() async => (await _get('seeded_at')) != null;
}
```

- [ ] **Step 6: Commit**

```bash
git add lib/domain/repositories/
git commit -m "feat: add repositories (word, progress, study_set, review, settings)"
```

---

### Task 5: Riverpod Provider 구성

**Files:**
- Create: `lib/application/providers/database_provider.dart`
- Create: `lib/application/providers/word_catalog_provider.dart`
- Create: `lib/application/providers/settings_provider.dart`
- Create: `lib/application/providers/progress_summary_provider.dart`

- [ ] **Step 1: database_provider.dart 작성**

```dart
// lib/application/providers/database_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/db/database.dart';

final databaseProvider = FutureProvider<Database>((ref) async {
  return AppDatabase.instance;
});
```

- [ ] **Step 2: word_catalog_provider.dart 작성**

JSON 로드 → DB 시드 → 메모리 캐시

```dart
// lib/application/providers/word_catalog_provider.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/word.dart';
import '../../domain/models/enums.dart';
import '../../domain/repositories/word_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import 'database_provider.dart';

final wordCatalogProvider =
    AsyncNotifierProvider<WordCatalogNotifier, List<Word>>(
  WordCatalogNotifier.new,
);

class WordCatalogNotifier extends AsyncNotifier<List<Word>> {
  @override
  Future<List<Word>> build() async {
    final db = await ref.watch(databaseProvider.future);
    final wordRepo = WordRepository(db);
    final settingsRepo = SettingsRepository(db);

    final seeded = await settingsRepo.isSeeded();
    if (!seeded) {
      await _seedFromAssets(wordRepo, settingsRepo);
    }
    return wordRepo.getAll();
  }

  Future<void> _seedFromAssets(
    WordRepository wordRepo,
    SettingsRepository settingsRepo,
  ) async {
    final n3Json = await rootBundle.loadString('assets/data/n3_words.json');
    final n2Json = await rootBundle.loadString('assets/data/n2_words.json');

    final n3List = (jsonDecode(n3Json) as List)
        .map((e) => Word.fromAssetJson(e as Map<String, dynamic>, JlptLevel.n3))
        .toList();
    final n2List = (jsonDecode(n2Json) as List)
        .map((e) => Word.fromAssetJson(e as Map<String, dynamic>, JlptLevel.n2))
        .toList();

    await wordRepo.insertAll([...n3List, ...n2List]);
    await settingsRepo.markSeeded();
  }
}
```

- [ ] **Step 3: settings_provider.dart 작성**

```dart
// lib/application/providers/settings_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import 'database_provider.dart';

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final db = await ref.watch(databaseProvider.future);
    return SettingsRepository(db).load();
  }

  Future<void> updateExamDate(DateTime date) async {
    final db = await ref.read(databaseProvider.future);
    await SettingsRepository(db).saveExamDate(date);
    final current = state.valueOrNull ?? AppSettings.defaults;
    state = AsyncData(
      AppSettings(
        examDate: date,
        themeMode: current.themeMode,
        seededAt: current.seededAt,
      ),
    );
  }

  Future<void> updateThemeMode(AppThemeMode mode) async {
    final db = await ref.read(databaseProvider.future);
    await SettingsRepository(db).saveThemeMode(mode);
    final current = state.valueOrNull ?? AppSettings.defaults;
    state = AsyncData(
      AppSettings(
        examDate: current.examDate,
        themeMode: mode,
        seededAt: current.seededAt,
      ),
    );
  }
}
```

- [ ] **Step 4: progress_summary_provider.dart 작성**

```dart
// lib/application/providers/progress_summary_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/enums.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../domain/repositories/word_repository.dart';
import 'database_provider.dart';
import 'settings_provider.dart';

class ProgressSummary {
  final JlptLevel currentLevel;
  final int completedCount;
  final int totalCount;
  final int daysUntilExam;
  final int dailyTarget;
  final bool isReviewOnlyMode;

  const ProgressSummary({
    required this.currentLevel,
    required this.completedCount,
    required this.totalCount,
    required this.daysUntilExam,
    required this.dailyTarget,
    required this.isReviewOnlyMode,
  });
}

final progressSummaryProvider =
    FutureProvider<ProgressSummary>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final settings = await ref.watch(settingsProvider.future);
  final progressRepo = ProgressRepository(db);
  final wordRepo = WordRepository(db);

  // N3 완료 여부로 현재 레벨 결정
  final n3Total = await wordRepo.countByLevel(JlptLevel.n3);
  final n3Completed = await progressRepo.countCompleted(JlptLevel.n3);
  final currentLevel =
      n3Completed >= n3Total ? JlptLevel.n2 : JlptLevel.n3;

  final total = await wordRepo.countByLevel(currentLevel);
  final completed = await progressRepo.countCompleted(currentLevel);
  final remaining = total - completed;

  final now = DateTime.now();
  final days = settings.daysUntilExam(now);
  final isReviewOnly = days <= 0;

  int dailyTarget = 0;
  if (!isReviewOnly && days > 0) {
    dailyTarget = (remaining / days).ceil();
  }

  return ProgressSummary(
    currentLevel: currentLevel,
    completedCount: completed,
    totalCount: total,
    daysUntilExam: days,
    dailyTarget: dailyTarget,
    isReviewOnlyMode: isReviewOnly,
  );
});
```

- [ ] **Step 5: Commit**

```bash
git add lib/application/providers/
git commit -m "feat: add Riverpod providers (database, wordCatalog, settings, progressSummary)"
```

---

### Task 6: 테마 및 라우터 설정

**Files:**
- Create: `lib/core/theme/app_theme.dart`
- Create: `lib/core/router/app_router.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: app_theme.dart 작성**

```dart
// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF1D4ED8);
  static const accent = Color(0xFFF59E0B);
  static const success = Color(0xFF16A34A);
  static const error = Color(0xFFDC2626);

  static const backgroundLight = Color(0xFFF8FAFC);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const textPrimaryLight = Color(0xFF0F172A);
  static const textSecondaryLight = Color(0xFF475569);
  static const borderLight = Color(0xFFE2E8F0);

  static const backgroundDark = Color(0xFF0B1220);
  static const surfaceDark = Color(0xFF111827);
  static const textPrimaryDark = Color(0xFFE5E7EB);
  static const textSecondaryDark = Color(0xFF94A3B8);
  static const borderDark = Color(0xFF1F2937);
}

class AppTheme {
  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.accent,
          error: AppColors.error,
          surface: AppColors.surfaceLight,
        ),
        scaffoldBackgroundColor: AppColors.backgroundLight,
        cardColor: AppColors.surfaceLight,
        dividerColor: AppColors.borderLight,
        textTheme: _textTheme(AppColors.textPrimaryLight, AppColors.textSecondaryLight),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.backgroundLight,
          foregroundColor: AppColors.textPrimaryLight,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surfaceLight,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondaryLight,
          type: BottomNavigationBarType.fixed,
        ),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.accent,
          error: AppColors.error,
          surface: AppColors.surfaceDark,
        ),
        scaffoldBackgroundColor: AppColors.backgroundDark,
        cardColor: AppColors.surfaceDark,
        dividerColor: AppColors.borderDark,
        textTheme: _textTheme(AppColors.textPrimaryDark, AppColors.textSecondaryDark),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.backgroundDark,
          foregroundColor: AppColors.textPrimaryDark,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surfaceDark,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondaryDark,
          type: BottomNavigationBarType.fixed,
        ),
      );

  static TextTheme _textTheme(Color primary, Color secondary) => TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
        titleLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: primary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: secondary,
        ),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: secondary,
        ),
      );
}
```

- [ ] **Step 2: app_router.dart 작성 (shell route + 플레이스홀더 화면)**

```dart
// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// 플레이스홀더 - 이후 화면 구현 시 교체
class _PlaceholderScreen extends StatelessWidget {
  final String name;
  const _PlaceholderScreen(this.name);
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(child: Text(name)),
      );
}

class _ScaffoldWithNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const _ScaffoldWithNavBar({required this.navigationShell});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: navigationShell,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: navigationShell.currentIndex,
          onTap: navigationShell.goBranch,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '홈'),
            BottomNavigationBarItem(icon: Icon(Icons.search_outlined), label: '탐색'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), label: '통계'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: '설정'),
          ],
        ),
      );
}

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) =>
          _ScaffoldWithNavBar(navigationShell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const _PlaceholderScreen('홈'),
            routes: [
              GoRoute(
                path: 'study/flashcard',
                builder: (_, __) => const _PlaceholderScreen('플래시카드'),
              ),
              GoRoute(
                path: 'study/quiz-reading',
                builder: (_, __) => const _PlaceholderScreen('1단계 퀴즈'),
              ),
              GoRoute(
                path: 'study/quiz-meaning',
                builder: (_, __) => const _PlaceholderScreen('2단계 퀴즈'),
              ),
              GoRoute(
                path: 'study/wrong-answers',
                builder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>? ?? {};
                  return _PlaceholderScreen('오답노트 stage=${extra['stage']}');
                },
              ),
              GoRoute(
                path: 'study/complete',
                builder: (_, __) => const _PlaceholderScreen('학습 완료'),
              ),
              GoRoute(
                path: 'review',
                builder: (_, __) => const _PlaceholderScreen('복습 퀴즈'),
              ),
              GoRoute(
                path: 'kana',
                builder: (_, __) => const _PlaceholderScreen('가나표'),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/explore',
            builder: (_, __) => const _PlaceholderScreen('탐색'),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/stats',
            builder: (_, __) => const _PlaceholderScreen('통계'),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/settings',
            builder: (_, __) => const _PlaceholderScreen('설정'),
          ),
        ]),
      ],
    ),
  ],
);
```

- [ ] **Step 3: main.dart 재작성**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'application/providers/settings_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'domain/models/app_settings.dart';

void main() {
  runApp(const ProviderScope(child: JlptApp()));
}

class JlptApp extends ConsumerWidget {
  const JlptApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final themeMode = settingsAsync.valueOrNull?.themeMode ?? AppThemeMode.system;

    return MaterialApp.router(
      title: 'JLPT',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (themeMode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.system => ThemeMode.system,
      },
      routerConfig: appRouter,
    );
  }
}
```

- [ ] **Step 4: flutter analyze 실행하여 에러 확인**

```bash
cd /Users/kangmin/dev/jlpt-study-app && flutter analyze
```

Expected: No issues found (또는 minor warnings만)

- [ ] **Step 5: Commit**

```bash
git add lib/core/ lib/main.dart
git commit -m "feat: add theme, router, update main.dart with ProviderScope"
```

---

### Task 7: 스플래시/로딩 처리 — wordCatalog 초기화

**Files:**
- Create: `lib/features/splash/splash_screen.dart`
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: splash_screen.dart 작성**

앱 시작 시 wordCatalogProvider를 watch하여 로딩 완료 후 홈으로 이동

```dart
// lib/features/splash/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/providers/word_catalog_provider.dart';
import '../../core/theme/app_theme.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(wordCatalogProvider);

    return catalog.when(
      data: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go('/');
        });
        return const _SplashBody(message: '준비 완료');
      },
      loading: () => const _SplashBody(message: '단어 데이터 로딩 중...'),
      error: (e, _) => _SplashBody(message: '로딩 실패: $e'),
    );
  }
}

class _SplashBody extends StatelessWidget {
  final String message;
  const _SplashBody({required this.message});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'JLPT',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(height: 24),
              Text(message, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
}
```

- [ ] **Step 2: app_router.dart의 initialLocation을 `/splash`로 변경하고 route 추가**

```dart
// app_router.dart 상단 import에 추가
import '../../features/splash/splash_screen.dart';

// GoRouter에 추가 (StatefulShellRoute 위에)
GoRoute(
  path: '/splash',
  builder: (_, __) => const SplashScreen(),
),

// initialLocation 변경
initialLocation: '/splash',
```

- [ ] **Step 3: flutter analyze 실행**

```bash
flutter analyze
```

Expected: No issues

- [ ] **Step 4: Commit**

```bash
git add lib/features/splash/ lib/core/router/app_router.dart
git commit -m "feat: add splash screen with word catalog initialization"
```

---

### Task 8: 빌드 검증

- [ ] **Step 1: iOS 시뮬레이터에서 빌드 확인**

```bash
flutter build ios --simulator --no-codesign 2>&1 | tail -5
```

Expected: `Build complete.`

- [ ] **Step 2: 앱 실행하여 스플래시 → 홈 이동 확인**

```bash
flutter run -d "iPhone 16"
```

Expected:
- 스플래시에서 "단어 데이터 로딩 중..." 표시
- DB 시드 완료 후 홈 플레이스홀더 화면 이동
- 바텀 탭 4개 (홈/탐색/통계/설정) 표시

- [ ] **Step 3: Commit**

```bash
git add .
git commit -m "chore: verify foundation layer build success"
```

---

## Self-Review

**Spec coverage:**
- [x] 7개 DB 테이블 스키마 — Task 3 완료
- [x] Word, WordProgress, TodayStudySet, ReviewSession, AppSettings 모델 — Task 2 완료
- [x] JSON 시드 → 메모리 캐시 — Task 5 word_catalog_provider
- [x] 디자인 토큰 (색상, 타이포) — Task 6 app_theme
- [x] go_router Shell + 4탭 구조 — Task 6 app_router
- [x] Riverpod ProviderScope — Task 6 main.dart
- [x] ProgressSummary (D-Day, 진도) 계산 — Task 5 progress_summary_provider
- [x] N3→N2 자동 전환 로직 — progress_summary_provider에 포함

**Placeholder scan:** 없음

**Type consistency:**
- `StudyStage` enum 이름: `flashcard`, `quizReading`, `quizMeaning`, `completed` — DB 저장 시 snake_case 변환 함수로 일관성 유지
- `QuizResult` enum: `correct`, `wrong`, `unknown`, `know`, `dontKnow` — DB `last_result` 값과 동일 변환 로직 사용
- `Word.fromAssetJson` ID 생성: `n3_0001` 형식 — PLAN.md 스키마와 일치
