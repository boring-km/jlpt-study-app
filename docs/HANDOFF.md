# HANDOFF — N2 집중 리디자인 (2026-09-20, 2차 갱신)

다음 세션이 이어받기 위한 문서. 코드 구조는 저장소를 보면 되므로 여기엔 **상태·결정·미완·재개 절차**만 적는다.

## 1. 현재 상태

| 항목 | 값 |
|---|---|
| 브랜치 | `feat/n2-followup` (main `2c2d15d`에서 분기, 미머지·미푸시) |
| 앱 버전 | `1.2.0+7`, iOS Deployment Target 15.0 |
| TestFlight | 빌드 7 업로드됨 (빌드 6은 ITMS-90068 MinimumOSVersion 13.0으로 거부 → 15.0으로 올려 재업로드). App Store Connect 처리 확인 필요 |
| 테스트 | `flutter analyze` 클린, `flutter test` 233/233, `flutter drive` 시뮬레이터 체크리스트 6/6 (`integration_test/checklist_test.dart`) |
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

## 4. 미완 / 파킹

1. **머지·푸시·TestFlight 빌드 8** — 사용자 결정 필요. `pubspec.yaml` 버전 아직 `1.2.0+7`.
2. **App Store 정식 제출** — ASC 웹 로그인 또는 API 키 필요.
3. 파킹된 소소한 것(모두 코스메틱/희귀 경로): 완료 화면 가나 단어 읽기 중복 표시(`quiz_complete_screen.dart` `'${expression}  ${reading}'`); 복습 필터 시트가 루트 내비게이터 위가 아님(하단 탭바 위에 뜸); 완료 화면 '다음 학습 시작' 가드 없음; 홈 `_guard`가 에러 로그 없이 삼킴; `isValidBackup`이 `user_version 0` 허용; `ExploreNotifier.updateFilter` await 전 스냅샷 경합. 나머지 Minor 13건은 final-review-report.md 참고(SHIP 판정).
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
