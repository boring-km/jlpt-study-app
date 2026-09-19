# N2 집중 리디자인 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** N3를 제거하고, 한자→가나 4지선다 퀴즈 단일 루프로 학습 흐름을 단순화하며, 약점 맞춤 오답 생성·오답 사유 로그·단어 추가·백업·시험일 설정을 추가한다.

**Architecture:** Flutter + Riverpod + sqflite 기존 레이어(domain/models → domain/repositories → application/providers → features)를 유지한다. 새 순수 Dart 서비스 2개(`DistractorGenerator`, `StudySetBuilder`)를 `lib/domain/services/`에 두고, 퀴즈 UI는 학습·복습 공용 `QuizScreen` 하나로 통합한다. DB는 v3로 올리고 카탈로그는 `data_version` 기준 upsert로 재시딩한다.

**Tech Stack:** Flutter 3.x (Dart SDK ^3.11), flutter_riverpod 2, go_router 16, sqflite 2, sqflite_common_ffi(테스트), share_plus, file_picker.

**Spec:** `docs/superpowers/specs/2026-09-19-n2-focus-redesign-design.md`

## Global Constraints

- Dart SDK `^3.11.4`. 기존 lint(`flutter_lints ^6`) 통과. 매 태스크 후 `flutter analyze` 에러 0.
- 테스트는 `sqflite_common_ffi` + `AppDatabase.openForTest()` 인메모리 DB 패턴 사용.
- 앱 내 단어 id 형식 `n2_0001`(에셋), `user_<epochMillis>`(사용자 추가).
- `jlpt_level` 컬럼은 남기되 쓰기는 항상 `'N2'`. 읽지 않음.
- 오답 태그 DB 문자열: `long_vowel | sokuon | dakuten | meaning | other`. 표시명: 장음 / 촉음 / 탁음 / 뜻 / 기타.
- 상수: `kKunMinPerDay = 6`, `kWeakPerDay = 5`, `kReviewSessionSize = 20`, `kWeakSlotRatio = 0.7`, `kDataVersion = 2`, 시험 후 일일 목표 `10`.
- 커밋 메시지 끝에 아래 두 줄:
  ```
  Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01MsbZwS3h3oizenuFD1CcRv
  ```
- UI 문구 한국어. 컨페티·스트릭 UI 추가 금지.

---

## 파일 구조

**생성**
- `lib/domain/models/error_tag.dart` — `ErrorTag` enum + DB/표시 변환
- `lib/domain/services/distractor_generator.dart` — 오답 읽기 생성
- `lib/domain/services/study_set_builder.dart` — 오늘 세트 단어 선택
- `lib/domain/repositories/miss_log_repository.dart`
- `lib/application/providers/miss_tag_counts_provider.dart`
- `lib/application/services/backup_service.dart`
- `lib/features/quiz/quiz_screen.dart` — 학습·복습 공용 퀴즈
- `lib/features/quiz/quiz_complete_screen.dart`
- `lib/features/review/review_filter_sheet.dart`
- `lib/features/words/add_word_sheet.dart`
- `tool/merge_audit.py` — 검수 배치 병합·검증 (1회용)

**수정**
- `lib/domain/models/enums.dart` — `JlptLevel` 삭제, `WordType` 추가, `StudyStage` 축소
- `lib/domain/models/word.dart`, `today_study_set.dart`, `review_session.dart`, `app_settings.dart`
- `lib/core/db/database.dart` — v3
- `lib/domain/repositories/*.dart` — 레벨 파라미터 제거, 신규 메서드
- `lib/application/providers/*.dart`
- `lib/core/router/app_router.dart`
- `lib/features/home/home_screen.dart`, `settings/settings_screen.dart`, `explore/*`, `stats/*`
- `pubspec.yaml`

**삭제**
- `lib/domain/models/enums.dart`의 `JlptLevel`, `QuizResult`
- `lib/widgets/word_badge.dart`
- `lib/features/study/**`, `lib/features/review/review_screen.dart`
- `assets/data/n3/`, `assets/data/n3_raw.csv`, `assets/data/n3_words.json`, `assets/data/batch_*.json`, `assets/data/n2_raw.csv`
- 해당 테스트 파일들

---

### Task 1: 도메인 enum·모델 재정의

**Files:**
- Modify: `lib/domain/models/enums.dart`
- Create: `lib/domain/models/error_tag.dart`
- Modify: `lib/domain/models/word.dart`
- Modify: `lib/domain/models/app_settings.dart`
- Test: `test/domain/models/error_tag_test.dart`, `test/domain/models/word_test.dart`, `test/domain/models/app_settings_test.dart`

**Interfaces:**
- Produces:
  - `enum WordType { on, kun, katakana, other }` + `WordType wordTypeFromDb(String)` + `String wordTypeToDb(WordType)`
  - `enum StudyStage { quiz, completed }` + `StudyStage studyStageFromDb(String)` + `String studyStageToDb(StudyStage)`
  - `enum ErrorTag { longVowel, sokuon, dakuten, meaning, other }` + `ErrorTag errorTagFromDb(String)` + `extension ErrorTagX on ErrorTag { String get dbValue; String get label; }`
  - `Word({required String id, required String expression, required String reading, required String meaningKo, WordType type = WordType.other, bool isTrap = false, String source = 'n2', WordExample? example})`, `bool get hasKanji`, `Word.fromAssetJson(Map)`, `Word.fromDbMap(Map)`, `Map toDbMap()`, `Word copyWith(...)`
  - `AppSettings.nextJlptDate(DateTime now) -> DateTime`, `AppSettings.defaults`, `daysUntilExam(now)`

- [ ] **Step 1: 실패 테스트 작성**

`test/domain/models/error_tag_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/domain/models/error_tag.dart';

void main() {
  test('dbValue round-trips', () {
    for (final tag in ErrorTag.values) {
      expect(errorTagFromDb(tag.dbValue), tag);
    }
  });

  test('labels are Korean', () {
    expect(ErrorTag.longVowel.label, '장음');
    expect(ErrorTag.sokuon.label, '촉음');
    expect(ErrorTag.dakuten.label, '탁음');
    expect(ErrorTag.meaning.label, '뜻');
    expect(ErrorTag.other.label, '기타');
  });

  test('unknown db value falls back to other', () {
    expect(errorTagFromDb('garbage'), ErrorTag.other);
  });
}
```

`test/domain/models/word_test.dart` 전체 교체:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:jlpt/domain/models/word.dart';

void main() {
  test('fromAssetJson builds n2 id and reads type/is_trap', () {
    final w = Word.fromAssetJson({
      'id': 7,
      'expression': '工夫',
      'reading': 'くふう',
      'meaning_ko': '궁리, 고안',
      'type': 'on',
      'is_trap': true,
      'example': {'ja': 'a', 'reading': 'b', 'ko': 'c'},
    });
    expect(w.id, 'n2_0007');
    expect(w.type, WordType.on);
    expect(w.isTrap, isTrue);
    expect(w.source, 'n2');
    expect(w.example?.ja, 'a');
  });

  test('fromAssetJson defaults type/is_trap when missing', () {
    final w = Word.fromAssetJson({
      'id': 1,
      'expression': 'やかん',
      'reading': 'やかん',
      'meaning_ko': '주전자',
    });
    expect(w.type, WordType.other);
    expect(w.isTrap, isFalse);
    expect(w.example, isNull);
  });

  test('hasKanji detects CJK ideographs', () {
    expect(const Word(id: 'a', expression: '補う', reading: 'おぎなう', meaningKo: 'x').hasKanji, isTrue);
    expect(const Word(id: 'b', expression: 'コンピューター', reading: 'コンピューター', meaningKo: 'x').hasKanji, isFalse);
    expect(const Word(id: 'c', expression: '～位', reading: 'い', meaningKo: 'x').hasKanji, isTrue);
  });

  test('toDbMap/fromDbMap round-trip', () {
    const w = Word(
      id: 'user_1',
      expression: '把握',
      reading: 'はあく',
      meaningKo: '파악',
      type: WordType.on,
      isTrap: false,
      source: 'user',
    );
    final map = w.toDbMap();
    expect(map['jlpt_level'], 'N2');
    expect(map['type'], 'on');
    expect(map['is_trap'], 0);
    expect(map['source'], 'user');
    final back = Word.fromDbMap({...map, 'is_trap': 0});
    expect(back.id, 'user_1');
    expect(back.type, WordType.on);
    expect(back.source, 'user');
  });
}
```

`test/domain/models/app_settings_test.dart` 전체 교체:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/domain/models/app_settings.dart';

void main() {
  group('nextJlptDate', () {
    test('before July returns first Sunday of July', () {
      expect(AppSettings.nextJlptDate(DateTime(2026, 3, 1)), DateTime(2026, 7, 5));
    });
    test('between July and December returns first Sunday of December', () {
      expect(AppSettings.nextJlptDate(DateTime(2026, 9, 19)), DateTime(2026, 12, 6));
    });
    test('on exam day returns that day', () {
      expect(AppSettings.nextJlptDate(DateTime(2026, 12, 6)), DateTime(2026, 12, 6));
    });
    test('after December exam rolls to next July', () {
      expect(AppSettings.nextJlptDate(DateTime(2026, 12, 7)), DateTime(2027, 7, 4));
    });
  });

  group('daysUntilExam', () {
    final s = AppSettings(examDate: DateTime(2026, 12, 6), themeMode: AppThemeMode.light);
    test('positive before', () => expect(s.daysUntilExam(DateTime(2026, 9, 19)), 78));
    test('zero on day', () => expect(s.daysUntilExam(DateTime(2026, 12, 6)), 0));
    test('negative after', () => expect(s.daysUntilExam(DateTime(2026, 12, 7)), -1));
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/domain/models/`
Expected: 컴파일 에러 (`error_tag.dart` 없음, `Word` 시그니처 불일치).

- [ ] **Step 3: 구현**

`lib/domain/models/enums.dart` 전체 교체:
```dart
enum WordType { on, kun, katakana, other }

WordType wordTypeFromDb(String value) {
  switch (value) {
    case 'on':
      return WordType.on;
    case 'kun':
      return WordType.kun;
    case 'katakana':
      return WordType.katakana;
    default:
      return WordType.other;
  }
}

String wordTypeToDb(WordType type) => type.name;

enum StudyStage { quiz, completed }

/// 구버전 값(flashcard, quiz_reading, quiz_meaning)은 전부 quiz로 매핑.
StudyStage studyStageFromDb(String value) =>
    value == 'completed' ? StudyStage.completed : StudyStage.quiz;

String studyStageToDb(StudyStage stage) => stage.name;
```

`lib/domain/models/error_tag.dart`:
```dart
enum ErrorTag { longVowel, sokuon, dakuten, meaning, other }

extension ErrorTagX on ErrorTag {
  String get dbValue => switch (this) {
        ErrorTag.longVowel => 'long_vowel',
        ErrorTag.sokuon => 'sokuon',
        ErrorTag.dakuten => 'dakuten',
        ErrorTag.meaning => 'meaning',
        ErrorTag.other => 'other',
      };

  String get label => switch (this) {
        ErrorTag.longVowel => '장음',
        ErrorTag.sokuon => '촉음',
        ErrorTag.dakuten => '탁음',
        ErrorTag.meaning => '뜻',
        ErrorTag.other => '기타',
      };
}

ErrorTag errorTagFromDb(String value) {
  for (final tag in ErrorTag.values) {
    if (tag.dbValue == value) return tag;
  }
  return ErrorTag.other;
}
```

`lib/domain/models/word.dart` 전체 교체:
```dart
import 'package:jlpt/domain/models/enums.dart';

final _kanjiRegex = RegExp(r'[一-鿿々]');

class WordExample {
  final String ja;
  final String reading;
  final String ko;

  const WordExample({required this.ja, required this.reading, required this.ko});

  factory WordExample.fromJson(Map<String, dynamic> json) => WordExample(
        ja: json['ja'] as String,
        reading: json['reading'] as String,
        ko: json['ko'] as String,
      );

  Map<String, dynamic> toJson() => {'ja': ja, 'reading': reading, 'ko': ko};
}

class Word {
  final String id;
  final String expression;
  final String reading;
  final String meaningKo;
  final WordType type;
  final bool isTrap;
  final String source; // 'n2' | 'user'
  final WordExample? example;

  const Word({
    required this.id,
    required this.expression,
    required this.reading,
    required this.meaningKo,
    this.type = WordType.other,
    this.isTrap = false,
    this.source = 'n2',
    this.example,
  });

  bool get hasKanji => _kanjiRegex.hasMatch(expression);

  factory Word.fromAssetJson(Map<String, dynamic> json) {
    final rawId = json['id'] as int;
    final exampleJson = json['example'];
    return Word(
      id: 'n2_${rawId.toString().padLeft(4, '0')}',
      expression: (json['expression'] as String?) ?? (json['reading'] as String),
      reading: json['reading'] as String,
      meaningKo: json['meaning_ko'] as String,
      type: wordTypeFromDb((json['type'] as String?) ?? 'other'),
      isTrap: (json['is_trap'] as bool?) ?? false,
      source: 'n2',
      example: exampleJson != null
          ? WordExample.fromJson(exampleJson as Map<String, dynamic>)
          : null,
    );
  }

  factory Word.fromDbMap(Map<String, dynamic> map) {
    final exampleJa = map['example_ja'] as String?;
    final exampleReading = map['example_reading'] as String?;
    final exampleKo = map['example_ko'] as String?;
    final reading = map['reading'] as String;
    return Word(
      id: map['id'] as String,
      expression: (map['expression'] as String?) ?? reading,
      reading: reading,
      meaningKo: map['meaning_ko'] as String,
      type: wordTypeFromDb((map['type'] as String?) ?? 'other'),
      isTrap: ((map['is_trap'] as int?) ?? 0) == 1,
      source: (map['source'] as String?) ?? 'n2',
      example: exampleJa != null && exampleReading != null && exampleKo != null
          ? WordExample(ja: exampleJa, reading: exampleReading, ko: exampleKo)
          : null,
    );
  }

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'jlpt_level': 'N2',
        'expression': expression,
        'reading': reading,
        'meaning_ko': meaningKo,
        'type': wordTypeToDb(type),
        'is_trap': isTrap ? 1 : 0,
        'source': source,
        'example_ja': example?.ja,
        'example_reading': example?.reading,
        'example_ko': example?.ko,
        'created_at': DateTime.now().toIso8601String(),
      };

  Word copyWith({
    String? expression,
    String? reading,
    String? meaningKo,
    WordType? type,
    bool? isTrap,
    String? source,
    WordExample? example,
  }) =>
      Word(
        id: id,
        expression: expression ?? this.expression,
        reading: reading ?? this.reading,
        meaningKo: meaningKo ?? this.meaningKo,
        type: type ?? this.type,
        isTrap: isTrap ?? this.isTrap,
        source: source ?? this.source,
        example: example ?? this.example,
      );
}
```

