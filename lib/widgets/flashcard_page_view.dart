import 'package:flutter/material.dart';
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
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: FlipCard(
        isFlipped: isFlipped,
        onTap: onFlip,
        front: CardFace(
          child: Center(
            child: Text(
              word.expression ?? word.reading,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        back: CardFace(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (word.expression != null)
                  Text(
                    word.expression!,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                if (word.expression != null) const SizedBox(height: 8),
                Text(
                  word.reading,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
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
                    style: const TextStyle(fontSize: 22),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    word.example!.reading,
                    style: TextStyle(
                      fontSize: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    word.example!.ko,
                    style: TextStyle(
                      fontSize: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );
}
