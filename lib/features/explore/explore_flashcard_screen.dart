import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/word.dart';
import '../../widgets/flip_card.dart';
import 'explore_provider.dart';

class ExploreFlashcardScreen extends ConsumerStatefulWidget {
  const ExploreFlashcardScreen({super.key});

  @override
  ConsumerState<ExploreFlashcardScreen> createState() =>
      _ExploreFlashcardScreenState();
}

class _ExploreFlashcardScreenState
    extends ConsumerState<ExploreFlashcardScreen> {
  int _currentIndex = 0;
  bool _isFlipped = false;

  @override
  Widget build(BuildContext context) {
    final exploreAsync = ref.watch(exploreProvider);

    return exploreAsync.when(
      data: (state) {
        final words = state.results;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => context.pop(),
            ),
            title: words.isEmpty
                ? const SizedBox.shrink()
                : Text('${_currentIndex + 1} / ${words.length}'),
          ),
          body: words.isEmpty
              ? const Center(child: Text('단어 없음'))
              : _FlashcardBody(
                  words: words,
                  currentIndex: _currentIndex,
                  isFlipped: _isFlipped,
                  onFlip: () => setState(() => _isFlipped = !_isFlipped),
                  onPrev: _currentIndex > 0
                      ? () => setState(() {
                            _currentIndex--;
                            _isFlipped = false;
                          })
                      : null,
                  onNext: () => setState(() {
                    if (_currentIndex < words.length - 1) {
                      _currentIndex++;
                    } else {
                      _currentIndex = 0;
                    }
                    _isFlipped = false;
                  }),
                ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('오류: $e')),
      ),
    );
  }
}

class _FlashcardBody extends StatelessWidget {
  final List<Word> words;
  final int currentIndex;
  final bool isFlipped;
  final VoidCallback onFlip;
  final VoidCallback? onPrev;
  final VoidCallback onNext;

  const _FlashcardBody({
    required this.words,
    required this.currentIndex,
    required this.isFlipped,
    required this.onFlip,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final word = words[currentIndex];

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
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );
}
