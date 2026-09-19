import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/database_provider.dart';
import '../../application/providers/miss_tag_counts_provider.dart';
import '../../application/providers/word_catalog_provider.dart';
import '../../domain/models/error_tag.dart';
import '../../domain/repositories/progress_repository.dart';

class StatsState {
  final int completed;
  final int total;
  final int weak;
  final Map<ErrorTag, int> missByTag;

  const StatsState({
    required this.completed,
    required this.total,
    required this.weak,
    required this.missByTag,
  });

  double get percent => total == 0 ? 0.0 : completed / total;
}

final statsProvider = FutureProvider<StatsState>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final catalog = await ref.watch(wordCatalogProvider.future);
  final repo = ProgressRepository(db);

  return StatsState(
    completed: await repo.countCompleted(),
    total: catalog.length,
    weak: await repo.countWeak(),
    missByTag: await ref.watch(missTagCountsProvider.future),
  );
});