`lib/domain/models/app_settings.dart` 전체 교체:
```dart
enum AppThemeMode { light, dark }

class AppSettings {
  final DateTime examDate;
  final AppThemeMode themeMode;

  const AppSettings({required this.examDate, required this.themeMode});

  static AppSettings get defaults => AppSettings(
        examDate: nextJlptDate(DateTime.now()),
        themeMode: AppThemeMode.light,
      );

  /// JLPT는 7월·12월 첫째 일요일. 오늘 이후(당일 포함) 가장 가까운 시험일.
  static DateTime nextJlptDate(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    for (var year = today.year; year <= today.year + 1; year++) {
      for (final month in [7, 12]) {
        final candidate = _firstSunday(year, month);
        if (!candidate.isBefore(today)) return candidate;
      }
    }
    return _firstSunday(today.year + 1, 7);
  }

  static DateTime _firstSunday(int year, int month) {
    final first = DateTime(year, month, 1);
    final offset = (DateTime.sunday - first.weekday) % 7;
    return DateTime(year, month, 1 + offset);
  }

  int daysUntilExam(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final exam = DateTime(examDate.year, examDate.month, examDate.day);
    return exam.difference(today).inDays;
  }

  AppSettings copyWith({DateTime? examDate, AppThemeMode? themeMode}) =>
      AppSettings(
        examDate: examDate ?? this.examDate,
        themeMode: themeMode ?? this.themeMode,
      );
}
```

- [ ] **Step 4: 모델 테스트 통과 확인**

Run: `flutter test test/domain/models/error_tag_test.dart test/domain/models/word_test.dart test/domain/models/app_settings_test.dart`
Expected: PASS (다른 파일들은 아직 컴파일 실패해도 무방. 이 세 파일만 지정 실행).

- [ ] **Step 5: 커밋 (WIP)**

```bash
git add lib/domain/models test/domain/models
git commit -m "refactor(models): drop JlptLevel, add WordType/ErrorTag, compute next JLPT date"
```
(빌드 깨진 상태 커밋 허용. Task 4에서 복구.)

---

### Task 2: DB 스키마 v3 + 마이그레이션

**Files:**
- Modify: `lib/core/db/database.dart`
- Test: `test/core/db/database_test.dart`

**Interfaces:**
- Produces: `AppDatabase.instance`, `AppDatabase.openForTest({String? name})`, `AppDatabase.close()`, `AppDatabase.openAtPath(String path, {int? version})` (테스트용 v2 생성에 사용), `AppDatabase.kVersion = 3`, `AppDatabase.kDataVersion = 2`
- `words` 컬럼 `type`, `is_trap`, `source`; 테이블 `miss_log(id, word_id, tag, created_at)`

- [ ] **Step 1: 실패 테스트 추가**

`test/core/db/database_test.dart` 기존 `creates all 7 tables` 테스트의 리스트에 `'miss_log'` 추가하고 이름을 `creates all 8 tables`로 변경. `words table has required columns` 리스트에 `'type', 'is_trap', 'source'` 추가. 아래 테스트 추가:

```dart
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
      await db.insert('word_progress', {'word_id': 'n3_0001', 'is_completed': 1, 'updated_at': 't'});
      await db.insert('word_progress', {'word_id': 'n2_0001', 'is_completed': 1, 'updated_at': 't'});
      await db.insert('daily_study_sets', {'study_date': '2026-01-01', 'jlpt_level': 'N3', 'target_count': 1, 'status': 'flashcard', 'created_at': 't', 'updated_at': 't'});
      await db.insert('daily_study_set_items', {'study_date': '2026-01-01', 'word_id': 'n3_0001', 'display_order': 0, 'updated_at': 't'});
      await db.insert('app_settings', {'key': 'seeded_at', 'value': 't', 'updated_at': 't'});
    });
    await v2.close();

    final v3 = await AppDatabase.openAtPath(path);
    expect((await v3.query('words')).map((r) => r['id']), ['n2_0001']);
    expect((await v3.query('word_progress')).length, 1);
    expect((await v3.query('daily_study_sets')).length, 0);
    expect((await v3.query('daily_study_set_items')).length, 0);
    final cols = (await v3.rawQuery('PRAGMA table_info(words)')).map((r) => r['name']).toList();
    expect(cols, containsAll(['type', 'is_trap', 'source']));
    final tables = (await v3.rawQuery("SELECT name FROM sqlite_master WHERE type='table'")).map((r) => r['name']).toList();
    expect(tables, contains('miss_log'));
    expect(await v3.query('app_settings', where: "key = 'data_version'"), isEmpty);
    await v3.close();
    await dir.delete(recursive: true);
  });
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/core/db/database_test.dart`
Expected: FAIL — `openAtPath` 없음.

- [ ] **Step 3: 구현**

`lib/core/db/database.dart` 전체 교체:
```dart
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
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/core/db/database_test.dart`
Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
git add lib/core/db/database.dart test/core/db/database_test.dart
git commit -m "feat(db): schema v3 with word type/trap/source, miss_log, N3 purge migration"
```

---

### Task 3: 리포지토리 재작성

**Files:**
- Modify: `lib/domain/repositories/word_repository.dart`
- Modify: `lib/domain/repositories/progress_repository.dart`
- Modify: `lib/domain/repositories/settings_repository.dart`
- Modify: `lib/domain/repositories/study_set_repository.dart`, `review_repository.dart` (enum 변환 함수만 교체)
- Create: `lib/domain/repositories/miss_log_repository.dart`
- Modify: `lib/domain/models/today_study_set.dart`, `lib/domain/models/review_session.dart`
- Test: `test/domain/repositories/word_repository_test.dart`, `progress_repository_test.dart`, `miss_log_repository_test.dart`, `settings_repository_test.dart`, `test/domain/models/today_study_set_test.dart`

**Interfaces:**
- Produces:
  - `WordRepository`: `insertAll(List<Word>)`, `upsertAll(List<Word>)`, `deleteN2NotIn(Set<String> keepIds)`, `insertUserWord(Word)`, `count()`, `getAll()`, `getById(String)`, `getByIds(List<String>)`, `search(String)`, `findByExpression(String) -> Word?`, `getReadingsByExpression(String) -> List<String>`, `getRandomReadingsStartingWith(String firstChar, {required int limit, required Set<String> exclude}) -> List<String>`, `getRandomMeanings({required int limit, required String excludeWordId}) -> List<String>`
  - `ProgressRepository`: `get`, `upsert`, `countCompleted()`, `getCompletedWordIds()`, `getUncompletedWordIds({WordType? type, String? source})`, `markCompleted`, `incrementMiss`, `decrementMiss`, `getWeakWordIds({int? limit})`, `countWeak()`, `resetAllProgress()`
  - `MissLogRepository(db)`: `add(String wordId, ErrorTag tag)`, `recentWordIdsByTag(ErrorTag tag, {int limit = 20}) -> List<String>`, `countByTag() -> Map<ErrorTag, int>`, `tagsForWord(String wordId) -> List<ErrorTag>`, `clear()`
  - `SettingsRepository`: `load()`, `saveExamDate`, `saveThemeMode`, `dataVersion() -> int`, `setDataVersion(int)`
  - `TodayStudyItem(studyDate, wordId, displayOrder, passed, attempts, updatedAt)`, `TodayStudySet(studyDate, targetCount, status, items, startedAt, completedAt, createdAt, updatedAt)`, `completedCount`, `copyWith`
  - `ReviewSessionItem(sessionId, wordId, displayOrder, passed, attempts)`, `ReviewSession(id, reviewDate, itemCount, status, items, startedAt, completedAt)`

- [ ] **Step 1: 모델 축소**

`lib/domain/models/today_study_set.dart` 전체 교체:
```dart
import 'package:jlpt/domain/models/enums.dart';

class TodayStudyItem {
  final String studyDate;
  final String wordId;
  final int displayOrder;
  final bool passed;
  final int attempts;
  final DateTime updatedAt;

  const TodayStudyItem({
    required this.studyDate,
    required this.wordId,
    required this.displayOrder,
    required this.passed,
    required this.attempts,
    required this.updatedAt,
  });

