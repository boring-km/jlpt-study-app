import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/providers/review_session_provider.dart';
import '../../application/providers/word_catalog_provider.dart';
import '../../application/providers/database_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/word.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/review_session.dart';
import '../../domain/repositories/word_repository.dart';

enum _ReviewPhase { loading, reading, meaning, done }

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  _ReviewPhase _phase = _ReviewPhase.loading;
  List<String> _readingQueue = [];
  List<String> _meaningQueue = [];
  int _queueIndex = 0;
  List<Word> _choices = [];
  String? _selectedChoice;
  bool _showFeedback = false;
  bool _meaningRevealed = false;

  @override
  void initState() {
    super.initState();
    Future(() => _init());
  }

  Future<void> _init() async {
    final session =
        await ref.read(reviewSessionProvider.notifier).startNewSession();
    if (!mounted) return;
    setState(() {
      _readingQueue = session.items.map((i) => i.wordId).toList();
      _meaningQueue = List.from(_readingQueue);
      _queueIndex = 0;
      _phase = _ReviewPhase.reading;
    });
    await _loadReadingChoices();
  }

  Future<void> _loadReadingChoices() async {
    if (_queueIndex >= _readingQueue.length) return;
    final wordId = _readingQueue[_queueIndex];
    final catalog = ref.read(wordCatalogProvider).valueOrNull ?? [];
    final wordMap = {for (final w in catalog) w.id: w};
    final target = wordMap[wordId];
    if (target == null) return;

    final db = await ref.read(databaseProvider.future);
    final session = ref.read(reviewSessionProvider).valueOrNull;
    if (session == null) return;
    final level = session.items.isNotEmpty &&
            session.items.first.wordId.startsWith('n2')
        ? JlptLevel.n2
        : JlptLevel.n3;
    final similar = await WordRepository(db).getSimilarReading(
      target.reading,
      level,
      3,
      [wordId],
    );
    if (!mounted) return;
    final choices = [target, ...similar]..shuffle();
    setState(() {
      _choices = choices;
      _selectedChoice = null;
      _showFeedback = false;
    });
  }

  void _onReadingSelect(String reading, bool isCorrect) {
    if (_showFeedback) return;
    setState(() {
      _selectedChoice = reading;
      _showFeedback = true;
    });
    final wordId = _readingQueue[_queueIndex];
    ref.read(reviewSessionProvider.notifier).updateItemResult(
          wordId,
          passed: isCorrect,
          isReadingStage: true,
        );
    if (!isCorrect) _readingQueue.add(wordId);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      final next = _queueIndex + 1;
      if (next >= _readingQueue.length) {
        setState(() {
          _phase = _ReviewPhase.meaning;
          _queueIndex = 0;
          _meaningRevealed = false;
        });
      } else {
        setState(() => _queueIndex = next);
        _loadReadingChoices();
      }
    });
  }

  void _onMeaningAssess(bool knows) {
    final wordId = _meaningQueue[_queueIndex];
    ref.read(reviewSessionProvider.notifier).updateItemResult(
          wordId,
          passed: knows,
          isReadingStage: false,
        );
    if (!knows) _meaningQueue.add(wordId);
    final next = _queueIndex + 1;
    if (next >= _meaningQueue.length) {
      ref.read(reviewSessionProvider.notifier).complete();
      setState(() => _phase = _ReviewPhase.done);
    } else {
      setState(() {
        _queueIndex = next;
        _meaningRevealed = false;
      });
    }
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
        _ReviewPhase.reading => _buildReadingPhase(wordMap),
        _ReviewPhase.meaning => _buildMeaningPhase(wordMap),
        _ReviewPhase.done => _buildDone(session, wordMap),
      },
    );
  }

  String _phaseTitle() => switch (_phase) {
        _ReviewPhase.reading =>
          '읽기 ${_queueIndex + 1} / ${_readingQueue.length}',
        _ReviewPhase.meaning =>
          '뜻 ${_queueIndex + 1} / ${_meaningQueue.length}',
        _ReviewPhase.done => '복습 완료',
        _ => '복습',
      };

  Widget _buildReadingPhase(Map<String, Word> wordMap) {
    if (_queueIndex >= _readingQueue.length) {
      return const Center(child: CircularProgressIndicator());
    }
    final wordId = _readingQueue[_queueIndex];
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
              style:
                  const TextStyle(fontSize: 56, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 48),
          ..._choices.map((choice) {
            final isCorrect = choice.reading == word.reading;
            Color? bgColor;
            if (_showFeedback) {
              if (isCorrect) {
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
                  foregroundColor: isCorrect && _showFeedback
                      ? AppColors.success
                      : Theme.of(context).colorScheme.onSurface,
                  elevation: 0,
                  side: BorderSide(
                    color: _showFeedback && isCorrect
                        ? AppColors.success
                        : Theme.of(context).dividerColor,
                    width: 2.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _showFeedback
                    ? null
                    : () => _onReadingSelect(choice.reading, isCorrect),
                child: Text(choice.reading,
                    style: const TextStyle(fontSize: 18)),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMeaningPhase(Map<String, Word> wordMap) {
    if (_queueIndex >= _meaningQueue.length) {
      return const Center(child: CircularProgressIndicator());
    }
    final wordId = _meaningQueue[_queueIndex];
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
              style:
                  const TextStyle(fontSize: 56, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 48),
          if (!_meaningRevealed)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () => setState(() => _meaningRevealed = true),
              child: const Text('뜻 확인', style: TextStyle(fontSize: 18)),
            ),
          if (_meaningRevealed) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Theme.of(context).dividerColor, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.reading,
                    style: TextStyle(
                        fontSize: 22,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(word.meaningKo,
                      style: const TextStyle(fontSize: 18)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error, width: 2.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => _onMeaningAssess(false),
                    child:
                        const Text('몰라', style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => _onMeaningAssess(true),
                    child:
                        const Text('알아', style: TextStyle(fontSize: 18)),
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
    final readingCorrect =
        session.items.where((i) => i.readingPassed).length;
    final meaningCorrect =
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
              label: '읽기 정답',
              value: '$readingCorrect / ${session.itemCount}'),
          _StatRow(
              label: '뜻 정답',
              value: '$meaningCorrect / ${session.itemCount}'),
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
