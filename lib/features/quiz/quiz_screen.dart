import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// 로딩이 실패했을 때 보여줄 메시지. null이면 정상 흐름.
  String? _error;

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

  List<String> _pendingWordIds() {
    switch (widget.mode) {
      case QuizMode.study:
        final set = ref.read(todayStudySetProvider).valueOrNull;
        return set?.items
                .where((i) => !i.passed)
                .map((i) => i.wordId)
                .toList() ??
            [];
      case QuizMode.review:
        final session = ref.read(reviewSessionProvider).valueOrNull;
        return session?.items
                .where((i) => !i.passed)
                .map((i) => i.wordId)
                .toList() ??
            [];
    }
  }

  Future<void> _record(String wordId, {required bool passed, ErrorTag? tag}) {
    switch (widget.mode) {
      case QuizMode.study:
        return ref
            .read(todayStudySetProvider.notifier)
            .updateItemResult(wordId, passed: passed, tag: tag);
      case QuizMode.review:
        return ref
            .read(reviewSessionProvider.notifier)
            .updateItemResult(wordId, passed: passed, tag: tag);
    }
  }

  Future<void> _initQueue() async {
    try {
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
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '문제를 불러오지 못했습니다.');
      return;
    }
    await _loadChoices();
  }

  /// 에러 화면의 '다시 시도'. 큐가 비어 있으면 처음부터 다시 잡는다.
  void _retry() {
    setState(() => _error = null);
    if (_queue.isEmpty) {
      _initQueue();
    } else {
      _loadChoices();
    }
  }

  Word? _currentWord() {
    if (_index >= _queue.length) return null;
    return ref.read(wordCatalogProvider.notifier).wordById(_queue[_index]);
  }

  /// DB가 터져도 화면이 스피너에 갇히지 않도록 에러 상태로 떨어뜨린다.
  Future<void> _loadChoices() async {
    try {
      await _loadChoicesInner();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '보기를 불러오지 못했습니다.');
    }
  }

  Future<void> _loadChoicesInner() async {
    final word = _currentWord();
    if (word == null) return;
    final db = await ref.read(databaseProvider.future);
    final repo = WordRepository(db);
    final List<QuizChoice> choices;

    if (word.hasKanji) {
      final siblings = (await repo.getReadingsByExpression(
        word.expression,
      )).toSet();
      final pool = await repo.getRandomReadingsStartingWith(
        word.reading.substring(0, 1),
        limit: 6,
        exclude: {...siblings, word.reading},
      );
      final distractors = _generator.generate(
        correct: word.reading,
        exclude: siblings,
        pool: pool,
      );
      choices = [
        QuizChoice(word.reading, isCorrect: true),
        for (final d in distractors)
          QuizChoice(d.reading, isCorrect: false, tag: d.tag),
      ];
    } else {
      final meanings = await repo.getRandomMeanings(
        limit: 3,
        excludeWordId: word.id,
      );
      choices = [
        QuizChoice(word.meaningKo, isCorrect: true),
        for (final m in meanings)
          QuizChoice(m, isCorrect: false, tag: ErrorTag.meaning),
      ];
    }
    choices.shuffle(Random());
    if (!mounted) return;
    setState(() {
      _choices = choices;
      _selected = null;
      _revealed = false;
      _error = null;
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
    // 맞았는지 틀렸는지를 손끝으로도 알린다 (색만으로 전달하지 않기).
    if (correct) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
    await _record(
      word.id,
      passed: correct,
      tag: correct ? null : (choice?.tag ?? ErrorTag.other),
    );
  }

  /// 공개 후 '다음'을 눌러야 넘어간다 — 정답 카드를 읽을 시간을 뺏지 않는다.
  void _advance() {
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
    // 새 보기가 도착할 때까지 로딩 상태로 떨어뜨린다. 인덱스만 올리면
    // 다음 단어에 이전 문제의 보기·공개 상태가 그대로 붙는다.
    setState(() {
      _index = next;
      _choices = [];
      _selected = null;
      _revealed = false;
    });
    _loadChoices();
  }

  void _goComplete() {
    context.go('/quiz/complete', extra: widget.mode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: _closeButton(context),
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error!,
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(onPressed: _retry, child: const Text('다시 시도')),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: () => context.go('/'),
                    child: const Text('홈으로'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final word = _currentWord();
    if (word == null || _choices.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: _closeButton(context),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: _closeButton(context),
        title: Text('${_index + 1} / ${_queue.length}'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 한자를 키우거나 Dynamic Type을 올려도 넘치지 않도록 본문은 스크롤.
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const SizedBox(height: AppSpacing.xl),
                    Center(
                      child: Text(
                        word.expression,
                        style: AppText.jaHero(context),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    for (var i = 0; i < _choices.length; i++) ...[
                      _ChoiceButton(
                        key: Key('quiz-choice-$i'),
                        text: _choices[i].text,
                        state: _choiceState(i),
                        onTap: () => _onSelect(i),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (!_revealed)
                      TextButton(
                        onPressed: () => _onSelect(null),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurfaceVariant,
                        ),
                        child: const Text('모르겠다'),
                      ),
                    if (_revealed) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _AnswerCard(word: word),
                    ],
                  ],
                ),
              ),
              if (_revealed) ...[
                const SizedBox(height: AppSpacing.base),
                ElevatedButton(onPressed: _advance, child: const Text('다음')),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _closeButton(BuildContext context) => IconButton(
    icon: const Icon(Icons.close),
    tooltip: '학습 닫기',
    onPressed: () => context.go('/'),
  );

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
  const _ChoiceButton({
    super.key,
    required this.text,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg, icon) = switch (state) {
      _ChoiceState.idle => (scheme.surfaceContainer, scheme.onSurface, null),
      _ChoiceState.correct => (
        scheme.successContainer,
        scheme.success,
        Icons.check_rounded,
      ),
      _ChoiceState.wrong => (
        scheme.errorContainer,
        scheme.error,
        Icons.close_rounded,
      ),
      _ChoiceState.dim => (
        scheme.surfaceContainer.withValues(alpha: 0.45),
        scheme.onSurfaceVariant,
        null,
      ),
    };
    final label = switch (state) {
      _ChoiceState.correct => '$text, 정답',
      _ChoiceState.wrong => '$text, 오답',
      _ => text,
    };
    final radius = BorderRadius.circular(AppRadius.md);
    final enabled = state == _ChoiceState.idle;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: Material(
        color: bg,
        borderRadius: radius,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
                vertical: 14,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: fg),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Flexible(
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      style: AppText.jaTitle(context, color: fg).copyWith(
                        decoration: state == _ChoiceState.wrong
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: fg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  word.reading,
                  style: AppText.jaTitle(context, color: scheme.primary),
                ),
              ),
              if (word.isTrap) ...[
                const SizedBox(width: AppSpacing.sm),
                const _TrapBadge(),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(word.meaningKo, style: theme.textTheme.bodyLarge),
          if (word.example != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(word.example!.ja, style: AppText.jaBody(context)),
            const SizedBox(height: AppSpacing.xs),
            Text(word.example!.reading, style: AppText.jaCaption(context)),
            Text(word.example!.ko, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// 표기에서 읽기를 유추할 수 없는 단어 표식. 색만으로 뜻을 전하지 않도록
/// 툴팁과 스크린리더 설명을 함께 붙인다.
class _TrapBadge extends StatelessWidget {
  const _TrapBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const explanation = '읽기가 표기와 다르게 굳어진 단어';
    return Tooltip(
      message: explanation,
      child: Semantics(
        label: '배신 단어. $explanation',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            '배신 단어',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
