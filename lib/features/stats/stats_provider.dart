import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/database_provider.dart';
import '../../application/providers/word_catalog_provider.dart';
import '../../domain/models/enums.dart';
import '../../domain/repositories/progress_repository.dart';

class StatsState {
  final int n3Completed;
  final int n3Total;
  final int n2Completed;
  final int n2Total;

  const StatsState({
    required this.n3Completed,
    required this.n3Total,
    required this.n2Completed,
    required this.n2Total,
  });

  double get n3Percent =>
      n3Total == 0 ? 0.0 : n3Completed / n3Total;

  double get n2Percent =>
      n2Total == 0 ? 0.0 : n2Completed / n2Total;

  double get overallPercent {
    final total = n3Total + n2Total;
    if (total == 0) return 0.0;
    return (n3Completed + n2Completed) / total;
  }
}

final statsProvider = FutureProvider<StatsState>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final catalog = await ref.watch(wordCatalogProvider.future);
  final repo = ProgressRepository(db);

  final n3Completed = (await repo.getCompletedWordIds(JlptLevel.n3)).length;
  final n2Completed = (await repo.getCompletedWordIds(JlptLevel.n2)).length;

  final n3Total = catalog.where((w) => w.jlptLevel == JlptLevel.n3).length;
  final n2Total = catalog.where((w) => w.jlptLevel == JlptLevel.n2).length;

  return StatsState(
    n3Completed: n3Completed,
    n3Total: n3Total,
    n2Completed: n2Completed,
    n2Total: n2Total,
  );
});
