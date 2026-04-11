import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/providers/review_session_provider.dart';
import '../../application/providers/word_catalog_provider.dart';
import '../../application/providers/database_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/word.dart';
import '../../domain/models/review_session.dart';
import '../../domain/repositories/word_repository.dart';

enum _ReviewPhase { loading, quiz, recall, done }

class ReviewScreen extends ConsumerStatefulWidget {
  /// 오늘 학습 완료 단어 ID 목록. null이면 전체 복습.
  final List<String>? todayWordIds;

  const ReviewScreen({super.key, this.todayWordIds});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  _ReviewPhase _phase = _ReviewPhase.loading;

  // Stage 1: 뜻 4지선다
  List<String> _quizQueue = [];
  int _quizIndex = 0;
  List<Word> _choices = [];
  String? _selectedMeaning;
  bool _showFeedback = false;

  // Stage 2: 알아/몰라 리콜
  List<String> _recallQueue = [];
  int _recallIndex = 0;
  bool _assessed = false;
  bool _knew = false;

  @override
  void initState() {
    super.initState();
    Future(() => _init());
  }

  Future<void> _init() async {
    final session = await ref
        .read(reviewSessionProvider.notifier)
        .startNewSession(wordIds: widget.todayWordIds);
    if (!mounted) return;
    setState(() {
      _quizQueue = session.items.map((i) => i.wordId).toList();
      _recallQueue = List.from(_quizQueue);
      _quizIndex = 0;
      _phase = _ReviewPhase.quiz;
    });
    await _loadChoices();
  }

  Future<void> _loadChoices() async {
    if (_quizIndex >= _quizQueue.length) return;
    final wordId = _quizQueue[_quizIndex];
    final catalog = ref.read(wordCatalogProvider).valueOrNull ?? [];
    final wordMap = {for (final w in catalog) w.id: w};
    final target = wordMap[wordId];
    if (target == null) return;

    final db = await ref.read(databaseProvider.future);
    final distractors = await WordRepository(db).getRandomByLevel(
      target.jlptLevel,
      3,
      [wordId],
    );
    if (!mounted) return;
    final choices = [target, ...distractors]..shuffle(Random());
    setState(() {
      _choices = choices;
      _selectedMeaning = null;
      _showFeedback = false;
    });
  }

