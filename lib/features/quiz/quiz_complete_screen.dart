import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/providers/database_provider.dart';
import '../../application/providers/review_session_provider.dart';
import '../../application/providers/today_study_set_provider.dart';
import '../../application/providers/word_catalog_provider.dart';
import '../../domain/models/error_tag.dart';
import '../../domain/repositories/miss_log_repository.dart';
import 'quiz_mode.dart';

class QuizCompleteScreen extends ConsumerStatefulWidget {
  final QuizMode mode;
  const QuizCompleteScreen({super.key, required this.mode});

  @override
  ConsumerState<QuizCompleteScreen> createState() => _QuizCompleteScreenState();
}

class _QuizCompleteScreenState extends ConsumerState<QuizCompleteScreen> {
  bool _finished = false;
  bool _finishStarted = false;
  Map<String, List<ErrorTag>> _tags = {};

  @override
  void initState() {
    super.initState();
    _finish();
  }

  /// 핫리로드/리빌드로 두 번 마감되지 않도록 한 번만 실행한다.
  Future<void> _finish() async {
    if (_finishStarted) return;
    _finishStarted = true;
    if (widget.mode == QuizMode.study) {
      await ref.read(todayStudySetProvider.notifier).finish();
    } else {
      await ref.read(reviewSessionProvider.notifier).complete();
    }
    if (!mounted) return;
    await ref.read(wordCatalogProvider.future); // wordById 준비 보장
    if (!mounted) return;
    final db = await ref.read(databaseProvider.future);
    if (!mounted) return;
    final repo = MissLogRepository(db);
    final tags = <String, List<ErrorTag>>{};
    for (final id in _wrongWordIds()) {
      tags[id] = await repo.tagsForWord(id);
      if (!mounted) return;
    }
    setState(() {
      _tags = tags;
      _finished = true;
    });
  }

  // (wordId, attempts) 목록
  List<(String, int)> _items() {
    switch (widget.mode) {
      case QuizMode.study:
        final set = ref.read(todayStudySetProvider).valueOrNull;
        return set?.items.map((i) => (i.wordId, i.attempts)).toList() ?? [];
      case QuizMode.review:
        final s = ref.read(reviewSessionProvider).valueOrNull;
        return s?.items.map((i) => (i.wordId, i.attempts)).toList() ?? [];
    }
  }

  List<String> _wrongWordIds() => _items().where((e) => e.$2 > 1).map((e) => e.$1).toList();

  @override
  Widget build(BuildContext context) {
    if (!_finished) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final items = _items();
    final attempts = items.fold<int>(0, (s, e) => s + e.$2);
    final wrong = _wrongWordIds();
    final catalog = ref.read(wordCatalogProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.mode == QuizMode.study ? '오늘 학습 완료' : '복습 완료', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('정답 ${items.length} / 시도 $attempts', style: theme.textTheme.bodyLarge),
              const SizedBox(height: 24),
              if (wrong.isEmpty)
                Text('한 번에 다 맞혔다', style: theme.textTheme.bodyMedium)
              else
                Text('틀린 단어 ${wrong.length}개', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: wrong.length,
                  itemBuilder: (context, i) {
                    final w = catalog.wordById(wrong[i]);
                    if (w == null) return const SizedBox.shrink();
                    final tags = _tags[w.id] ?? [];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${w.expression}  ${w.reading}'),
                      subtitle: Text(w.meaningKo),
                      trailing: Wrap(
                        spacing: 4,
                        children: [for (final t in tags) Chip(label: Text(t.label), visualDensity: VisualDensity.compact)],
                      ),
                    );
                  },
                ),
              ),
              if (widget.mode == QuizMode.study)
                OutlinedButton(
                  onPressed: () async {
                    await ref.read(todayStudySetProvider.notifier).appendNextSet();
                    if (context.mounted) context.go('/quiz', extra: QuizMode.study);
                  },
                  child: const Text('다음 학습 시작'),
                ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () => context.go('/'), child: const Text('홈으로')),
            ],
          ),
        ),
      ),
    );
  }
}
