import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/error_tag.dart';
import '../../domain/models/today_study_set.dart';
import '../../domain/repositories/miss_log_repository.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../domain/repositories/study_set_repository.dart';
import '../../domain/services/study_set_builder.dart';
import '../../features/explore/explore_provider.dart';
import '../../features/stats/stats_provider.dart';
import 'database_provider.dart';
import 'miss_tag_counts_provider.dart';
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

  /// [studyDate]는 항목이 속할 세트의 날짜다. 여기서 `todayDateString`을 다시
  /// 계산하면 자정을 넘긴 append에서 부모 세트(어제)와 항목(오늘)의 날짜가
  /// 어긋나 고아 항목이 생기므로, 호출자가 세트의 날짜를 그대로 넘긴다.
  Future<List<TodayStudyItem>> _buildItems({
    required int startOrder,
    required Set<String> exclude,
    required String studyDate,
  }) async {
    final db = await ref.read(databaseProvider.future);
    final summary = await ref.read(progressSummaryProvider.future);
    final builder = StudySetBuilder(ProgressRepository(db));
    final newIds = await builder.pickNewWordIds(summary.dailyTarget, exclude: exclude);
    final weakIds = await builder.pickWeakWordIds(exclude: {...exclude, ...newIds});
    final ids = [...newIds, ...weakIds]..shuffle();
    final now = DateTime.now();
    return [
      for (var i = 0; i < ids.length; i++)
        TodayStudyItem(
          studyDate: studyDate,
          wordId: ids[i],
          displayOrder: startOrder + i,
          passed: false,
          attempts: 0,
          updatedAt: now,
        ),
    ];
  }

  Future<TodayStudySet> createTodaySet() async {
    // 진행 중인 build()가 나중에 state를 덮어쓰지 않도록 먼저 해소한다.
    await future;
    final db = await ref.read(databaseProvider.future);
    final now = DateTime.now();
    final studyDate = todayDateString(now);
    final items = await _buildItems(
      startOrder: 0,
      exclude: const {},
      studyDate: studyDate,
    );
    final set = TodayStudySet(
      studyDate: studyDate,
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
    final current = await future;
    if (current == null) return createTodaySet();
    final db = await ref.read(databaseProvider.future);
    final items = await _buildItems(
      startOrder: current.items.length,
      exclude: current.items.map((i) => i.wordId).toSet(),
      studyDate: current.studyDate,
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
    final current = await future;
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
      ref.invalidate(missTagCountsProvider);
    }
    final items = List<TodayStudyItem>.from(current.items)..[idx] = updated;
    state = AsyncData(current.copyWith(items: items, updatedAt: DateTime.now()));
  }

  Future<void> finish() async {
    final current = await future;
    if (current == null) return;
    final db = await ref.read(databaseProvider.future);
    final progressRepo = ProgressRepository(db);
    for (final item in current.items.where((i) => i.passed)) {
      await progressRepo.markCompleted(item.wordId);
    }
    final now = DateTime.now();
    await StudySetRepository(db).updateSetStatus(current.studyDate, StudyStage.completed, completedAt: now);
    state = AsyncData(current.copyWith(status: StudyStage.completed, completedAt: now, updatedAt: now));
    // 완료 표시는 홈(요약)뿐 아니라 탐색 목록의 ✓·필터와 통계 화면도 바꾼다.
    ref.invalidate(progressSummaryProvider);
    ref.invalidate(exploreProvider);
    ref.invalidate(statsProvider);
  }
}