  void _onQuizSelect(String meaning, bool isCorrect) {
    if (_showFeedback) return;
    setState(() {
      _selectedMeaning = meaning;
      _showFeedback = true;
    });
    final wordId = _quizQueue[_quizIndex];
    ref.read(reviewSessionProvider.notifier).updateItemResult(
          wordId,
          passed: isCorrect,
          isReadingStage: true,
        );
    if (!isCorrect) _quizQueue.add(wordId);
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      final next = _quizIndex + 1;
      if (next >= _quizQueue.length) {
        setState(() {
          _phase = _ReviewPhase.recall;
          _recallIndex = 0;
          _assessed = false;
          _knew = false;
        });
      } else {
        setState(() => _quizIndex = next);
        _loadChoices();
      }
    });
  }

  void _onDontKnow() {
    if (_showFeedback) return;
    _onQuizSelect('', false);
  }

  void _onAssess(bool knows) {
    final wordId = _recallQueue[_recallIndex];
    ref.read(reviewSessionProvider.notifier).updateItemResult(
          wordId,
          passed: knows,
          isReadingStage: false,
        );
    if (!knows) _recallQueue.add(wordId);
    setState(() {
      _assessed = true;
      _knew = knows;
    });
  }

  void _onCorrectToWrong() {
    final wordId = _recallQueue[_recallIndex];
    ref.read(reviewSessionProvider.notifier).updateItemResult(
          wordId,
          passed: false,
          isReadingStage: false,
        );
    _recallQueue.add(wordId);
    _onRecallNext();
  }

  void _onRecallNext() {
    final next = _recallIndex + 1;
    if (next >= _recallQueue.length) {
      ref.read(reviewSessionProvider.notifier).complete();
      setState(() => _phase = _ReviewPhase.done);
      return;
    }
    setState(() {
      _recallIndex = next;
      _assessed = false;
      _knew = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(wordCatalogProvider).valueOrNull ?? [];
    final wordMap = {for (final w in catalog) w.id: w};
    final session = ref.watch(reviewSessionProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(_phaseTitle()),
      ),
      body: switch (_phase) {
        _ReviewPhase.loading =>
          const Center(child: CircularProgressIndicator()),
        _ReviewPhase.quiz => _buildQuizPhase(wordMap),
        _ReviewPhase.recall => _buildRecallPhase(wordMap),
        _ReviewPhase.done => _buildDone(session, wordMap),
      },
    );
  }

  String _phaseTitle() => switch (_phase) {
        _ReviewPhase.quiz =>
          '1단계 ${_quizIndex + 1} / ${_quizQueue.length}',
        _ReviewPhase.recall =>
          '2단계 ${_recallIndex + 1} / ${_recallQueue.length}',
        _ReviewPhase.done => '복습 완료',
        _ => '복습',
      };

  Widget _buildQuizPhase(Map<String, Word> wordMap) {
    if (_quizIndex >= _quizQueue.length) {
      return const Center(child: CircularProgressIndicator());
    }
    final wordId = _quizQueue[_quizIndex];
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
          if (word.expression != null && word.expression != word.reading)
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
            Color borderColor = Theme.of(context).dividerColor;
            Color fgColor = Theme.of(context).colorScheme.onSurface;

            if (_showFeedback) {
              if (isCorrectChoice) {
                bgColor = AppColors.success;
                borderColor = AppColors.success;
                fgColor = Colors.white;
              } else if (isSelected) {
                bgColor = AppColors.error;
                borderColor = AppColors.error;
                fgColor = Colors.white;
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor, width: 2.0),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _showFeedback
                        ? null
                        : () =>
                            _onQuizSelect(choice.meaningKo, isCorrectChoice),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 12),
                      child: Center(
                        child: Text(
                          choice.meaningKo,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: _showFeedback &&
                                    (isCorrectChoice || isSelected)
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: fgColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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

  Widget _buildRecallPhase(Map<String, Word> wordMap) {
    if (_recallIndex >= _recallQueue.length) {
      return const Center(child: CircularProgressIndicator());
    }
    final wordId = _recallQueue[_recallIndex];
    final word = wordMap[wordId];
    if (word == null) return const Center(child: Text('단어 없음'));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Center(
            child: Text(
              (word.expression?.isNotEmpty ?? false)
                  ? word.expression!
                  : word.reading,
              style: const TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 48),
          if (!_assessed) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(
                          color: AppColors.error, width: 2.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => _onAssess(false),
                    child: const Text('몰라', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => _onAssess(true),
                    child: const Text('알아', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ],
          if (_assessed) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _knew ? AppColors.success : AppColors.error,
                  width: 2.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _knew ? Icons.check_circle : Icons.cancel,
                        color: _knew ? AppColors.success : AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        word.reading,
                        style: TextStyle(
                          fontSize: 22,
                          color: _knew ? AppColors.success : AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(word.meaningKo, style: const TextStyle(fontSize: 18)),
                  if (word.example != null) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(word.example!.ja,
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      word.example!.ko,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (_knew)
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(
                            color: AppColors.error, width: 2.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _onCorrectToWrong,
                      child:
                          const Text('몰랐어', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                if (_knew) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _onRecallNext,
                    child: const Text('다음', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDone(ReviewSession? session, Map<String, Word> wordMap) {
    if (session == null) return const Center(child: Text('세션 없음'));
    final stage1Correct =
        session.items.where((i) => i.readingPassed).length;
    final stage2Correct =
        session.items.where((i) => i.meaningPassed).length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.done_all, size: 64, color: AppColors.success),
          const SizedBox(height: 24),
          Text(
            '복습 완료',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _StatRow(
              label: '1단계 정답',
              value: '$stage1Correct / ${session.itemCount}'),
          _StatRow(
              label: '2단계 정답',
              value: '$stage2Correct / ${session.itemCount}'),
          const SizedBox(height: 48),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => context.go('/'),
            child: const Text('홈으로', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyLarge),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      );
}
