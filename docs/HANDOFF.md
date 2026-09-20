# HANDOFF — N2 집중 리디자인 (2026-09-20, 3차 갱신: UI 폴리시)

다음 세션이 이어받기 위한 문서. 코드 구조는 저장소를 보면 되므로 여기엔 **상태·결정·미완·재개 절차**만 적는다.

## 1. 현재 상태

| 항목 | 값 |
|---|---|
| 브랜치 | `main` = `b667a78`. **`feat/ui-polish` 작업 중(미커밋)** — §3.5 참고 |
| 앱 버전 | `1.2.0+8`, iOS Deployment Target 15.0 |
| TestFlight | 빌드 8 업로드 성공 (2026-09-20 21:23, Delivery UUID 0049e883). App Store Connect 처리 확인 필요 |
| 테스트 | `flutter analyze` 클린, `flutter test` 258/258, `flutter drive` 시뮬레이터 체크리스트 8/8 (`integration_test/checklist_test.dart`) |
| 스펙 | `docs/superpowers/specs/2026-09-19-n2-focus-redesign-design.md` |
| 플랜 | `docs/superpowers/plans/2026-09-19-n2-focus-redesign.md` (Task 1–14) |
| SDD 레저 | `.superpowers/sdd/2026-09-19-n2-focus-redesign/progress.md` (git-ignored, 로컬만) — 모든 판정·이월 항목 기록 |
| 데이터 검수 로그 | `docs/data-audit/changes_01..10.md` |

## 2. 이번에 한 것 (요약)

- 요구사항 문서(`~/Downloads/jlpt-n2-app-requirements.md`) 기준 갭 분석 → 스펙·플랜 작성.
- **데이터**: N2 1,906개 전수 검수(에이전트 10개 병렬) → 1,901개. 읽기 순수 가나화, 예문 후리가나 외래어 가타카나 복원, 음독/훈독 `type` 약 230건 교정, 배신 단어 24개 `is_trap`, 어색한 예문·번역 재작성, 중복 3개 삭제. `tool/merge_audit.py`로 병합.
- **N3 완전 제거**: `JlptLevel`, 뱃지, N3 에셋, 레벨 필터. DB v3 마이그레이션에서 기기 내 N3 행 삭제.
- **DB v3**: `words.type/is_trap/source`, `miss_log` 테이블, `data_version` 기준 에셋 upsert 재시딩(진도 보존).
- **학습 루프 단순화**: 플래시카드·뜻 퀴즈·오답노트 화면 삭제 → `/quiz` 한 화면(한자→가나 4지선다, 정답 카드, 오답 재등장) → `/quiz/complete`.
- **오답 생성기** `DistractorGenerator`: 장음·촉음·탁음 규칙 변형, 고른 오답 종류로 `miss_log` 태그 자동 기록. 가나 단어는 뜻 4지선다.
- **세트 구성** `StudySetBuilder`: 사용자 단어 → 훈독 최소 6 → 랜덤, + 약점 5개. "다음 학습 시작"은 세트 삭제 대신 append.
- **복습**: 홈 카드 → 태그 필터 시트(전체/장음/촉음/탁음/뜻) → 세션.
- **단어 추가**: 시트(표기·읽기·뜻), 카탈로그 중복 감지, 홈 클립보드 칩(`hasStrings`만 확인, 탭 시에만 읽음), 탐색 `+`·'추가한 단어' 필터.
- **설정**: `/settings` 라우트 + 홈 톱니 아이콘, 시험일 DatePicker, "다음 JLPT" 원탭. 기본 시험일 = 다음 7월/12월 첫째 일요일 자동. 시험일 지나도 학습 버튼 유지.
- `ios/ExportOptions.plist`(App Store Connect 업로드 옵션) 커밋.

## 3. 2차 세션(2026-09-20 오후)에서 한 것

- **Task 12 나머지 완료**: `BackupService`(내보내기 = 임시 스냅샷 `jlpt-backup-<date>.db` 공유, 가져오기 = `user_version`·컬럼 검증 → `.pre-import` 롤백 복사 → 원자적 교체), `SettingsNotifier.resetProgress()` 실제 동작, 백업 타일 재진입 가드. 리뷰 3라운드.
- **최종 전체 브랜치 리뷰(Task 14)** 수행 → Critical 1(자정 넘김 시 세트 항목 날짜 불일치로 다음날 UNIQUE 크래시) + Important 4 + 트리아지 FIX 6 모두 수정·재리뷰 클린. 상세: `.superpowers/sdd/.../final-review-report.md`(로컬).
  - `finish()`/`complete()`가 탐색·통계 프로바이더도 invalidate.
  - 탐색 필터가 카탈로그 변경 후에도 유지(`exploreFilterProvider`).
  - `kMaxDailyTarget = 40` 상한(스펙 §5.1 갱신).
  - 홈 `_busy` 가드, 퀴즈 로드 실패 화면, 복습 시트 칩 가드, v3 마이그레이션 테스트 강화, `ios/Podfile.lock` 갱신.
