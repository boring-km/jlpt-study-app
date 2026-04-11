import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/providers/progress_summary_provider.dart';
import '../../application/providers/settings_provider.dart';
import '../../application/providers/today_study_set_provider.dart';
import '../../domain/models/app_settings.dart';
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
    final settings = ref.watch(settingsProvider);
    final themeMode = settings.valueOrNull?.themeMode ?? AppThemeMode.light;

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
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.grid_view_outlined),
                    tooltip: 'ひらがな·カタカナ 표',
                    onPressed: () => context.push('/kana'),
                  ),
                  IconButton(
                    icon: Icon(switch (themeMode) {
                      AppThemeMode.light => Icons.light_mode_outlined,
                      AppThemeMode.dark => Icons.dark_mode_outlined,
                    }),
                    tooltip: switch (themeMode) {
                      AppThemeMode.light => '라이트 모드',
                      AppThemeMode.dark => '다크 모드',
                    },
                    onPressed: () {
                      final next = switch (themeMode) {
                        AppThemeMode.light => AppThemeMode.dark,
                        AppThemeMode.dark => AppThemeMode.light,
                      };
                      ref.read(settingsProvider.notifier).updateThemeMode(next);
                    },
                  ),
                  WordBadge(level: summary.currentLevel),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '오늘 $todayCompleted / $todayTarget 완료',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'N3 ${summary.n3Completed}/${summary.n3Total}'
            ' · '
            'N2 ${summary.n2Completed}/${summary.n2Total}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (summary.n3Total + summary.n2Total) > 0
                  ? (summary.n3Completed + summary.n2Completed) /
                      (summary.n3Total + summary.n2Total)
                  : 0,
              minHeight: 6,
              backgroundColor: Theme.of(context).dividerColor,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 32),
          if (!summary.isReviewOnlyMode) ...[
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
            if (isSetCompleted)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2.0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => _startNextStudy(context, ref),
                    child: const Text(
                      '다음 학습 시작',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
          if (summary.isReviewOnlyMode)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                  label: '오늘 복습',
                  icon: Icons.replay_outlined,
                  enabled: isSetCompleted,
                  onTap: () {
                    final wordIds = set?.items
                            .where((i) => i.isFullyCompleted)
                            .map((i) => i.wordId)
                            .toList() ??
                        [];
                    context.push('/review/today', extra: wordIds);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SmallCard(
                  label: '전체 복습',
                  icon: Icons.history_outlined,
                  enabled: summary.completedCount > 0,
                  subtitle: summary.weakCount > 0
                      ? '약점 ${summary.weakCount}개'
                      : null,
                  onTap: () => context.push('/review'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _startNextStudy(BuildContext context, WidgetRef ref) async {
    await ref.read(todayStudySetProvider.notifier).createNextSet();
    final set = ref.read(todayStudySetProvider).valueOrNull;
    if (set == null || !context.mounted) return;
    context.push('/study/flashcard');
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
  final String? subtitle;
  final VoidCallback onTap;

  const _SmallCard({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.subtitle,
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
                ? Theme.of(context).dividerColor
                : Theme.of(context).dividerColor.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: enabled
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: enabled
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 11,
                  color: enabled
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
