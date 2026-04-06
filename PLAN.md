# JLPT N2 앱 기획서

## 개요
- **앱 이름:** JLPT N2
- **목표:** JLPT N2/N3 단어 암기 iOS 앱
- **타겟:** 한자 읽기(히라가나)를 공부하는 한국어 사용자
- **디자인:** 미니멀, 다크모드 지원 (앱 내 토글)
- **플랫폼:** iOS only, 완전 오프라인 동작

### 디자인 키 컬러

| 역할 | 색상 | 용도 |
|------|------|------|
| Primary | `#1D4ED8` | 주요 CTA, 진행 상태, 활성 탭, 강조 포인트 |
| Accent | `#F59E0B` | 정답률/배지/하이라이트, 완료 연출 보조 색상 |

- 기본 방향: 차분한 뉴트럴 베이스 위에 블루를 주색으로 쓰고, 앰버를 보조 강조색으로 제한적으로 사용
- 다크모드에서도 동일한 색상 체계를 유지하되, 배경과 대비를 충분히 확보

### 디자인 토큰

#### Color Tokens

| 토큰 | 값 | 용도 |
|------|------|------|
| `color.primary` | `#1D4ED8` | 주요 버튼, 활성 상태, 링크성 강조 |
| `color.accent` | `#F59E0B` | 배지, 하이라이트, 완료 연출 |
| `color.success` | `#16A34A` | 정답 피드백, 완료 상태 |
| `color.error` | `#DC2626` | 오답 피드백, 경고성 상태 |
| `color.background.light` | `#F8FAFC` | 라이트모드 기본 배경 |
| `color.surface.light` | `#FFFFFF` | 카드, 시트, 입력 영역 |
| `color.text.primary.light` | `#0F172A` | 라이트모드 본문 텍스트 |
| `color.text.secondary.light` | `#475569` | 라이트모드 보조 텍스트 |
| `color.background.dark` | `#0B1220` | 다크모드 기본 배경 |
| `color.surface.dark` | `#111827` | 다크모드 카드, 시트 |
| `color.text.primary.dark` | `#E5E7EB` | 다크모드 본문 텍스트 |
| `color.text.secondary.dark` | `#94A3B8` | 다크모드 보조 텍스트 |
| `color.border.light` | `#E2E8F0` | 라이트모드 구분선 |
| `color.border.dark` | `#1F2937` | 다크모드 구분선 |

#### Typography Tokens

| 토큰 | 값 | 용도 |
|------|------|------|
| `font.family.base` | `Pretendard` | 한국어 UI 기본 글꼴 |
| `font.family.jp` | `NotoSansJP` | 일본어 단어/예문 표시 |
| `font.size.display` | `32` | D-Day, 큰 헤드라인 |
| `font.size.title` | `24` | 화면 타이틀 |
| `font.size.body` | `16` | 기본 본문 |
| `font.size.caption` | `13` | 보조 정보, 라벨 |
| `font.weight.regular` | `400` | 본문 |
| `font.weight.medium` | `500` | 버튼, 보조 강조 |
| `font.weight.bold` | `700` | 타이틀, 핵심 수치 |

#### Radius / Spacing / Motion Tokens

| 토큰 | 값 | 용도 |
|------|------|------|
| `radius.sm` | `8` | 작은 칩, 태그 |
| `radius.md` | `14` | 카드, 버튼 |
| `radius.lg` | `20` | 큰 카드, 모달 |
| `spacing.xs` | `4` | 미세 간격 |
| `spacing.sm` | `8` | 라벨/아이콘 간격 |
| `spacing.md` | `16` | 기본 내부 여백 |
| `spacing.lg` | `24` | 섹션 간격 |
| `spacing.xl` | `32` | 큰 블록 간격 |
| `motion.fast` | `150ms` | 버튼, 선택 피드백 |
| `motion.normal` | `250ms` | 화면 전환, 카드 플립 |
| `motion.slow` | `400ms` | 완료 연출, 강조 모션 |

