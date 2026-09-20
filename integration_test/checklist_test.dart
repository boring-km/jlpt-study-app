// 시뮬레이터 인수 체크리스트. 실제 기기(시뮬레이터)에서 앱 전체 흐름을 한 번
// 훑으면서 각 단계의 스크린샷을 남긴다.
//
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/checklist_test.dart \
//     -d <simulator-udid>
//
// DB가 깨끗한 상태(v3 onCreate + 에셋 시딩)를 전제로 한다. 실행 전에
// `xcrun simctl uninstall booted com.kangmin.jlpt`로 앱을 지워 둘 것.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jlpt/features/explore/word_list_screen.dart';
import 'package:jlpt/features/home/home_screen.dart';
import 'package:jlpt/features/quiz/quiz_complete_screen.dart';
import 'package:jlpt/features/quiz/quiz_screen.dart';
import 'package:jlpt/features/settings/settings_screen.dart';
import 'package:jlpt/main.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  bool present(Finder finder) => finder.evaluate().isNotEmpty;

  /// 실제 프레임을 [ms]밀리초만큼 돌린다. 라우트 전환 애니메이션이 끝나기를
  /// 기다리는 용도 — 전환 중에 탭하면 좌표가 어긋나 hit test가 빗나간다.
  Future<void> settle(WidgetTester tester, [int ms = 1200]) async {
    for (var i = 0; i < ms ~/ 50; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// 조건이 참이 될 때까지 실제 프레임을 계속 돌린다. `pumpAndSettle`은 앱이
  /// 애니메이션·타이머로 계속 바쁘면 타임아웃으로 죽기 때문에 쓰지 않는다.
  Future<void> waitFor(
    WidgetTester tester,
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 30),
    String? reason,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (condition()) return;
      await tester.pump(const Duration(milliseconds: 100));
    }
    if (!condition()) {
      fail('waitFor timed out after $timeout: ${reason ?? 'condition'}');
    }
  }

  /// [target]을 눌러 [done]이 참이 될 때까지 재시도한다. 전환 애니메이션 중에
  /// 눌러 탭이 삼켜지는 경우가 있어서 한 번으로는 부족하다. [done]이 이미
  /// 참이면 누르지 않으므로 토글류 위젯에도 안전하다.
  Future<void> tapUntil(
    WidgetTester tester,
    Finder target,
    bool Function() done, {
    Duration perAttempt = const Duration(seconds: 15),
    int attempts = 4,
    required String reason,
  }) async {
    for (var a = 0; a < attempts; a++) {
      if (done()) return;
      if (target.evaluate().isEmpty) {
        await settle(tester, 500);
        continue;
      }
      await tester.tap(target.first, warnIfMissed: false);
      final deadline = DateTime.now().add(perAttempt);
      while (DateTime.now().isBefore(deadline)) {
        if (done()) return;
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    fail('tapUntil gave up after $attempts attempts: $reason');
  }

  /// 스크린샷을 찍기 전에 iOS 서피스를 이미지로 바꿔야 한다. 한 번만.
  var surfaceConverted = false;
  Future<void> shot(WidgetTester tester, String name) async {
    if (!surfaceConverted) {
      surfaceConverted = true;
      await binding.convertFlutterSurfaceToImage();
    }
    await settle(tester, 900);
    await binding.takeScreenshot(name);
  }

  /// 현재 퀴즈 화면의 AppBar 제목('3 / 25'). 로딩 중이면 null.
  String? quizTitle(WidgetTester tester) {
    final appBar = find.byType(AppBar);
    if (appBar.evaluate().isEmpty) return null;
    final titles = find.descendant(of: appBar, matching: find.byType(Text));
    for (final e in titles.evaluate()) {
      final data = (e.widget as Text).data;
      if (data != null && RegExp(r'^\d+ / \d+$').hasMatch(data)) return data;
    }
    return null;
  }

  /// 홈 화면이 완전히 전면에 있는 상태. 퀴즈/설정 라우트가 남아 있으면 전환이
  /// 아직 안 끝난 것이므로 탭하면 안 된다.
  bool onHome() =>
      present(find.byType(HomeScreen)) &&
      !present(find.byType(QuizScreen)) &&
      !present(find.byType(QuizCompleteScreen)) &&
      !present(find.byType(SettingsScreen));

  testWidgets('simulator acceptance checklist', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JlptApp()));

    // ---------------------------------------------------------------
    // 1. 홈 D-day
    // ---------------------------------------------------------------
    // 첫 프레임에서 에셋의 1,900여 단어를 시딩한다 — 넉넉히 기다린다.
    await waitFor(
      tester,
      () => present(find.text('D-77')),
      timeout: const Duration(seconds: 120),
      reason: '홈의 D-77',
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('D-77'), findsOneWidget);
    expect(find.text('오늘 0 / 25 완료'), findsOneWidget);
    expect(find.text('N2 0 / 1901'), findsOneWidget);
    await shot(tester, '01_home');
    expect(tester.takeException(), isNull);

    // ---------------------------------------------------------------
    // 2. 학습 시작 → 오답 카드 → 완료 화면
    // ---------------------------------------------------------------
    await tapUntil(
      tester,
      find.text('학습 시작'),
      () =>
          present(find.byType(QuizScreen)) &&
          present(find.byKey(const Key('quiz-choice-0'))),
      perAttempt: const Duration(seconds: 40),
      reason: '학습 시작 → 퀴즈 첫 문제',
    );
    await settle(tester);

    // 헤드워드 + 보기 4개
    expect(find.byKey(const Key('quiz-choice-0')), findsOneWidget);
    expect(find.byKey(const Key('quiz-choice-3')), findsOneWidget);

    // 일부러 틀린다: 정답이 아닌 보기를 고른다.
    final quizState = tester.state<QuizScreenState>(find.byType(QuizScreen));
    final correctIndex = quizState.correctChoiceIndexForTest;
    expect(correctIndex, isNonNegative);
    final wrongIndex = correctIndex == 0 ? 1 : 0;
    await tester.tap(find.byKey(Key('quiz-choice-$wrongIndex')));

    // 오답이면 정답 카드가 뜨고 '다음' 버튼이 나온다.
    await waitFor(
      tester,
      () => present(find.widgetWithText(ElevatedButton, '다음')),
      timeout: const Duration(seconds: 20),
      reason: '오답 후 정답 카드 + 다음 버튼',
    );
    await shot(tester, '02_quiz_wrong_card');
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(ElevatedButton, '다음'));
    await tester.pump(const Duration(milliseconds: 300));

    // 나머지는 정답으로 밀어서 세트를 끝낸다 (오답 단어는 큐 뒤에 다시 붙는다).
    for (var i = 0; i < 120; i++) {
      if (present(find.byType(QuizCompleteScreen))) break;
      final quiz = find.byType(QuizScreen);
      if (quiz.evaluate().isEmpty ||
          find.byKey(const Key('quiz-choice-0')).evaluate().isEmpty) {
        await tester.pump(const Duration(milliseconds: 100));
        continue;
      }
      final state = tester.state<QuizScreenState>(quiz);
      final ci = state.correctChoiceIndexForTest;
      if (ci < 0) {
        await tester.pump(const Duration(milliseconds: 100));
        continue;
      }
      final before = quizTitle(tester);
      await tester.tap(find.byKey(Key('quiz-choice-$ci')));
      // 정답도 자동으로 넘어가지 않는다 — '다음'을 눌러야 진행한다.
      await waitFor(
        tester,
        () => present(find.widgetWithText(ElevatedButton, '다음')),
        timeout: const Duration(seconds: 25),
        reason: '정답 후 다음 버튼',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, '다음'));
      await waitFor(
        tester,
        () =>
            present(find.byType(QuizCompleteScreen)) ||
            (present(find.byKey(const Key('quiz-choice-0'))) &&
                quizTitle(tester) != before),
        timeout: const Duration(seconds: 25),
        reason: '다음 문제로 진행 (이전: $before)',
      );
    }

    await waitFor(
      tester,
      () =>
          present(find.byType(QuizCompleteScreen)) &&
          present(find.text('오늘 학습 완료')),
      timeout: const Duration(seconds: 60),
      reason: '학습 완료 화면',
    );
    await settle(tester);

    // 틀린 단어가 태그 칩과 함께 보인다.
    expect(find.textContaining('틀린 단어'), findsOneWidget);
    const tagLabels = ['장음', '촉음', '탁음', '뜻', '기타'];
    final chips = find.byType(Chip);
    expect(chips, findsWidgets, reason: '오답 단어의 태그 칩');
    final chipTexts = <String>[
      for (final e
          in find.descendant(of: chips, matching: find.byType(Text)).evaluate())
        (e.widget as Text).data ?? '',
    ];
    expect(
      chipTexts.any(tagLabels.contains),
      isTrue,
      reason: '태그 칩 라벨이 장음/촉음/탁음/뜻/기타 중 하나여야 한다. 실제: $chipTexts',
    );
    await shot(tester, '03_quiz_complete');
    expect(tester.takeException(), isNull);

    // 홈으로
    await tapUntil(
      tester,
      find.widgetWithText(TextButton, '홈으로'),
      () => onHome() && present(find.text('D-77')),
      reason: '완료 화면 → 홈',
    );
    await settle(tester);

    // ---------------------------------------------------------------
    // 3. 복습 → 시트 → 칩 → 복습 퀴즈
    // ---------------------------------------------------------------
    await tapUntil(
      tester,
      find.text('복습'),
      () => present(find.widgetWithText(ActionChip, '전체')),
      reason: '복습 카드 → 필터 시트',
    );
    await settle(tester);
    await shot(tester, '04_review_sheet');
    expect(tester.takeException(), isNull);

    await tapUntil(
      tester,
      find.widgetWithText(ActionChip, '전체'),
      () =>
          present(find.byType(QuizScreen)) &&
          present(find.byKey(const Key('quiz-choice-0'))),
      perAttempt: const Duration(seconds: 40),
      reason: "'전체' 칩 → 복습 퀴즈",
    );
    await settle(tester);
    expect(find.byType(QuizScreen), findsOneWidget);
    await shot(tester, '05_review_quiz');
    expect(tester.takeException(), isNull);

    // 닫기
    await tapUntil(
      tester,
      find.byIcon(Icons.close),
      () => onHome() && present(find.text('D-77')),
      reason: '복습 퀴즈 닫기 → 홈',
    );
    await settle(tester);

    // ---------------------------------------------------------------
    // 4. 단어 추가 → 탐색 '추가한 단어' 필터
    // ---------------------------------------------------------------
    await tapUntil(
      tester,
      find.text('단어 추가'),
      () => present(find.byKey(const Key('add-expression'))),
      reason: '단어 추가 카드 → 시트',
    );
    await settle(tester);
    await tester.enterText(find.byKey(const Key('add-expression')), '検証');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byKey(const Key('add-reading')), 'けんしょう');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byKey(const Key('add-meaning')), '검증');
    // 중복 조회 디바운스(300ms)가 끝나야 저장 버튼이 살아 있다.
    await settle(tester, 1000);
    await tapUntil(
      tester,
      find.byKey(const Key('add-save')),
      () => !present(find.byKey(const Key('add-expression'))),
      reason: '저장 → 시트 닫힘',
    );
    await settle(tester);
    expect(tester.takeException(), isNull);

    // 탐색 탭
    await tapUntil(
      tester,
      find.byIcon(Icons.search_outlined),
      () =>
          present(find.byType(WordListScreen)) && present(find.text('추가한 단어')),
      reason: '탐색 탭',
    );
    await settle(tester);
    await tapUntil(
      tester,
      find.text('추가한 단어'),
      () => present(find.text('検証')),
      reason: "'추가한 단어' 필터 → 検証",
    );
    expect(find.text('検証'), findsWidgets);
    await shot(tester, '06_explore_user_filter');
    expect(tester.takeException(), isNull);

    // ---------------------------------------------------------------
    // 5. 설정 시험일 변경 → 홈 D-day 갱신
    // ---------------------------------------------------------------
    await tapUntil(
      tester,
      find.byIcon(Icons.home_outlined),
      () => onHome() && present(find.text('D-77')),
      reason: '홈 탭 복귀',
    );
    await settle(tester);
    await tapUntil(
      tester,
      find.byIcon(Icons.settings_outlined),
      () => present(find.byType(SettingsScreen)) && present(find.text('시험일')),
      reason: '설정 화면 열기',
    );
    await settle(tester);
    // 시험일 행과 '다음 JLPT로 설정' 행이 같은 날짜를 보여주므로 시험일 행 안에서만 찾는다.
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, '시험일'),
        matching: find.text('2026.12.06'),
      ),
      findsOneWidget,
    );

    await tapUntil(
      tester,
      find.text('시험일'),
      () =>
          present(find.byIcon(Icons.edit_outlined)) ||
          present(find.byIcon(Icons.edit)),
      reason: '시험일 타일 → 날짜 선택 다이얼로그',
    );
    await settle(tester);
    // 캘린더 → 직접 입력 모드로 전환한 뒤 날짜를 타이핑한다 (en_US: mm/dd/yyyy).
    await tapUntil(
      tester,
      present(find.byIcon(Icons.edit_outlined))
          ? find.byIcon(Icons.edit_outlined)
          : find.byIcon(Icons.edit),
      () => present(find.byType(TextField)),
      reason: '직접 입력 모드 전환',
    );
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, '12/13/2026');
    await settle(tester, 500);
    await tapUntil(
      tester,
      find.text('OK'),
      () => present(find.text('2026.12.13')),
      reason: 'OK → 시험일 갱신',
    );
    await settle(tester);
    expect(find.text('2026.12.13'), findsOneWidget);
    await shot(tester, '07_settings_exam_date');
    expect(tester.takeException(), isNull);

    // 홈으로 돌아가 D-day 갱신 확인
    await tapUntil(
      tester,
      find.byType(BackButton),
      () => onHome() && present(find.text('D-84')),
      reason: '설정 뒤로 → 홈 D-84',
    );
    await settle(tester);
    expect(find.text('D-84'), findsOneWidget);
    await shot(tester, '08_home_dday_updated');
    expect(tester.takeException(), isNull);

    // ---------------------------------------------------------------
    // 6. 백업 내보내기 → 네이티브 공유 시트
    // ---------------------------------------------------------------
    // UIKit 공유 시트는 Flutter가 볼 수 없다. 외부에서 simctl로 찍을 수 있게
    // 마커를 출력하고 창을 열어 둔다.
    await tapUntil(
      tester,
      find.byIcon(Icons.settings_outlined),
      () => present(find.text('백업 내보내기')),
      reason: '설정 화면(백업) 열기',
    );
    await settle(tester);
    await tester.tap(find.text('백업 내보내기'));
    await settle(tester, 500);
    // ignore: avoid_print
    print('JLPT_CHECKLIST_MARKER share_sheet_window_open');
    await stdout.flush();
    // 공유 시트가 뜨고 외부 스크린샷이 찍힐 시간을 벌어 준다.
    await settle(tester, 15000);
    // ignore: avoid_print
    print('JLPT_CHECKLIST_MARKER share_sheet_window_close');
    await stdout.flush();
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
