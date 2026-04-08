import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../application/providers/today_study_set_provider.dart';
import '../../../application/providers/word_catalog_provider.dart';
import '../../../domain/models/word.dart';
import '../../../domain/models/enums.dart';
import '../../../widgets/flashcard_page_view.dart';
import '../../../widgets/word_badge.dart';

class FlashcardScreen extends ConsumerStatefulWidget {
  const FlashcardScreen({super.key});

  @override
  ConsumerState<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends ConsumerState<FlashcardScreen> {
  int _currentIndex = 0;
  bool _isFlipped = false;

  @override
  Widget build(BuildContext context) {
    final setAsync = ref.watch(todayStudySetProvider);
    final catalogAsync = ref.watch(wordCatalogProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: setAsync.when(
          data: (set) => set != null
              ? Text('${_currentIndex + 1} / ${set.items.length}')
              : const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
          error: (e, s) => const SizedBox.shrink(),
        ),
        actions: [
          setAsync.when(
            data: (set) => set != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: WordBadge(level: set.jlptLevel),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (e, s) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: setAsync.when(
        data: (set) {
          if (set == null) return const Center(child: Text('학습 세트 없음'));
          return catalogAsync.when(
            data: (catalog) {
              final wordMap = {for (final w in catalog) w.id: w};
              final words = set.items
                  .map((item) => wordMap[item.wordId])
                  .whereType<Word>()
                  .toList();
              if (words.isEmpty) {
                return const Center(child: Text('단어 없음'));
              }
              final isLastCard = _currentIndex == words.length - 1;
              return FlashcardPageView(
                words: words,
                currentIndex: _currentIndex,
                isFlipped: _isFlipped,
                onPageChanged: (index) => setState(() {
                  _currentIndex = index;
                  _isFlipped = false;
                }),
                onFlip: () => setState(() => _isFlipped = !_isFlipped),
                bottomWidget: isLastCard && _isFlipped
                    ? ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 14),
                        ),
                        onPressed: () {
                          ref
                              .read(todayStudySetProvider.notifier)
                              .advanceStage(StudyStage.quizReading);
                          context.go('/study/quiz-reading');
                        },
                        child: const Text('1단계 퀴즈 시작'),
                      )
                    : null,
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('오류: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
      ),
    );
  }
}
