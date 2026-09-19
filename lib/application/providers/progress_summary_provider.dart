import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../domain/repositories/word_repository.dart';
import 'database_provider.dart';
import 'settings_provider.dart';
import 'word_catalog_provider.dart';

/// 시험일 이후 하루 신규 단어 수.
const int kPostExamDailyTarget = 10;

class ProgressSummary {
  final int completedCount;
  final int totalCount;
  final int daysUntilExam;
  final int dailyTarget;
  final int weakCount;

  const ProgressSummary({
    required this.completedCount,
    required this.totalCount,
    required this.daysUntilExam,
    required this.dailyTarget,
    required this.weakCount,
  });

  bool get isExamPassed => daysUntilExam < 0;
  int get remainingCount => totalCount - completedCount;
}

final progressSummaryProvider = FutureProvider<ProgressSummary>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final settings = await ref.watch(settingsProvider.future);
  await ref.watch(wordCatalogProvider.future); // 시딩 완료 보장
  final progressRepo = ProgressRepository(db);
  final wordRepo = WordRepository(db);

  final total = await wordRepo.count();
  final completed = await progressRepo.countCompleted();
  final remaining = total - completed;
  final days = settings.daysUntilExam(DateTime.now());

  final int dailyTarget;
  if (days <= 0) {
    dailyTarget = remaining == 0 ? 0 : kPostExamDailyTarget;
  } else {
    dailyTarget = (remaining / days).ceil();
  }

  return ProgressSummary(
    completedCount: completed,
    totalCount: total,
    daysUntilExam: days,
    dailyTarget: dailyTarget,
    weakCount: await progressRepo.countWeak(),
  );
});
