import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/providers/progress_summary_provider.dart';
import '../../application/providers/today_study_set_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/today_study_set.dart';
import '../../widgets/word_badge.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(progressSummaryProvider);
    final setAsync = ref.watch(todayStudySetProvider);

    return Scaffold(
      body: SafeArea(
        child: summaryAsync.when(
          data: (summary) => _HomeBody(summary: summary, setAsync: setAsync),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('오류: $e')),
        ),
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  final ProgressSummary summary;
  final AsyncValue<TodayStudySet?> setAsync;

  const _HomeBody({required this.summary, required this.setAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final set = setAsync.valueOrNull;
    final todayCompleted = set?.completedCount ?? 0;
    final todayTarget = set?.targetCount ?? summary.dailyTarget;
    final isSetCompleted = set?.status == StudyStage.completed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                summary.daysUntilExam >= 0
                    ? 'D-${summary.daysUntilExam}'
                    : 'D+${summary.daysUntilExam.abs()}',
                style: Theme.of(context).textTheme.displayLarge,
              ),
              WordBadge(level: summary.currentLevel),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '오늘 $todayCompleted / $todayTarget 완료',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: todayTarget > 0 ? todayCompleted / todayTarget : 0,
              minHeight: 6,
              backgroundColor: AppColors.borderLight,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${summary.currentLevel == JlptLevel.n3 ? "N3" : "N2"} '
            '${summary.completedCount} / ${summary.totalCount}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          if (!summary.isReviewOnlyMode)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: isSetCompleted
                    ? null
                    : () => _startStudy(context, ref, set),
                child: Text(
                  set == null
                      ? '오늘 학습 시작'
                      : isSetCompleted
                          ? '오늘 학습 완료 ✓'
                          : '이어하기',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (summary.isReviewOnlyMode)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => context.push('/review'),
                child: const Text(
                  '복습 시작',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SmallCard(
                  label: '복습',
                  icon: Icons.replay_outlined,
                  enabled: summary.completedCount > 0,
                  onTap: () => context.push('/review'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SmallCard(
                  label: '히라가나·가타카나 표',
                  icon: Icons.grid_view_outlined,
                  enabled: true,
                  onTap: () => context.push('/kana'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _startStudy(
    BuildContext context,
    WidgetRef ref,
    TodayStudySet? currentSet,
  ) async {
    if (currentSet == null) {
      await ref.read(todayStudySetProvider.notifier).createTodaySet();
    }
    final set = ref.read(todayStudySetProvider).valueOrNull;
    if (set == null || !context.mounted) return;

    switch (set.status) {
      case StudyStage.flashcard:
        context.push('/study/flashcard');
      case StudyStage.quizReading:
        context.push('/study/quiz-reading');
      case StudyStage.quizMeaning:
        context.push('/study/quiz-meaning');
      case StudyStage.completed:
        break;
    }
  }
}

class _SmallCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _SmallCard({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enabled
                ? AppColors.borderLight
                : AppColors.borderLight.withOpacity(0.4),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color:
                  enabled ? AppColors.primary : AppColors.textSecondaryLight,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: enabled
                    ? AppColors.textPrimaryLight
                    : AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
