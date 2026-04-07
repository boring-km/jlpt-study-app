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

class _QuizReadingScreenState extends ConsumerState<QuizReadingScreen> {
  List<String> _queue = [];
  int _queueIndex = 0;
  List<Word> _choices = [];
  String? _selectedChoice;
  bool _showFeedback = false;
  bool _initialized = false;

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
    final similar = await wordRepo.getSimilarReading(
      target.reading,
      set.jlptLevel,
      3,
      [wordId],
    );

    final choices = [target, ...similar]..shuffle();
    setState(() {
      _choices = choices;
      _selectedChoice = null;
      _showFeedback = false;
    });
  }

  void _onSelect(String reading, bool isCorrect) {
    if (_showFeedback) return;
    setState(() {
      _selectedChoice = reading;
      _showFeedback = true;
    });

    final wordId = _queue[_queueIndex];
    ref.read(todayStudySetProvider.notifier).updateItemResult(
          wordId,
          passed: isCorrect,
          isReadingStage: true,
        );

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      _advance(isCorrect, wordId);
    });
  }

  void _onDontKnow() => _onSelect('', false);

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
    final correctReading = word.reading;

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
          const SizedBox(height: 48),
          ..._choices.map((choice) {
            Color? bgColor;
            if (_showFeedback) {
              if (choice.reading == correctReading) {
                bgColor = AppColors.success.withValues(alpha: 0.15);
              } else if (_selectedChoice == choice.reading) {
                bgColor = AppColors.error.withValues(alpha: 0.15);
              }
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: bgColor ?? Theme.of(context).cardColor,
                  foregroundColor: choice.reading == correctReading && _showFeedback
                      ? AppColors.success
                      : AppColors.textPrimaryLight,
                  elevation: 0,
                  side: BorderSide(
                    color: _showFeedback && choice.reading == correctReading
                        ? AppColors.success
                        : AppColors.borderLight,
                    width: 2.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _showFeedback
                    ? null
                    : () => _onSelect(
                          choice.reading,
                          choice.reading == correctReading,
                        ),
                child: Text(choice.reading, style: const TextStyle(fontSize: 18)),
              ),
            );
          }),
          const Spacer(),
          TextButton(
            onPressed: _showFeedback ? null : _onDontKnow,
            child: Text(
              '모르겠다',
              style: TextStyle(
                color: AppColors.textSecondaryLight,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
