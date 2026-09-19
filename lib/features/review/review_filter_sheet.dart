import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/providers/miss_tag_counts_provider.dart';
import '../../application/providers/review_session_provider.dart';
import '../../domain/models/error_tag.dart';
import '../quiz/quiz_mode.dart';

/// 복습 범위를 고르는 바텀시트. 칩을 눌러야 세션이 만들어진다 —
/// 시트만 열고 닫으면 빈 복습 세션이 남지 않는다.
Future<void> showReviewFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => const _ReviewFilterSheet(),
  );
}

class _ReviewFilterSheet extends ConsumerWidget {
  const _ReviewFilterSheet();

  Future<void> _start(BuildContext context, WidgetRef ref, ErrorTag? tag) async {
    // pop 이후에는 이 시트 컨텍스트로 조상을 찾을 수 없으므로 미리 붙잡아 둔다.
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    await ref.read(reviewSessionProvider.notifier).startNewSession(tag: tag);
    if (!context.mounted) return;
    navigator.pop();
    router.push('/quiz', extra: QuizMode.review);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(missTagCountsProvider).valueOrNull ?? const {};
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('복습', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('전체'),
                  onPressed: () => _start(context, ref, null),
                ),
                for (final tag in ErrorTag.values)
                  if ((counts[tag] ?? 0) > 0)
                    ActionChip(
                      label: Text('${tag.label} ${counts[tag]}'),
                      onPressed: () => _start(context, ref, tag),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
