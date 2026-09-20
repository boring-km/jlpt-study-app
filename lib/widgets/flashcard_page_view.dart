import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../domain/models/word.dart';
import 'flip_card.dart';

/// Swipeable flashcard viewer powered by [PageView].
class FlashcardPageView extends StatefulWidget {
  final List<Word> words;
  final int currentIndex;
  final bool isFlipped;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onFlip;

  /// Optional widget displayed below the card (e.g. quiz start button).
  final Widget? bottomWidget;

  const FlashcardPageView({
    super.key,
    required this.words,
    required this.currentIndex,
    required this.isFlipped,
    required this.onPageChanged,
    required this.onFlip,
    this.bottomWidget,
  });

  @override
  State<FlashcardPageView> createState() => _FlashcardPageViewState();
}

class _FlashcardPageViewState extends State<FlashcardPageView> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.currentIndex);
  }

  @override
  void didUpdateWidget(FlashcardPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync controller when index changes externally.
    if (widget.currentIndex != oldWidget.currentIndex &&
        _pageController.hasClients &&
        _pageController.page?.round() != widget.currentIndex) {
      _pageController.jumpToPage(widget.currentIndex);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.words.length,
            onPageChanged: widget.onPageChanged,
            itemBuilder: (context, index) {
              final word = widget.words[index];
              final isActive = index == widget.currentIndex;
              return _FlashcardPage(
                word: word,
                isFlipped: isActive ? widget.isFlipped : false,
                onFlip: widget.onFlip,
              );
            },
          ),
        ),
        if (widget.bottomWidget != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: widget.bottomWidget!,
          ),
        ],
      ],
    );
  }
}

class _FlashcardPage extends StatelessWidget {
  final Word word;
  final bool isFlipped;
  final VoidCallback onFlip;

  const _FlashcardPage({
    required this.word,
    required this.isFlipped,
    required this.onFlip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 가나 전용 단어는 expression이 reading과 같다 — 뒷면에서 두 번 보이지 않게 한다.
    final hasExpression =
        word.expression.isNotEmpty && word.expression != word.reading;
    final example = word.example;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: FlipCard(
        isFlipped: isFlipped,
        onTap: onFlip,
        front: CardFace(
          child: Center(
            child: Text(
              word.expression.isNotEmpty ? word.expression : word.reading,
              style: AppText.jaDisplay(context),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        back: CardFace(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasExpression) ...[
                  Text(
                    word.expression,
                    // 뒷면에선 읽기·뜻과 함께 놓이므로 표제를 한 단 낮춘다.
                    style: AppText.jaHeadline(context),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Text(
                  word.reading,
                  style: AppText.jaTitle(
                    context,
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  word.meaningKo,
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                if (example != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.base),
                  Text(
                    example.ja,
                    style: AppText.jaBody(context),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    example.reading,
                    style: AppText.jaCaption(context),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    example.ko,
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CardFace extends StatelessWidget {
  final Widget child;
  const CardFace({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
