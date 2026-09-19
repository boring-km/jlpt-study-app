import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/providers/database_provider.dart';
import '../../application/providers/review_session_provider.dart';
import '../../application/providers/today_study_set_provider.dart';
import '../../application/providers/word_catalog_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/error_tag.dart';
import '../../domain/models/word.dart';
import '../../domain/repositories/word_repository.dart';
import '../../domain/services/distractor_generator.dart';
import 'quiz_mode.dart';

class QuizChoice {
  final String text;
  final bool isCorrect;
  final ErrorTag? tag; // 오답 선택 시 기록할 태그
  const QuizChoice(this.text, {required this.isCorrect, this.tag});
}

class QuizScreen extends ConsumerStatefulWidget {
  final QuizMode mode;
  const QuizScreen({super.key, required this.mode});

  @override
  ConsumerState<QuizScreen> createState() => QuizScreenState();
}

class QuizScreenState extends ConsumerState<QuizScreen> {
  final _generator = DistractorGenerator();
  List<String> _queue = [];
  int _index = 0;
  List<QuizChoice> _choices = [];
  int? _selected;
  bool _revealed = false;
  bool _initialized = false;
  Timer? _autoNext;

  @visibleForTesting
  int get correctChoiceIndexForTest => _choices.indexWhere((c) => c.isCorrect);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _initQueue();
    }
  }

  @override
  void dispose() {
    _autoNext?.cancel();
    super.dispose();
  }

  List<String> _pendingWordIds() {
    switch (widget.mode) {
      case QuizMode.study:
        final set = ref.read(todayStudySetProvider).valueOrNull;
        return set?.items.where((i) => !i.passed).map((i) => i.wordId).toList() ?? [];
      case QuizMode.review:
        final session = ref.read(reviewSessionProvider).valueOrNull;
        return session?.items.where((i) => !i.passed).map((i) => i.wordId).toList() ?? [];
    }
  }

  Future<void> _record(String wordId, {required bool passed, ErrorTag? tag}) {
    switch (widget.mode) {
      case QuizMode.study:
        return ref.read(todayStudySetProvider.notifier).updateItemResult(wordId, passed: passed, tag: tag);
      case QuizMode.review:
        return ref.read(reviewSessionProvider.notifier).updateItemResult(wordId, passed: passed, tag: tag);
    }
  }

  Future<void> _initQueue() async {
    // wordById가 카탈로그 state에 의존하므로 로딩(및 최초 시딩) 완료를 먼저 보장한다.
    await ref.read(wordCatalogProvider.future);
    if (!mounted) return;
    final ids = _pendingWordIds();
    if (ids.isEmpty) {
      _goComplete();
      return;
    }
    setState(() {
      _queue = ids;
      _index = 0;
    });
    await _loadChoices();
  }

  Word? _currentWord() {
    if (_index >= _queue.length) return null;
    return ref.read(wordCatalogProvider.notifier).wordById(_queue[_index]);
  }

  Future<void> _loadChoices() async {
    final word = _currentWord();
    if (word == null) return;
    final db = await ref.read(databaseProvider.future);
    final repo = WordRepository(db);
    final List<QuizChoice> choices;

    if (word.hasKanji) {
      final siblings = (await repo.getReadingsByExpression(word.expression)).toSet();
      final pool = await repo.getRandomReadingsStartingWith(
        word.reading.substring(0, 1),
        limit: 6,
        exclude: {...siblings, word.reading},
      );
      final distractors = _generator.generate(correct: word.reading, exclude: siblings, pool: pool);
      choices = [
        QuizChoice(word.reading, isCorrect: true),
        for (final d in distractors) QuizChoice(d.reading, isCorrect: false, tag: d.tag),
      ];
    } else {
      final meanings = await repo.getRandomMeanings(limit: 3, excludeWordId: word.id);
      choices = [
        QuizChoice(word.meaningKo, isCorrect: true),
        for (final m in meanings) QuizChoice(m, isCorrect: false, tag: ErrorTag.meaning),
      ];
    }
    choices.shuffle(Random());
    if (!mounted) return;
    setState(() {
      _choices = choices;
      _selected = null;
      _revealed = false;
    });
  }

  Future<void> _onSelect(int? index) async {
    if (_revealed) return;
    final word = _currentWord();
    if (word == null) return;
    final choice = index != null ? _choices[index] : null;
    final correct = choice?.isCorrect ?? false;
    setState(() {
      _selected = index;
      _revealed = true;
    });
    await _record(word.id, passed: correct, tag: correct ? null : (choice?.tag ?? ErrorTag.other));
    if (!mounted) return;
    if (correct) {
      _autoNext?.cancel();
      _autoNext = Timer(const Duration(milliseconds: 1000), _advance);
    }
  }

  /// 타이머와 '다음' 탭이 겹쳐 두 번 넘어가지 않도록 진입 즉시 타이머를 해제한다.
  void _advance() {
    _autoNext?.cancel();
    _autoNext = null;
    if (!mounted) return;
    final word = _currentWord();
    if (word == null) return;
    final wasCorrect = _selected != null && _choices[_selected!].isCorrect;
    if (!wasCorrect) _queue.add(word.id);
    final next = _index + 1;
    if (next >= _queue.length) {
      _goComplete();
      return;
    }
    setState(() => _index = next);
    _loadChoices();
  }

  void _goComplete() {
    context.go('/quiz/complete', extra: widget.mode);
  }

  @override
  Widget build(BuildContext context) {
    final word = _currentWord();
    if (word == null || _choices.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('${_index + 1} / ${_queue.length}'),
        actions: [
          IconButton(icon: const Icon(Icons.close), onPressed: () => context.go('/')),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(
                child: Text(
                  word.expression,
                  style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              for (var i = 0; i < _choices.length; i++) ...[
                _ChoiceButton(
                  key: Key('quiz-choice-$i'),
                  text: _choices[i].text,
                  state: _choiceState(i),
                  onTap: () => _onSelect(i),
                ),
                const SizedBox(height: 10),
              ],
              if (!_revealed)
                TextButton(onPressed: () => _onSelect(null), child: const Text('모르겠다')),
              if (_revealed) ...[
                const SizedBox(height: 8),
                Expanded(child: SingleChildScrollView(child: _AnswerCard(word: word))),
                if (!(_selected != null && _choices[_selected!].isCorrect))
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(onPressed: _advance, child: const Text('다음')),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  _ChoiceState _choiceState(int i) {
    if (!_revealed) return _ChoiceState.idle;
    if (_choices[i].isCorrect) return _ChoiceState.correct;
    if (_selected == i) return _ChoiceState.wrong;
    return _ChoiceState.dim;
  }
}

enum _ChoiceState { idle, correct, wrong, dim }

class _ChoiceButton extends StatelessWidget {
  final String text;
  final _ChoiceState state;
  final VoidCallback onTap;
  const _ChoiceButton({super.key, required this.text, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, border, fg) = switch (state) {
      _ChoiceState.idle => (theme.cardColor, theme.dividerColor, theme.colorScheme.onSurface),
      _ChoiceState.correct => (AppColors.success.withValues(alpha: 0.12), AppColors.success, AppColors.success),
      _ChoiceState.wrong => (AppColors.error.withValues(alpha: 0.12), AppColors.error, AppColors.error),
      _ChoiceState.dim => (theme.cardColor, theme.dividerColor.withValues(alpha: 0.4), theme.colorScheme.onSurfaceVariant),
    };
    return GestureDetector(
      onTap: state == _ChoiceState.idle ? onTap : null,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Text(text, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: fg)),
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  final Word word;
  const _AnswerCard({required this.word});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(word.reading, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
              const SizedBox(width: 8),
              if (word.isTrap)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('배신 단어', style: TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(word.meaningKo, style: const TextStyle(fontSize: 18)),
          if (word.example != null) ...[
            const SizedBox(height: 12),
            Text(word.example!.ja, style: const TextStyle(fontSize: 16)),
            Text(word.example!.reading, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
            Text(word.example!.ko, style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}
