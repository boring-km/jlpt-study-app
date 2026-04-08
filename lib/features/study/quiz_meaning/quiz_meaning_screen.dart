import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../application/providers/today_study_set_provider.dart';
import '../../../application/providers/word_catalog_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/word.dart';
import '../../../widgets/word_badge.dart';

class QuizMeaningScreen extends ConsumerStatefulWidget {
  const QuizMeaningScreen({super.key});

  @override
  ConsumerState<QuizMeaningScreen> createState() => _QuizMeaningScreenState();
}

class _QuizMeaningScreenState extends ConsumerState<QuizMeaningScreen> {
  List<String> _queue = [];
  int _queueIndex = 0;
  bool _assessed = false;
  bool _knew = false;
  bool _initialized = false;

  void _maybeInitQueue(List<String> wordIds) {
    if (_initialized || wordIds.isEmpty) return;
    _initialized = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _queue = wordIds;
        _queueIndex = 0;
        _assessed = false;
        _knew = false;
      });
    });
  }

  void _onAssess(bool knows) {
    final wordId = _queue[_queueIndex];
    ref.read(todayStudySetProvider.notifier).updateItemResult(
          wordId,
          passed: knows,
          isReadingStage: false,
        );
    if (!knows) _queue.add(wordId);
    setState(() {
      _assessed = true;
      _knew = knows;
    });
  }

  void _onCorrectToWrong() {
    final wordId = _queue[_queueIndex];
    ref.read(todayStudySetProvider.notifier).updateItemResult(
          wordId,
          passed: false,
          isReadingStage: false,
        );
    _queue.add(wordId);
    _onNext();
  }

  void _onNext() {
    final nextIndex = _queueIndex + 1;
    if (nextIndex >= _queue.length) {
      _finish();
      return;
    }
    setState(() {
      _queueIndex = nextIndex;
      _assessed = false;
      _knew = false;
    });
  }

  void _finish() {
    context.go('/study/wrong-answers', extra: {'stage': 'meaning'});
  }

  @override
  Widget build(BuildContext context) {
    final setAsync = ref.watch(todayStudySetProvider);
    final catalog = ref.watch(wordCatalogProvider).valueOrNull ?? [];
    final wordMap = {for (final w in catalog) w.id: w};

    final wordIds = setAsync.valueOrNull?.items.map((i) => i.wordId).toList() ?? [];
    _maybeInitQueue(wordIds);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('${_queueIndex + 1} / ${_queue.length}'),
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

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Center(
            child: Text(
              (word.expression?.isNotEmpty ?? false) ? word.expression! : word.reading,
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
                      side: const BorderSide(color: AppColors.error, width: 2.0),
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
                    Text(word.example!.ja, style: const TextStyle(fontSize: 13)),
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
                        side: const BorderSide(color: AppColors.error, width: 2.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _onCorrectToWrong,
                      child: const Text('몰랐어', style: TextStyle(fontSize: 18)),
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
                    onPressed: _onNext,
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
}
