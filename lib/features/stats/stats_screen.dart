import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/error_tag.dart';
import 'stats_provider.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('통계')),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '통계를 불러오지 못했다',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => ref.invalidate(statsProvider),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (stats) => _StatsBody(stats: stats),
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  final StatsState stats;
  const _StatsBody({required this.stats});

  /// `장음 3 · 촉음 1` — 0인 태그는 빼고 [ErrorTag.values] 순서로 이어 붙인다.
  String _missSummary() => [
    for (final tag in ErrorTag.values)
      if ((stats.missByTag[tag] ?? 0) > 0)
        '${tag.label} ${stats.missByTag[tag]}',
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final missSummary = _missSummary();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _LevelProgressCard(
          label: 'N2',
          completed: stats.completed,
          total: stats.total,
          percent: stats.percent,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('약점 ${stats.weak}개', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (missSummary.isNotEmpty)
          Text(
            missSummary,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Text('틀린 단어가 생기면 여기서 종류별로 본다', style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _LevelProgressCard extends StatelessWidget {
  final String label;
  final int completed;
  final int total;
  final double percent;

  const _LevelProgressCard({
    required this.label,
    required this.completed,
    required this.total,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              Text('$completed / $total', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 4,
              semanticsLabel: 'N2 진행률',
              semanticsValue: '${(percent * 100).round()}%',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${(percent * 100).toStringAsFixed(1)}%',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
