import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../application/providers/today_study_set_provider.dart';
import '../../../application/providers/word_catalog_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/word.dart';
import '../../../domain/models/today_study_set.dart';
import '../../../domain/models/enums.dart';
import '../../../widgets/flip_card.dart';
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
          error: (_, __) => const SizedBox.shrink(),
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
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: setAsync.when(
        data: (set) {
          if (set == null) return const Center(child: Text('학습 세트 없음'));
          return catalogAsync.when(
            data: (catalog) {
              final wordMap = {for (final w in catalog) w.id: w};
              return _FlashcardBody(
                set: set,
                wordMap: wordMap,
                currentIndex: _currentIndex,
                isFlipped: _isFlipped,
                onFlip: () => setState(() => _isFlipped = !_isFlipped),
                onPrev: _currentIndex > 0
                    ? () => setState(() {
                          _currentIndex--;
                          _isFlipped = false;
                        })
                    : null,
                onNext: () => _onNext(context, ref, set),
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

  void _onNext(BuildContext context, WidgetRef ref, TodayStudySet set) {
    if (_currentIndex < set.items.length - 1) {
      setState(() {
        _currentIndex++;
        _isFlipped = false;
      });
    } else {
      ref
          .read(todayStudySetProvider.notifier)
          .advanceStage(StudyStage.quizReading);
      context.go('/study/quiz-reading');
    }
  }
}

class _FlashcardBody extends StatelessWidget {
  final TodayStudySet set;
  final Map<String, Word> wordMap;
  final int currentIndex;
  final bool isFlipped;
  final VoidCallback onFlip;
  final VoidCallback? onPrev;
  final VoidCallback onNext;

  const _FlashcardBody({
    required this.set,
    required this.wordMap,
    required this.currentIndex,
    required this.isFlipped,
    required this.onFlip,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final item = set.items[currentIndex];
    final word = wordMap[item.wordId];
    if (word == null) return const Center(child: Text('단어 없음'));

    final isLastCard = currentIndex == set.items.length - 1;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Expanded(
            child: FlipCard(
              isFlipped: isFlipped,
              onTap: onFlip,
              front: _CardFace(
                child: Center(
                  child: Text(
                    word.expression ?? word.reading,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              back: _CardFace(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        word.reading,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        word.meaningKo,
                        style: const TextStyle(fontSize: 20),
                        textAlign: TextAlign.center,
                      ),
                      if (word.example != null) ...[
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 12),
                        Text(
                          word.example!.ja,
                          style: const TextStyle(fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          word.example!.reading,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          word.example!.ko,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (onPrev != null)
                IconButton(
                  onPressed: onPrev,
                  icon: const Icon(Icons.arrow_back_ios),
                ),
              const Spacer(),
              if (isLastCard && isFlipped)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                  ),
                  onPressed: onNext,
                  child: const Text('1단계 퀴즈 시작'),
                )
              else
                IconButton(
                  onPressed: onNext,
                  icon: const Icon(Icons.arrow_forward_ios),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  final Widget child;
  const _CardFace({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );
}
