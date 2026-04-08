import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/flashcard_page_view.dart';
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
            actions: [
              IconButton(
                icon: const Icon(Icons.list_alt_outlined),
                tooltip: '리스트로 보기',
                onPressed: () => context.go('/explore'),
              ),
            ],
          ),
          body: words.isEmpty
              ? const Center(child: Text('단어 없음'))
              : FlashcardPageView(
                  words: words,
                  currentIndex: _currentIndex,
                  isFlipped: _isFlipped,
                  onPageChanged: (index) => setState(() {
                    _currentIndex = index;
                    _isFlipped = false;
                  }),
                  onFlip: () => setState(() => _isFlipped = !_isFlipped),
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
