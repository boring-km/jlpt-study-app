# N2 집중 리디자인 설계

작성일: 2026-09-19. 근거 문서: `~/Downloads/jlpt-n2-app-requirements.md` (시험일 2026-12-06, D-78).

## 목표

1. 매일 쓰게 만드는 단순한 루프: 홈 → 퀴즈 한 화면 → 완료.
2. 시험에서 실제로 틀리는 지점(장음·촉음·탁음·훈독)을 퀴즈가 직접 공략.
3. N3 제거, N2 단일 레벨.
4. 사용자 단어 추가, 백업, 시험일 변경.
5. 1,906개 단어 데이터 전수 검수.

## 비목표

- SRS(SM-2) 간격 반복. 이후 작업.
- CSV 임포트/익스포트. DB 파일 백업으로 대체.
- `hanja_ko`(한국어 한자음) 필드. Unihan 작업 별도.
- iOS 공유 익스텐션. 클립보드 감지로 대체.
- 수동 오답 사유 태깅 UI. 자동 태깅만.
- 통계·가나표·탐색 플래시카드 화면 재설계. N3 제거에 따른 최소 수정만.

## 1. 데이터

### 1.1 `assets/data/n2_words.json` v2 스키마

```json
{
  "id": 1,
  "expression": "丸ごと",
  "reading": "まるごと",
  "meaning_ko": "통째로, 전부",
  "type": "kun",
  "is_trap": false,
  "example": { "ja": "りんごを丸ごと食べた。", "reading": "りんごをまるごとたべた。", "ko": "사과를 통째로 먹었다." }
}
```

- `id`: 기존 값 유지. 앱 내 id는 `n2_0001` 형식 그대로.
- `expression`: 표제어. 접사는 `～` 유지(`～位`, `長～`). 괄호 보조설명·공백 제거. 상용 한자 표기가 표준이면 한자로.
- `reading`: 순수 가나만(히라가나, 가타카나, `ー`). `～`·괄호·공백 금지. 접사는 접사 부분만.
- `type`: `on`(한자 음독어) | `kun`(한자 훈독 동사·형용사·명사) | `katakana` | `other`(가나만, 접사 등).
- `is_trap`: 한국어 한자음으로 뜻을 유추하면 틀리는 단어.
- `meaning_en`: 유지하되 앱은 읽지 않음.
- 진짜 중복 2건 삭제: id 1072(率直), 1794(やかん). 같은 한자 다른 읽기 7쌍(～日, ～所, ～等, 紅葉, 長～, 留まる, 鈍い)은 유지.

### 1.2 검수 절차

1. 스크립트: 중복 2건 제거 → 10개 배치(~190개)로 분할 → 휴리스틱으로 `type` 초벌.
2. LLM 에이전트 10개 병렬. 배치별 검수 규칙:
   - `reading` 정확성, 순수 가나.
   - `meaning_ko`: 자연스러운 한국어, 1~3개 의미 쉼표 구분, 마침표 없음, 동사는 `-다`형. 배신 단어는 올바른 뉘앙스가 첫 의미.
   - `example.ja`: 자연스러운 N2 수준 문장, 표제어(활용형 허용) 반드시 포함, 10~25자.
   - `example.reading`: 문장 전체 히라가나(가타카나어는 가타카나 유지), 구두점 원문 그대로.
   - `example.ko`: 자연스러운 번역.
   - `type`, `is_trap` 확정.
   - id 보존, 항목 삭제·추가 금지. 변경 항목은 별도 로그.
3. 스크립트 검증: 개수 1,904, id 유일, reading 순수 가나, 예문에 표제어(`～` 제거 후) 포함, type 값 유효. 실패 항목은 재검수.
4. 병합 → `n2_words.json` 교체. `batch_*.json`, `n2_raw.csv`, `n3*` 삭제.

### 1.3 데이터 버전

`app_settings.data_version` = `2`. 카탈로그 로드 시 저장된 값이 낮으면 에셋에서 upsert(id 충돌 시 텍스트 필드 갱신, `created_at` 보존). 에셋에 없는 `source='n2'` 단어와 그 진도는 삭제.