#### Component Usage Rules

- 주요 CTA는 `color.primary` 단색 버튼을 기본으로 사용
- 정답/오답 피드백은 각각 `color.success`, `color.error`를 사용하고 Primary/Accent와 혼용하지 않음
- N2/N3 뱃지는 레벨 구분보다 정보 태깅 목적이므로 중립 베이스 위에 텍스트 중심으로 표현
- 완료 화면의 시각 효과는 `color.primary + color.accent` 조합을 사용하고 과도한 다색 사용은 피함
- 일본어 본문은 `font.family.jp`, 나머지 UI는 `font.family.base`를 기본으로 사용

---

## 설정

| 항목 | 기본값 | 비고 |
|------|--------|------|
| 시험 날짜 | 2026.07.05 | 설정 화면에서 변경 가능 |
| 하루 학습량 | 자동 계산 | `ceil(미완료 단어 수 ÷ 남은 날 수)`, 읽기 전용 표시 |
| 다크모드 | 시스템 따름 | 앱 내 토글로 시스템 / 라이트 / 다크 선택 가능 |

- 당일 학습 미완료 시 → 남은 날 기준으로 **자동 재계산**
- 시험 날짜 경과 시 → **복습 전용 모드** 자동 전환
- 하루 기준: 기기 로컬 시간 기준
- 진도 저장: 로컬 전용 (백업 없음)
- 하루 학습량은 **개수만 표시**하며 퍼센트로 환산하지 않음
- 오늘의 학습 세트는 하루 동안 고정되며, 앱 재실행 후에도 유지됨

---

## 학습 순서

- **N3 (2,046개) 전부 완료 → 자동으로 N2 (1,905개) 시작**
- 오늘의 단어 배정: 미완료 단어 중 **랜덤**으로 할당량만큼 추출
- 모든 화면에서 단어별 **N2 / N3 뱃지** 항상 표시
- 한자 없는 단어(히라가나/가타카나)도 포함, 그대로 표시
- 오늘의 단어 배정은 해당 날짜에 최초 1회 생성 후 고정

---

## 네비게이션 구조

바텀 탭 바 4개:

```
┌─────────────────────┐
│      콘텐츠 영역     │
├─────────────────────┤
│  🏠    🔍   📊  ⚙️  │
│  홈  탐색 통계 설정  │
└─────────────────────┘
```

---

## 화면 목록

1. 홈
2. 오늘의 학습 — 플래시카드
3. 오늘의 학습 — 1단계 퀴즈 (읽기)
4. 오늘의 학습 — 2단계 퀴즈 (뜻)
5. 오답노트
6. 학습 완료
7. 복습 퀴즈
8. 탐색 — 단어 리스트 / 플래시카드 브라우저
9. 통계
10. 히라가나 / 가타카나 표
11. 설정

---

## 화면별 상세 설계

---

### 1. 홈

```
┌─────────────────────┐
│  D-90        N3 진행중│
│  오늘 12/44  ━━━━━━  │
│  N3 123/2046         │
├─────────────────────┤
│  ┌───────────────┐  │
│  │  오늘 학습 시작  │  │
│  └───────────────┘  │
│  ┌──────┐ ┌──────┐  │
│  │ 복습  │ │ 가나표│  │
│  └──────┘ └──────┘  │
└─────────────────────┘
```

| 요소 | 내용 |
|------|------|
| D-DAY | `D-90` 크게 표시 |
| 현재 레벨 | `N3 진행 중` 뱃지 |
| 오늘 진도 | `오늘 12 / 44 완료` 프로그레스 바 |
| 전체 진도 | `N3 123 / 2,046` |
| 버튼 (큰 카드) | 오늘 학습 시작 / 이어하기 |
| 버튼 (작은 카드 2개) | 복습 / 히라가나·가타카나 표 |

