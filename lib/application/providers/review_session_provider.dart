import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/review_session.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/error_tag.dart';
import '../../domain/repositories/miss_log_repository.dart';
import '../../domain/repositories/review_repository.dart';
import '../../domain/repositories/progress_repository.dart';
import 'database_provider.dart';
import 'miss_tag_counts_provider.dart';
import 'progress_summary_provider.dart';
import 'today_study_set_provider.dart' show todayDateString;

final reviewSessionProvider =
    AsyncNotifierProvider<ReviewSessionNotifier, ReviewSession?>(
  ReviewSessionNotifier.new,
);

class ReviewSessionNotifier extends AsyncNotifier<ReviewSession?> {
  @override
  Future<ReviewSession?> build() async => null;

  /// 전체 복습 세션 단어 수
  static const int kReviewSessionSize = 20;

  /// 약점 슬롯 비율 (0.0~1.0). 0.7 → 20개 중 14개는 약점, 6개는 나머지에서.
  static const double kWeakSlotRatio = 0.7;

  /// [tag]가 주어지면 해당 태그 오답 단어를 먼저 채우고, 부족분은
  /// 약점 70% + 나머지 30% 블렌드로 채운다.
  Future<ReviewSession> startNewSession({ErrorTag? tag}) async {
    // 진행 중인 build()가 나중에 state를 덮어쓰지 않도록 먼저 해소한다.
    await future;
    final db = await ref.read(databaseProvider.future);
    final progressRepo = ProgressRepository(db);
    final reviewRepo = ReviewRepository(db);

    final selected = <String>[];
    if (tag != null) {
      selected.addAll(
        await MissLogRepository(db)
            .recentWordIdsByTag(tag, limit: kReviewSessionSize),
      );
    }
    if (selected.length < kReviewSessionSize) {
      final blend = await _buildBlendedSelection(progressRepo);
      for (final id in blend) {
        if (selected.length >= kReviewSessionSize) break;
        if (!selected.contains(id)) selected.add(id);
      }
    }

    final now = DateTime.now();
    final sessionId = 'review_${now.millisecondsSinceEpoch}';

    final items = [
      for (var i = 0; i < selected.length; i++)
        ReviewSessionItem(
          sessionId: sessionId,
          wordId: selected[i],
          displayOrder: i,
          passed: false,
          attempts: 0,
        ),
    ];

    final session = ReviewSession(
      id: sessionId,
      reviewDate: todayDateString(now),
      itemCount: selected.length,
      status: StudyStage.quiz,
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
    ErrorTag? tag,
  }) async {
    final current = await future;
    if (current == null) return;
    final idx = current.items.indexWhere((i) => i.wordId == wordId);
    if (idx < 0) return;
    final db = await ref.read(databaseProvider.future);
    final item = current.items[idx];
    final updated = item.copyWith(
      passed: passed,
      attempts: item.attempts + 1,
    );
    await ReviewRepository(db).updateItem(updated);

    final progressRepo = ProgressRepository(db);
    if (passed) {
      await progressRepo.decrementMiss(wordId);
    } else {
      await progressRepo.incrementMiss(wordId);
      await MissLogRepository(db).add(wordId, tag ?? ErrorTag.other);
      ref.invalidate(missTagCountsProvider);
    }

    final items = List<ReviewSessionItem>.from(current.items)..[idx] = updated;
    state = AsyncData(current.copyWith(items: items));
  }

  Future<void> complete() async {
    final current = await future;
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
    ref.invalidate(missTagCountsProvider);
  }

  /// 약점 70% + 비약점 30%로 세션 단어를 고름.
  /// - 약점 풀에서 weakSlots만큼 추출 (miss_count DESC 순서로 가져와서 셔플)
  /// - 남은 슬롯은 약점이 아닌 완료 단어에서 랜덤으로 채움
  /// - 약점/비약점이 부족하면 서로 채워줌
  /// - 최종 리스트는 셔플해서 예측 가능한 앞쪽 배치 방지
  @visibleForTesting
  Future<List<String>> buildBlendedSelectionForTest(
    ProgressRepository progressRepo, {
    int? size,
    double? weakRatio,
  }) =>
      _buildBlendedSelection(
        progressRepo,
        size: size,
        weakRatio: weakRatio,
      );

  Future<List<String>> _buildBlendedSelection(
    ProgressRepository progressRepo, {
    int? size,
    double? weakRatio,
  }) async {
    final targetSize = size ?? kReviewSessionSize;
    final ratio = weakRatio ?? kWeakSlotRatio;
    final weakSlots = (targetSize * ratio).ceil();

    // 약점 풀은 targetSize 전체만큼 길게 받아두고 셔플해서 뽑음 (중복 등장 완화)
    final weakPool = await progressRepo.getWeakWordIds(limit: targetSize * 2);
    weakPool.shuffle();
    final pickedWeak = weakPool.take(weakSlots).toList();

    // 비약점 풀 = 전체 완료 단어 - 이미 뽑힌 약점
    final completedIds = await progressRepo.getCompletedWordIds();
    final pickedWeakSet = pickedWeak.toSet();
    final cleanPool =
        completedIds.where((id) => !pickedWeakSet.contains(id)).toList();
    cleanPool.shuffle();

    final cleanSlots = targetSize - pickedWeak.length;
    final pickedClean = cleanPool.take(cleanSlots).toList();

    // 약점이 부족했으면 남은 약점 풀로 마저 채움
    final combined = <String>[...pickedWeak, ...pickedClean];
    if (combined.length < targetSize) {
      final fillerPool = weakPool
          .skip(pickedWeak.length)
          .where((id) => !combined.contains(id))
          .toList();
      combined.addAll(fillerPool.take(targetSize - combined.length));
    }

    combined.shuffle();
    return combined;
  }
}