## 2. DB 스키마 v3

`words` 추가 컬럼:
- `type TEXT NOT NULL DEFAULT 'other'`
- `is_trap INTEGER NOT NULL DEFAULT 0`
- `source TEXT NOT NULL DEFAULT 'n2'` (`n2` | `user`)
- `jlpt_level` 컬럼은 남기되 앱은 읽지 않음. 쓰기는 `'N2'` 고정.

새 테이블:
```sql
CREATE TABLE miss_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  word_id TEXT NOT NULL REFERENCES words(id),
  tag TEXT NOT NULL,          -- long_vowel | sokuon | dakuten | meaning | other
  created_at TEXT NOT NULL
);
CREATE INDEX idx_miss_log_tag ON miss_log (tag, created_at);
```

마이그레이션 v2→v3 순서:
1. `words`에 컬럼 3개 추가.
2. N3 삭제: `review_session_items`, `daily_study_set_items`, `word_progress`에서 N3 word_id 행 삭제 → `daily_study_sets WHERE jlpt_level='N3'` 삭제 → `words WHERE jlpt_level='N3'` 삭제.
3. `miss_log` 생성.
4. `data_version` 리셋(삭제) → 다음 카탈로그 로드에서 v2 에셋 upsert.

기존 `daily_study_sets.status` 값 `flashcard`/`quiz_reading`/`quiz_meaning`은 읽을 때 `quiz`로 매핑. 컬럼 변경 없음.

## 3. 도메인 모델

- `JlptLevel` 삭제. `WordBadge` 삭제.
- `Word`: `+ WordType type`, `+ bool isTrap`, `+ String source`. `- jlptLevel`. `hasKanji` = expression에 한자 문자 포함.
- `WordType { on, kun, katakana, other }`.
- `ErrorTag { longVowel, sokuon, dakuten, meaning, other }` ↔ 문자열 `long_vowel` 등. 표시명 장음/촉음/탁음/뜻/기타.
- `StudyStage { quiz, completed }`.
- `TodayStudyItem`: `passed`(←`reading_passed`), `attempts`(←`reading_attempts`). `meaning_*` 컬럼은 무시.
- `ReviewSessionItem` 동일 축소.
- `WordProgress` 변경 없음.
- `AppSettings`: `examDate` 기본값 = `nextJlptDate(now)` (7월·12월 첫째 일요일 중 오늘 이후 가장 가까운 날, 당일 포함).

Repository 변경: 레벨 파라미터 전부 제거. 추가:
- `WordRepository.insertUserWord`, `findByExpression`, `getReadingsByExpression`(같은 한자 다른 읽기 제외용), `getRandomReadingsStartingWith`, `getRandomMeanings`.
- `ProgressRepository.getUncompletedWordIds({WordType? type, String? source})`.
- `MissLogRepository.add(wordId, tag)`, `recentWordIdsByTag(tag, limit)`, `countByTag()`.

## 4. 오답 생성기 `DistractorGenerator`

순수 Dart, `lib/domain/services/distractor_generator.dart`. 입력: 정답 읽기(히라가나), 제외 읽기 집합, 보충용 풀. 출력: `List<Distractor(reading, ErrorTag)>` 3개, 정답·서로 간 중복 없음.

변형 규칙(각각 후보 여러 개 생성):
- 장음 `longVowel`
  - 삭제: お단 가나 뒤 `う`, え단 뒤 `い`, `ー` 제거.
  - 추가: お단 가나 뒤 `う` 삽입, え단 뒤 `い` 삽입(이미 있으면 제외).
- 촉음 `sokuon`
  - 삭제: `っ` 제거.
  - 추가: か·さ·た·ぱ행 가나 앞(첫 글자 제외)에 `っ` 삽입.
- 탁음 `dakuten`
  - 청음↔탁음 토글(か↔が, さ↔ざ, た↔だ, は↔ば), は행↔ぱ행 반탁음 토글. 위치 하나만.