- 복습 버튼: 완료 단어가 없으면 비활성
- 오늘 학습 완료 시: 진도 100% 표시만 (별도 메시지 없음)
- 시험 날짜 경과 후에는 `오늘 학습 시작` 대신 `복습 시작`만 노출

---

### 2. 오늘의 학습 — 플래시카드

| 요소 | 내용 |
|------|------|
| 상단 | 진도 `1 / 44` + N2/N3 뱃지 |
| 앞면 | 한자(없으면 히라가나/가타카나) 크게, 가운데 |
| 탭하면 | **좌우 플립 애니메이션** 으로 뒤집기 |
| 뒷면 | 히라가나 읽기 + 한국어 뜻 + 예문(일본어/한국어) |
| 이동 | 스와이프 or 이전/다음 버튼 |
| 마지막 카드 후 | `1단계 퀴즈 시작` 버튼 |
| 중간 이탈 | 처음부터 다시 |

---

### 3. 오늘의 학습 — 1단계 퀴즈 (읽기)

| 요소 | 내용 |
|------|------|
| 상단 | 진도 `1 / 44` + N2/N3 뱃지 |
| 질문 | 한자(없으면 히라가나/가타카나) 크게 |
| 선택지 | 히라가나 4개 버튼 |
| 오답 선택지 | **reading의 첫 글자 또는 첫 음절이 같은 단어**에서 3개 추출 |
| 추가 버튼 | `모르겠다` → 오답 처리, 오늘 세트에서 계속 반복 |
| 선택 후 | 정답: 초록 / 오답: 빨강 즉시 표시 → **1.5초 후 자동 다음** |
| 마지막 후 | 오답노트 화면으로 이동 |
| 중간 이탈 | 현재 단계만 처음부터 다시 |

- **"모르겠다" 처리**: 오답 처리되어 오늘 세트에 남음. 다음날로 넘어가지 않음. 반드시 정답을 맞혀야 완료.

---

### 4. 오늘의 학습 — 2단계 퀴즈 (뜻)

1단계 전체 통과 후 진행.

| 요소 | 내용 |
|------|------|
| 상단 | 진도 `1 / 44` + N2/N3 뱃지 |
| 질문 | 한자(없으면 히라가나, 가타카나면 가타카나) 크게 |
| 버튼 | `알아` / `몰라` |
| 버튼 선택 후 | 한국어 뜻 + 예문 공개 |
| `몰라` 선택 시 | 오답 처리, 오늘 세트 재퀴즈 시 포함 |
| 마지막 후 | 오답노트 화면으로 이동 |
| 중간 이탈 | 현재 단계만 처음부터 다시 |

- 2단계는 자가평가 방식으로 유지하며, 통계도 자가평가 기반 결과로 집계

---

### 5. 오답노트

1단계 / 2단계 퀴즈 종료 후 공통으로 사용.

| 요소 | 내용 |
|------|------|
| 결과 요약 | `38 / 44 정답` |
| 오답 목록 | 한자 + 히라가나 + 한국어 뜻 + N2/N3 뱃지 |
| 오답 탭하면 | **그 자리에서 예문까지 펼쳐보기** |
| 버튼 (오답 있을 때) | `다시 퀴즈` (전체 세트 재시작) |
| 버튼 (전부 맞았을 때) | `다음 단계로` (1단계→2단계) 또는 `완료` (2단계→완료 화면) |

---

### 6. 학습 완료

| 요소 | 내용 |
|------|------|
| 연출 | **시각적 이펙트** (컨페티, 애니메이션 등) |
| 통계 | 총 시도 횟수, 최종 정답률 |
| 전체 진도 | `N3 167 / 2,046` 업데이트 |
| 버튼 | `복습하기` / `홈으로` |

---

### 7. 복습 퀴즈

- 완료된 단어 중 **랜덤 20개** 자동 선택
- 완료 단어가 20개 미만이면 가능한 개수만큼만 출제
- **1단계(읽기) → 2단계(뜻)** 순서로 진행
- 완료 처리 없음, 결과(오답노트)만 보여주고 끝

