# Study Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 홈, 플래시카드, 1단계/2단계 퀴즈, 오답노트, 학습 완료, 복습 퀴즈 화면을 구현한다.

**Architecture:** foundation-layer 플랜이 완료된 상태를 전제로 한다. 각 화면은 Riverpod AsyncNotifier/Notifier로 상태를 관리하며, Repository를 통해서만 DB에 접근한다. 화면 전환은 go_router를 사용한다.

**Tech Stack:** Flutter, Riverpod 2.x, sqflite, go_router

**전제 조건:** `docs/superpowers/plans/2026-04-07-foundation-layer.md` 완료

---

## File Structure

```
lib/
  features/
    home/
      home_screen.dart              # 홈 화면
      home_provider.dart            # HomeState Notifier
    study/
      flashcard/
        flashcard_screen.dart       # 플래시카드 화면
        flashcard_provider.dart     # FlashcardState Notifier
      quiz_reading/
        quiz_reading_screen.dart    # 1단계 퀴즈 화면
        quiz_reading_provider.dart  # QuizReadingState Notifier
      quiz_meaning/
        quiz_meaning_screen.dart    # 2단계 퀴즈 화면
        quiz_meaning_provider.dart  # QuizMeaningState Notifier
      wrong_answers/
        wrong_answers_screen.dart   # 오답노트 화면
      complete/
        complete_screen.dart        # 학습 완료 화면
    review/
      review_screen.dart            # 복습 퀴즈 화면 (1단계+2단계 포함)
      review_provider.dart          # ReviewState Notifier
  application/
    providers/
      today_study_set_provider.dart # TodayStudySet AsyncNotifier
      review_session_provider.dart  # ReviewSession AsyncNotifier
  widgets/
    word_badge.dart                 # N2/N3 뱃지 위젯
    flip_card.dart                  # 좌우 플립 카드 위젯
```

---

### Task 1: 공용 위젯 — WordBadge, FlipCard

**Files:**
- Create: `lib/widgets/word_badge.dart`
- Create: `lib/widgets/flip_card.dart`

- [ ] **Step 1: word_badge.dart 작성**

```dart
// lib/widgets/word_badge.dart
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../domain/models/enums.dart';

class WordBadge extends StatelessWidget {
  final JlptLevel level;

  const WordBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final label = level == JlptLevel.n3 ? 'N3' : 'N2';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: flip_card.dart 작성**

```dart
// lib/widgets/flip_card.dart
import 'dart:math';
import 'package:flutter/material.dart';

class FlipCard extends StatefulWidget {
  final Widget front;
  final Widget back;
  final bool isFlipped;
  final VoidCallback onTap;

