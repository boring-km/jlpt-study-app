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
  bool _revealed = false;
  bool _initialized = false;

  void _maybeInitQueue(List<String> wordIds) {
    if (_initialized || wordIds.isEmpty) return;
    _initialized = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _queue = wordIds;
        _queueIndex = 0;
        _revealed = false;
      });
    });
  }

  void _onReveal() => setState(() => _revealed = true);

  void _onAssess(bool knows) {
    final wordId = _queue[_queueIndex];
    ref.read(todayStudySetProvider.notifier).updateItemResult(
          wordId,
          passed: knows,
          isReadingStage: false,
        );
    if (!knows) _queue.add(wordId);
    final nextIndex = _queueIndex + 1;
    if (nextIndex >= _queue.length) {
      _finish();
      return;
    }
    setState(() {
      _queueIndex = nextIndex;
      _revealed = false;
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
          if (!_revealed)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _onReveal,
              child: const Text('뜻 확인', style: TextStyle(fontSize: 18)),
            ),
          if (_revealed) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.reading,
                    style: const TextStyle(
                      fontSize: 22,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
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
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
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
                      side: const BorderSide(color: AppColors.error),
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
        ],
      ),
    );
  }
}
