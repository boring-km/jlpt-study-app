import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/review_session.dart';
import '../../domain/models/enums.dart';
import '../../domain/repositories/review_repository.dart';
import '../../domain/repositories/progress_repository.dart';
import 'database_provider.dart';
import 'progress_summary_provider.dart';

final reviewSessionProvider =
    AsyncNotifierProvider<ReviewSessionNotifier, ReviewSession?>(
  ReviewSessionNotifier.new,
);

class ReviewSessionNotifier extends AsyncNotifier<ReviewSession?> {
  @override
  Future<ReviewSession?> build() async => null;

  Future<ReviewSession> startNewSession() async {
    final db = await ref.read(databaseProvider.future);
    final summary = await ref.read(progressSummaryProvider.future);
    final progressRepo = ProgressRepository(db);
    final reviewRepo = ReviewRepository(db);

    final completedIds =
        await progressRepo.getCompletedWordIds(summary.currentLevel);
    completedIds.shuffle();
    final selected = completedIds.take(20).toList();

    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final sessionId = 'review_${now.millisecondsSinceEpoch}';

    final items = selected.asMap().entries.map((e) {
      return ReviewSessionItem(
        sessionId: sessionId,
        wordId: e.value,
        displayOrder: e.key,
        readingPassed: false,
        meaningPassed: false,
        readingAttempts: 0,
        meaningAttempts: 0,
      );
    }).toList();

    final session = ReviewSession(
      id: sessionId,
      reviewDate: today,
      itemCount: selected.length,
      status: StudyStage.quizReading,
      items: items,
      startedAt: now,
    );

    await reviewRepo.createSession(session);
    state = AsyncData(session);
    return session;
  }

  Future<void> updateItemResult(
    String wordId, {
    required bool passed,
    required bool isReadingStage,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final db = await ref.read(databaseProvider.future);
    final repo = ReviewRepository(db);

    final idx = current.items.indexWhere((i) => i.wordId == wordId);
    if (idx < 0) return;
    final item = current.items[idx];
    final updated = isReadingStage
        ? item.copyWith(
            readingPassed: passed,
            readingAttempts: item.readingAttempts + 1,
          )
        : item.copyWith(
            meaningPassed: passed,
            meaningAttempts: item.meaningAttempts + 1,
          );
    await repo.updateItem(updated);

    final newItems = List<ReviewSessionItem>.from(current.items);
    newItems[idx] = updated;
    state = AsyncData(current.copyWith(items: newItems));
  }

  Future<void> complete() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final db = await ref.read(databaseProvider.future);
    final now = DateTime.now();
    await ReviewRepository(db).updateSessionStatus(
      current.id,
      StudyStage.completed,
      completedAt: now,
    );
    state = AsyncData(current.copyWith(
      status: StudyStage.completed,
      completedAt: now,
    ));
    ref.invalidate(progressSummaryProvider);
  }
}
