import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../application/providers/today_study_set_provider.dart';
import '../../../application/providers/word_catalog_provider.dart';
import '../../../application/providers/database_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/word.dart';
import '../../../domain/repositories/word_repository.dart';
import '../../../widgets/word_badge.dart';

class QuizReadingScreen extends ConsumerStatefulWidget {
  const QuizReadingScreen({super.key});

  @override
  ConsumerState<QuizReadingScreen> createState() => _QuizReadingScreenState();
}

class _QuizReadingScreenState extends ConsumerState<QuizReadingScreen>
    with TickerProviderStateMixin {
  List<String> _queue = [];
  int _queueIndex = 0;
  List<Word> _choices = [];
  String? _selectedMeaning;
  bool _showFeedback = false;
  bool _initialized = false;

  late AnimationController _feedbackController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _feedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _feedbackController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _initQueue();
    }
  }

  Future<void> _initQueue() async {
    final set = ref.read(todayStudySetProvider).valueOrNull;
    if (set == null) return;
    final allIds = set.items.map((i) => i.wordId).toList();
    setState(() {
      _queue = List.from(allIds);
      _queueIndex = 0;
    });
    await _loadChoices();
  }

  Future<void> _loadChoices() async {
    if (_queueIndex >= _queue.length) return;
    final wordId = _queue[_queueIndex];
    final catalog = ref.read(wordCatalogProvider).valueOrNull ?? [];
    final wordMap = {for (final w in catalog) w.id: w};
    final target = wordMap[wordId];
    if (target == null) return;

    final db = await ref.read(databaseProvider.future);
    final wordRepo = WordRepository(db);
    final set = ref.read(todayStudySetProvider).valueOrNull!;
    final distractors = await wordRepo.getRandomByLevel(
      set.jlptLevel,
      3,
      [wordId],
    );

    final choices = [target, ...distractors]..shuffle(Random());
    setState(() {
      _choices = choices;
      _selectedMeaning = null;
      _showFeedback = false;
    });
  }

  void _onSelect(String meaning, bool isCorrect) {
    if (_showFeedback) return;
    setState(() {
      _selectedMeaning = meaning;
      _showFeedback = true;
    });

    _feedbackController.forward().then((_) => _feedbackController.reverse());

    final wordId = _queue[_queueIndex];
    ref.read(todayStudySetProvider.notifier).updateItemResult(
          wordId,
          passed: isCorrect,
          isReadingStage: true,
        );

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      _advance(isCorrect, wordId);
    });
  }

  void _onDontKnow() {
    final wordId = _queue[_queueIndex];
    final catalog = ref.read(wordCatalogProvider).valueOrNull ?? [];
    final wordMap = {for (final w in catalog) w.id: w};
    final target = wordMap[wordId];
    if (target == null) return;
    _onSelect('', false);
  }

  void _advance(bool isCorrect, String wordId) {
    if (!isCorrect) {
      _queue.add(wordId);
    }
    final nextIndex = _queueIndex + 1;
    if (nextIndex >= _queue.length) {
      _goToWrongAnswers();
      return;
    }
    setState(() => _queueIndex = nextIndex);
    _loadChoices();
  }

  void _goToWrongAnswers() {
    context.go('/study/wrong-answers', extra: {'stage': 'reading'});
  }

  @override
  Widget build(BuildContext context) {
    final setAsync = ref.watch(todayStudySetProvider);
    final catalog = ref.watch(wordCatalogProvider).valueOrNull ?? [];
    final wordMap = {for (final w in catalog) w.id: w};

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: setAsync.when(
          data: (set) => set != null
              ? Text('${_queueIndex + 1} / ${_queue.length}')
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
      body: _queue.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(wordMap),
    );
  }

  Widget _buildBody(Map<String, Word> wordMap) {
    if (_queueIndex >= _queue.length) {
      return const Center(child: CircularProgressIndicator());
    }
    final wordId = _queue[_queueIndex];
    final word = wordMap[wordId];
    if (word == null) return const Center(child: Text('단어 없음'));
    final correctMeaning = word.meaningKo;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Center(
            child: Text(
              word.expression ?? word.reading,
              style: const TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if ((word.expression != null && word.expression != word.reading))
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  word.reading,
                  style: TextStyle(
                    fontSize: 20,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 48),
          ..._choices.map((choice) {
            final isCorrectChoice = choice.meaningKo == correctMeaning;
            final isSelected = _selectedMeaning == choice.meaningKo;

            Color bgColor = Theme.of(context).cardColor;
            Color borderColor = AppColors.borderLight;
            Color fgColor = Theme.of(context).colorScheme.onSurface;
            double elevation = 0;

            if (_showFeedback) {
              if (isCorrectChoice) {
                bgColor = AppColors.success;
                borderColor = AppColors.success;
                fgColor = Colors.white;
                elevation = 4;
              } else if (isSelected) {
                bgColor = AppColors.error;
                borderColor = AppColors.error;
                fgColor = Colors.white;
                elevation = 4;
              }
            }

            Widget button = AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 2.0),
                boxShadow: elevation > 0
                    ? [
                        BoxShadow(
                          color: bgColor.withValues(alpha: 0.45),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _showFeedback
                      ? null
                      : () => _onSelect(choice.meaningKo, isCorrectChoice),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: _showFeedback && (isCorrectChoice || isSelected)
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: fgColor,
                        ),
                        child: Text(choice.meaningKo, textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                ),
              ),
            );

            if (_showFeedback && (isCorrectChoice || isSelected)) {
              button = ScaleTransition(scale: _scaleAnimation, child: button);
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: button,
            );
          }),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _showFeedback ? null : _onDontKnow,
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              side: BorderSide(
                color: Theme.of(context).colorScheme.outline,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.help_outline, size: 20),
            label: const Text('모르겠다', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
