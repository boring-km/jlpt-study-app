import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'stats_provider.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('통계')),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (stats) => _StatsBody(stats: stats),
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  final StatsState stats;
  const _StatsBody({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          _LevelProgressCard(
            label: 'N3',
            completed: stats.n3Completed,
            total: stats.n3Total,
            percent: stats.n3Percent,
          ),
          const SizedBox(height: 16),
          _LevelProgressCard(
            label: 'N2',
            completed: stats.n2Completed,
            total: stats.n2Total,
            percent: stats.n2Percent,
          ),
          const SizedBox(height: 32),
          Text(
            '전체 진도',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: stats.overallPercent,
            minHeight: 12,
            backgroundColor: Theme.of(context).dividerColor,
            valueColor:
                AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 8),
          Text(
            '${(stats.overallPercent * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.end,
          ),
        ],
      ),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(
                '$completed / $total',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: percent,
            minHeight: 8,
            backgroundColor: Theme.of(context).dividerColor,
            valueColor:
                AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 6),
          Text(
            '${(percent * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