---

### 8. 탐색

바텀 탭 `탐색` 진입 시 모드 선택 화면:

```
┌─────────────────────┐
│  [ 단어 리스트  ]   │
│  [ 플래시카드   ]   │
└─────────────────────┘
```

#### 단어 리스트

| 요소 | 내용 |
|------|------|
| 검색 바 | 한자 / 히라가나 / 한국어로 검색 |
| 필터 | N2 / N3 / 완료 / 미완료 |
| 목록 | 한자 + 히라가나 + 한국어 뜻 + N2/N3 뱃지 |
| 단어 탭하면 | **그 자리에서** 예문까지 펼쳐보기 |

#### 플래시카드 브라우저

| 요소 | 내용 |
|------|------|
| 필터 | N2 / N3 / 완료 / 미완료 |
| 카드 앞면 | 한자(없으면 히라가나/가타카나), 루비 없음 |
| 탭하면 | 좌우 플립 → 히라가나 + 한국어 뜻 + 예문 |
| 이동 | 스와이프 or 이전/다음 버튼 |
| 중간 이탈 | 처음부터 다시 |

---

### 9. 통계

| 요소 | 내용 |
|------|------|
| 날짜별 학습량 | 달력 또는 막대 그래프 |
| 정답률 추이 | 1단계 / 2단계 퀴즈별 정답률 |
| 연속 학습일 | 현재 스트릭 표시 |

---

### 10. 히라가나 / 가타카나 표

| 요소 | 내용 |
|------|------|
| 탭 | 히라가나 / 가타카나 전환 |
| 표 | 50음도 표 형태 |
| 각 칸 | 문자 + 로마자 발음 표기 (예: あ / a) |
| 인터랙션 | 보기만 (별도 기능 없음) |

---

### 11. 설정

| 요소 | 내용 |
|------|------|
| 시험 날짜 | 날짜 선택 (Date Picker) |
| 하루 학습량 | 자동 계산값 표시 (읽기 전용) |
| 다크모드 | 시스템 / 라이트 / 다크 선택 |
| 앱 정보 | 버전 |

---

## 전체 학습 흐름

```
① 플래시카드
   오늘의 단어 N개 (랜덤 추출)
   앞면: 한자 → 탭 → 좌우 플립 → 뒷면: 히라가나 + 뜻 + 예문
        ↓
② 1단계 퀴즈 — 읽기 (4지선다 + 모르겠다)
   한자 → 히라가나 고르기
   유사 리딩 오답 3개 / 선택 즉시 피드백 / 1.5초 자동 진행
   "모르겠다" = 오답, 오늘 세트에 계속 잔류
        ↓
③ 오답노트 (그 자리에서 펼쳐보기)
        ↓
   전부 맞을 때까지 ②~③ 반복
        ↓
④ 2단계 퀴즈 — 뜻 (알아 / 몰라 자가평가)
   단어 → 버튼 선택 → 뜻 + 예문 공개
        ↓
⑤ 오답노트 (그 자리에서 펼쳐보기)
        ↓
   전부 "알아"를 누를 때까지 ④~⑤ 반복
        ↓
⑥ 오늘 학습 완료 ✓ (시각적 이펙트)
   1단계와 2단계를 모두 통과한 단어만 완료 처리 → 복습 대상에 추가
```

---

## 기술 스택

| 항목 | 선택 | 이유 |
|------|------|------|
| Framework | Flutter (iOS only) | |
| 상태관리 | Riverpod | 컴파일 타임 안전성, AsyncValue |
| 로컬 DB | sqflite | 날짜별 쿼리, 통계 집계 등 SQL 필요 |
| 단어 데이터 | JSON assets → 앱 시작 시 메모리 로드 | 스플래시에서 로드 후 메모리 캐시 |
| 라우팅 | go_router | |
| 폰트 | NotoSansJP 번들링 | 모든 기기에서 일관된 한자 렌더링 |

---

## 데이터