- **시뮬레이터 체크리스트** 6/6 통과(플랜 Task 14 Step 4). `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/checklist_test.dart -d <sim>`.

## 3.5. 3차 세션(2026-09-20 밤) — UI 디자인 평가·폴리시 (`feat/ui-polish`, 미커밋)

- **평가**: `/impeccable critique` 듀얼 에이전트 → **19/40 Poor**, 네이티브 감사 9/20. 핵심: `dividerColor`(근검정) 한 토큰이 카드 테두리·구분선·진행바 트랙을 겸용해 "검은 선 격자", 바텀시트가 셸 내비게이터 안에 떠 탭바 위에 잘림, 한자가 Pretendard 폴백(한국식 자형), 넷플릭스 레드/카카오 옐로 팔레트. 스냅샷 `.impeccable/critique/2026-09-20T13-05-32Z__lib-features.md`.
- **선택한 방향: "종이와 먹"** (테두리 0, 톤으로 위계, 종이·먹·주홍 3색, 한자 NotoSansJP 주인공). P0 기능 결함도 이 브랜치에 포함하기로 결정.
- **구현 요약** (`lib/core/theme/app_theme.dart` 전면 재작성 + 화면 전부):
  - 팔레트: 라이트 종이 `#FAF8F3`/먹 `#1C1917`/주홍 `#B5371F`, 다크 반전(주홍 `#EC7A63`, 다크 `onPrimary`=먹). 정답 이끼 `#2A6236`. 전부 WCAG AA 계산 확인. `AppSpacing`/`AppRadius`/`AppText.ja*`(NotoSansJP + Pretendard 폴백) 토큰.
  - 카드·칩·선택지·검색창 테두리 제거 → `surfaceContainer` 면. 선은 리스트 행 사이 헤어라인 + 탭바 상단 1줄만.
  - `AppThemeMode.system` 추가(기본값). 홈 테마 토글 제거, 설정 3분할(시스템/라이트/다크). 스플래시 테마 색.
  - 바텀시트 2곳 `useRootNavigator: true, useSafeArea: true` + 전폭(`stretch`) + 하단 `viewPadding`. 탭바 `NavigationBar`(M3).
  - 퀴즈: 닫기 좌측, 한자 64px NotoSansJP, 정답=이끼+체크 / 오답=취소선+X, **1초 자동 넘김 제거(항상 '다음')**, 햅틱. 완료 화면: **첫 시도 정답 N / 25** + 시도 횟수, `_finish()` try/catch·재시도, 가나 단어 읽기 중복 제거, 스크롤 가능·버튼 하단 고정.
  - 설정: iOS grouped 섹션, **백업 가져오기 확인 다이얼로그**, 초기화 문구 사실 기준·`초기화` 파괴 색·햅틱. 탐색: 검색 250ms 디바운스·지우기, 칩 2축 구분·44pt, 빈 상태·필터 지우기, `push`/`pop` 정합. 통계·가나·플래시카드 동일 토큰.
  - 접근성: `Semantics`(버튼·선택·enabled), 진행바 시맨틱, Reduce Motion(`disableAnimationsOf`), Dynamic Type용 스크롤·`Flexible`·`mainAxisExtent`.
- **검증**: analyze 클린, 단위 258/258, 통합 8/8(시뮬레이터 iPhone 17), 다크 모드 시스템 연동 캡처 확인. 코드 리뷰 15건(P0 0) 전부 반영. MD3 감사 69/100(감점은 iPad 적응형 부재·의도된 커스텀).
- **남긴 것**: 커밋·머지·TestFlight는 사용자 확인 후. 리뷰 후 재-critique 미실행. MD3 감사 권고 중 미적용: `FilledButton` 전환, 본문 maxWidth 600(iPad), 모션 토큰, 고대비 테마.

## 4. 미완 / 파킹