  factory TodayStudyItem.fromDbMap(Map<String, dynamic> map) => TodayStudyItem(
        studyDate: map['study_date'] as String,
        wordId: map['word_id'] as String,
        displayOrder: map['display_order'] as int,
        passed: (map['reading_passed'] as int) == 1,
        attempts: map['reading_attempts'] as int,
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toDbMap() => {
        'study_date': studyDate,
        'word_id': wordId,
        'display_order': displayOrder,
        'reading_passed': passed ? 1 : 0,
        'meaning_passed': passed ? 1 : 0,
        'reading_attempts': attempts,
        'meaning_attempts': 0,
        'last_result': null,
        'updated_at': updatedAt.toIso8601String(),
      };

  TodayStudyItem copyWith({bool? passed, int? attempts, DateTime? updatedAt}) =>
      TodayStudyItem(
        studyDate: studyDate,
        wordId: wordId,
        displayOrder: displayOrder,
        passed: passed ?? this.passed,
        attempts: attempts ?? this.attempts,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class TodayStudySet {
  final String studyDate;
  final int targetCount;
  final StudyStage status;
  final List<TodayStudyItem> items;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TodayStudySet({
    required this.studyDate,
    required this.targetCount,
    required this.status,
    required this.items,
    this.startedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  int get completedCount => items.where((i) => i.passed).length;

  factory TodayStudySet.fromDbMap(
    Map<String, dynamic> map,
    List<TodayStudyItem> items,
  ) {
    final startedAtStr = map['started_at'] as String?;
    final completedAtStr = map['completed_at'] as String?;
    return TodayStudySet(
      studyDate: map['study_date'] as String,
      targetCount: map['target_count'] as int,
      status: studyStageFromDb(map['status'] as String),
      items: items,
      startedAt: startedAtStr != null ? DateTime.parse(startedAtStr) : null,
      completedAt: completedAtStr != null ? DateTime.parse(completedAtStr) : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toDbMap() => {
        'study_date': studyDate,
        'jlpt_level': 'N2',
        'target_count': targetCount,
        'status': studyStageToDb(status),
        'started_at': startedAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  TodayStudySet copyWith({
    int? targetCount,
    StudyStage? status,
    List<TodayStudyItem>? items,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? updatedAt,
  }) =>
      TodayStudySet(
        studyDate: studyDate,
        targetCount: targetCount ?? this.targetCount,
        status: status ?? this.status,
        items: items ?? this.items,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt ?? this.completedAt,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
```

`lib/domain/models/review_session.dart` 전체 교체:
```dart
import 'package:jlpt/domain/models/enums.dart';

class ReviewSessionItem {
  final String sessionId;
  final String wordId;
  final int displayOrder;
  final bool passed;
  final int attempts;

  const ReviewSessionItem({
    required this.sessionId,
    required this.wordId,
    required this.displayOrder,
    required this.passed,
    required this.attempts,
  });

  factory ReviewSessionItem.fromDbMap(Map<String, dynamic> map) => ReviewSessionItem(
        sessionId: map['session_id'] as String,
        wordId: map['word_id'] as String,
        displayOrder: map['display_order'] as int,
        passed: (map['reading_passed'] as int) == 1,
        attempts: map['reading_attempts'] as int,
      );

  Map<String, dynamic> toDbMap() => {
        'session_id': sessionId,
        'word_id': wordId,
        'display_order': displayOrder,
        'reading_passed': passed ? 1 : 0,
        'meaning_passed': passed ? 1 : 0,
        'reading_attempts': attempts,
        'meaning_attempts': 0,
      };

  ReviewSessionItem copyWith({bool? passed, int? attempts}) => ReviewSessionItem(
        sessionId: sessionId,
        wordId: wordId,
        displayOrder: displayOrder,
        passed: passed ?? this.passed,
        attempts: attempts ?? this.attempts,
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
  ) {
    final completedAtStr = map['completed_at'] as String?;
    return ReviewSession(
      id: map['id'] as String,
      reviewDate: map['review_date'] as String,
      itemCount: map['item_count'] as int,
      status: studyStageFromDb(map['status'] as String),
      items: items,
      startedAt: DateTime.parse(map['started_at'] as String),
      completedAt: completedAtStr != null ? DateTime.parse(completedAtStr) : null,
    );
  }

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'review_date': reviewDate,
        'item_count': itemCount,
        'status': studyStageToDb(status),
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
```

`study_set_repository.dart`, `review_repository.dart`: 파일 하단 `_studyStageToSnake` 함수 삭제, 호출부를 `studyStageToDb(status)`로 교체. `study_set_repository.dart`에 추가:
```dart
  Future<void> appendItems(String date, List<TodayStudyItem> items) async {
    final batch = _db.batch();
    for (final item in items) {
      batch.insert('daily_study_set_items', item.toDbMap());
    }
    await batch.commit(noResult: true);
    await _db.update(
      'daily_study_sets',
      {
        'status': studyStageToDb(StudyStage.quiz),
        'completed_at': null,
        'target_count': (await getByDate(date))!.items.length + items.length,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'study_date = ?',
      whereArgs: [date],
    );
  }

  Future<void> deleteAll() async {
    await _db.delete('daily_study_set_items');
    await _db.delete('daily_study_sets');
  }
```
(`appendItems` 안 `getByDate` 호출은 insert 전에 먼저 해서 `existingCount`로 받아둔 뒤 `existingCount + items.length`로 계산할 것. 위 코드처럼 insert 후 호출하면 중복 계산된다.)

`review_repository.dart`에 추가:
```dart
  Future<void> deleteAll() async {
    await _db.delete('review_session_items');
    await _db.delete('review_sessions');
  }
```
`currentStreak`/`getCompletedDates`는 삭제.

- [ ] **Step 2: 실패 테스트 작성**

`test/domain/repositories/miss_log_repository_test.dart`:
```dart
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
```

`test/domain/repositories/word_repository_test.dart` 전체 교체:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jlpt/core/db/database.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:jlpt/domain/models/word.dart';
import 'package:jlpt/domain/models/word_progress.dart';
import 'package:jlpt/domain/repositories/progress_repository.dart';
import 'package:jlpt/domain/repositories/word_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const words = [
    Word(id: 'n2_0001', expression: '紅葉', reading: 'こうよう', meaningKo: '단풍', type: WordType.on),
    Word(id: 'n2_0002', expression: '紅葉', reading: 'もみじ', meaningKo: '단풍', type: WordType.kun),
    Word(id: 'n2_0003', expression: '工夫', reading: 'くふう', meaningKo: '궁리', type: WordType.on, isTrap: true),
    Word(id: 'n2_0004', expression: 'こうこく', reading: 'こうこく', meaningKo: '광고'),
  ];

  test('upsertAll updates text fields and keeps progress', () async {
    final db = await AppDatabase.openForTest();
    final repo = WordRepository(db);
    await repo.insertAll(words);
    await ProgressRepository(db).markCompleted('n2_0003');
    await repo.upsertAll([words[2].copyWith(meaningKo: '궁리, 고안')]);
    expect((await repo.getById('n2_0003'))!.meaningKo, '궁리, 고안');
    expect((await ProgressRepository(db).get('n2_0003'))!.isCompleted, isTrue);
    expect(await repo.count(), 4);
    await db.close();
  });

  test('deleteN2NotIn removes stale n2 words and their progress, keeps user words', () async {
    final db = await AppDatabase.openForTest();
    final repo = WordRepository(db);
    await repo.insertAll(words);
    await repo.insertUserWord(const Word(id: 'user_1', expression: '把握', reading: 'はあく', meaningKo: '파악', source: 'user'));
    await ProgressRepository(db).markCompleted('n2_0004');
    await repo.deleteN2NotIn({'n2_0001', 'n2_0002', 'n2_0003'});
    expect(await repo.getById('n2_0004'), isNull);
    expect(await ProgressRepository(db).get('n2_0004'), isNull);
    expect(await repo.getById('user_1'), isNotNull);
    await db.close();
  });

  test('findByExpression / getReadingsByExpression', () async {
    final db = await AppDatabase.openForTest();
    final repo = WordRepository(db);
    await repo.insertAll(words);
    expect((await repo.findByExpression('工夫'))!.id, 'n2_0003');
    expect(await repo.findByExpression('없음'), isNull);
    expect(await repo.getReadingsByExpression('紅葉'), containsAll(['こうよう', 'もみじ']));
    await db.close();
  });

  test('getRandomReadingsStartingWith excludes given readings', () async {
    final db = await AppDatabase.openForTest();
    final repo = WordRepository(db);
    await repo.insertAll(words);
    final r = await repo.getRandomReadingsStartingWith('こ', limit: 5, exclude: {'こうよう'});
    expect(r, ['こうこく']);
    await db.close();
  });

  test('getRandomMeanings excludes the word itself', () async {
    final db = await AppDatabase.openForTest();
    final repo = WordRepository(db);
    await repo.insertAll(words);
    final m = await repo.getRandomMeanings(limit: 10, excludeWordId: 'n2_0003');
    expect(m, isNot(contains('궁리')));
    expect(m.toSet().length, m.length);
    await db.close();
  });
}
```

`test/domain/repositories/progress_repository_test.dart` — 기존 파일에서 `JlptLevel` 인자 전부 제거하고 아래 테스트 추가:
```dart
  test('getUncompletedWordIds filters by type and source', () async {
    final db = await AppDatabase.openForTest();
    await WordRepository(db).insertAll(const [
      Word(id: 'n2_0001', expression: '補う', reading: 'おぎなう', meaningKo: 'x', type: WordType.kun),
      Word(id: 'n2_0002', expression: '生産', reading: 'せいさん', meaningKo: 'y', type: WordType.on),
      Word(id: 'user_1', expression: '把握', reading: 'はあく', meaningKo: 'z', source: 'user'),
    ]);
    final repo = ProgressRepository(db);
    await repo.markCompleted('n2_0002');
    expect(await repo.getUncompletedWordIds(), containsAll(['n2_0001', 'user_1']));
    expect(await repo.getUncompletedWordIds(type: WordType.kun), ['n2_0001']);
    expect(await repo.getUncompletedWordIds(source: 'user'), ['user_1']);
    await db.close();
  });

  test('resetAllProgress clears progress, sets, sessions, miss_log', () async {
    final db = await AppDatabase.openForTest();
    await WordRepository(db).insertAll(const [
      Word(id: 'n2_0001', expression: 'a', reading: 'あ', meaningKo: 'x'),
    ]);
    final repo = ProgressRepository(db);
    await repo.markCompleted('n2_0001');
    await db.insert('miss_log', {'word_id': 'n2_0001', 'tag': 'other', 'created_at': 't'});
    await repo.resetAllProgress();
    expect(await repo.countCompleted(), 0);
    expect(await db.query('miss_log'), isEmpty);
    expect(await WordRepository(db).count(), 1);
    await db.close();
  });
```

`test/domain/repositories/settings_repository_test.dart` — `examDate` 기본값 검증을 `AppSettings.nextJlptDate(DateTime.now())`와 비교하도록 변경하고 추가:
```dart
  test('dataVersion defaults to 0 and persists', () async {
    final db = await AppDatabase.openForTest();
    final repo = SettingsRepository(db);
    expect(await repo.dataVersion(), 0);
    await repo.setDataVersion(2);
    expect(await repo.dataVersion(), 2);
    await db.close();
  });
```

`test/domain/models/today_study_set_test.dart`, `review_session` 관련 테스트: 새 생성자(`passed`, `attempts`)로 갱신. `fromDbMap`에 `'status': 'quiz_reading'`을 주면 `StudyStage.quiz`가 되는 케이스 하나 추가.

- [ ] **Step 3: 실패 확인**

Run: `flutter test test/domain/repositories test/domain/models`
Expected: 컴파일 실패.

- [ ] **Step 4: 리포지토리 구현**

`lib/domain/repositories/word_repository.dart` 전체 교체:
```dart
import 'package:sqflite/sqflite.dart';
import '../models/word.dart';

class WordRepository {
  final Database _db;
  const WordRepository(this._db);

  Future<void> insertAll(List<Word> words) async {
    final batch = _db.batch();
    for (final word in words) {
      batch.insert('words', word.toDbMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  /// id 충돌 시 텍스트·분류 필드만 갱신. created_at·진도 보존.
  Future<void> upsertAll(List<Word> words) async {
    final batch = _db.batch();
    for (final w in words) {
      final m = w.toDbMap();
      batch.rawInsert(
        '''
        INSERT INTO words (id, jlpt_level, expression, reading, meaning_ko, type, is_trap, source,
                           example_ja, example_reading, example_ko, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          expression = excluded.expression,
          reading = excluded.reading,
          meaning_ko = excluded.meaning_ko,
          type = excluded.type,
          is_trap = excluded.is_trap,
          example_ja = excluded.example_ja,
          example_reading = excluded.example_reading,
          example_ko = excluded.example_ko
        ''',
        [
          m['id'], m['jlpt_level'], m['expression'], m['reading'], m['meaning_ko'],
          m['type'], m['is_trap'], m['source'],
          m['example_ja'], m['example_reading'], m['example_ko'], m['created_at'],
        ],
      );
    }
    await batch.commit(noResult: true);
  }

  /// 에셋에서 사라진 n2 단어와 그 진도·로그 삭제. 사용자 단어는 건드리지 않음.
  Future<void> deleteN2NotIn(Set<String> keepIds) async {
    final rows = await _db.query('words', columns: ['id'], where: "source = 'n2'");
    final stale = rows.map((r) => r['id'] as String).where((id) => !keepIds.contains(id)).toList();
    if (stale.isEmpty) return;
    final batch = _db.batch();
    for (final id in stale) {
      batch.delete('miss_log', where: 'word_id = ?', whereArgs: [id]);
      batch.delete('review_session_items', where: 'word_id = ?', whereArgs: [id]);
      batch.delete('daily_study_set_items', where: 'word_id = ?', whereArgs: [id]);
      batch.delete('word_progress', where: 'word_id = ?', whereArgs: [id]);
      batch.delete('words', where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  Future<void> insertUserWord(Word word) async {
    await _db.insert('words', word.toDbMap(), conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<int> count() async {
    final result = await _db.rawQuery('SELECT COUNT(*) as c FROM words');
    return result.first['c'] as int;
  }

  Future<List<Word>> getAll() async {
    final rows = await _db.query('words', orderBy: 'id');
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
    final rows = await _db.rawQuery('SELECT * FROM words WHERE id IN ($placeholders)', ids);
    return rows.map(Word.fromDbMap).toList();
  }

  Future<List<Word>> search(String query) async {
    final q = '%$query%';
    final rows = await _db.rawQuery(
      'SELECT * FROM words WHERE expression LIKE ? OR reading LIKE ? OR meaning_ko LIKE ? ORDER BY id',
      [q, q, q],
    );
    return rows.map(Word.fromDbMap).toList();
  }

  Future<Word?> findByExpression(String expression) async {
    final rows = await _db.query('words', where: 'expression = ?', whereArgs: [expression], limit: 1);
    if (rows.isEmpty) return null;
    return Word.fromDbMap(rows.first);
  }

  Future<List<String>> getReadingsByExpression(String expression) async {
    final rows = await _db.query('words', columns: ['reading'], where: 'expression = ?', whereArgs: [expression]);
    return rows.map((r) => r['reading'] as String).toList();
  }

  Future<List<String>> getRandomReadingsStartingWith(
    String firstChar, {
    required int limit,
    required Set<String> exclude,
  }) async {
    final rows = await _db.rawQuery(
      'SELECT DISTINCT reading FROM words WHERE reading LIKE ? ORDER BY RANDOM() LIMIT ?',
      ['$firstChar%', limit + exclude.length],
    );
    return rows
        .map((r) => r['reading'] as String)
        .where((r) => !exclude.contains(r))
        .take(limit)
        .toList();
  }

  Future<List<String>> getRandomMeanings({
    required int limit,
    required String excludeWordId,
  }) async {
    final rows = await _db.rawQuery(
      'SELECT DISTINCT meaning_ko FROM words WHERE id != ? ORDER BY RANDOM() LIMIT ?',
      [excludeWordId, limit],
    );
    return rows.map((r) => r['meaning_ko'] as String).toList();
  }
}
```

`lib/domain/repositories/progress_repository.dart` 전체 교체:
```dart
import 'package:sqflite/sqflite.dart';
import '../models/enums.dart';
import '../models/word_progress.dart';

class ProgressRepository {
  final Database _db;
  const ProgressRepository(this._db);

  Future<WordProgress?> get(String wordId) async {
    final rows = await _db.query('word_progress', where: 'word_id = ?', whereArgs: [wordId]);
    if (rows.isEmpty) return null;
    return WordProgress.fromDbMap(rows.first);
  }

  Future<void> upsert(WordProgress progress) async {
    await _db.insert('word_progress', progress.toDbMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> countCompleted() async {
    final result = await _db.rawQuery('SELECT COUNT(*) as c FROM word_progress WHERE is_completed = 1');
    return result.first['c'] as int;
  }

  Future<List<String>> getCompletedWordIds() async {
    final rows = await _db.rawQuery(
      'SELECT word_id FROM word_progress WHERE is_completed = 1 ORDER BY completed_at DESC',
    );
    return rows.map((r) => r['word_id'] as String).toList();
  }

  Future<List<String>> getUncompletedWordIds({WordType? type, String? source}) async {
    final where = <String>['(wp.is_completed IS NULL OR wp.is_completed = 0)'];
    final args = <Object>[];
    if (type != null) {
      where.add('w.type = ?');
      args.add(wordTypeToDb(type));
    }
    if (source != null) {
      where.add('w.source = ?');
      args.add(source);
    }
    final rows = await _db.rawQuery(
      'SELECT w.id FROM words w LEFT JOIN word_progress wp ON w.id = wp.word_id WHERE ${where.join(' AND ')} ORDER BY w.id',
      args,
    );
    return rows.map((r) => r['id'] as String).toList();
  }

  Future<void> markCompleted(String wordId) async {
    final now = DateTime.now().toIso8601String();
    await _db.rawInsert(
      '''
      INSERT INTO word_progress (word_id, is_completed, completed_at, review_count, miss_count, updated_at)
      VALUES (?, 1, ?, 0, 0, ?)
      ON CONFLICT(word_id) DO UPDATE SET
        is_completed = 1,
        completed_at = COALESCE(word_progress.completed_at, excluded.completed_at),
        updated_at = excluded.updated_at
      ''',
      [wordId, now, now],
    );
  }

  Future<void> incrementMiss(String wordId) async {
    final now = DateTime.now().toIso8601String();
    await _db.rawInsert(
      '''
      INSERT INTO word_progress (word_id, is_completed, review_count, miss_count, updated_at)
      VALUES (?, 0, 0, 1, ?)
      ON CONFLICT(word_id) DO UPDATE SET
        miss_count = word_progress.miss_count + 1,
        updated_at = excluded.updated_at
      ''',
      [wordId, now],
    );
  }

  Future<void> decrementMiss(String wordId) async {
    final now = DateTime.now().toIso8601String();
    await _db.rawUpdate(
      'UPDATE word_progress SET miss_count = MAX(0, miss_count - 1), updated_at = ? WHERE word_id = ?',
      [now, wordId],
    );
  }

  Future<List<String>> getWeakWordIds({int? limit}) async {
    final limitClause = limit != null ? 'LIMIT $limit' : '';
    final rows = await _db.rawQuery(
      '''
      SELECT word_id FROM word_progress
      WHERE is_completed = 1 AND miss_count > 0
      ORDER BY miss_count DESC, updated_at DESC
      $limitClause
      ''',
    );
    return rows.map((r) => r['word_id'] as String).toList();
  }

  Future<int> countWeak() async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as c FROM word_progress WHERE is_completed = 1 AND miss_count > 0',
    );
    return result.first['c'] as int;
  }

  /// 진도·세트·세션·오답 로그 전부 삭제. 단어는 유지.
  Future<void> resetAllProgress() async {
    final batch = _db.batch();
    batch.delete('miss_log');
    batch.delete('review_session_items');
    batch.delete('review_sessions');
    batch.delete('daily_study_set_items');
    batch.delete('daily_study_sets');
    batch.delete('word_progress');
    await batch.commit(noResult: true);
  }
}
```

`lib/domain/repositories/miss_log_repository.dart`:
```dart
import 'package:sqflite/sqflite.dart';
import '../models/error_tag.dart';

class MissLogRepository {
  final Database _db;
  const MissLogRepository(this._db);

  Future<void> add(String wordId, ErrorTag tag) async {
    await _db.insert('miss_log', {
      'word_id': wordId,
      'tag': tag.dbValue,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// 태그별 최근 오답 단어. 단어당 한 번, 최근 순.
  Future<List<String>> recentWordIdsByTag(ErrorTag tag, {int limit = 20}) async {
    final rows = await _db.rawQuery(
      '''
      SELECT word_id, MAX(created_at) AS last_at FROM miss_log
      WHERE tag = ?
      GROUP BY word_id
      ORDER BY last_at DESC
      LIMIT ?
      ''',
      [tag.dbValue, limit],
    );
    return rows.map((r) => r['word_id'] as String).toList();
  }

  /// 태그별 오답 단어 수(distinct).
  Future<Map<ErrorTag, int>> countByTag() async {
    final rows = await _db.rawQuery(
      'SELECT tag, COUNT(DISTINCT word_id) AS c FROM miss_log GROUP BY tag',
    );
    return {
      for (final r in rows) errorTagFromDb(r['tag'] as String): r['c'] as int,
    };
  }

  Future<List<ErrorTag>> tagsForWord(String wordId) async {
    final rows = await _db.rawQuery(
      'SELECT DISTINCT tag FROM miss_log WHERE word_id = ?',
      [wordId],
    );
    return rows.map((r) => errorTagFromDb(r['tag'] as String)).toList();
  }

  Future<void> clear() => _db.delete('miss_log');
}
```

`lib/domain/repositories/settings_repository.dart`: `seededAt` 관련 제거, `load()`에서 `AppSettings(examDate:..., themeMode:...)`만 반환, 추가:
```dart
  Future<int> dataVersion() async {
    final v = await _get('data_version');
    return v != null ? int.tryParse(v) ?? 0 : 0;
  }

  Future<void> setDataVersion(int version) => _set('data_version', version.toString());
```
`markSeeded`, `isSeeded` 삭제.

- [ ] **Step 5: 통과 확인**

Run: `flutter test test/domain`
Expected: PASS (word_progress_test 등 `JlptLevel` 참조 남은 테스트가 있으면 인자 제거).

- [ ] **Step 6: 커밋**

```bash
git add lib/domain test/domain
git commit -m "refactor(repos): single-level repositories, miss_log, data_version, upsert seeding helpers"
```

---

### Task 4: 카탈로그 재시딩 + N3 에셋 삭제 + 프로바이더 컴파일 복구

**Files:**
- Modify: `lib/application/providers/word_catalog_provider.dart`
- Modify: `lib/application/providers/settings_provider.dart`
- Modify: `lib/application/providers/progress_summary_provider.dart`
- Modify: `pubspec.yaml`
- Delete: `assets/data/n3/`, `assets/data/n3_raw.csv`, `assets/data/n3_words.json`, `assets/data/batch_*.json`, `assets/data/n2_raw.csv`
- Test: `test/application/providers/word_catalog_provider_test.dart`, `settings_provider_test.dart`, `progress_summary_provider_test.dart`

**Interfaces:**
- Produces:
  - `wordCatalogProvider: AsyncNotifierProvider<WordCatalogNotifier, List<Word>>`, `WordCatalogNotifier.addUserWord(Word) -> Future<void>`, `WordCatalogNotifier.wordById(String) -> Word?` (state에서 조회)
  - `ProgressSummary(completedCount, totalCount, daysUntilExam, dailyTarget, weakCount)`; `bool get isExamPassed => daysUntilExam < 0`
  - `SettingsNotifier.updateExamDate(DateTime)`, `updateThemeMode(AppThemeMode)`

- [ ] **Step 1: 실패 테스트**

`test/application/providers/word_catalog_provider_test.dart` — 기존 내용을 확인해 시딩 관련 테스트를 아래로 교체:
```dart
  test('seeds from asset when data_version is stale and records version', () async {
    final db = await AppDatabase.openForTest();
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) async => db),
    ]);
    addTearDown(container.dispose);
    final words = await container.read(wordCatalogProvider.future);
    expect(words.length, greaterThan(1000));
    expect(words.every((w) => w.id.startsWith('n2_')), isTrue);
    expect(await SettingsRepository(db).dataVersion(), AppDatabase.kDataVersion);
    await db.close();
  });

  test('addUserWord inserts and updates state', () async {
    final db = await AppDatabase.openForTest();
    await SettingsRepository(db).setDataVersion(AppDatabase.kDataVersion); // 시딩 스킵
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) async => db),
    ]);
    addTearDown(container.dispose);
    await container.read(wordCatalogProvider.future);
    await container.read(wordCatalogProvider.notifier).addUserWord(
      const Word(id: 'user_1', expression: '把握', reading: 'はあく', meaningKo: '파악', source: 'user'),
    );
    final words = await container.read(wordCatalogProvider.future);
    expect(words.map((w) => w.id), contains('user_1'));
    await db.close();
  });
```
(위젯 테스트에서 에셋 로딩은 `TestWidgetsFlutterBinding.ensureInitialized()` 필요. 기존 테스트 파일이 어떻게 하는지 따라갈 것.)

`test/application/providers/progress_summary_provider_test.dart` — `JlptLevel`·`currentLevel`·`n3*` 참조 제거. 기대값: `completedCount`, `totalCount`, `dailyTarget = ceil(remaining/days)`, 시험일 지난 설정이면 `dailyTarget == 10`.

- [ ] **Step 2: 구현**

`lib/application/providers/word_catalog_provider.dart` 전체 교체:
```dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/database.dart';
import '../../domain/models/word.dart';
import '../../domain/repositories/word_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import 'database_provider.dart';

final wordCatalogProvider =
    AsyncNotifierProvider<WordCatalogNotifier, List<Word>>(WordCatalogNotifier.new);

class WordCatalogNotifier extends AsyncNotifier<List<Word>> {
  @override
  Future<List<Word>> build() async {
    final db = await ref.watch(databaseProvider.future);
    final wordRepo = WordRepository(db);
    final settingsRepo = SettingsRepository(db);

    if (await settingsRepo.dataVersion() < AppDatabase.kDataVersion) {
      await _seedFromAssets(wordRepo, settingsRepo);
    }
    return wordRepo.getAll();
  }

  Future<void> _seedFromAssets(WordRepository wordRepo, SettingsRepository settingsRepo) async {
    final json = await rootBundle.loadString('assets/data/n2_words.json');
    final words = (jsonDecode(json) as List)
        .map((e) => Word.fromAssetJson(e as Map<String, dynamic>))
        .toList();
    await wordRepo.upsertAll(words);
    await wordRepo.deleteN2NotIn(words.map((w) => w.id).toSet());
    await settingsRepo.setDataVersion(AppDatabase.kDataVersion);
  }

  Word? wordById(String id) {
    final list = state.valueOrNull;
    if (list == null) return null;
    for (final w in list) {
      if (w.id == id) return w;
    }
    return null;
  }

  Future<void> addUserWord(Word word) async {
    final db = await ref.read(databaseProvider.future);
    await WordRepository(db).insertUserWord(word);
    final current = state.valueOrNull ?? [];
    state = AsyncData([...current, word]);
  }
}
```

`settings_provider.dart`: `seededAt` 제거, `copyWith` 사용:
```dart
  Future<void> updateExamDate(DateTime date) async {
    final db = await ref.read(databaseProvider.future);
    await SettingsRepository(db).saveExamDate(date);
    state = AsyncData((state.valueOrNull ?? AppSettings.defaults).copyWith(examDate: date));
  }

  Future<void> updateThemeMode(AppThemeMode mode) async {
    final db = await ref.read(databaseProvider.future);
    await SettingsRepository(db).saveThemeMode(mode);
    state = AsyncData((state.valueOrNull ?? AppSettings.defaults).copyWith(themeMode: mode));
  }
```

`progress_summary_provider.dart` 전체 교체:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../domain/repositories/word_repository.dart';
import 'database_provider.dart';
import 'settings_provider.dart';
import 'word_catalog_provider.dart';

/// 시험일 이후 하루 신규 단어 수.
const int kPostExamDailyTarget = 10;

class ProgressSummary {
  final int completedCount;
  final int totalCount;
  final int daysUntilExam;
  final int dailyTarget;
  final int weakCount;

  const ProgressSummary({
    required this.completedCount,
    required this.totalCount,
    required this.daysUntilExam,
    required this.dailyTarget,
    required this.weakCount,
  });

  bool get isExamPassed => daysUntilExam < 0;
  int get remainingCount => totalCount - completedCount;
}

final progressSummaryProvider = FutureProvider<ProgressSummary>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final settings = await ref.watch(settingsProvider.future);
  await ref.watch(wordCatalogProvider.future); // 시딩 완료 보장
  final progressRepo = ProgressRepository(db);
  final wordRepo = WordRepository(db);

  final total = await wordRepo.count();
  final completed = await progressRepo.countCompleted();
  final remaining = total - completed;
  final days = settings.daysUntilExam(DateTime.now());

  final int dailyTarget;
  if (days <= 0) {
    dailyTarget = remaining == 0 ? 0 : kPostExamDailyTarget;
  } else {
    dailyTarget = (remaining / days).ceil();
  }

  return ProgressSummary(
    completedCount: completed,
    totalCount: total,
    daysUntilExam: days,
    dailyTarget: dailyTarget,
    weakCount: await progressRepo.countWeak(),
  );
});
```

`pubspec.yaml` assets에서 `- assets/data/n3_words.json` 줄 삭제. 파일 삭제:
```bash
git rm -r -q assets/data/n3 assets/data/n3_raw.csv assets/data/n3_words.json assets/data/n2_raw.csv assets/data/batch_*.json
```

`lib/widgets/word_badge.dart`, `test/widgets/word_badge_test.dart` 삭제.

- [ ] **Step 3: 통과 확인**

Run: `flutter test test/application/providers/word_catalog_provider_test.dart test/application/providers/settings_provider_test.dart test/application/providers/progress_summary_provider_test.dart`
Expected: PASS.

- [ ] **Step 4: 커밋**

```bash
git add -A lib/application pubspec.yaml assets test/application lib/widgets test/widgets
git commit -m "feat(catalog): version-based reseeding, drop N3 assets, single-level progress summary"
```

---

### Task 5: 오늘 세트 구성 (`StudySetBuilder`) + `TodayStudySetNotifier`

**Files:**
- Create: `lib/domain/services/study_set_builder.dart`
- Modify: `lib/application/providers/today_study_set_provider.dart`
- Test: `test/domain/services/study_set_builder_test.dart`, `test/application/providers/today_study_set_provider_test.dart`

**Interfaces:**
- Produces:
  - `const int kKunMinPerDay = 6; const int kWeakPerDay = 5;`
  - `class StudySetBuilder { StudySetBuilder(ProgressRepository repo, {Random? random}); Future<List<String>> pickNewWordIds(int target, {Set<String> exclude = const {}}); Future<List<String>> pickWeakWordIds({Set<String> exclude = const {}}); }`
  - `TodayStudySetNotifier`: `createTodaySet()`, `appendNextSet()`, `updateItemResult(String wordId, {required bool passed, ErrorTag? tag})`, `finish()` (status completed + 통과 단어 markCompleted + summary invalidate)

- [ ] **Step 1: 실패 테스트**

`test/domain/services/study_set_builder_test.dart`:
```dart
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
```

`test/application/providers/today_study_set_provider_test.dart` 전체 교체:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jlpt/core/db/database.dart';
import 'package:jlpt/application/providers/database_provider.dart';
import 'package:jlpt/application/providers/progress_summary_provider.dart';
import 'package:jlpt/application/providers/today_study_set_provider.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:jlpt/domain/models/error_tag.dart';
import 'package:jlpt/domain/models/word.dart';
import 'package:jlpt/domain/repositories/progress_repository.dart';
import 'package:jlpt/domain/repositories/settings_repository.dart';
import 'package:jlpt/domain/repositories/word_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<(Database, ProviderContainer)> setup({int dailyTarget = 5}) async {
    final db = await AppDatabase.openForTest();
    await SettingsRepository(db).setDataVersion(AppDatabase.kDataVersion);
    await WordRepository(db).insertAll([
      for (var i = 0; i < 12; i++)
        Word(id: 'n2_${i.toString().padLeft(4, '0')}', expression: '語$i', reading: 'ご$i', meaningKo: 'x', type: WordType.on),
    ]);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) async => db),
      progressSummaryProvider.overrideWith((ref) async => ProgressSummary(
            completedCount: 0, totalCount: 12, daysUntilExam: 10, dailyTarget: dailyTarget, weakCount: 0,
          )),
    ]);
    addTearDown(container.dispose);
    return (db, container);
  }

  test('returns null on fresh DB', () async {
    final (db, c) = await setup();
    expect(await c.read(todayStudySetProvider.future), isNull);
    await db.close();
  });

  test('createTodaySet picks dailyTarget items with status quiz', () async {
    final (db, c) = await setup();
    final set = await c.read(todayStudySetProvider.notifier).createTodaySet();
    expect(set.items.length, 5);
    expect(set.targetCount, 5);
    expect(set.status, StudyStage.quiz);
    await db.close();
  });

  test('updateItemResult wrong: attempts+1, miss_count+1, miss_log row', () async {
    final (db, c) = await setup();
    final n = c.read(todayStudySetProvider.notifier);
    final set = await n.createTodaySet();
    final id = set.items.first.wordId;
    await n.updateItemResult(id, passed: false, tag: ErrorTag.sokuon);
    final after = c.read(todayStudySetProvider).valueOrNull!;
    expect(after.items.first.passed, isFalse);
    expect(after.items.first.attempts, 1);
    expect((await ProgressRepository(db).get(id))!.missCount, 1);
    expect((await db.query('miss_log')).single['tag'], 'sokuon');
    await n.updateItemResult(id, passed: true);
    expect(c.read(todayStudySetProvider).valueOrNull!.items.first.passed, isTrue);
    await db.close();
  });

  test('finish marks passed words completed and status completed', () async {
    final (db, c) = await setup();
    final n = c.read(todayStudySetProvider.notifier);
    final set = await n.createTodaySet();
    for (final item in set.items) {
      await n.updateItemResult(item.wordId, passed: true);
    }
    await n.finish();
    expect(c.read(todayStudySetProvider).valueOrNull!.status, StudyStage.completed);
    expect(await ProgressRepository(db).countCompleted(), 5);
    await db.close();
  });

  test('appendNextSet keeps existing items and adds new ones', () async {
    final (db, c) = await setup();
    final n = c.read(todayStudySetProvider.notifier);
    final first = await n.createTodaySet();
    for (final item in first.items) {
      await n.updateItemResult(item.wordId, passed: true);
    }
    await n.finish();
    final second = await n.appendNextSet();
    expect(second.items.length, 10);
    expect(second.items.take(5).every((i) => i.passed), isTrue);
    expect(second.items.skip(5).every((i) => !i.passed), isTrue);
    expect(second.status, StudyStage.quiz);
    expect(second.items.map((i) => i.wordId).toSet().length, 10);
    await db.close();
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/domain/services test/application/providers/today_study_set_provider_test.dart`
Expected: 컴파일 실패.

- [ ] **Step 3: 구현**

`lib/domain/services/study_set_builder.dart`:
```dart
import 'dart:math';
import '../models/enums.dart';
import '../repositories/progress_repository.dart';

/// 하루 세트에 반드시 포함할 훈독 단어 최소 수.
const int kKunMinPerDay = 6;

/// 하루 세트에 덧붙일 약점 단어 수.
const int kWeakPerDay = 5;

class StudySetBuilder {
  final ProgressRepository _repo;
  final Random _random;

  StudySetBuilder(this._repo, {Random? random}) : _random = random ?? Random();

  /// 사용자 단어 → 훈독 최소 보장 → 나머지 랜덤. 결과는 셔플.
  Future<List<String>> pickNewWordIds(int target, {Set<String> exclude = const {}}) async {
    if (target <= 0) return [];
    final picked = <String>[];
    final taken = <String>{...exclude};

    void addAll(Iterable<String> ids, int max) {
      for (final id in ids) {
        if (picked.length >= target || max <= 0) break;
        if (taken.add(id)) {
          picked.add(id);
          max--;
        }
      }
    }

    final userIds = await _repo.getUncompletedWordIds(source: 'user');
    addAll(userIds, target);

    final kunIds = await _repo.getUncompletedWordIds(type: WordType.kun)..shuffle(_random);
    addAll(kunIds, kKunMinPerDay);

    final allIds = await _repo.getUncompletedWordIds()..shuffle(_random);
    addAll(allIds, target);

    picked.shuffle(_random);
    return picked;
  }

  Future<List<String>> pickWeakWordIds({Set<String> exclude = const {}}) async {
    final weak = await _repo.getWeakWordIds(limit: kWeakPerDay + exclude.length);
    return weak.where((id) => !exclude.contains(id)).take(kWeakPerDay).toList();
  }
}
```

`lib/application/providers/today_study_set_provider.dart` 전체 교체:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/error_tag.dart';
import '../../domain/models/today_study_set.dart';
import '../../domain/repositories/miss_log_repository.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../domain/repositories/study_set_repository.dart';
import '../../domain/services/study_set_builder.dart';
import 'database_provider.dart';
import 'progress_summary_provider.dart';

final todayStudySetProvider =
    AsyncNotifierProvider<TodayStudySetNotifier, TodayStudySet?>(TodayStudySetNotifier.new);

String todayDateString([DateTime? now]) {
  final d = now ?? DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class TodayStudySetNotifier extends AsyncNotifier<TodayStudySet?> {
  @override
  Future<TodayStudySet?> build() async {
    final db = await ref.watch(databaseProvider.future);
    return StudySetRepository(db).getByDate(todayDateString());
  }

  Future<List<TodayStudyItem>> _buildItems({
    required int startOrder,
    required Set<String> exclude,
  }) async {
    final db = await ref.read(databaseProvider.future);
    final summary = await ref.read(progressSummaryProvider.future);
    final builder = StudySetBuilder(ProgressRepository(db));
    final newIds = await builder.pickNewWordIds(summary.dailyTarget, exclude: exclude);
    final weakIds = await builder.pickWeakWordIds(exclude: {...exclude, ...newIds});
    final ids = [...newIds, ...weakIds]..shuffle();
    final now = DateTime.now();
    final today = todayDateString(now);
    return [
      for (var i = 0; i < ids.length; i++)
        TodayStudyItem(
          studyDate: today,
          wordId: ids[i],
          displayOrder: startOrder + i,
          passed: false,
          attempts: 0,
          updatedAt: now,
        ),
    ];
  }

  Future<TodayStudySet> createTodaySet() async {
    final db = await ref.read(databaseProvider.future);
    final items = await _buildItems(startOrder: 0, exclude: const {});
    final now = DateTime.now();
    final set = TodayStudySet(
      studyDate: todayDateString(now),
      targetCount: items.length,
      status: StudyStage.quiz,
      items: items,
      startedAt: now,
      createdAt: now,
      updatedAt: now,
    );
    await StudySetRepository(db).createSet(set);
    state = AsyncData(set);
    return set;
  }

  /// 완료된 오늘 세트에 새 단어를 덧붙이고 다시 quiz 상태로.
  Future<TodayStudySet> appendNextSet() async {
    final current = state.valueOrNull;
    if (current == null) return createTodaySet();
    final db = await ref.read(databaseProvider.future);
    final items = await _buildItems(
      startOrder: current.items.length,
      exclude: current.items.map((i) => i.wordId).toSet(),
    );
    await StudySetRepository(db).appendItems(current.studyDate, items);
    final updated = current.copyWith(
      items: [...current.items, ...items],
      targetCount: current.items.length + items.length,
      status: StudyStage.quiz,
      completedAt: null,
      updatedAt: DateTime.now(),
    );
    state = AsyncData(updated);
    return updated;
  }

  Future<void> updateItemResult(String wordId, {required bool passed, ErrorTag? tag}) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final idx = current.items.indexWhere((i) => i.wordId == wordId);
    if (idx < 0) return;
    final db = await ref.read(databaseProvider.future);
    final item = current.items[idx];
    final updated = item.copyWith(
      passed: passed,
      attempts: item.attempts + 1,
      updatedAt: DateTime.now(),
    );
    await StudySetRepository(db).updateItem(updated);
    final progressRepo = ProgressRepository(db);
    if (passed) {
      await progressRepo.decrementMiss(wordId);
    } else {
      await progressRepo.incrementMiss(wordId);
      await MissLogRepository(db).add(wordId, tag ?? ErrorTag.other);
    }
    final items = List<TodayStudyItem>.from(current.items)..[idx] = updated;
    state = AsyncData(current.copyWith(items: items, updatedAt: DateTime.now()));
  }

  Future<void> finish() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final db = await ref.read(databaseProvider.future);
    final progressRepo = ProgressRepository(db);
    for (final item in current.items.where((i) => i.passed)) {
      await progressRepo.markCompleted(item.wordId);
    }
    final now = DateTime.now();
    await StudySetRepository(db).updateSetStatus(current.studyDate, StudyStage.completed, completedAt: now);
    state = AsyncData(current.copyWith(status: StudyStage.completed, completedAt: now, updatedAt: now));
    ref.invalidate(progressSummaryProvider);
  }
}
```

`copyWith`에서 `completedAt: null`을 전달해도 기존 값이 유지되는 문제가 있다. `TodayStudySet.copyWith`를 `Object? completedAt = _unset` 센티널 패턴으로 바꿔 null 설정 가능하게 하라:
```dart
const _unset = Object();
// copyWith 시그니처: Object? completedAt = _unset
// 본문: completedAt: identical(completedAt, _unset) ? this.completedAt : completedAt as DateTime?
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/domain/services test/application/providers/today_study_set_provider_test.dart`
Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
git add lib/domain/services/study_set_builder.dart lib/domain/models/today_study_set.dart lib/application/providers/today_study_set_provider.dart test/domain/services test/application/providers/today_study_set_provider_test.dart
git commit -m "feat(study): kun-first daily set builder, append-next-set, miss tagging on wrong answers"
```

---

### Task 6: 복습 세션 프로바이더 (태그 필터)

**Files:**
- Modify: `lib/application/providers/review_session_provider.dart`
- Create: `lib/application/providers/miss_tag_counts_provider.dart`
- Test: `test/application/providers/review_session_provider_test.dart`

**Interfaces:**
- Produces:
  - `ReviewSessionNotifier.startNewSession({ErrorTag? tag})`, `updateItemResult(String wordId, {required bool passed, ErrorTag? tag})`, `complete()`
  - `missTagCountsProvider: FutureProvider<Map<ErrorTag, int>>`

- [ ] **Step 1: 실패 테스트**

`test/application/providers/review_session_provider_test.dart` — 기존 파일에서 `JlptLevel` 제거. `buildBlendedSelectionForTest(progressRepo, level, ...)` 호출을 `buildBlendedSelectionForTest(progressRepo, ...)`로. 추가:
```dart
  test('startNewSession with tag uses miss_log words first', () async {
    final db = await AppDatabase.openForTest();
    await SettingsRepository(db).setDataVersion(AppDatabase.kDataVersion);
    await WordRepository(db).insertAll([
      for (var i = 0; i < 30; i++)
        Word(id: 'n2_$i', expression: '語$i', reading: 'ご$i', meaningKo: 'x'),
    ]);
    final progressRepo = ProgressRepository(db);
    for (var i = 0; i < 30; i++) {
      await progressRepo.markCompleted('n2_$i');
    }
    final missRepo = MissLogRepository(db);
    await missRepo.add('n2_3', ErrorTag.longVowel);
    await missRepo.add('n2_7', ErrorTag.longVowel);
    await missRepo.add('n2_9', ErrorTag.sokuon);

    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) async => db),
      progressSummaryProvider.overrideWith((ref) async => const ProgressSummary(
            completedCount: 30, totalCount: 30, daysUntilExam: 10, dailyTarget: 0, weakCount: 0,
          )),
    ]);
    addTearDown(container.dispose);
    final session = await container.read(reviewSessionProvider.notifier).startNewSession(tag: ErrorTag.longVowel);
    final ids = session.items.map((i) => i.wordId).toList();
    expect(ids, containsAll(['n2_3', 'n2_7']));
    expect(ids.length, 20); // 부족분은 블렌드로 채움
    expect(ids.toSet().length, 20);
    await db.close();
  });
```

- [ ] **Step 2: 구현**

`review_session_provider.dart`: `JlptLevel`/`level` 파라미터 제거. `startNewSession({List<String>? wordIds})` → `startNewSession({ErrorTag? tag})`:
```dart
  Future<ReviewSession> startNewSession({ErrorTag? tag}) async {
    final db = await ref.read(databaseProvider.future);
    final progressRepo = ProgressRepository(db);
    final reviewRepo = ReviewRepository(db);

    final selected = <String>[];
    if (tag != null) {
      selected.addAll(await MissLogRepository(db).recentWordIdsByTag(tag, limit: kReviewSessionSize));
    }
    if (selected.length < kReviewSessionSize) {
      final blend = await _buildBlendedSelection(progressRepo);
      for (final id in blend) {
        if (selected.length >= kReviewSessionSize) break;
        if (!selected.contains(id)) selected.add(id);
      }
    }
    // ... 이하 기존 세션 생성 로직 동일 (ReviewSessionItem에 passed:false, attempts:0)
  }
```
`updateItemResult`는 Task 5의 `TodayStudySetNotifier.updateItemResult`와 동일 구조(오답 시 `MissLogRepository.add`). `status: StudyStage.quiz`로 생성.

`miss_tag_counts_provider.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/error_tag.dart';
import '../../domain/repositories/miss_log_repository.dart';
import 'database_provider.dart';

final missTagCountsProvider = FutureProvider<Map<ErrorTag, int>>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return MissLogRepository(db).countByTag();
});
```
`ReviewSessionNotifier.complete()`와 `TodayStudySetNotifier.updateItemResult`(오답 시)에서 `ref.invalidate(missTagCountsProvider)` 호출.

- [ ] **Step 3: 통과 확인**

Run: `flutter test test/application/providers/review_session_provider_test.dart`
Expected: PASS.

- [ ] **Step 4: 커밋**

```bash
git add lib/application/providers test/application/providers
git commit -m "feat(review): tag-filtered review sessions and miss tag counts"
```

---

### Task 7: 오답 생성기 `DistractorGenerator`

**Files:**
- Create: `lib/domain/services/distractor_generator.dart`
- Test: `test/domain/services/distractor_generator_test.dart`

**Interfaces:**
- Produces:
  - `class Distractor { final String reading; final ErrorTag tag; }`
  - `class DistractorGenerator { DistractorGenerator({Random? random}); List<Distractor> generate({required String correct, Set<String> exclude = const {}, List<String> pool = const [], int count = 3}); List<String> longVowelVariants(String r); List<String> sokuonVariants(String r); List<String> dakutenVariants(String r); }`

- [ ] **Step 1: 실패 테스트**

`test/domain/services/distractor_generator_test.dart`:
```dart
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/domain/models/error_tag.dart';
import 'package:jlpt/domain/services/distractor_generator.dart';

void main() {
  final g = DistractorGenerator(random: Random(42));

  group('longVowelVariants', () {
    test('removes う after o-row and い after e-row', () {
      expect(g.longVowelVariants('しょうり'), contains('しょり'));
      expect(g.longVowelVariants('せいさん'), contains('せさん'));
    });
    test('adds う after o-row kana lacking it', () {
      expect(g.longVowelVariants('ここく'), contains('こうこく'));
    });
    test('removes ー', () {
      expect(g.longVowelVariants('コーヒー'), contains('コヒー'));
    });
    test('never returns the input itself', () {
      expect(g.longVowelVariants('こうこく'), isNot(contains('こうこく')));
    });
  });

  group('sokuonVariants', () {
    test('removes っ', () {
      expect(g.sokuonVariants('いっち'), contains('いち'));
    });
    test('inserts っ before k/s/t/p row, not at index 0', () {
      final v = g.sokuonVariants('けか');
      expect(v, contains('けっか'));
      expect(v.every((s) => !s.startsWith('っ')), isTrue);
    });
  });

  group('dakutenVariants', () {
    test('toggles voiced/unvoiced', () {
      expect(g.dakutenVariants('がまん'), contains('かまん'));
      expect(g.dakutenVariants('かまん'), contains('がまん'));
    });
    test('toggles handakuten', () {
      expect(g.dakutenVariants('はあく'), contains('ぱあく'));
    });
  });

  group('generate', () {
    test('returns 3 distinct readings none equal to correct or excluded', () {
      final d = g.generate(correct: 'せいさん', exclude: {'せさん'});
      expect(d.length, 3);
      expect(d.map((x) => x.reading).toSet().length, 3);
      expect(d.every((x) => x.reading != 'せいさん' && x.reading != 'せさん'), isTrue);
    });
    test('covers different tags when possible', () {
      final d = g.generate(correct: 'けっこう');
      expect(d.map((x) => x.tag).toSet().length, greaterThanOrEqualTo(2));
    });
    test('falls back to pool with tag other when variants are scarce', () {
      final d = g.generate(correct: 'い', pool: ['いえ', 'いぬ', 'いし', 'いろ']);
      expect(d.length, 3);
      expect(d.where((x) => x.tag == ErrorTag.other).isNotEmpty, isTrue);
    });
    test('mixed katakana reading uses pool only', () {
      final d = g.generate(correct: 'ハンド', pool: ['ハンカチ', 'ハンバーグ', 'ハンサム']);
      expect(d.every((x) => x.tag == ErrorTag.other), isTrue);
    });
    test('returns fewer when nothing available', () {
      expect(g.generate(correct: 'い'), isEmpty);
    });
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/domain/services/distractor_generator_test.dart`
Expected: 컴파일 실패.

- [ ] **Step 3: 구현**

`lib/domain/services/distractor_generator.dart`:
```dart
import 'dart:math';
import '../models/error_tag.dart';

class Distractor {
  final String reading;
  final ErrorTag tag;
  const Distractor(this.reading, this.tag);
}

/// 정답 읽기를 장음·촉음·탁음 규칙으로 변형해 시험형 오답을 만든다.
class DistractorGenerator {
  final Random _random;
  DistractorGenerator({Random? random}) : _random = random ?? Random();

  static const _oRow = 'おこそとのほもよろをごぞどぼぽょ';
  static const _eRow = 'えけせてねへめれげぜでべぺ';
  static const _sokuonTargets = 'かきくけこさしすせそたちつてとぱぴぷぺぽ';
  static const _dakutenPairs = {
    'か': 'が', 'き': 'ぎ', 'く': 'ぐ', 'け': 'げ', 'こ': 'ご',
    'さ': 'ざ', 'し': 'じ', 'す': 'ず', 'せ': 'ぜ', 'そ': 'ぞ',
    'た': 'だ', 'ち': 'ぢ', 'つ': 'づ', 'て': 'で', 'と': 'ど',
    'は': 'ば', 'ひ': 'び', 'ふ': 'ぶ', 'へ': 'べ', 'ほ': 'ぼ',
  };
  static const _handakutenPairs = {
    'は': 'ぱ', 'ひ': 'ぴ', 'ふ': 'ぷ', 'へ': 'ぺ', 'ほ': 'ぽ',
    'ば': 'ぱ', 'び': 'ぴ', 'ぶ': 'ぷ', 'べ': 'ぺ', 'ぼ': 'ぽ',
  };
  static final _katakana = RegExp(r'[゠-ヺ]');

  List<String> longVowelVariants(String r) {
    final out = <String>{};
    final chars = r.split('');
    for (var i = 0; i < chars.length; i++) {
      final c = chars[i];
      final prev = i > 0 ? chars[i - 1] : '';
      // 삭제
      if (c == 'ー' || (c == 'う' && _oRow.contains(prev)) || (c == 'い' && _eRow.contains(prev))) {
        out.add((List.of(chars)..removeAt(i)).join());
      }
      // 추가
      final next = i + 1 < chars.length ? chars[i + 1] : '';
      if (_oRow.contains(c) && next != 'う') {
        out.add((List.of(chars)..insert(i + 1, 'う')).join());
      }
      if (_eRow.contains(c) && next != 'い') {
        out.add((List.of(chars)..insert(i + 1, 'い')).join());
      }
    }
    out.remove(r);
    return out.toList();
  }

  List<String> sokuonVariants(String r) {
    final out = <String>{};
    final chars = r.split('');
    for (var i = 0; i < chars.length; i++) {
      if (chars[i] == 'っ') {
        out.add((List.of(chars)..removeAt(i)).join());
      } else if (i > 0 && _sokuonTargets.contains(chars[i]) && chars[i - 1] != 'っ') {
        out.add((List.of(chars)..insert(i, 'っ')).join());
      }
    }
    out.remove(r);
    return out.toList();
  }

  List<String> dakutenVariants(String r) {
    final out = <String>{};
    final chars = r.split('');
    final reverse = {for (final e in _dakutenPairs.entries) e.value: e.key};
    final reverseHan = {for (final e in _handakutenPairs.entries) e.value: e.key};
    for (var i = 0; i < chars.length; i++) {
      final c = chars[i];
      for (final swap in [
        _dakutenPairs[c],
        reverse[c],
        _handakutenPairs[c],
        reverseHan[c],
      ]) {
        if (swap != null) {
          out.add((List.of(chars)..[i] = swap).join());
        }
      }
    }
    out.remove(r);
    return out.toList();
  }

  List<Distractor> generate({
    required String correct,
    Set<String> exclude = const {},
    List<String> pool = const [],
    int count = 3,
  }) {
    final banned = {correct, ...exclude};
    final result = <Distractor>[];
    final used = <String>{};

    void take(Distractor d) {
      if (result.length >= count) return;
      if (banned.contains(d.reading) || !used.add(d.reading)) return;
      result.add(d);
    }

    if (!_katakana.hasMatch(correct)) {
      final buckets = <ErrorTag, List<String>>{
        ErrorTag.longVowel: longVowelVariants(correct)..shuffle(_random),
        ErrorTag.sokuon: sokuonVariants(correct)..shuffle(_random),
        ErrorTag.dakuten: dakutenVariants(correct)..shuffle(_random),
      };
      // 카테고리 순환: 각 태그에서 하나씩 돌아가며 뽑아 태그 다양성 확보
      var progressed = true;
      while (result.length < count && progressed) {
        progressed = false;
        for (final entry in buckets.entries) {
          if (entry.value.isEmpty) continue;
          take(Distractor(entry.value.removeLast(), entry.key));
          progressed = true;
        }
      }
    }

    final shuffledPool = List.of(pool)..shuffle(_random);
    for (final p in shuffledPool) {
      take(Distractor(p, ErrorTag.other));
    }
    return result;
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/domain/services/distractor_generator_test.dart`
Expected: PASS. (`covers different tags` 케이스가 시드에 따라 흔들리면 `Random(42)` 유지하고 기대값을 실제 결과로 확인 후 고정.)

- [ ] **Step 5: 커밋**

```bash
git add lib/domain/services/distractor_generator.dart test/domain/services/distractor_generator_test.dart
git commit -m "feat(quiz): weakness-targeted distractor generator (long vowel, sokuon, dakuten)"
```

---

### Task 8: 구 학습 화면·라우트 삭제 + 홈 개편

**Files:**
- Delete: `lib/features/study/` 전체, `lib/features/review/review_screen.dart`, 대응 테스트 `test/features/study/`, `test/features/review/review_screen_test.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/home/home_screen.dart`
- Modify: `lib/features/stats/stats_provider.dart`, `stats_screen.dart`
- Modify: `lib/features/explore/explore_provider.dart`, `word_list_screen.dart`, `explore_flashcard_screen.dart`
- Test: `test/features/home/home_screen_test.dart`, `test/features/stats/stats_screen_test.dart`, `test/features/explore/*`

**Interfaces:**
- Consumes: `ProgressSummary`(Task 4), `TodayStudySetNotifier`(Task 5), `missTagCountsProvider`(Task 6)
- Produces: 라우트 `/quiz` (extra: `QuizMode`), `/quiz/complete` (extra: `QuizMode`) — 화면은 Task 9에서 구현. 이 태스크에서는 라우터에 임시 `PlaceholderScreen('quiz')`로 연결.
- `enum QuizMode { study, review }` — `lib/features/quiz/quiz_mode.dart`에 생성.

- [ ] **Step 1: 삭제**

```bash
git rm -r -q lib/features/study lib/features/review/review_screen.dart test/features/study test/features/review
```

- [ ] **Step 2: 라우터**

`app_router.dart`에서 삭제된 import·`/study/*`·`/review*` 라우트 제거. 추가:
```dart
    GoRoute(
      path: '/quiz',
      builder: (context, state) => const PlaceholderScreen('quiz'),
    ),
    GoRoute(
      path: '/quiz/complete',
      builder: (context, state) => const PlaceholderScreen('quiz complete'),
    ),
```
`lib/features/quiz/quiz_mode.dart`:
```dart
enum QuizMode { study, review }
```

- [ ] **Step 3: 홈 테스트 갱신**

`test/features/home/home_screen_test.dart`: `ProgressSummary` 생성자를 새 필드로. 테스트 케이스:
- `shows D-Day text` → `D-30`
- `shows progress line` → `'N2 10 / 100'` 텍스트 존재
- `shows study button when no set` → `'학습 시작'`
- `exam passed still shows study button` → summary `daysUntilExam: -5` 로 `'D+5'`와 `'학습 시작'` 둘 다 존재
- `shows review card with weak count` → `weakCount: 3` → `'약점 3개'`
- `shows add word card` → `'단어 추가'`
- N3 뱃지 테스트 삭제.

- [ ] **Step 4: 홈 구현**

`home_screen.dart`의 `_HomeBody.build`를 아래 구조로 교체 (스타일 코드는 기존 것 재사용):
- 상단 Row: D-day 텍스트(`D-n` / `D+n`), 우측 가나표·테마 아이콘 (뱃지 제거).
- `'오늘 $todayCompleted / $todayTarget 완료'`
- `'N2 ${summary.completedCount} / ${summary.totalCount}'` + `LinearProgressIndicator(value: completed/total)`
- 큰 버튼: `set == null` → `'학습 시작'`, 진행 중 → `'이어하기'`, 완료 → `'오늘 학습 완료 ✓'`(비활성). 완료 시 아래 OutlinedButton `'다음 학습 시작'` → `appendNextSet()` 후 `/quiz` push. `isReviewOnlyMode` 분기 삭제.
- 작은 카드 2개: `'복습'`(subtitle 약점 n개, `enabled: summary.completedCount > 0`, onTap → `showReviewFilterSheet(context)` — Task 10에서 생성; 이 태스크에서는 `context.push('/quiz', extra: QuizMode.review)`로 임시), `'단어 추가'`(onTap → Task 11의 `showAddWordSheet(context)`; 이 태스크에서는 빈 콜백).
- 시작 로직:
```dart
  Future<void> _startStudy(BuildContext context, WidgetRef ref, TodayStudySet? currentSet) async {
    if (currentSet == null) {
      await ref.read(todayStudySetProvider.notifier).createTodaySet();
    }
    if (!context.mounted) return;
    context.push('/quiz', extra: QuizMode.study);
  }
```

- [ ] **Step 5: 통계·탐색 수정**

`stats_provider.dart`:
```dart
class StatsState {
  final int completed;
  final int total;
  final int weak;
  final Map<ErrorTag, int> missByTag;
  const StatsState({required this.completed, required this.total, required this.weak, required this.missByTag});
  double get percent => total == 0 ? 0.0 : completed / total;
}

final statsProvider = FutureProvider<StatsState>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final catalog = await ref.watch(wordCatalogProvider.future);
  final repo = ProgressRepository(db);
  return StatsState(
    completed: await repo.countCompleted(),
    total: catalog.length,
    weak: await repo.countWeak(),
    missByTag: await ref.watch(missTagCountsProvider.future),
  );
});
```
`stats_screen.dart`: 카드 하나(`N2`), 아래 `'약점 n개'`, 태그별 오답 수 Row (`장음 3 · 촉음 1 · ...`, 0인 태그 생략). N3 카드·전체 진도 섹션 삭제.

`explore_provider.dart`: `levelFilter` 제거, `String? sourceFilter` 추가(`'user'`만 사용). `build()`에서 `getCompletedWordIds()` 단일 호출. `updateFilter`에서 `sourceFilter != null`이면 `results.where((w) => w.source == filter.sourceFilter)`.
`word_list_screen.dart`: N3/N2 칩 삭제, `'추가한 단어'` 칩 추가(sourceFilter 토글). `WordBadge` 사용 제거. AppBar actions에 `IconButton(Icons.add)` → Task 11의 `showAddWordSheet(context)` (이 태스크에서는 빈 콜백).
`explore_flashcard_screen.dart`: `WordBadge`·`jlptLevel` 참조 제거.

- [ ] **Step 6: 전체 컴파일·테스트**

Run: `flutter analyze && flutter test`
Expected: analyze 에러 0, 테스트 전부 PASS. (남은 `JlptLevel` 참조는 `grep -rn JlptLevel lib test`로 찾아 제거.)

- [ ] **Step 7: 커밋**

```bash
git add -A lib test
git commit -m "refactor: remove N3 level, legacy study screens and review quiz; simplify home, stats, explore"
```

---

### Task 9: `QuizScreen` + `QuizCompleteScreen`

**Files:**
- Create: `lib/features/quiz/quiz_screen.dart`
- Create: `lib/features/quiz/quiz_complete_screen.dart`
- Modify: `lib/core/router/app_router.dart` (Placeholder → 실제 화면)
- Test: `test/features/quiz/quiz_screen_test.dart`, `test/features/quiz/quiz_complete_screen_test.dart`

**Interfaces:**
- Consumes: `todayStudySetProvider`, `reviewSessionProvider`, `wordCatalogProvider`, `DistractorGenerator`, `WordRepository.getReadingsByExpression/getRandomReadingsStartingWith/getRandomMeanings`
- Produces: `QuizScreen({required QuizMode mode})`, `QuizCompleteScreen({required QuizMode mode})`

- [ ] **Step 1: 실패 테스트**

`test/features/quiz/quiz_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jlpt/application/providers/database_provider.dart';
import 'package:jlpt/application/providers/progress_summary_provider.dart';
import 'package:jlpt/application/providers/today_study_set_provider.dart';
import 'package:jlpt/core/db/database.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:jlpt/domain/models/word.dart';
import 'package:jlpt/domain/repositories/settings_repository.dart';
import 'package:jlpt/domain/repositories/word_repository.dart';
import 'package:jlpt/features/quiz/quiz_mode.dart';
import 'package:jlpt/features/quiz/quiz_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<(Database, ProviderContainer)> setup() async {
    final db = await AppDatabase.openForTest();
    await SettingsRepository(db).setDataVersion(AppDatabase.kDataVersion);
    await WordRepository(db).insertAll(const [
      Word(id: 'n2_0001', expression: '生産', reading: 'せいさん', meaningKo: '생산', type: WordType.on),
      Word(id: 'n2_0002', expression: '把握', reading: 'はあく', meaningKo: '파악', type: WordType.on),
      Word(id: 'n2_0003', expression: 'コーヒー', reading: 'コーヒー', meaningKo: '커피', type: WordType.katakana),
    ]);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) async => db),
      progressSummaryProvider.overrideWith((ref) async => const ProgressSummary(
            completedCount: 0, totalCount: 3, daysUntilExam: 10, dailyTarget: 3, weakCount: 0,
          )),
    ]);
    await container.read(todayStudySetProvider.notifier).createTodaySet();
    return (db, container);
  }

  Widget app(ProviderContainer c) => UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(
          routerConfig: GoRouter(routes: [
            GoRoute(path: '/', builder: (_, __) => const QuizScreen(mode: QuizMode.study)),
            GoRoute(path: '/quiz/complete', builder: (_, __) => const Scaffold(body: Text('COMPLETE'))),
          ]),
        ),
      );

  testWidgets('shows expression, 4 choices and dont-know button', (tester) async {
    final (db, c) = await setup();
    await tester.pumpWidget(app(c));
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.byKey(const Key('quiz-choice-0')), findsOneWidget);
    expect(find.byKey(const Key('quiz-choice-3')), findsOneWidget);
    expect(find.text('모르겠다'), findsOneWidget);
    await db.close();
  });

  testWidgets('wrong answer reveals card, requeues, and waits for 다음', (tester) async {
    final (db, c) = await setup();
    await tester.pumpWidget(app(c));
    await tester.pumpAndSettle();
    await tester.tap(find.text('모르겠다'));
    await tester.pump();
    expect(find.text('다음'), findsOneWidget);
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 4'), findsOneWidget); // 큐 길이 +1
    await db.close();
  });

  testWidgets('finishing all items navigates to complete', (tester) async {
    final (db, c) = await setup();
    await tester.pumpWidget(app(c));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      final state = tester.state<QuizScreenState>(find.byType(QuizScreen));
      await tester.tap(find.byKey(Key('quiz-choice-${state.correctChoiceIndexForTest}')));
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();
    }
    expect(find.text('COMPLETE'), findsOneWidget);
    await db.close();
  });
}
```

- [ ] **Step 2: 구현**

`lib/features/quiz/quiz_screen.dart`:
```dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/providers/database_provider.dart';
import '../../application/providers/review_session_provider.dart';
import '../../application/providers/today_study_set_provider.dart';
import '../../application/providers/word_catalog_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/error_tag.dart';
import '../../domain/models/word.dart';
import '../../domain/repositories/word_repository.dart';
import '../../domain/services/distractor_generator.dart';
import 'quiz_mode.dart';

class QuizChoice {
  final String text;
  final bool isCorrect;
  final ErrorTag? tag; // 오답 선택 시 기록할 태그
  const QuizChoice(this.text, {required this.isCorrect, this.tag});
}

class QuizScreen extends ConsumerStatefulWidget {
  final QuizMode mode;
  const QuizScreen({super.key, required this.mode});

  @override
  ConsumerState<QuizScreen> createState() => QuizScreenState();
}

class QuizScreenState extends ConsumerState<QuizScreen> {
  final _generator = DistractorGenerator();
  List<String> _queue = [];
  int _index = 0;
  List<QuizChoice> _choices = [];
  int? _selected;
  bool _revealed = false;
  bool _initialized = false;
  Timer? _autoNext;

  @visibleForTesting
  int get correctChoiceIndexForTest => _choices.indexWhere((c) => c.isCorrect);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _initQueue();
    }
  }

  @override
  void dispose() {
    _autoNext?.cancel();
    super.dispose();
  }

  List<String> _pendingWordIds() {
    switch (widget.mode) {
      case QuizMode.study:
        final set = ref.read(todayStudySetProvider).valueOrNull;
        return set?.items.where((i) => !i.passed).map((i) => i.wordId).toList() ?? [];
      case QuizMode.review:
        final session = ref.read(reviewSessionProvider).valueOrNull;
        return session?.items.where((i) => !i.passed).map((i) => i.wordId).toList() ?? [];
    }
  }

  Future<void> _record(String wordId, {required bool passed, ErrorTag? tag}) {
    switch (widget.mode) {
      case QuizMode.study:
        return ref.read(todayStudySetProvider.notifier).updateItemResult(wordId, passed: passed, tag: tag);
      case QuizMode.review:
        return ref.read(reviewSessionProvider.notifier).updateItemResult(wordId, passed: passed, tag: tag);
    }
  }

  Future<void> _initQueue() async {
    final ids = _pendingWordIds();
    if (ids.isEmpty) {
      _goComplete();
      return;
    }
    setState(() {
      _queue = ids;
      _index = 0;
    });
    await _loadChoices();
  }

  Word? _currentWord() {
    if (_index >= _queue.length) return null;
    return ref.read(wordCatalogProvider.notifier).wordById(_queue[_index]);
  }

  Future<void> _loadChoices() async {
    final word = _currentWord();
    if (word == null) return;
    final db = await ref.read(databaseProvider.future);
    final repo = WordRepository(db);
    final List<QuizChoice> choices;

    if (word.hasKanji) {
      final siblings = (await repo.getReadingsByExpression(word.expression)).toSet();
      final pool = await repo.getRandomReadingsStartingWith(
        word.reading.substring(0, 1),
        limit: 6,
        exclude: {...siblings, word.reading},
      );
      final distractors = _generator.generate(correct: word.reading, exclude: siblings, pool: pool);
      choices = [
        QuizChoice(word.reading, isCorrect: true),
        for (final d in distractors) QuizChoice(d.reading, isCorrect: false, tag: d.tag),
      ];
    } else {
      final meanings = await repo.getRandomMeanings(limit: 3, excludeWordId: word.id);
      choices = [
        QuizChoice(word.meaningKo, isCorrect: true),
        for (final m in meanings) QuizChoice(m, isCorrect: false, tag: ErrorTag.meaning),
      ];
    }
    choices.shuffle(Random());
    if (!mounted) return;
    setState(() {
      _choices = choices;
      _selected = null;
      _revealed = false;
    });
  }

  Future<void> _onSelect(int? index) async {
    if (_revealed) return;
    final word = _currentWord();
    if (word == null) return;
    final choice = index != null ? _choices[index] : null;
    final correct = choice?.isCorrect ?? false;
    setState(() {
      _selected = index;
      _revealed = true;
    });
    await _record(word.id, passed: correct, tag: correct ? null : (choice?.tag ?? ErrorTag.other));
    if (correct) {
      _autoNext = Timer(const Duration(milliseconds: 1000), _advance);
    }
  }

  void _advance() {
    if (!mounted) return;
    final word = _currentWord();
    if (word == null) return;
    final wasCorrect = _selected != null && _choices[_selected!].isCorrect;
    if (!wasCorrect) _queue.add(word.id);
    final next = _index + 1;
    if (next >= _queue.length) {
      _goComplete();
      return;
    }
    setState(() => _index = next);
    _loadChoices();
  }

  void _goComplete() {
    context.go('/quiz/complete', extra: widget.mode);
  }

  @override
  Widget build(BuildContext context) {
    final word = _currentWord();
    if (word == null || _choices.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('${_index + 1} / ${_queue.length}'),
        actions: [
          IconButton(icon: const Icon(Icons.close), onPressed: () => context.go('/')),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(
                child: Text(
                  word.hasKanji ? word.expression : word.expression,
                  style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              for (var i = 0; i < _choices.length; i++) ...[
                _ChoiceButton(
                  key: Key('quiz-choice-$i'),
                  text: _choices[i].text,
                  state: _choiceState(i),
                  onTap: () => _onSelect(i),
                ),
                const SizedBox(height: 10),
              ],
              if (!_revealed)
                TextButton(onPressed: () => _onSelect(null), child: const Text('모르겠다')),
              if (_revealed) ...[
                const SizedBox(height: 8),
                Expanded(child: SingleChildScrollView(child: _AnswerCard(word: word))),
                if (!(_selected != null && _choices[_selected!].isCorrect))
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(onPressed: _advance, child: const Text('다음')),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  _ChoiceState _choiceState(int i) {
    if (!_revealed) return _ChoiceState.idle;
    if (_choices[i].isCorrect) return _ChoiceState.correct;
    if (_selected == i) return _ChoiceState.wrong;
    return _ChoiceState.dim;
  }
}

enum _ChoiceState { idle, correct, wrong, dim }

class _ChoiceButton extends StatelessWidget {
  final String text;
  final _ChoiceState state;
  final VoidCallback onTap;
  const _ChoiceButton({super.key, required this.text, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, border, fg) = switch (state) {
      _ChoiceState.idle => (theme.cardColor, theme.dividerColor, theme.colorScheme.onSurface),
      _ChoiceState.correct => (AppColors.success.withValues(alpha: 0.12), AppColors.success, AppColors.success),
      _ChoiceState.wrong => (AppColors.error.withValues(alpha: 0.12), AppColors.error, AppColors.error),
      _ChoiceState.dim => (theme.cardColor, theme.dividerColor.withValues(alpha: 0.4), theme.colorScheme.onSurfaceVariant),
    };
    return GestureDetector(
      onTap: state == _ChoiceState.idle ? onTap : null,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Text(text, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: fg)),
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  final Word word;
  const _AnswerCard({required this.word});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(word.reading, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
              const SizedBox(width: 8),
              if (word.isTrap)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('배신 단어', style: TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(word.meaningKo, style: const TextStyle(fontSize: 18)),
          if (word.example != null) ...[
            const SizedBox(height: 12),
            Text(word.example!.ja, style: const TextStyle(fontSize: 16)),
            Text(word.example!.reading, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
            Text(word.example!.ko, style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}
```
(`AppColors.success`/`AppColors.error`는 `core/theme/app_theme.dart`에 이미 존재. 없으면 `#16A34A`/`#DC2626`로 추가.)

`lib/features/quiz/quiz_complete_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/providers/database_provider.dart';
import '../../application/providers/review_session_provider.dart';
import '../../application/providers/today_study_set_provider.dart';
import '../../application/providers/word_catalog_provider.dart';
import '../../domain/models/error_tag.dart';
import '../../domain/repositories/miss_log_repository.dart';
import 'quiz_mode.dart';

class QuizCompleteScreen extends ConsumerStatefulWidget {
  final QuizMode mode;
  const QuizCompleteScreen({super.key, required this.mode});

  @override
  ConsumerState<QuizCompleteScreen> createState() => _QuizCompleteScreenState();
}

class _QuizCompleteScreenState extends ConsumerState<QuizCompleteScreen> {
  bool _finished = false;
  Map<String, List<ErrorTag>> _tags = {};

  @override
  void initState() {
    super.initState();
    _finish();
  }

  Future<void> _finish() async {
    if (widget.mode == QuizMode.study) {
      await ref.read(todayStudySetProvider.notifier).finish();
    } else {
      await ref.read(reviewSessionProvider.notifier).complete();
    }
    final db = await ref.read(databaseProvider.future);
    final repo = MissLogRepository(db);
    final tags = <String, List<ErrorTag>>{};
    for (final id in _wrongWordIds()) {
      tags[id] = await repo.tagsForWord(id);
    }
    if (!mounted) return;
    setState(() {
      _tags = tags;
      _finished = true;
    });
  }

  // (wordId, attempts) 목록
  List<(String, int)> _items() {
    switch (widget.mode) {
      case QuizMode.study:
        final set = ref.read(todayStudySetProvider).valueOrNull;
        return set?.items.map((i) => (i.wordId, i.attempts)).toList() ?? [];
      case QuizMode.review:
        final s = ref.read(reviewSessionProvider).valueOrNull;
        return s?.items.map((i) => (i.wordId, i.attempts)).toList() ?? [];
    }
  }

  List<String> _wrongWordIds() => _items().where((e) => e.$2 > 1).map((e) => e.$1).toList();

  @override
  Widget build(BuildContext context) {
    if (!_finished) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final items = _items();
    final attempts = items.fold<int>(0, (s, e) => s + e.$2);
    final wrong = _wrongWordIds();
    final catalog = ref.read(wordCatalogProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.mode == QuizMode.study ? '오늘 학습 완료' : '복습 완료', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('정답 ${items.length} / 시도 $attempts', style: theme.textTheme.bodyLarge),
              const SizedBox(height: 24),
              if (wrong.isEmpty)
                Text('한 번에 다 맞혔다', style: theme.textTheme.bodyMedium)
              else
                Text('틀린 단어 ${wrong.length}개', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: wrong.length,
                  itemBuilder: (context, i) {
                    final w = catalog.wordById(wrong[i]);
                    if (w == null) return const SizedBox.shrink();
                    final tags = _tags[w.id] ?? [];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${w.expression}  ${w.reading}'),
                      subtitle: Text(w.meaningKo),
                      trailing: Wrap(
                        spacing: 4,
                        children: [for (final t in tags) Chip(label: Text(t.label), visualDensity: VisualDensity.compact)],
                      ),
                    );
                  },
                ),
              ),
              if (widget.mode == QuizMode.study)
                OutlinedButton(
                  onPressed: () async {
                    await ref.read(todayStudySetProvider.notifier).appendNextSet();
                    if (context.mounted) context.go('/quiz', extra: QuizMode.study);
                  },
                  child: const Text('다음 학습 시작'),
                ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () => context.go('/'), child: const Text('홈으로')),
            ],
          ),
        ),
      ),
    );
  }
}
```

라우터:
```dart
    GoRoute(
      path: '/quiz',
      builder: (context, state) => QuizScreen(mode: state.extra as QuizMode? ?? QuizMode.study),
    ),
    GoRoute(
      path: '/quiz/complete',
      builder: (context, state) => QuizCompleteScreen(mode: state.extra as QuizMode? ?? QuizMode.study),
    ),
```
`PlaceholderScreen` 클래스 삭제.

`test/features/quiz/quiz_complete_screen_test.dart`: 학습 모드에서 세트 아이템 3개 중 1개 attempts=2인 상태로 렌더 → `'정답 3 / 시도 4'`, `'틀린 단어 1개'`, `'다음 학습 시작'` 표시 확인. 복습 모드 → `'복습 완료'`, `'다음 학습 시작'` 없음.

- [ ] **Step 3: 통과 확인**

Run: `flutter test test/features/quiz && flutter analyze`
Expected: PASS, 에러 0.

- [ ] **Step 4: 커밋**

```bash
git add lib/features/quiz lib/core/router test/features/quiz
git commit -m "feat(quiz): single-loop reading quiz with answer card and completion summary"
```

---

### Task 10: 복습 필터 시트

**Files:**
- Create: `lib/features/review/review_filter_sheet.dart`
- Modify: `lib/features/home/home_screen.dart` (복습 카드 onTap)
- Test: `test/features/review/review_filter_sheet_test.dart`

**Interfaces:**
- Produces: `Future<void> showReviewFilterSheet(BuildContext context)` — 선택 시 `reviewSessionProvider.notifier.startNewSession(tag:)` 후 `/quiz` push (extra `QuizMode.review`).

- [ ] **Step 1: 실패 테스트**

```dart
  testWidgets('shows 전체 and tag chips with counts', (tester) async {
    // missTagCountsProvider override: {longVowel: 3, sokuon: 1}
    // 버튼 탭 → showReviewFilterSheet(context)
    // expect find.text('전체'), find.text('장음 3'), find.text('촉음 1'); '탁음' 은 0이라 미표시
  });
```
위 주석대로 실제 코드 작성. `ProviderScope(overrides: [missTagCountsProvider.overrideWith((ref) async => {ErrorTag.longVowel: 3, ErrorTag.sokuon: 1})])`.

- [ ] **Step 2: 구현**

```dart
Future<void> showReviewFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => const _ReviewFilterSheet(),
  );
}

class _ReviewFilterSheet extends ConsumerWidget {
  const _ReviewFilterSheet();

  Future<void> _start(BuildContext context, WidgetRef ref, ErrorTag? tag) async {
    await ref.read(reviewSessionProvider.notifier).startNewSession(tag: tag);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    context.push('/quiz', extra: QuizMode.review);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(missTagCountsProvider).valueOrNull ?? {};
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('복습', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(label: const Text('전체'), onPressed: () => _start(context, ref, null)),
                for (final tag in ErrorTag.values)
                  if ((counts[tag] ?? 0) > 0)
                    ActionChip(
                      label: Text('${tag.label} ${counts[tag]}'),
                      onPressed: () => _start(context, ref, tag),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```
홈 복습 카드 `onTap: () => showReviewFilterSheet(context)`.

- [ ] **Step 3: 통과·커밋**

Run: `flutter test test/features/review test/features/home`
```bash
git add lib/features/review lib/features/home test/features/review
git commit -m "feat(review): filter review session by miss tag"
```

---

### Task 11: 단어 추가 시트 + 클립보드 칩

**Files:**
- Create: `lib/features/words/add_word_sheet.dart`
- Modify: `lib/features/home/home_screen.dart` (단어 추가 카드, 클립보드 칩, `WidgetsBindingObserver`)
- Modify: `lib/features/explore/word_list_screen.dart` (`+` 아이콘)
- Test: `test/features/words/add_word_sheet_test.dart`

**Interfaces:**
- Produces: `Future<void> showAddWordSheet(BuildContext context, {String? initialExpression})`, `bool looksJapanese(String text)` (같은 파일, top-level)

- [ ] **Step 1: 실패 테스트**

```dart
  test('looksJapanese', () {
    expect(looksJapanese('把握'), isTrue);
    expect(looksJapanese('おぎなう'), isTrue);
    expect(looksJapanese('hello'), isFalse);
    expect(looksJapanese('把握\n生産'), isFalse);
    expect(looksJapanese('あ' * 21), isFalse);
  });

  testWidgets('saves user word with reading required for kanji', (tester) async {
    // DB + wordCatalogProvider 실제, dataVersion 세팅해 시딩 스킵
    // 시트 열기 → 표기 '把握' 입력, 저장 탭 → '읽기를 입력하세요' 에러 표시
    // 읽기 'はあく' 입력, 저장 → 시트 닫힘, catalog에 source 'user' 단어 1개, expression '把握'
  });

  testWidgets('existing expression shows 이미 있는 단어 and disables save', (tester) async {
    // 카탈로그에 '生産' 존재 → 표기 '生産' 입력 → '이미 있는 단어' 텍스트, 저장 버튼 onPressed null
  });
```
주석대로 실제 코드 작성.

- [ ] **Step 2: 구현**

```dart
final _jaRegex = RegExp(r'[぀-ヿ一-鿿]');
final _katakanaOnly = RegExp(r'^[゠-ヿー]+$');
final _kanji = RegExp(r'[一-鿿々]');

bool looksJapanese(String text) {
  final t = text.trim();
  return t.isNotEmpty && t.length <= 20 && !t.contains('\n') && _jaRegex.hasMatch(t);
}

Future<void> showAddWordSheet(BuildContext context, {String? initialExpression}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: AddWordSheet(initialExpression: initialExpression),
    ),
  );
}

class AddWordSheet extends ConsumerStatefulWidget { ... }
```
State:
- 컨트롤러 4개 (`expression`, `reading`, `meaning`, `source` 기본 `'뉴스'`).
- `expression` 변경 시 300ms 디바운스로 `WordRepository.findByExpression` → 있으면 `_existing = word`, 읽기·뜻 채우고 안내 `'이미 있는 단어'`, 저장 비활성.
- 저장 검증: 표기 비어있으면 `'표기를 입력하세요'`; 한자 포함(`_kanji`)인데 읽기 비었으면 `'읽기를 입력하세요'`; 한자 없고 읽기 비었으면 읽기=표기.
- 저장: `Word(id: 'user_${DateTime.now().millisecondsSinceEpoch}', expression, reading, meaningKo: meaning.isEmpty ? '' : meaning, type: _katakanaOnly.hasMatch(expression) ? WordType.katakana : WordType.other, source: 'user')` → `wordCatalogProvider.notifier.addUserWord` → `ref.invalidate(progressSummaryProvider); ref.invalidate(exploreProvider);` → pop.
- 필드 위젯 `Key('add-expression')`, `Key('add-reading')`, `Key('add-meaning')`, 저장 버튼 `Key('add-save')`.

홈: `_HomeBody`를 `ConsumerStatefulWidget`으로 바꾸고 `WidgetsBindingObserver` 믹스인. `initState`와 `didChangeAppLifecycleState(resumed)`에서 `Clipboard.hasStrings()` → `_clipboardAvailable` 세팅. 하단에 `if (_clipboardAvailable) ActionChip(avatar: Icon(Icons.content_paste), label: Text('클립보드에서 단어 추가'), onPressed: _addFromClipboard)`.
```dart
  Future<void> _addFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim() ?? '';
    if (!mounted) return;
    setState(() => _clipboardAvailable = false);
    if (!looksJapanese(text)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('클립보드에 일본어 단어가 없다')));
      return;
    }
    await showAddWordSheet(context, initialExpression: text);
  }
```
`단어 추가` 카드 onTap → `showAddWordSheet(context)`. 탐색 `+` → 동일.

- [ ] **Step 3: 통과·커밋**

Run: `flutter test test/features/words test/features/home test/features/explore && flutter analyze`
```bash
git add lib/features/words lib/features/home lib/features/explore test/features/words
git commit -m "feat(words): add user words via sheet and clipboard shortcut"
```

---

### Task 12: 설정 — 시험일·백업·데이터 초기화

**Files:**
- Create: `lib/application/services/backup_service.dart`
- Modify: `lib/features/settings/settings_screen.dart`
- Modify: `lib/application/providers/settings_provider.dart` (`resetProgress()`)
- Modify: `pubspec.yaml` (`share_plus`, `file_picker`)
- Test: `test/features/settings/settings_screen_test.dart`, `test/application/services/backup_service_test.dart`

**Interfaces:**
- Produces:
  - `class BackupService { Future<void> export(); Future<void> importFrom(String path); }` — `export`는 `Share.shareXFiles`, `importFrom`은 검증→교체. 검증 함수 `static Future<bool> isValidBackup(String path)`는 순수 sqflite로 테스트 가능.
  - `SettingsNotifier.resetProgress()`

- [ ] **Step 1: 의존성**

`pubspec.yaml` dependencies에 `share_plus: ^11.0.0`, `file_picker: ^10.0.0` 추가 후 `flutter pub get`. (버전은 `flutter pub add share_plus file_picker`로 최신 해석 사용.)

- [ ] **Step 2: 실패 테스트**

`test/application/services/backup_service_test.dart`:
```dart
  test('isValidBackup true for our schema, false for random file', () async {
    final dir = await Directory.systemTemp.createTemp('bk');
    final good = p.join(dir.path, 'good.db');
    final db = await AppDatabase.openAtPath(good);
    await db.close();
    expect(await BackupService.isValidBackup(good), isTrue);
    final bad = p.join(dir.path, 'bad.db');
    await File(bad).writeAsString('not a db');
    expect(await BackupService.isValidBackup(bad), isFalse);
    await dir.delete(recursive: true);
  });
```

`test/features/settings/settings_screen_test.dart` 추가:
```dart
  testWidgets('shows exam date and opens date picker', (tester) async {
    // settingsProvider override로 examDate 2026-12-06
    // expect find.text('2026.12.06')
    // tap → expect find.byType(DatePickerDialog)
  });
  testWidgets('shows 다음 JLPT button, 백업 내보내기, 백업 가져오기', ...);
```

- [ ] **Step 3: 구현**

`backup_service.dart`:
```dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/db/database.dart';

class BackupService {
  static Future<bool> isValidBackup(String path) async {
    Database? db;
    try {
      db = await openDatabase(path, readOnly: true);
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('words','word_progress')",
      );
      return rows.length == 2;
    } catch (_) {
      return false;
    } finally {
      await db?.close();
    }
  }

  Future<void> export() async {
    final path = await AppDatabase.filePath;
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    await Share.shareXFiles([XFile(path, name: 'jlpt-backup-$stamp.db')]);
  }

  /// 파일 선택 → 검증 → DB 닫고 교체. 성공 시 true.
  Future<bool> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles();
    final picked = result?.files.single.path;
    if (picked == null) return false;
    return importFrom(picked);
  }

  Future<bool> importFrom(String sourcePath) async {
    if (!await isValidBackup(sourcePath)) return false;
    await AppDatabase.close();
    final target = await AppDatabase.filePath;
    await File(sourcePath).copy(target);
    return true;
  }
}
```

`settings_provider.dart`에 추가:
```dart
  Future<void> resetProgress() async {
    final db = await ref.read(databaseProvider.future);
    await ProgressRepository(db).resetAllProgress();
    ref.invalidate(progressSummaryProvider);
    ref.invalidate(todayStudySetProvider);
    ref.invalidate(missTagCountsProvider);
  }
```

`settings_screen.dart` 섹션 순서: 시험일 / 테마 / 백업 / 데이터 초기화.
```dart
// 시험일
ListTile(
  title: const Text('시험일'),
  subtitle: Text(_fmt(examDate)),  // yyyy.MM.dd
  trailing: const Icon(Icons.chevron_right),
  onTap: () async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: examDate.isBefore(now) ? now : examDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3, 12, 31),
    );
    if (picked != null) ref.read(settingsProvider.notifier).updateExamDate(picked);
  },
),
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: TextButton(
    onPressed: () => ref.read(settingsProvider.notifier).updateExamDate(AppSettings.nextJlptDate(DateTime.now())),
    child: Text('다음 JLPT (${_fmt(AppSettings.nextJlptDate(DateTime.now()))})'),
  ),
),
```
백업:
```dart
ListTile(title: const Text('백업 내보내기'), onTap: () => BackupService().export()),
ListTile(
  title: const Text('백업 가져오기'),
  onTap: () async {
    final ok = await BackupService().pickAndImport();
    if (!context.mounted) return;
    if (ok) {
      ref.invalidate(databaseProvider);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('가져왔다. 앱을 다시 실행해라')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('백업 파일이 아니다')));
    }
  },
),
```
데이터 초기화 다이얼로그의 `확인` → `ref.read(settingsProvider.notifier).resetProgress()` 후 pop.

- [ ] **Step 4: 통과·커밋**

Run: `flutter test test/features/settings test/application/services && flutter analyze`
```bash
git add pubspec.yaml pubspec.lock lib/application lib/features/settings test/features/settings test/application/services
git commit -m "feat(settings): configurable exam date, database backup export/import, working progress reset"
```

---

### Task 13: 데이터 병합·검증·적용

**Files:**
- Create: `tool/merge_audit.py`
- Modify: `assets/data/n2_words.json`
- Test: 스크립트 검증 + `flutter test`

전제: 검수 에이전트 출력 `<scratchpad>/audit/out/batch_01..10.json`이 모두 존재하고 `validate.py` `TOTAL 0`.

- [ ] **Step 1: 병합 스크립트**

`tool/merge_audit.py`:
```python
#!/usr/bin/env python3
"""검수된 배치를 병합해 assets/data/n2_words.json을 만든다.
사용: python3 tool/merge_audit.py <out_dir> <in_dir>
"""
import glob, json, re, sys
out_dir, in_dir = sys.argv[1], sys.argv[2]
KANA = re.compile(r'^[぀-ゟ゠-ヿー]+$')
TYPES = {'on', 'kun', 'katakana', 'other'}

merged = []
for f in sorted(glob.glob(f'{out_dir}/batch_*.json')):
    src = json.load(open(f.replace(out_dir, in_dir)))
    out = json.load(open(f))
    assert [x['id'] for x in src] == [x['id'] for x in out], f'id order mismatch in {f}'
    merged.extend(out)

ids = [x['id'] for x in merged]
assert len(ids) == len(set(ids)) == 1904, len(ids)
for x in merged:
    assert KANA.match(x['reading']), (x['id'], x['reading'])
    assert x['type'] in TYPES, x['id']
    assert isinstance(x['is_trap'], bool), x['id']
    core = x['expression'].replace('～', '')
    stem = core[:-1] if re.search(r'[぀-ゟ]$', core) and len(core) > 1 else core
    assert stem in x['example']['ja'], (x['id'], x['expression'], x['example']['ja'])

final = [{
    'id': x['id'], 'expression': x['expression'], 'reading': x['reading'],
    'meaning_en': x.get('meaning_en', ''), 'meaning_ko': x['meaning_ko'],
    'type': x['type'], 'is_trap': x['is_trap'], 'example': x['example'],
} for x in merged]
json.dump(final, open('assets/data/n2_words.json', 'w'), ensure_ascii=False, indent=2)
from collections import Counter
print('written', len(final), Counter(x['type'] for x in final), 'trap', sum(x['is_trap'] for x in final))
```

- [ ] **Step 2: 실행**

```bash
python3 tool/merge_audit.py <scratchpad>/audit/out <scratchpad>/audit/in
```
Expected: `written 1904 ...`. assert 실패 시 해당 배치 재검수.

- [ ] **Step 3: 샘플 검토**

무작위 30개를 뽑아 사람이 읽는다 (`python3 -c "import json,random; w=json.load(open('assets/data/n2_words.json')); [print(x) for x in random.sample(w,30)]"`). 배신 단어 목록(`is_trap`) 전체 출력해 오탐 제거.

- [ ] **Step 4: 전체 테스트·커밋**

Run: `flutter test && flutter analyze`
```bash
git add assets/data/n2_words.json tool/merge_audit.py
git commit -m "data: audit and normalize N2 word data (v2 schema with type/is_trap)"
```

---

### Task 14: 최종 검증

- [ ] **Step 1:** `flutter analyze` 에러·경고 0.
- [ ] **Step 2:** `flutter test` 전부 PASS.
- [ ] **Step 3:** `grep -rn "JlptLevel\|n3_\|N3" lib test` 결과 0 (마이그레이션 SQL의 `'N3'` 문자열 제외).
- [ ] **Step 4:** iOS 시뮬레이터 실행. 확인 항목:
  - 홈 D-day가 `D-78`(2026-09-19 기준) 근처.
  - 학습 시작 → 퀴즈 → 오답 시 카드 공개 + 다음 → 완료 화면 틀린 단어에 태그 칩.
  - 복습 카드 → 시트 → 태그 칩 → 퀴즈.
  - 단어 추가 → 탐색 `추가한 단어` 필터에 표시.
  - 설정 시험일 변경 → 홈 D-day 갱신.
  - 백업 내보내기 공유 시트 표시.
- [ ] **Step 5:** `pubspec.yaml` version `1.2.0+6`으로 올리고 커밋 `chore: bump version to 1.2.0+6`.
