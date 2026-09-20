import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
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

  /// 목록에서 push로 들어오므로 pop이 기본. 깊은 링크로 바로 열렸을 때만 go.
  void _backToList() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/explore');
    }
  }

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
              tooltip: '닫기',
              onPressed: _backToList,
            ),
            title: words.isEmpty
                ? const SizedBox.shrink()
                : Text('${_currentIndex + 1} / ${words.length}'),
          ),
          body: SafeArea(
            child: words.isEmpty
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
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '단어를 불러오지 못했다',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => ref.invalidate(exploreProvider),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
