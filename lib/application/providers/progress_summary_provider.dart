import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/enums.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../domain/repositories/word_repository.dart';
import 'database_provider.dart';
import 'settings_provider.dart';

class ProgressSummary {
  final JlptLevel currentLevel;
  final int completedCount;
  final int totalCount;
  final int n3Completed;
  final int n3Total;
  final int n2Completed;
  final int n2Total;
  final int daysUntilExam;
  final int dailyTarget;
  final bool isReviewOnlyMode;

  const ProgressSummary({
    required this.currentLevel,
    required this.completedCount,
    required this.totalCount,
    required this.n3Completed,
    required this.n3Total,
    required this.n2Completed,
    required this.n2Total,
    required this.daysUntilExam,
    required this.dailyTarget,
    required this.isReviewOnlyMode,
  });
}

final progressSummaryProvider = FutureProvider<ProgressSummary>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final settings = await ref.watch(settingsProvider.future);
  final progressRepo = ProgressRepository(db);
  final wordRepo = WordRepository(db);

  // N3 완료 여부로 현재 레벨 결정
  final n3Total = await wordRepo.countByLevel(JlptLevel.n3);
  final n3Completed = await progressRepo.countCompleted(JlptLevel.n3);
  final currentLevel =
      n3Completed >= n3Total && n3Total > 0 ? JlptLevel.n2 : JlptLevel.n3;

  final total = await wordRepo.countByLevel(currentLevel);
  final completed = await progressRepo.countCompleted(currentLevel);

  // dailyTarget은 N3+N2 전체 남은 단어 기준으로 계산
  final n2Total = await wordRepo.countByLevel(JlptLevel.n2);
  final n2Completed = await progressRepo.countCompleted(JlptLevel.n2);
  final totalRemaining = (n3Total - n3Completed) + (n2Total - n2Completed);

  final now = DateTime.now();
  final days = settings.daysUntilExam(now);
  final isReviewOnly = days <= 0;

  int dailyTarget = 0;
  if (!isReviewOnly && days > 0) {
    dailyTarget = (totalRemaining / days).ceil();
  }

  return ProgressSummary(
    currentLevel: currentLevel,
    completedCount: completed,
    totalCount: total,
    n3Completed: n3Completed,
    n3Total: n3Total,
    n2Completed: n2Completed,
    n2Total: n2Total,
    daysUntilExam: days,
    dailyTarget: dailyTarget,
    isReviewOnlyMode: isReviewOnly,
  );
});
