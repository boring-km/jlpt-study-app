import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/word.dart';
import '../../domain/models/enums.dart';
import '../../domain/repositories/word_repository.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../application/providers/database_provider.dart';
import '../../application/providers/word_catalog_provider.dart';

class ExploreFilter {
  final String query;
  final JlptLevel? levelFilter;
  final bool? completedFilter;

  const ExploreFilter({
    this.query = '',
    this.levelFilter,
    this.completedFilter,
  });

  ExploreFilter copyWith({
    String? query,
    Object? levelFilter = _sentinel,
    Object? completedFilter = _sentinel,
  }) =>
      ExploreFilter(
        query: query ?? this.query,
        levelFilter: levelFilter == _sentinel
            ? this.levelFilter
            : levelFilter as JlptLevel?,
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
    final progressRepo = ProgressRepository(db);
    final n3Ids = (await progressRepo.getCompletedWordIds(JlptLevel.n3)).toSet();
    final n2Ids = (await progressRepo.getCompletedWordIds(JlptLevel.n2)).toSet();
    final completedIds = {...n3Ids, ...n2Ids};

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

    List<Word> results;
    if (filter.query.isNotEmpty) {
      results = await wordRepo.search(filter.query);
    } else {
      results = filter.levelFilter != null
          ? await wordRepo.getByLevel(filter.levelFilter!)
          : await wordRepo.getAll();
    }

    if (filter.levelFilter != null && filter.query.isNotEmpty) {
      results = results
          .where((w) => w.jlptLevel == filter.levelFilter)
          .toList();
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
