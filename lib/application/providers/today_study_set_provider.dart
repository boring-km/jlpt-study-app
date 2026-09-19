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
