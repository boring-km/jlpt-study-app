import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/today_study_set.dart';
import '../../domain/models/enums.dart';
import '../../domain/repositories/study_set_repository.dart';
import '../../domain/repositories/progress_repository.dart';
import 'database_provider.dart';
import 'progress_summary_provider.dart';

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

  /// 완료된 세트를 삭제하고 새 단어 세트로 학습 시작
  Future<TodayStudySet> createNextSet() async {
    final db = await ref.read(databaseProvider.future);
    final repo = StudySetRepository(db);
    final today = _todayStr();
    await repo.deleteSet(today);
    return createTodaySet();
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

  /// 단어 결과 업데이트. 오답이면 miss_count +1, 정답이면 -1 (0 floor).
  Future<void> updateItemResult(
    String wordId, {
    required bool passed,
    required bool isReadingStage,
  }) async {
    final db = await ref.read(databaseProvider.future);
    final repo = StudySetRepository(db);
    final progressRepo = ProgressRepository(db);
    final current = state.valueOrNull;
    if (current == null) return;

    final itemIndex = current.items.indexWhere((i) => i.wordId == wordId);
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

    if (passed) {
      await progressRepo.decrementMiss(wordId);
    } else {
      await progressRepo.incrementMiss(wordId);
    }

    final newItems = List<TodayStudyItem>.from(current.items);
    newItems[itemIndex] = updated;
    state = AsyncData(
      current.copyWith(items: newItems, updatedAt: DateTime.now()),
    );
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
