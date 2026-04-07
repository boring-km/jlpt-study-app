import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../application/providers/today_study_set_provider.dart';
import '../../../application/providers/word_catalog_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/word.dart';
import '../../../domain/models/enums.dart';
import '../../../widgets/word_badge.dart';

class WrongAnswersScreen extends ConsumerWidget {
  final String stage; // 'reading' or 'meaning'

  const WrongAnswersScreen({super.key, required this.stage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setAsync = ref.watch(todayStudySetProvider);
    final catalog = ref.watch(wordCatalogProvider).valueOrNull ?? [];
    final wordMap = {for (final w in catalog) w.id: w};

    return setAsync.when(
      data: (set) {
        if (set == null) {
          return const Scaffold(body: Center(child: Text('세트 없음')));
        }

        final isReading = stage == 'reading';
        final wrongItems = isReading
            ? set.items.where((i) => !i.readingPassed).toList()
            : set.items.where((i) => !i.meaningPassed).toList();
        final correctCount = set.items.length - wrongItems.length;
        final allPassed = wrongItems.isEmpty;

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(isReading ? '1단계 결과' : '2단계 결과'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '$correctCount / ${set.items.length} 정답',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (wrongItems.isNotEmpty) ...[
                  Text('오답 ${wrongItems.length}개',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: wrongItems.length,
                      itemBuilder: (context, index) {
                        final item = wrongItems[index];
                        final word = wordMap[item.wordId];
                        if (word == null) return const SizedBox.shrink();
                        return _WrongWordTile(word: word, level: set.jlptLevel);
                      },
                    ),
                  ),
                ] else
                  Expanded(
                    child: Center(
                      child: Text(
                        '모두 정답!',
                        style: TextStyle(
                          fontSize: 24,
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                if (!allPassed)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () {
                      if (isReading) {
                        context.go('/study/quiz-reading');
                      } else {
                        context.go('/study/quiz-meaning');
                      }
                    },
                    child: const Text('다시 퀴즈', style: TextStyle(fontSize: 18)),
                  ),
                if (allPassed && isReading)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () {
                      ref
                          .read(todayStudySetProvider.notifier)
                          .advanceStage(StudyStage.quizMeaning);
                      context.go('/study/quiz-meaning');
                    },
                    child: const Text('다음 단계로', style: TextStyle(fontSize: 18)),
                  ),
                if (allPassed && !isReading)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () async {
                      await ref
                          .read(todayStudySetProvider.notifier)
                          .advanceStage(StudyStage.completed);
                      await ref
                          .read(todayStudySetProvider.notifier)
                          .markCompletedWords();
                      if (context.mounted) context.go('/study/complete');
                    },
                    child: const Text('완료', style: TextStyle(fontSize: 18)),
                  ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => Scaffold(body: Center(child: Text('오류: $e'))),
    );
  }
}

class _WrongWordTile extends StatefulWidget {
  final Word word;
  final JlptLevel level;
  const _WrongWordTile({required this.word, required this.level});

  @override
  State<_WrongWordTile> createState() => _WrongWordTileState();
}

class _WrongWordTileState extends State<_WrongWordTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  (widget.word.expression?.isNotEmpty ?? false)
                      ? widget.word.expression!
                      : widget.word.reading,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.word.reading,
                  style: TextStyle(
                      fontSize: 14, color: AppColors.textSecondaryLight),
                ),
                const Spacer(),
                WordBadge(level: widget.level),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.word.meaningKo,
              style: TextStyle(
                  fontSize: 14, color: AppColors.textSecondaryLight),
            ),
            if (_expanded && widget.word.example != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(widget.word.example!.ja,
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                widget.word.example!.ko,
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondaryLight),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