| 레벨 | 단어 수 | 파일 |
|------|---------|------|
| N3 | 2,046개 | `assets/data/n3_words.json` |
| N2 | 1,905개 | `assets/data/n2_words.json` |

- 각 단어: `expression`(한자), `reading`(히라가나), `meaning_ko`(한국어 뜻), `example_jp`(일본어 예문), `example_ko`(한국어 예문)
- 학습 완료 저장 기준: 1단계 퀴즈와 2단계 퀴즈를 모두 통과한 시점에 `completed_at` 기록
- 오늘의 학습 세트 저장: 날짜별로 배정된 단어 목록과 현재 단계 진행 상태를 로컬 DB에 저장

## DB 스키마

### 1. `words`

앱 번들 JSON을 최초 실행 시 적재하는 기준 테이블.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| `id` | `TEXT` | `PRIMARY KEY` | 단어 고유 ID (`n3_0001` 형태 권장) |
| `jlpt_level` | `TEXT` | `NOT NULL` | `N2` 또는 `N3` |
| `expression` | `TEXT` |  | 한자 표기, 없으면 `NULL` 또는 빈 값 |
| `reading` | `TEXT` | `NOT NULL` | 히라가나 읽기 |
| `meaning_ko` | `TEXT` | `NOT NULL` | 한국어 뜻 |
| `example_jp` | `TEXT` |  | 일본어 예문 |
| `example_ko` | `TEXT` |  | 한국어 예문 |
| `created_at` | `TEXT` | `NOT NULL` | 적재 시각 ISO-8601 |

인덱스:
- `idx_words_level` on (`jlpt_level`)
- `idx_words_reading` on (`reading`)

### 2. `word_progress`

단어별 학습 완료 여부와 복습 풀을 관리하는 테이블.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| `word_id` | `TEXT` | `PRIMARY KEY`, `REFERENCES words(id)` | 단어 ID |
| `is_completed` | `INTEGER` | `NOT NULL DEFAULT 0` | 0/1 |
| `completed_at` | `TEXT` |  | 1단계+2단계 모두 완료 시각 |
| `last_reviewed_at` | `TEXT` |  | 복습 퀴즈 마지막 완료 시각 |
| `review_count` | `INTEGER` | `NOT NULL DEFAULT 0` | 복습 완료 횟수 |
| `updated_at` | `TEXT` | `NOT NULL` | 마지막 갱신 시각 |

인덱스:
- `idx_word_progress_completed` on (`is_completed`, `completed_at`)

### 3. `daily_study_sets`

날짜별로 고정되는 오늘의 학습 세트 메타 정보.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| `study_date` | `TEXT` | `PRIMARY KEY` | 로컬 날짜 `YYYY-MM-DD` |
| `jlpt_level` | `TEXT` | `NOT NULL` | 해당 날짜 학습 대상 레벨 |
| `target_count` | `INTEGER` | `NOT NULL` | 그날 목표 단어 수 |
| `status` | `TEXT` | `NOT NULL` | `flashcard`, `quiz_reading`, `quiz_meaning`, `completed` |
| `started_at` | `TEXT` |  | 세트 시작 시각 |
| `completed_at` | `TEXT` |  | 세트 완료 시각 |
| `created_at` | `TEXT` | `NOT NULL` | 세트 생성 시각 |
| `updated_at` | `TEXT` | `NOT NULL` | 마지막 갱신 시각 |

### 4. `daily_study_set_items`