선택: 카테고리별 후보를 섞어 카테고리 순환으로 3개 채움(장음·촉음·탁음 하나씩 우선). 후보 부족 시 풀에서 첫 글자 같은 실제 읽기로 보충, 태그 `other`. 읽기에 가타카나가 섞이면 변형 생략하고 풀만 사용.

가나 없는 단어(`hasKanji == false`): 읽기 대신 **뜻 4지선다**. 오답 = 카탈로그 랜덤 `meaning_ko` 3개. 오답 태그 `meaning`.

## 5. 학습 흐름

### 5.1 오늘 세트 구성 (`createTodaySet`)

목표 수 `N = max(1, ceil(미완료 n2 단어 수 / 남은 일수))`. 시험일 지났으면 `N = 10`.
1. `source='user'` 미완료 전부(최대 N).
2. `type='kun'` 미완료 랜덤 `min(6, 남은 슬롯)`. 상수 `kKunMinPerDay = 6`.
3. 나머지 미완료 랜덤으로 채움.
4. 약점(`is_completed=1 AND miss_count>0`) 상위 `min(5, weakCount)` 추가. 목표 수에 포함 안 함.
5. 순서 셔플.

"다음 학습 시작": 오늘 세트 삭제 대신 1~4 규칙으로 뽑은 항목을 `display_order` 이어서 append, status를 `quiz`로. 기존 항목 결과 보존.

### 5.2 퀴즈 화면 `/quiz`

하나의 `QuizScreen`이 학습·복습 공용. `QuizSource` 인터페이스: `items`, `recordResult(wordId, passed, tag)`, `complete()`. 구현체 `StudyQuizSource`(todayStudySetProvider), `ReviewQuizSource`(reviewSessionProvider).

화면:
- 상단: `현재 / 전체`, 닫기 버튼(진행 저장됨, 홈으로).
- 표제어 크게. `is_trap`이면 정답 공개 후 "배신 단어" 칩.
- 선택지 4개 + "모르겠다"(태그 `other`).
- 정답: 초록 표시, 카드에 읽기·뜻·예문(ja/reading/ko) 공개, 1.0초 후 자동 진행.
- 오답: 빨강 + 정답 초록, 카드 공개, "다음" 탭까지 대기. 해당 단어 큐 끝에 재추가. `miss_log` 기록, `miss_count+1`.
- 큐 소진 → 완료 화면.

### 5.3 완료 화면 `/quiz/complete`

- `정답 X / 시도 Y`, 틀린 단어 목록(표제어·읽기·뜻·태그 칩).
- 학습 모드: 통과 단어 `markCompleted`, 버튼 "다음 학습 시작" / "홈으로".
- 복습 모드: 버튼 "홈으로".
- 컨페티 없음.

### 5.4 복습

홈 "복습" 카드 → 바텀시트 필터 칩: 전체 / 장음 / 촉음 / 탁음 / 뜻 (각 칩에 개수). 선택 → 세션 생성 → `/quiz`.
- 전체: 기존 약점 70% + 완료 30% 블렌드, 20개.
- 태그: `miss_log`에서 해당 태그 최근 순 distinct word_id 20개. 부족하면 블렌드로 채움.

### 5.5 삭제 화면

`flashcard_screen`, `quiz_reading_screen`, `quiz_meaning_screen`, `wrong_answers_screen`, `review_screen`(퀴즈 부분). 라우트 `/study/*`, `/review`, `/review/today` 제거. 탐색 플래시카드 브라우저(`explore_flashcard_screen`)는 유지.

## 6. 홈

- `D-78` (시험일 지나면 `D+n`), 우측 가나표·테마 아이콘.
- `오늘 x / y 완료`, `N2 완료 / 1904` + 진행바.
- 큰 버튼: `학습 시작` / `이어하기` / `오늘 학습 완료 ✓`(비활성) + 완료 시 `다음 학습 시작`.
- 시험일 경과해도 버튼 유지. 복습 전용 잠금 제거.
- 작은 카드 2개: `복습`(약점 n개), `단어 추가`.
- 클립보드: 앱 활성화(`resumed`) 시 `Clipboard.hasStrings()`가 true면 홈 하단에 "클립보드에서 단어 추가" 액션 칩 표시. 탭하면 그때 `getData` → 일본어(한자·가나 포함, 20자 이하, 줄바꿈 없음)면 추가 시트에 프리필. 같은 텍스트는 한 번만 제안(메모리 보관). iOS 붙여넣기 권한 프롬프트는 탭 시에만 발생.

