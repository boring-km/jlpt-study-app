import 'package:flutter_riverpod/flutter_riverpod.dart';
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

class ExploreNotifier extends AsyncNotifier<ExploreState> {
  @override
  Future<ExploreState> build() async {
    final db = await ref.watch(databaseProvider.future);
    final catalog = await ref.watch(wordCatalogProvider.future);
    final completedIds =
        (await ProgressRepository(db).getCompletedWordIds()).toSet();

    return ExploreState(
      filter: const ExploreFilter(),
      results: catalog,
      completedWordIds: completedIds,
      isLoading: false,
    );
  }

  Future<void> updateFilter(ExploreFilter filter) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(isLoading: true, filter: filter));

    final db = await ref.read(databaseProvider.future);
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
        final isCompleted = current.completedWordIds.contains(w.id);
        return filter.completedFilter! ? isCompleted : !isCompleted;
      }).toList();
    }

    state = AsyncData(
      current.copyWith(
        filter: filter,
        results: results,
        isLoading: false,
      ),
    );
  }
}