하루 세트에 포함된 단어와 단계별 통과 여부.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| `study_date` | `TEXT` | `NOT NULL`, `REFERENCES daily_study_sets(study_date)` | 로컬 날짜 |
| `word_id` | `TEXT` | `NOT NULL`, `REFERENCES words(id)` | 단어 ID |
| `display_order` | `INTEGER` | `NOT NULL` | 플래시카드/퀴즈 순서 |
| `reading_passed` | `INTEGER` | `NOT NULL DEFAULT 0` | 1단계 최종 통과 여부 |
| `meaning_passed` | `INTEGER` | `NOT NULL DEFAULT 0` | 2단계 최종 통과 여부 |
| `reading_attempts` | `INTEGER` | `NOT NULL DEFAULT 0` | 1단계 시도 횟수 |
| `meaning_attempts` | `INTEGER` | `NOT NULL DEFAULT 0` | 2단계 시도 횟수 |
| `last_result` | `TEXT` |  | 최근 결과: `correct`, `wrong`, `unknown`, `know`, `dont_know` |
| `updated_at` | `TEXT` | `NOT NULL` | 마지막 갱신 시각 |

기본 키:
- `PRIMARY KEY (study_date, word_id)`

인덱스:
- `idx_daily_items_order` on (`study_date`, `display_order`)

### 5. `review_sessions`

복습 퀴즈 세션 자체를 저장하는 테이블.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| `id` | `TEXT` | `PRIMARY KEY` | 세션 ID |
| `review_date` | `TEXT` | `NOT NULL` | 로컬 날짜 |
| `item_count` | `INTEGER` | `NOT NULL` | 출제 개수 |
| `status` | `TEXT` | `NOT NULL` | `quiz_reading`, `quiz_meaning`, `completed` |
| `started_at` | `TEXT` | `NOT NULL` | 시작 시각 |
| `completed_at` | `TEXT` |  | 완료 시각 |

### 6. `review_session_items`

복습 퀴즈에 포함된 단어별 결과 저장.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| `session_id` | `TEXT` | `NOT NULL`, `REFERENCES review_sessions(id)` | 세션 ID |
| `word_id` | `TEXT` | `NOT NULL`, `REFERENCES words(id)` | 단어 ID |
| `display_order` | `INTEGER` | `NOT NULL` | 출제 순서 |
| `reading_passed` | `INTEGER` | `NOT NULL DEFAULT 0` | 1단계 통과 여부 |
| `meaning_passed` | `INTEGER` | `NOT NULL DEFAULT 0` | 2단계 통과 여부 |
| `reading_attempts` | `INTEGER` | `NOT NULL DEFAULT 0` | 1단계 시도 횟수 |
| `meaning_attempts` | `INTEGER` | `NOT NULL DEFAULT 0` | 2단계 시도 횟수 |

기본 키:
- `PRIMARY KEY (session_id, word_id)`

### 7. `app_settings`

앱 설정 저장 테이블.

| 컬럼 | 타입 | 제약 | 설명 |
|------|------|------|------|
| `key` | `TEXT` | `PRIMARY KEY` | 설정 키 |
| `value` | `TEXT` | `NOT NULL` | 설정 값 |
| `updated_at` | `TEXT` | `NOT NULL` | 마지막 갱신 시각 |

권장 키:
- `exam_date`
- `theme_mode`
- `seeded_at`

## 상태 모델

### 앱 전역 상태

| 상태명 | 타입 | 설명 |
|------|------|------|
| `appSettingsState` | `AppSettings` | 시험 날짜, 테마 모드 |
| `wordCatalogState` | `AsyncValue<List<Word>>` | JSON 로드 후 메모리 캐시된 단어 목록 |
| `progressSummaryState` | `AsyncValue<ProgressSummary>` | 현재 레벨, 완료 개수, D-Day, 오늘 목표 개수 |
| `todayStudySetState` | `AsyncValue<TodayStudySet?>` | 오늘 날짜 기준 학습 세트 |
| `reviewSessionState` | `AsyncValue<ReviewSession?>` | 현재 진행 중인 복습 세션 |
| `statsOverviewState` | `AsyncValue<StatsOverview>` | 학습량, 정답률, 스트릭 |

### 핵심 도메인 모델

#### `Word`

```dart
class Word {
  final String id;
  final JlptLevel jlptLevel;
  final String? expression;
  final String reading;
  final String meaningKo;
  final String? exampleJp;
  final String? exampleKo;
}
```

#### `WordProgress`