## 7. 단어 추가 시트 `AddWordSheet`

- 필드: 표기(필수), 읽기(표기에 한자 있으면 필수, 없으면 자동 복사), 뜻(선택), 출처(기본 `뉴스`, 자유 입력).
- 표기 입력 시 카탈로그 정확 일치 조회 → 있으면 읽기·뜻 자동 채움 + "이미 있는 단어" 안내, 저장 비활성.
- 저장: id `user_<epochMillis>`, `source='user'`, `type` = 가타카나만이면 `katakana`, 그 외 `other`, `is_trap=0`, 예문 없음. 즉시 카탈로그 갱신.
- 진입점: 홈 카드, 탐색 리스트 `+` 아이콘, 클립보드 칩.
- 탐색 리스트 필터 칩: 전체 / 완료 / 미완료 / 추가한 단어.

## 8. 설정

- 시험일: 현재 날짜 표시, 탭 → `showDatePicker`(오늘 ~ +3년). 하단 `다음 JLPT (YYYY.MM.DD)` 버튼.
- 테마: 기존.
- 백업 내보내기: DB 파일 `share_plus`로 공유.
- 백업 가져오기: `file_picker`로 파일 선택 → 임시 열어 `words` 테이블 존재 확인 → DB 닫고 파일 교체 → 프로바이더 전체 invalidate. 실패 시 원본 유지, 에러 스낵바.
- 데이터 초기화: 현재 동작 없는 스텁. `word_progress`, `daily_study_*`, `review_session*`, `miss_log` 비움. 사용자 단어는 유지.

의존성 추가: `share_plus`, `file_picker`.

## 9. 통계·탐색 최소 수정

- 통계: N3 관련 수치 제거. 완료 수·약점 수·태그별 오답 수(`miss_log.countByTag`) 표시.
- 탐색 리스트: 레벨 필터 제거, §7 필터. 뱃지 제거.

## 10. 테스트

- `DistractorGenerator`: 각 변형 규칙 단위 테스트, 중복·정답 제외, 부족 시 풀 보충, 가타카나 스킵.
- `AppSettings.nextJlptDate`: 7월 전 / 7~12월 사이 / 12월 시험 당일 / 12월 시험 후.
- 마이그레이션 v3: v2 DB에 N3 행 있는 상태로 업그레이드 → N3 행 0, 컬럼 존재, miss_log 존재.
- 카탈로그 upsert: data_version 낮을 때 텍스트 갱신·진도 보존·삭제된 id 정리.
- `createTodaySet` 구성: user 우선, kun 최소 6, 약점 추가, append 동작.
- `MissLogRepository`, 태그 필터 복습 선택.
- 위젯: QuizScreen 정답/오답 흐름, AddWordSheet 중복 안내, SettingsScreen DatePicker, HomeScreen 버튼 상태.
- 기존 N3·삭제 화면 테스트 제거.
- 데이터 검증 스크립트 통과.

## 11. 작업 순서·커밋

1. `data: audit and normalize N2 word data (v2 schema)` — 에이전트 병렬, 코드와 독립.
2. `refactor: remove N3 level and simplify study stages` — enum·뱃지·에셋·마이그레이션 v3·모델 축소.
3. `feat: configurable exam date` — 설정 UI, 기본값 계산, 시험 후 버튼 유지.
4. `feat: reading quiz with weakness-targeted distractors and miss tags` — 생성기, miss_log, QuizScreen, 완료 화면, 세트 구성, 복습 필터.
5. `feat: add user words with clipboard shortcut` — 시트, 클립보드 칩, 탐색 필터.
6. `feat: database backup export/import and working data reset`.
7. 검증: `flutter analyze`, `flutter test`, 시뮬레이터 실행 확인.
