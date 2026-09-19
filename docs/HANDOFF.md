# HANDOFF — N2 집중 리디자인 (2026-09-20)

다음 세션이 이어받기 위한 문서. 코드 구조는 저장소를 보면 되므로 여기엔 **상태·결정·미완·재개 절차**만 적는다.

## 1. 현재 상태

| 항목 | 값 |
|---|---|
| 브랜치 | `main` = `b220026` (origin 동기화). `feat/n2-focus` 머지 완료, 브랜치도 푸시됨 |
| 앱 버전 | `1.2.0+7`, iOS Deployment Target 15.0 |
| TestFlight | 빌드 7 업로드됨 (빌드 6은 ITMS-90068 MinimumOSVersion 13.0으로 거부 → 15.0으로 올려 재업로드). App Store Connect 처리 확인 필요 |
| 테스트 | `flutter analyze` 클린, `flutter test` 205/205 |
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

## 3. 미완 (다음 세션에서 마저)

사용자 요청: "토큰 많아지면 최소로 진행했던 거 마저 확인".

1. **Task 12 나머지** — 백업 내보내기(`share_plus`, DB 파일 공유 시트) / 가져오기(`file_picker`, 검증 후 교체) / '데이터 초기화' 실제 동작(`ProgressRepository.resetAllProgress()` 이미 있음, 설정 다이얼로그 확인 버튼만 연결하면 됨). 플랜 Task 12 브리프 참고.
2. **최종 전체 브랜치 코드 리뷰** (플랜 Task 14) — 토큰 부족으로 생략. 레저의 `minor (deferred)` 9줄 분류 필요. 눈에 띄는 것: 복습 시트 칩 더블탭 시 세션 2개 생성; `_lookup` 에러 삼킴; `exploreProvider` invalidate 시 필터 리셋; 퀴즈 비공개 레이아웃 스크롤 없음(긴 표제어 오버플로 가능); `_ChoiceButton` 시맨틱 없음; 라우터 `extra` 캐스트 예외.
3. **시뮬레이터 실사용 확인** — 자동 테스트만 통과. 플랜 Task 14 Step 4 체크리스트(홈 D-day, 학습→퀴즈→완료, 복습 필터, 단어 추가, 시험일 변경).
4. **App Store 정식 제출** — ASC 웹 로그인(Chrome) 또는 API 키(.p8) 필요. TestFlight는 됨.
5. 스펙 §7 '출처' 필드 생략함(저장할 컬럼 없음). 원하면 `words.note` 컬럼 + 시트 필드 추가.
6. `hanja_ko`(한국어 한자음), SRS, CSV 임포트/익스포트 — 스펙 비목표. 이후 과제.

## 4. 판정 기록 (플랜과 다르게 결정한 것)

- Tasks 1–3, 10–11 각각 한 번에 구현·리뷰 (파일 결합도).
- `getRandomMeanings`가 정답과 같은 뜻을 오답으로 뽑을 수 있던 플랜 코드 수정 (뜻 문자열 기준 제외).
- `targetCount = items.length` 유지 — 스펙의 "약점은 목표에 미포함"은 신규 단어 쿼터에만 적용. 홈 "오늘 x / y"는 통과해야 할 전체 수.
- 시험 당일(`days == 0`)은 아직 "시험 전"으로 취급 — 일일 목표 = 남은 단어 전부.
- 반탁음 역매핑 충돌(플랜 코드 버그) 수정 — ぱ행 → は행·ば행 둘 다 생성.
- 퀴즈 `_advance`에서 상태 리셋 추가(플랜 코드는 다음 문제 정답이 잠깐 노출됨).
- `insertUserWord`가 `source='user'` 강제 (플랜은 호출자에 의존 → 재시딩 때 삭제 위험).
- 중복 단어 가드를 저장 시점에 재조회 (디바운스 창 우회 방지).
- iOS Deployment Target 13.0 → 15.0 (Apple 거부).

## 5. 재개 절차

```bash
git checkout main && git pull
flutter pub get && flutter analyze && flutter test
cat .superpowers/sdd/2026-09-19-n2-focus-redesign/progress.md   # 있으면
```
플랜 Task 12(백업 부분)·Task 14 브리프를 그대로 실행하면 됨. 리뷰 방식은 이번과 동일하게 `superpowers:subagent-driven-development`.

TestFlight 업로드:
```bash
# pubspec.yaml version 올린 뒤
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
# 마지막 "failed to list directory build/ios/ipa" 는 무해 (upload 모드라 IPA 파일 안 남음)
```
