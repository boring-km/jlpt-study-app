import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../domain/models/word.dart';
import '../../domain/repositories/word_repository.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../application/providers/database_provider.dart';
import '../../application/providers/word_catalog_provider.dart';

class ExploreFilter {
  final String query;

  /// `Word.source` 값으로 거르기. 현재는 `'user'`(추가한 단어)만 쓴다.
  final String? sourceFilter;
  final bool? completedFilter;

  const ExploreFilter({
    this.query = '',
    this.sourceFilter,
    this.completedFilter,
  });

  ExploreFilter copyWith({
    String? query,
    Object? sourceFilter = _sentinel,
    Object? completedFilter = _sentinel,
  }) =>
      ExploreFilter(
        query: query ?? this.query,
        sourceFilter: sourceFilter == _sentinel
            ? this.sourceFilter
            : sourceFilter as String?,
        completedFilter: completedFilter == _sentinel
            ? this.completedFilter
            : completedFilter as bool?,
      );
}

const _sentinel = Object();

class ExploreState {
  final ExploreFilter filter;
  final List<Word> results;
  final Set<String> completedWordIds;
  final bool isLoading;

  const ExploreState({
    required this.filter,
    required this.results,
    required this.completedWordIds,
    required this.isLoading,
  });

  ExploreState copyWith({
    ExploreFilter? filter,
    List<Word>? results,
    Set<String>? completedWordIds,
    bool? isLoading,
  }) =>
      ExploreState(
        filter: filter ?? this.filter,
        results: results ?? this.results,
        completedWordIds: completedWordIds ?? this.completedWordIds,
        isLoading: isLoading ?? this.isLoading,
      );
}

final exploreProvider =
    AsyncNotifierProvider<ExploreNotifier, ExploreState>(ExploreNotifier.new);

/// 사용자가 고른 필터. 카탈로그가 바뀌면([wordCatalogProvider]) [exploreProvider]가
/// 통째로 다시 빌드되므로, 필터를 그 상태 안에 두면 단어를 하나 추가할 때마다
/// 칩 선택과 검색어가 풀린다. 그래서 다시 빌드되는 상태 바깥에 보관한다.
final exploreFilterProvider =
    StateProvider<ExploreFilter>((ref) => const ExploreFilter());

class ExploreNotifier extends AsyncNotifier<ExploreState> {
  @override
  Future<ExploreState> build() async {
    final db = await ref.watch(databaseProvider.future);
    final catalog = await ref.watch(wordCatalogProvider.future);
    final completedIds =
        (await ProgressRepository(db).getCompletedWordIds()).toSet();
    // watch가 아니라 read — 필터 변경은 updateFilter가 직접 처리한다.
    // watch하면 필터를 바꿀 때마다 build()가 다시 돌아 무한 루프가 된다.
    final filter = ref.read(exploreFilterProvider);

    return ExploreState(
      filter: filter,
      results: _isUnfiltered(filter)
          ? catalog
          : await _applyFilter(filter, db, completedIds),
      completedWordIds: completedIds,
      isLoading: false,
    );
  }

  static bool _isUnfiltered(ExploreFilter filter) =>
      filter.query.isEmpty &&
      filter.sourceFilter == null &&
      filter.completedFilter == null;

  Future<List<Word>> _applyFilter(
    ExploreFilter filter,
    Database db,
    Set<String> completedWordIds,
  ) async {
    final wordRepo = WordRepository(db);

    var results = filter.query.isNotEmpty
        ? await wordRepo.search(filter.query)
        : await wordRepo.getAll();

    if (filter.sourceFilter != null) {
      results =
          results.where((w) => w.source == filter.sourceFilter).toList();
    }

    if (filter.completedFilter != null) {
      results = results.where((w) {
        final isCompleted = completedWordIds.contains(w.id);
        return filter.completedFilter! ? isCompleted : !isCompleted;
      }).toList();
    }

    return results;
  }

  Future<void> updateFilter(ExploreFilter filter) async {
    final current = state.valueOrNull;
    if (current == null) return;
    ref.read(exploreFilterProvider.notifier).state = filter;
    state = AsyncData(current.copyWith(isLoading: true, filter: filter));

    final db = await ref.read(databaseProvider.future);
    final results = await _applyFilter(filter, db, current.completedWordIds);

    state = AsyncData(
      current.copyWith(
        filter: filter,
        results: results,
        isLoading: false,
      ),
    );
  }
}