  const FlipCard({
    super.key,
    required this.front,
    required this.back,
    required this.isFlipped,
    required this.onTap,
  });

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlipped != oldWidget.isFlipped) {
      if (widget.isFlipped) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * pi;
          final isFrontVisible = angle < pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: isFrontVisible
                ? widget.front
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: widget.back,
                  ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/
git commit -m "feat: add WordBadge and FlipCard widgets"
```

---

### Task 2: TodayStudySet Provider

**Files:**
- Create: `lib/application/providers/today_study_set_provider.dart`

- [ ] **Step 1: today_study_set_provider.dart 작성**

오늘 날짜 기준으로 세트를 조회하거나 없으면 새로 생성

```dart
// lib/application/providers/today_study_set_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/today_study_set.dart';
import '../../domain/models/enums.dart';
import '../../domain/repositories/study_set_repository.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../domain/repositories/word_repository.dart';
import 'database_provider.dart';
import 'progress_summary_provider.dart';
import 'settings_provider.dart';

final todayStudySetProvider =
    AsyncNotifierProvider<TodayStudySetNotifier, TodayStudySet?>(
  TodayStudySetNotifier.new,
);

class TodayStudySetNotifier extends AsyncNotifier<TodayStudySet?> {
  @override
  Future<TodayStudySet?> build() async {
    final db = await ref.watch(databaseProvider.future);
    final today = _todayStr();
    final repo = StudySetRepository(db);
    return repo.getByDate(today);
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 오늘 세트가 없을 때 새로 생성 (홈 화면 "오늘 학습 시작" 탭 시 호출)
  Future<TodayStudySet> createTodaySet() async {
    final db = await ref.read(databaseProvider.future);
    final summary = await ref.read(progressSummaryProvider.future);
    final progressRepo = ProgressRepository(db);
    final studyRepo = StudySetRepository(db);
    final today = _todayStr();

    // 미완료 단어 목록에서 랜덤 추출
    final uncompletedIds =
        await progressRepo.getUncompletedWordIds(summary.currentLevel);
    uncompletedIds.shuffle();
    final selected = uncompletedIds.take(summary.dailyTarget).toList();

    final now = DateTime.now();
    final items = selected.asMap().entries.map((e) {
      return TodayStudyItem(
        studyDate: today,
        wordId: e.value,
        displayOrder: e.key,
        readingPassed: false,
        meaningPassed: false,
        readingAttempts: 0,
        meaningAttempts: 0,
        updatedAt: now,
      );
    }).toList();

    final set = TodayStudySet(
      studyDate: today,
      jlptLevel: summary.currentLevel,
      targetCount: selected.length,
      status: StudyStage.flashcard,
      items: items,
      startedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    await studyRepo.createSet(set);
    state = AsyncData(set);
    return set;
  }

  /// 현재 단계 완료 후 다음 단계로 진행
  Future<void> advanceStage(StudyStage nextStage) async {
    final db = await ref.read(databaseProvider.future);
    final today = _todayStr();
    final repo = StudySetRepository(db);
    final completedAt =
        nextStage == StudyStage.completed ? DateTime.now() : null;
    await repo.updateSetStatus(today, nextStage, completedAt: completedAt);
    state = AsyncData(
      state.valueOrNull?.copyWith(
        status: nextStage,
        completedAt: completedAt,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// 단어 결과 업데이트
  Future<void> updateItemResult(
    String wordId, {
    required bool passed,
    required bool isReadingStage,
  }) async {
    final db = await ref.read(databaseProvider.future);
    final today = _todayStr();
    final repo = StudySetRepository(db);
    final current = state.valueOrNull;
    if (current == null) return;

    final itemIndex =
        current.items.indexWhere((i) => i.wordId == wordId);
    if (itemIndex < 0) return;
    final item = current.items[itemIndex];

    final updated = isReadingStage
        ? item.copyWith(
            readingPassed: passed,
            readingAttempts: item.readingAttempts + 1,
            lastResult: passed ? QuizResult.correct : QuizResult.wrong,
            updatedAt: DateTime.now(),
          )
        : item.copyWith(
            meaningPassed: passed,
            meaningAttempts: item.meaningAttempts + 1,
            lastResult: passed ? QuizResult.know : QuizResult.dontKnow,
            updatedAt: DateTime.now(),
          );

    await repo.updateItem(updated);

    final newItems = List<TodayStudyItem>.from(current.items);
    newItems[itemIndex] = updated;
    state = AsyncData(current.copyWith(items: newItems, updatedAt: DateTime.now()));
  }

  /// 1단계+2단계 모두 통과한 단어를 completed로 마킹
  Future<void> markCompletedWords() async {
    final db = await ref.read(databaseProvider.future);
    final progressRepo = ProgressRepository(db);
    final current = state.valueOrNull;
    if (current == null) return;

    for (final item in current.items) {
      if (item.isFullyCompleted) {
        await progressRepo.markCompleted(item.wordId);
      }
    }
    ref.invalidate(progressSummaryProvider);
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/application/providers/today_study_set_provider.dart
git commit -m "feat: add TodayStudySetNotifier provider"
```

---

### Task 3: 홈 화면

**Files:**
- Create: `lib/features/home/home_screen.dart`
- Modify: `lib/core/router/app_router.dart` (플레이스홀더 교체)

- [ ] **Step 1: home_screen.dart 작성**

```dart
// lib/features/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/providers/progress_summary_provider.dart';
import '../../application/providers/today_study_set_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/enums.dart';
import '../../widgets/word_badge.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(progressSummaryProvider);
    final setAsync = ref.watch(todayStudySetProvider);

    return Scaffold(
      body: SafeArea(
        child: summaryAsync.when(
          data: (summary) => _HomeBody(summary: summary, setAsync: setAsync),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('오류: $e')),
        ),
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  final ProgressSummary summary;
  final AsyncValue<dynamic> setAsync;

  const _HomeBody({required this.summary, required this.setAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final set = setAsync.valueOrNull;
    final todayCompleted = set?.completedCount ?? 0;
    final todayTarget = set?.targetCount ?? summary.dailyTarget;
    final isSetCompleted = set?.status == StudyStage.completed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // D-DAY + 현재 레벨
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                summary.daysUntilExam >= 0
                    ? 'D-${summary.daysUntilExam}'
                    : 'D+${summary.daysUntilExam.abs()}',
                style: Theme.of(context).textTheme.displayLarge,
              ),
              WordBadge(level: summary.currentLevel),
            ],
          ),
          const SizedBox(height: 8),

          // 오늘 진도
          Text(
            '오늘 $todayCompleted / $todayTarget 완료',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: todayTarget > 0 ? todayCompleted / todayTarget : 0,
              minHeight: 6,
              backgroundColor: AppColors.borderLight,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 8),

          // 전체 진도
          Text(
            '${summary.currentLevel == JlptLevel.n3 ? "N3" : "N2"} '
            '${summary.completedCount} / ${summary.totalCount}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),

          // 오늘 학습 시작 / 이어하기 버튼
          if (!summary.isReviewOnlyMode)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: isSetCompleted
                    ? null
                    : () => _startStudy(context, ref, set),
                child: Text(
                  set == null
                      ? '오늘 학습 시작'
                      : isSetCompleted
                          ? '오늘 학습 완료 ✓'
                          : '이어하기',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          if (summary.isReviewOnlyMode)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => context.push('/review'),
                child: const Text(
                  '복습 시작',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),

          const SizedBox(height: 16),

          // 복습 / 가나표 버튼
          Row(
            children: [
              Expanded(
                child: _SmallCard(
                  label: '복습',
                  icon: Icons.replay_outlined,
                  enabled: summary.completedCount > 0,
                  onTap: () => context.push('/review'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SmallCard(
                  label: '히라가나·가타카나 표',
                  icon: Icons.grid_view_outlined,
                  enabled: true,
                  onTap: () => context.push('/kana'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _startStudy(
    BuildContext context,
    WidgetRef ref,
    dynamic currentSet,
  ) async {
    if (currentSet == null) {
      await ref.read(todayStudySetProvider.notifier).createTodaySet();
    }
    final set = ref.read(todayStudySetProvider).valueOrNull;
    if (set == null || !context.mounted) return;

    switch (set.status) {
      case StudyStage.flashcard:
        context.push('/study/flashcard');
      case StudyStage.quizReading:
        context.push('/study/quiz-reading');
      case StudyStage.quizMeaning:
        context.push('/study/quiz-meaning');
      case StudyStage.completed:
        break;
    }
  }
}

class _SmallCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _SmallCard({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enabled ? AppColors.borderLight : AppColors.borderLight.withOpacity(0.4),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: enabled ? AppColors.primary : AppColors.textSecondaryLight,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: enabled
                    ? AppColors.textPrimaryLight
                    : AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: app_router.dart 홈 플레이스홀더를 HomeScreen으로 교체**

```dart
// app_router.dart 상단에 import 추가
import '../../features/home/home_screen.dart';

// '/' route builder 교체
GoRoute(
  path: '/',
  builder: (_, __) => const HomeScreen(),
  routes: [ ... ] // 기존 하위 routes 유지
),
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/home/ lib/core/router/app_router.dart
git commit -m "feat: add Home screen with D-Day, progress, study start button"
```

---

### Task 4: 플래시카드 화면

**Files:**
- Create: `lib/features/study/flashcard/flashcard_screen.dart`
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: flashcard_screen.dart 작성**

```dart
// lib/features/study/flashcard/flashcard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../application/providers/today_study_set_provider.dart';
import '../../../application/providers/word_catalog_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/word.dart';
import '../../../domain/models/today_study_set.dart';
import '../../../domain/models/enums.dart';
import '../../../widgets/flip_card.dart';
import '../../../widgets/word_badge.dart';

class FlashcardScreen extends ConsumerStatefulWidget {
  const FlashcardScreen({super.key});

  @override
  ConsumerState<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends ConsumerState<FlashcardScreen> {
  int _currentIndex = 0;
  bool _isFlipped = false;

  @override
  Widget build(BuildContext context) {
    final setAsync = ref.watch(todayStudySetProvider);
    final catalogAsync = ref.watch(wordCatalogProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: setAsync.when(
          data: (set) => set != null
              ? Text('${_currentIndex + 1} / ${set.items.length}')
              : const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        actions: [
          setAsync.when(
            data: (set) => set != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: WordBadge(level: set.jlptLevel),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: setAsync.when(
        data: (set) {
          if (set == null) return const Center(child: Text('학습 세트 없음'));
          return catalogAsync.when(
            data: (catalog) {
              final wordMap = {for (final w in catalog) w.id: w};
              return _FlashcardBody(
                set: set,
                wordMap: wordMap,
                currentIndex: _currentIndex,
                isFlipped: _isFlipped,
                onFlip: () => setState(() => _isFlipped = !_isFlipped),
                onPrev: _currentIndex > 0
                    ? () => setState(() {
                          _currentIndex--;
                          _isFlipped = false;
                        })
                    : null,
                onNext: () => _onNext(context, ref, set),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('오류: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
      ),
    );
  }

  void _onNext(BuildContext context, WidgetRef ref, TodayStudySet set) {
    if (_currentIndex < set.items.length - 1) {
      setState(() {
        _currentIndex++;
        _isFlipped = false;
      });
    } else {
      // 마지막 카드 → 1단계 퀴즈로
      ref
          .read(todayStudySetProvider.notifier)
          .advanceStage(StudyStage.quizReading);
      context.go('/study/quiz-reading');
    }
  }
}

class _FlashcardBody extends StatelessWidget {
  final TodayStudySet set;
  final Map<String, Word> wordMap;
  final int currentIndex;
  final bool isFlipped;
  final VoidCallback onFlip;
  final VoidCallback? onPrev;
  final VoidCallback onNext;

  const _FlashcardBody({
    required this.set,
    required this.wordMap,
    required this.currentIndex,
    required this.isFlipped,
    required this.onFlip,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final item = set.items[currentIndex];
    final word = wordMap[item.wordId];
    if (word == null) return const Center(child: Text('단어 없음'));

    final isLastCard = currentIndex == set.items.length - 1;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Expanded(
            child: FlipCard(
              isFlipped: isFlipped,
              onTap: onFlip,
              front: _CardFace(
                child: Center(
                  child: Text(
                    word.expression.isNotEmpty ? word.expression : word.reading,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              back: _CardFace(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        word.reading,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        word.meaningKo,
                        style: const TextStyle(fontSize: 20),
                        textAlign: TextAlign.center,
                      ),
                      if (word.example != null) ...[
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 12),
                        Text(
                          word.example!.ja,
                          style: const TextStyle(fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          word.example!.reading,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          word.example!.ko,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (onPrev != null)
                IconButton(
                  onPressed: onPrev,
                  icon: const Icon(Icons.arrow_back_ios),
                ),
              const Spacer(),
              if (isLastCard && isFlipped)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                  ),
                  onPressed: onNext,
                  child: const Text('1단계 퀴즈 시작'),
                )
              else
                IconButton(
                  onPressed: onNext,
                  icon: const Icon(Icons.arrow_forward_ios),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  final Widget child;
  const _CardFace({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );
}
```

- [ ] **Step 2: app_router.dart flashcard 플레이스홀더 교체**

```dart
import '../../features/study/flashcard/flashcard_screen.dart';

// study/flashcard route
GoRoute(
  path: 'study/flashcard',
  builder: (_, __) => const FlashcardScreen(),
),
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/study/flashcard/ lib/core/router/app_router.dart
git commit -m "feat: add flashcard screen with flip animation"
```

---

### Task 5: 1단계 퀴즈 (읽기) 화면

**Files:**
- Create: `lib/features/study/quiz_reading/quiz_reading_screen.dart`
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: quiz_reading_screen.dart 작성**

```dart
// lib/features/study/quiz_reading/quiz_reading_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../application/providers/today_study_set_provider.dart';
import '../../../application/providers/word_catalog_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/word.dart';
import '../../../domain/models/enums.dart';
import '../../../domain/repositories/word_repository.dart';
import '../../../application/providers/database_provider.dart';
import '../../../widgets/word_badge.dart';

class QuizReadingScreen extends ConsumerStatefulWidget {
  const QuizReadingScreen({super.key});

  @override
  ConsumerState<QuizReadingScreen> createState() => _QuizReadingScreenState();
}

class _QuizReadingScreenState extends ConsumerState<QuizReadingScreen> {
  // 현재 라운드에서 남은 wordId 목록 (오답 포함 재출제)
  List<String> _queue = [];
  int _queueIndex = 0;
  List<Word> _choices = [];
  String? _selectedChoice;
  bool _showFeedback = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _initQueue();
    }
  }

  Future<void> _initQueue() async {
    final set = ref.read(todayStudySetProvider).valueOrNull;
    if (set == null) return;
    final allIds = set.items.map((i) => i.wordId).toList();
    setState(() {
      _queue = List.from(allIds);
      _queueIndex = 0;
    });
    await _loadChoices();
  }

  Future<void> _loadChoices() async {
    if (_queueIndex >= _queue.length) return;
    final wordId = _queue[_queueIndex];
    final catalog = ref.read(wordCatalogProvider).valueOrNull ?? [];
    final wordMap = {for (final w in catalog) w.id: w};
    final target = wordMap[wordId];
    if (target == null) return;

    final db = await ref.read(databaseProvider.future);
    final wordRepo = WordRepository(db);
    final set = ref.read(todayStudySetProvider).valueOrNull!;
    final excludeIds = [wordId];
    final similar = await wordRepo.getSimilarReading(
      target.reading,
      set.jlptLevel,
      3,
      excludeIds,
    );

    final choices = [target, ...similar]..shuffle();
    setState(() {
      _choices = choices;
      _selectedChoice = null;
      _showFeedback = false;
    });
  }

  void _onSelect(String reading, bool isCorrect) {
    if (_showFeedback) return;
    setState(() {
      _selectedChoice = reading;
      _showFeedback = true;
    });

    final wordId = _queue[_queueIndex];
    ref.read(todayStudySetProvider.notifier).updateItemResult(
          wordId,
          passed: isCorrect,
          isReadingStage: true,
        );

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      _advance(isCorrect, wordId);
    });
  }

  void _onDontKnow() => _onSelect('', false);

  void _advance(bool isCorrect, String wordId) {
    if (!isCorrect) {
      // 오답: 큐 끝에 다시 추가
      _queue.add(wordId);
    }
    final nextIndex = _queueIndex + 1;
    if (nextIndex >= _queue.length) {
      // 모두 통과 → 오답노트
      _goToWrongAnswers();
      return;
    }
    setState(() => _queueIndex = nextIndex);
    _loadChoices();
  }

  void _goToWrongAnswers() {
    context.go('/study/wrong-answers', extra: {'stage': 'reading'});
  }

  @override
  Widget build(BuildContext context) {
    final setAsync = ref.watch(todayStudySetProvider);
    final catalog = ref.watch(wordCatalogProvider).valueOrNull ?? [];
    final wordMap = {for (final w in catalog) w.id: w};

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: setAsync.when(
          data: (set) => set != null
              ? Text('${_queueIndex + 1} / ${_queue.length}')
              : const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        actions: [
          setAsync.when(
            data: (set) => set != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: WordBadge(level: set.jlptLevel),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: _queue.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(wordMap),
    );
  }

  Widget _buildBody(Map<String, Word> wordMap) {
    if (_queueIndex >= _queue.length) {
      return const Center(child: CircularProgressIndicator());
    }
    final wordId = _queue[_queueIndex];
    final word = wordMap[wordId];
    if (word == null) return const Center(child: Text('단어 없음'));
    final correctReading = word.reading;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          // 질문
          Center(
            child: Text(
              word.expression.isNotEmpty ? word.expression : word.reading,
              style: const TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 48),
          // 선택지 4개
          ..._choices.map((choice) {
            final isSelected = _selectedChoice == choice.reading ||
                (_selectedChoice == '' && choice.reading == correctReading);
            Color? bgColor;
            if (_showFeedback) {
              if (choice.reading == correctReading) {
                bgColor = AppColors.success.withOpacity(0.15);
              } else if (_selectedChoice == choice.reading) {
                bgColor = AppColors.error.withOpacity(0.15);
              }
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: bgColor ?? Theme.of(context).cardColor,
                  foregroundColor: choice.reading == correctReading && _showFeedback
                      ? AppColors.success
                      : AppColors.textPrimaryLight,
                  elevation: 0,
                  side: BorderSide(
                    color: _showFeedback && choice.reading == correctReading
                        ? AppColors.success
                        : AppColors.borderLight,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _showFeedback
                    ? null
                    : () => _onSelect(
                          choice.reading,
                          choice.reading == correctReading,
                        ),
                child: Text(choice.reading, style: const TextStyle(fontSize: 18)),
              ),
            );
          }),
          const Spacer(),
          // 모르겠다 버튼
          TextButton(
            onPressed: _showFeedback ? null : _onDontKnow,
            child: Text(
              '모르겠다',
              style: TextStyle(
                color: AppColors.textSecondaryLight,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: app_router.dart quiz-reading 플레이스홀더 교체**

```dart
import '../../features/study/quiz_reading/quiz_reading_screen.dart';

GoRoute(
  path: 'study/quiz-reading',
  builder: (_, __) => const QuizReadingScreen(),
),
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/study/quiz_reading/ lib/core/router/app_router.dart
git commit -m "feat: add quiz reading screen (1단계 읽기 퀴즈)"
```

---

### Task 6: 2단계 퀴즈 (뜻) 화면

**Files:**
- Create: `lib/features/study/quiz_meaning/quiz_meaning_screen.dart`
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: quiz_meaning_screen.dart 작성**

```dart
// lib/features/study/quiz_meaning/quiz_meaning_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../application/providers/today_study_set_provider.dart';
import '../../../application/providers/word_catalog_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/word.dart';
import '../../../domain/models/enums.dart';
import '../../../widgets/word_badge.dart';

class QuizMeaningScreen extends ConsumerStatefulWidget {
  const QuizMeaningScreen({super.key});

  @override
  ConsumerState<QuizMeaningScreen> createState() => _QuizMeaningScreenState();
}

class _QuizMeaningScreenState extends ConsumerState<QuizMeaningScreen> {
  List<String> _queue = [];
  int _queueIndex = 0;
  bool _revealed = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _initQueue();
    }
  }

  void _initQueue() {
    final set = ref.read(todayStudySetProvider).valueOrNull;
    if (set == null) return;
    setState(() {
      _queue = set.items.map((i) => i.wordId).toList();
      _queueIndex = 0;
      _revealed = false;
    });
  }

  void _onReveal() => setState(() => _revealed = true);

  void _onAssess(bool knows) {
    final wordId = _queue[_queueIndex];
    ref.read(todayStudySetProvider.notifier).updateItemResult(
          wordId,
          passed: knows,
          isReadingStage: false,
        );
    if (!knows) _queue.add(wordId); // 오답: 재출제
    final nextIndex = _queueIndex + 1;
    if (nextIndex >= _queue.length) {
      _finish();
      return;
    }
    setState(() {
      _queueIndex = nextIndex;
      _revealed = false;
    });
  }

  void _finish() {
    context.go('/study/wrong-answers', extra: {'stage': 'meaning'});
  }

  @override
  Widget build(BuildContext context) {
    final setAsync = ref.watch(todayStudySetProvider);
    final catalog = ref.watch(wordCatalogProvider).valueOrNull ?? [];
    final wordMap = {for (final w in catalog) w.id: w};

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('${_queueIndex + 1} / ${_queue.length}'),
        actions: [
          setAsync.when(
            data: (set) => set != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: WordBadge(level: set.jlptLevel),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: _queue.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(wordMap),
    );
  }

  Widget _buildBody(Map<String, Word> wordMap) {
    if (_queueIndex >= _queue.length) {
      return const Center(child: CircularProgressIndicator());
    }
    final wordId = _queue[_queueIndex];
    final word = wordMap[wordId];
    if (word == null) return const Center(child: Text('단어 없음'));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Center(
            child: Text(
              word.expression.isNotEmpty ? word.expression : word.reading,
              style: const TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 48),
          if (!_revealed)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _onReveal,
              child: const Text('뜻 확인', style: TextStyle(fontSize: 18)),
            ),
          if (_revealed) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.reading,
                    style: const TextStyle(
                      fontSize: 22,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(word.meaningKo, style: const TextStyle(fontSize: 18)),
                  if (word.example != null) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(word.example!.ja,
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(word.example!.ko,
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryLight)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => _onAssess(false),
                    child: const Text('몰라', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => _onAssess(true),
                    child: const Text('알아', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: app_router.dart quiz-meaning 교체**

```dart
import '../../features/study/quiz_meaning/quiz_meaning_screen.dart';

GoRoute(
  path: 'study/quiz-meaning',
  builder: (_, __) => const QuizMeaningScreen(),
),
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/study/quiz_meaning/ lib/core/router/app_router.dart
git commit -m "feat: add quiz meaning screen (2단계 뜻 퀴즈)"
```

---

### Task 7: 오답노트 화면

**Files:**
- Create: `lib/features/study/wrong_answers/wrong_answers_screen.dart`
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: wrong_answers_screen.dart 작성**

```dart
// lib/features/study/wrong_answers/wrong_answers_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../application/providers/today_study_set_provider.dart';
import '../../../application/providers/word_catalog_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/word.dart';
import '../../../domain/models/enums.dart';
import '../../../widgets/word_badge.dart';

class WrongAnswersScreen extends ConsumerWidget {
  final String stage; // 'reading' or 'meaning'

  const WrongAnswersScreen({super.key, required this.stage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setAsync = ref.watch(todayStudySetProvider);
    final catalog = ref.watch(wordCatalogProvider).valueOrNull ?? [];
    final wordMap = {for (final w in catalog) w.id: w};

    return setAsync.when(
      data: (set) {
        if (set == null) {
          return const Scaffold(body: Center(child: Text('세트 없음')));
        }

        final isReading = stage == 'reading';
        final wrongItems = isReading
            ? set.items.where((i) => !i.readingPassed).toList()
            : set.items.where((i) => !i.meaningPassed).toList();
        final correctCount = set.items.length - wrongItems.length;
        final allPassed = wrongItems.isEmpty;

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(isReading ? '1단계 결과' : '2단계 결과'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 결과 요약
                Text(
                  '$correctCount / ${set.items.length} 정답',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // 오답 목록
                if (wrongItems.isNotEmpty) ...[
                  Text('오답 ${wrongItems.length}개',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: wrongItems.length,
                      itemBuilder: (context, index) {
                        final item = wrongItems[index];
                        final word = wordMap[item.wordId];
                        if (word == null) return const SizedBox.shrink();
                        return _WrongWordTile(word: word, level: set.jlptLevel);
                      },
                    ),
                  ),
                ] else
                  Expanded(
                    child: Center(
                      child: Text(
                        '모두 정답!',
                        style: TextStyle(
                          fontSize: 24,
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // 버튼
                if (!allPassed)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () {
                      if (isReading) {
                        context.go('/study/quiz-reading');
                      } else {
                        context.go('/study/quiz-meaning');
                      }
                    },
                    child: const Text('다시 퀴즈', style: TextStyle(fontSize: 18)),
                  ),

                if (allPassed && isReading)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () {
                      ref
                          .read(todayStudySetProvider.notifier)
                          .advanceStage(StudyStage.quizMeaning);
                      context.go('/study/quiz-meaning');
                    },
                    child: const Text('다음 단계로', style: TextStyle(fontSize: 18)),
                  ),

                if (allPassed && !isReading)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () async {
                      await ref
                          .read(todayStudySetProvider.notifier)
                          .advanceStage(StudyStage.completed);
                      await ref
                          .read(todayStudySetProvider.notifier)
                          .markCompletedWords();
                      if (context.mounted) context.go('/study/complete');
                    },
                    child: const Text('완료', style: TextStyle(fontSize: 18)),
                  ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('오류: $e'))),
    );
  }
}

class _WrongWordTile extends StatefulWidget {
  final Word word;
  final JlptLevel level;
  const _WrongWordTile({required this.word, required this.level});

  @override
  State<_WrongWordTile> createState() => _WrongWordTileState();
}

class _WrongWordTileState extends State<_WrongWordTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  widget.word.expression.isNotEmpty
                      ? widget.word.expression
                      : widget.word.reading,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Text(widget.word.reading,
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondaryLight)),
                const Spacer(),
                WordBadge(level: widget.level),
              ],
            ),
            const SizedBox(height: 4),
            Text(widget.word.meaningKo,
                style: TextStyle(
                    fontSize: 14, color: AppColors.textSecondaryLight)),
            if (_expanded && widget.word.example != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(widget.word.example!.ja,
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
              Text(widget.word.example!.ko,
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondaryLight)),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: app_router.dart wrong-answers 교체**

```dart
import '../../features/study/wrong_answers/wrong_answers_screen.dart';

GoRoute(
  path: 'study/wrong-answers',
  builder: (context, state) {
    final extra = state.extra as Map<String, dynamic>? ?? {};
    final stage = extra['stage'] as String? ?? 'reading';
    return WrongAnswersScreen(stage: stage);
  },
),
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/study/wrong_answers/ lib/core/router/app_router.dart
git commit -m "feat: add wrong answers screen with expandable word tiles"
```

---

### Task 8: 학습 완료 화면

**Files:**
- Create: `lib/features/study/complete/complete_screen.dart`
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: complete_screen.dart 작성**

```dart
// lib/features/study/complete/complete_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../application/providers/today_study_set_provider.dart';
import '../../../application/providers/progress_summary_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/enums.dart';

class CompleteScreen extends ConsumerStatefulWidget {
  const CompleteScreen({super.key});

  @override
  ConsumerState<CompleteScreen> createState() => _CompleteScreenState();
}

class _CompleteScreenState extends ConsumerState<CompleteScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final setAsync = ref.watch(todayStudySetProvider);
    final summaryAsync = ref.watch(progressSummaryProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScaleTransition(
                scale: _scaleAnim,
                child: const Icon(
                  Icons.check_circle_outline,
                  size: 80,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '오늘 학습 완료!',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // 통계
              setAsync.when(
                data: (set) {
                  if (set == null) return const SizedBox.shrink();
                  final totalAttempts = set.items.fold<int>(
                    0,
                    (sum, i) => sum + i.readingAttempts + i.meaningAttempts,
                  );
                  final correctCount = set.items
                      .where((i) => i.isFullyCompleted)
                      .length;
                  final accuracy = set.items.isEmpty
                      ? 0.0
                      : correctCount / set.items.length * 100;

                  return Column(
                    children: [
                      _StatRow(
                        label: '총 시도',
                        value: '$totalAttempts회',
                      ),
                      _StatRow(
                        label: '최종 정답률',
                        value: '${accuracy.toStringAsFixed(0)}%',
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 16),

              // 전체 진도
              summaryAsync.when(
                data: (summary) => _StatRow(
                  label:
                      '${summary.currentLevel == JlptLevel.n3 ? "N3" : "N2"} 전체 진도',
                  value: '${summary.completedCount} / ${summary.totalCount}',
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 48),

              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => context.push('/review'),
                child: const Text('복습하기', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => context.go('/'),
                child: const Text('홈으로', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyLarge),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      );
}
```

- [ ] **Step 2: app_router.dart complete 교체**

```dart
import '../../features/study/complete/complete_screen.dart';

GoRoute(
  path: 'study/complete',
  builder: (_, __) => const CompleteScreen(),
),
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/study/complete/ lib/core/router/app_router.dart
git commit -m "feat: add study complete screen with stats"
```

---

### Task 9: 복습 퀴즈 화면

**Files:**
- Create: `lib/application/providers/review_session_provider.dart`
- Create: `lib/features/review/review_screen.dart`
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: review_session_provider.dart 작성**

```dart
// lib/application/providers/review_session_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/review_session.dart';
import '../../domain/models/enums.dart';
import '../../domain/repositories/review_repository.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../domain/repositories/word_repository.dart';
import 'database_provider.dart';
import 'progress_summary_provider.dart';

final reviewSessionProvider =
    AsyncNotifierProvider<ReviewSessionNotifier, ReviewSession?>(
  ReviewSessionNotifier.new,
);

class ReviewSessionNotifier extends AsyncNotifier<ReviewSession?> {
  @override
  Future<ReviewSession?> build() async => null;

  Future<ReviewSession> startNewSession() async {
    final db = await ref.read(databaseProvider.future);
    final summary = await ref.read(progressSummaryProvider.future);
    final progressRepo = ProgressRepository(db);
    final reviewRepo = ReviewRepository(db);

    final completedIds =
        await progressRepo.getCompletedWordIds(summary.currentLevel);
    completedIds.shuffle();
    final selected = completedIds.take(20).toList();

    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final sessionId = 'review_${now.millisecondsSinceEpoch}';

    final items = selected.asMap().entries.map((e) {
      return ReviewSessionItem(
        sessionId: sessionId,
        wordId: e.value,
        displayOrder: e.key,
        readingPassed: false,
        meaningPassed: false,
        readingAttempts: 0,
        meaningAttempts: 0,
      );
    }).toList();

    final session = ReviewSession(
      id: sessionId,
      reviewDate: today,
      itemCount: selected.length,
      status: StudyStage.quizReading,
      items: items,
      startedAt: now,
    );

    await reviewRepo.createSession(session);
    state = AsyncData(session);
    return session;
  }

  Future<void> updateItemResult(
    String wordId, {
    required bool passed,
    required bool isReadingStage,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final db = await ref.read(databaseProvider.future);
    final repo = ReviewRepository(db);

    final idx = current.items.indexWhere((i) => i.wordId == wordId);
    if (idx < 0) return;
    final item = current.items[idx];
    final updated = isReadingStage
        ? item.copyWith(
            readingPassed: passed,
            readingAttempts: item.readingAttempts + 1,
          )
        : item.copyWith(
            meaningPassed: passed,
            meaningAttempts: item.meaningAttempts + 1,
          );
    await repo.updateItem(updated);

    final newItems = List<ReviewSessionItem>.from(current.items);
    newItems[idx] = updated;
    state = AsyncData(current.copyWith(items: newItems));
  }

  Future<void> complete() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final db = await ref.read(databaseProvider.future);
    final now = DateTime.now();
    await ReviewRepository(db).updateSessionStatus(
      current.id,
      StudyStage.completed,
      completedAt: now,
    );
    state = AsyncData(current.copyWith(
      status: StudyStage.completed,
      completedAt: now,
    ));
    ref.invalidate(progressSummaryProvider);
  }
}
```

- [ ] **Step 2: review_screen.dart 작성**

복습 퀴즈는 1단계(읽기) → 2단계(뜻) → 결과 순으로 내부 상태 머신으로 처리

```dart
// lib/features/review/review_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/providers/review_session_provider.dart';
import '../../application/providers/word_catalog_provider.dart';
import '../../application/providers/database_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/word.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/review_session.dart';
import '../../domain/repositories/word_repository.dart';
import '../../widgets/word_badge.dart';

enum _ReviewPhase { loading, reading, readingResult, meaning, meaningResult, done }

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  _ReviewPhase _phase = _ReviewPhase.loading;
  List<String> _readingQueue = [];
  List<String> _meaningQueue = [];
  int _queueIndex = 0;
  List<Word> _choices = [];
  String? _selectedChoice;
  bool _showFeedback = false;
  bool _meaningRevealed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final session =
        await ref.read(reviewSessionProvider.notifier).startNewSession();
    setState(() {
      _readingQueue = session.items.map((i) => i.wordId).toList();
      _meaningQueue = List.from(_readingQueue);
      _queueIndex = 0;
      _phase = _ReviewPhase.reading;
    });
    await _loadReadingChoices();
  }

  Future<void> _loadReadingChoices() async {
    if (_queueIndex >= _readingQueue.length) return;
    final wordId = _readingQueue[_queueIndex];
    final catalog = ref.read(wordCatalogProvider).valueOrNull ?? [];
    final wordMap = {for (final w in catalog) w.id: w};
    final target = wordMap[wordId];
    if (target == null) return;

    final db = await ref.read(databaseProvider.future);
    final session = ref.read(reviewSessionProvider).valueOrNull!;
    final similar = await WordRepository(db).getSimilarReading(
      target.reading,
      session.items.first.wordId.startsWith('n3') ? JlptLevel.n3 : JlptLevel.n2,
      3,
      [wordId],
    );
    final choices = [target, ...similar]..shuffle();
    setState(() {
      _choices = choices;
      _selectedChoice = null;
      _showFeedback = false;
    });
  }

  void _onReadingSelect(String reading, bool isCorrect) {
    if (_showFeedback) return;
    setState(() {
      _selectedChoice = reading;
      _showFeedback = true;
    });
    final wordId = _readingQueue[_queueIndex];
    ref.read(reviewSessionProvider.notifier).updateItemResult(
          wordId,
          passed: isCorrect,
          isReadingStage: true,
        );
    if (!isCorrect) _readingQueue.add(wordId);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      final next = _queueIndex + 1;
      if (next >= _readingQueue.length) {
        setState(() {
          _phase = _ReviewPhase.meaning;
          _queueIndex = 0;
          _meaningRevealed = false;
        });
      } else {
        setState(() => _queueIndex = next);
        _loadReadingChoices();
      }
    });
  }

  void _onMeaningAssess(bool knows) {
    final wordId = _meaningQueue[_queueIndex];
    ref.read(reviewSessionProvider.notifier).updateItemResult(
          wordId,
          passed: knows,
          isReadingStage: false,
        );
    if (!knows) _meaningQueue.add(wordId);
    final next = _queueIndex + 1;
    if (next >= _meaningQueue.length) {
      ref.read(reviewSessionProvider.notifier).complete();
      setState(() => _phase = _ReviewPhase.done);
    } else {
      setState(() {
        _queueIndex = next;
        _meaningRevealed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(wordCatalogProvider).valueOrNull ?? [];
    final wordMap = {for (final w in catalog) w.id: w};
    final sessionAsync = ref.watch(reviewSessionProvider);
    final session = sessionAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(_phaseTitle()),
      ),
      body: switch (_phase) {
        _ReviewPhase.loading =>
          const Center(child: CircularProgressIndicator()),
        _ReviewPhase.reading =>
          _buildReadingPhase(wordMap, session),
        _ReviewPhase.meaning =>
          _buildMeaningPhase(wordMap),
        _ReviewPhase.done =>
          _buildDone(session, wordMap),
        _ => const SizedBox.shrink(),
      },
    );
  }

  String _phaseTitle() => switch (_phase) {
        _ReviewPhase.reading =>
          '읽기 ${_queueIndex + 1} / ${_readingQueue.length}',
        _ReviewPhase.meaning =>
          '뜻 ${_queueIndex + 1} / ${_meaningQueue.length}',
        _ReviewPhase.done => '복습 완료',
        _ => '복습',
      };

  Widget _buildReadingPhase(Map<String, Word> wordMap, ReviewSession? session) {
    if (_queueIndex >= _readingQueue.length) {
      return const Center(child: CircularProgressIndicator());
    }
    final wordId = _readingQueue[_queueIndex];
    final word = wordMap[wordId];
    if (word == null) return const Center(child: Text('단어 없음'));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Center(
            child: Text(
              word.expression.isNotEmpty ? word.expression : word.reading,
              style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 48),
          ..._choices.map((choice) {
            final isCorrect = choice.reading == word.reading;
            Color? bgColor;
            if (_showFeedback) {
              if (isCorrect) bgColor = AppColors.success.withOpacity(0.15);
              else if (_selectedChoice == choice.reading)
                bgColor = AppColors.error.withOpacity(0.15);
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: bgColor ?? Theme.of(context).cardColor,
                  foregroundColor: isCorrect && _showFeedback
                      ? AppColors.success
                      : AppColors.textPrimaryLight,
                  elevation: 0,
                  side: BorderSide(
                    color: _showFeedback && isCorrect
                        ? AppColors.success
                        : AppColors.borderLight,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _showFeedback
                    ? null
                    : () => _onReadingSelect(choice.reading, isCorrect),
                child: Text(choice.reading,
                    style: const TextStyle(fontSize: 18)),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMeaningPhase(Map<String, Word> wordMap) {
    if (_queueIndex >= _meaningQueue.length) {
      return const Center(child: CircularProgressIndicator());
    }
    final wordId = _meaningQueue[_queueIndex];
    final word = wordMap[wordId];
    if (word == null) return const Center(child: Text('단어 없음'));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Center(
            child: Text(
              word.expression.isNotEmpty ? word.expression : word.reading,
              style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 48),
          if (!_meaningRevealed)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () => setState(() => _meaningRevealed = true),
              child: const Text('뜻 확인', style: TextStyle(fontSize: 18)),
            ),
          if (_meaningRevealed) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(word.reading,
                      style: const TextStyle(
                          fontSize: 22,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(word.meaningKo,
                      style: const TextStyle(fontSize: 18)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => _onMeaningAssess(false),
                    child: const Text('몰라', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => _onMeaningAssess(true),
                    child: const Text('알아', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDone(ReviewSession? session, Map<String, Word> wordMap) {
    if (session == null) return const Center(child: Text('세션 없음'));
    final readingCorrect =
        session.items.where((i) => i.readingPassed).length;
    final meaningCorrect =
        session.items.where((i) => i.meaningPassed).length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.done_all, size: 64, color: AppColors.success),
          const SizedBox(height: 24),
          Text('복습 완료',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center),
          const SizedBox(height: 32),
          _StatRow(label: '읽기 정답', value: '$readingCorrect / ${session.itemCount}'),
          _StatRow(label: '뜻 정답', value: '$meaningCorrect / ${session.itemCount}'),
          const SizedBox(height: 48),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => context.go('/'),
            child: const Text('홈으로', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyLarge),
            Text(value,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ],
        ),
      );
}
```

- [ ] **Step 3: app_router.dart review 교체**

```dart
import '../../features/review/review_screen.dart';

GoRoute(
  path: 'review',
  builder: (_, __) => const ReviewScreen(),
),
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/review/ lib/application/providers/review_session_provider.dart lib/core/router/app_router.dart
git commit -m "feat: add review quiz screen (1단계+2단계)"
```

---

### Task 10: 빌드 검증

- [ ] **Step 1: flutter analyze**

```bash
flutter analyze
```

Expected: No issues (또는 info 수준 경고만)

- [ ] **Step 2: iOS 빌드 확인**

```bash
flutter build ios --simulator --no-codesign 2>&1 | tail -5
```

Expected: `Build complete.`

- [ ] **Step 3: 학습 플로우 전체 수동 테스트**

실행 후 확인 항목:
- 홈: D-Day, 오늘 진도, N3/N2 뱃지 표시
- 오늘 학습 시작 → 플래시카드 (카드 탭 시 플립 애니메이션)
- 마지막 카드 뒤집은 후 "1단계 퀴즈 시작" 버튼 노출
- 1단계 퀴즈: 4지선다, 정답 초록/오답 빨강, 1.5초 자동 이동, 모르겠다 동작
- 오답노트: 오답 목록, 탭 시 예문 펼치기
- 전부 정답 → "다음 단계로" 버튼
- 2단계 퀴즈: 뜻 확인 → 알아/몰라
- 학습 완료 화면: 통계 표시, 홈으로/복습하기 버튼
- 복습 퀴즈: 홈의 복습 버튼 탭 → 복습 플로우 동작

- [ ] **Step 4: Final commit**

```bash
git add .
git commit -m "chore: verify study flow build and manual test"
```

---

## Self-Review

**Spec coverage:**
- [x] 플래시카드 — Task 4 (플립 애니메이션, 스와이프/이전/다음, 마지막 후 퀴즈 시작)
- [x] 1단계 퀴즈 — Task 5 (4지선다, 유사 reading 오답, 모르겠다, 1.5초 자동 진행)
- [x] 2단계 퀴즈 — Task 6 (알아/몰라 자가평가, 오답 재출제)
- [x] 오답노트 — Task 7 (결과 요약, 오답 목록 탭 시 예문 펼치기, 다시퀴즈/다음단계/완료)
- [x] 학습 완료 — Task 8 (시각적 이펙트, 통계, 복습하기/홈으로)
- [x] 복습 퀴즈 — Task 9 (완료 단어 랜덤 20개, 1단계→2단계 순서, 결과만 표시)
- [x] 홈 — Task 3 (D-Day, 오늘/전체 진도, 오늘 학습 시작/이어하기, 복습/가나표 버튼)
- [x] 중간 이탈 처리 — 플래시카드/퀴즈 모두 뒤로가기 시 홈으로 (go_router pop)
- [x] 오늘 세트 날짜별 고정 — TodayStudySetNotifier.createTodaySet()에서 최초 1회 생성

**Placeholder scan:** 없음

**Type consistency:**
- `StudyStage.quizReading` / `quizMeaning` — advanceStage() 호출부와 일치
- `TodayStudyItem.isFullyCompleted` — `readingPassed && meaningPassed` 로 정의, 완료 화면/오답노트 모두 동일 속성 사용
- `QuizResult` enum — updateItemResult()에서 isReadingStage 플래그로 분기, DB 저장 시 snake_case 변환 함수 공유