1. ~~머지·푸시·TestFlight 빌드 8~~ 완료.
2. **App Store 정식 제출** — ASC 웹 로그인 또는 API 키 필요.
3. 파킹 항목 중 **feat/ui-polish에서 해결**: 완료 화면 가나 읽기 중복, 복습 시트 루트 내비게이터, 완료 화면 '다음 학습 시작' 가드. **남음**: 홈 `_guard`가 에러 로그 없이 삼킴; `isValidBackup`이 `user_version 0` 허용; `ExploreNotifier.updateFilter` await 전 스냅샷 경합. 나머지 Minor 13건은 final-review-report.md 참고(SHIP 판정).
4. 스펙 §7 '출처' 필드, `hanja_ko`, SRS, CSV — 이후 과제.

## 5. 판정 기록 (플랜과 다르게 결정한 것)

- Tasks 1–3, 10–11 각각 한 번에 구현·리뷰 (파일 결합도).
- `getRandomMeanings`가 정답과 같은 뜻을 오답으로 뽑을 수 있던 플랜 코드 수정 (뜻 문자열 기준 제외).
- `targetCount = items.length` 유지 — 스펙의 "약점은 목표에 미포함"은 신규 단어 쿼터에만 적용. 홈 "오늘 x / y"는 통과해야 할 전체 수.
- 시험 당일(`days == 0`)은 아직 "시험 전"으로 취급 — 일일 목표 = 남은 단어 전부.
- 반탁음 역매핑 충돌(플랜 코드 버그) 수정 — ぱ행 → は행·ば행 둘 다 생성.
- 퀴즈 `_advance`에서 상태 리셋 추가(플랜 코드는 다음 문제 정답이 잠깐 노출됨).
- `insertUserWord`가 `source='user'` 강제 (플랜은 호출자에 의존 → 재시딩 때 삭제 위험).
- 중복 단어 가드를 저장 시점에 재조회 (디바운스 창 우회 방지).
- iOS Deployment Target 13.0 → 15.0 (Apple 거부).
- `dailyTarget` 상한 40 (스펙 §5.1 공식엔 상한 없음 → D-1에 전체 카탈로그가 세트가 됨).
- `isValidBackup`: `user_version <= 3`, 3이면 v3 컬럼·`miss_log` 필수.
- 시뮬레이터 체크리스트는 수동 대신 `integration_test`로 자동화·커밋.

## 6. 재개 절차

```bash
git checkout main && git pull
flutter pub get && flutter analyze && flutter test
cat .superpowers/sdd/2026-09-19-n2-focus-redesign/progress.md   # 있으면
```
플랜 Task 1–14 전부 완료. 남은 건 §4.

TestFlight 업로드:
```bash
# pubspec.yaml version 올린 뒤
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
# 마지막 "failed to list directory build/ios/ipa" 는 무해 (upload 모드라 IPA 파일 안 남음)
```

## 7. 다음 세션용 프롬프트 (복붙)

**A. (완료) UI 디자인 평가 → 개선** — §3.5. 후속으로 쓸 프롬프트:
```
docs/HANDOFF.md §3.5 읽고, feat/ui-polish를 커밋(메시지: "feat: paper-and-ink UI polish")하고 main에 머지·푸시한 뒤 /testflight 로 올려줘.
```
```
docs/HANDOFF.md 읽고 feat/ui-polish 상태에서 /impeccable critique 재실행해 점수 변화 확인하고, P1 이상만 한 라운드 더 고쳐줘.
```

**B. 남은 파킹 3건 처리**
```
docs/HANDOFF.md §4-3의 남은 파킹 항목 3개를 브랜치 feat/parked-fixes에서 한 fix 라운드로 처리해줘: 홈 _guard에 debugPrint, isValidBackup user_version 0 거부, ExploreNotifier.updateFilter 스냅샷 경합. 각각 테스트 추가, 리뷰 1회, 258+ 테스트 통과 후 머지 여부 물어봐.
```

**C. TestFlight 업로드**
```
/testflight
```
(또는 "TestFlight 올려줘". 빌드 번호 자동 +1, 커밋·푸시·업로드·검증까지.)

**D. App Store 정식 제출**
```
App Store Connect에 1.2.0 정식 제출 준비해줘. Chrome으로 appstoreconnect.apple.com 열어줄 테니 로그인은 내가 할게. 최신 처리 완료 빌드 선택, 스크린샷/설명 현황 확인, 심사 제출 직전에 멈추고 나한테 확인받아.
```