```dart
class WordProgress {
  final String wordId;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime? lastReviewedAt;
  final int reviewCount;
}
```

#### `TodayStudySet`

```dart
class TodayStudySet {
  final DateTime studyDate;
  final JlptLevel jlptLevel;
  final int targetCount;
  final StudyStage status;
  final List<TodayStudyItem> items;
  final DateTime? startedAt;
  final DateTime? completedAt;
}
```

#### `TodayStudyItem`

```dart
class TodayStudyItem {
  final String wordId;
  final int displayOrder;
  final bool readingPassed;
  final bool meaningPassed;
  final int readingAttempts;
  final int meaningAttempts;
  final QuizResult? lastResult;
}
```

#### `ReviewSession`

```dart
class ReviewSession {
  final String id;
  final DateTime reviewDate;
  final StudyStage status;
  final List<ReviewSessionItem> items;
  final DateTime startedAt;
  final DateTime? completedAt;
}
```

### UI 흐름 상태

#### 홈 화면

- `currentLevel`
- `daysUntilExam`
- `todayCompletedCount`
- `todayTargetCount`
- `totalCompletedCount`
- `totalLevelWordCount`
- `hasReviewableWords`
- `isReviewOnlyMode`

#### 플래시카드 화면

- `currentIndex`
- `isFrontVisible`
- `items`
- `canContinueToReadingQuiz`

#### 1단계 퀴즈 화면

- `currentIndex`
- `choiceWords`
- `selectedChoice`
- `showAnswerFeedback`
- `wrongWordIds`
- `remainingWordIds`

#### 2단계 퀴즈 화면

- `currentIndex`
- `revealedMeaning`
- `selectedSelfAssessment`
- `wrongWordIds`
- `remainingWordIds`

#### 오답노트 화면

- `stage`
- `wrongItems`
- `correctCount`
- `totalCount`
- `canAdvance`

#### 통계 화면

- `dailyStudyCounts`
- `readingAccuracySeries`
- `meaningAccuracySeries`
- `currentStreak`

## 구현 메모

- `todayStudySetState` 생성 시점에만 랜덤 샘플링을 수행하고 이후에는 DB를 단일 소스로 사용
- 홈 화면의 `오늘 n / m 완료`는 `daily_study_set_items`에서 `reading_passed && meaning_passed` 개수로 계산
- 스트릭은 `daily_study_sets.completed_at` 존재 여부를 기준으로 연속 일수를 계산
- 1단계 선택지 생성은 같은 레벨 우선, 부족하면 현재 학습 레벨 전체에서 `reading` 시작음 일치 후보를 확장
- Riverpod에서는 화면별 `Notifier/AsyncNotifier`와 저장소 계층을 분리하고, DB 접근은 repository에서만 수행

---

## 트레이드오프 및 설계 결정 사항

| 항목 | 결정 | 이유 |
|------|------|------|
| 오답 선택지 | `reading` 시작음이 같은 단어 우선 | 추가 데이터 없이 구현 가능, 단순 랜덤보다 학습 효과 높음 |
| "모르겠다" | 오늘 세트 잔류 | 반드시 외워야 완료 — 타협 없는 학습 |
| 단어 배정 | 날짜별 랜덤 고정 | 매일 다양성은 유지하면서 재실행 시 일관성 보장 |
| 백업 | 로컬만 | 구현 단순화, 오프라인 우선 |
| 통계 위치 | 바텀 탭 | 자주 확인하는 기능 → 접근성 |
| 탐색 | 바텀 탭 | 학습 외 자유 탐색 → 분리 |
| 중간 이탈 | 현재 단계만 리셋 | 사용성 저하 없이 단계 학습 흐름 유지 |
| 2단계 퀴즈 | 자가평가 유지 | 구현 단순화, 빠른 반복 학습에 적합 |
| 스트릭 기준 | 당일 학습 완료만 인정 | 복습과 구분되는 핵심 학습 지표 유지 |
