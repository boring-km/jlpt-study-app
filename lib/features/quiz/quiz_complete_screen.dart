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
  bool _failed = false;
  bool _busy = false;
  Map<String, List<ErrorTag>> _tags = {};

  @override
  void initState() {
    super.initState();
    _finish();
  }

  /// 핫리로드/리빌드로 두 번 마감되지 않도록 한 번만 실행한다.
  /// 마감이 실패해도 스피너에 갇히지 않도록 전부 감싸서 에러 상태로 떨어뜨린다.
  Future<void> _finish() async {
    if (_finishStarted) return;
    _finishStarted = true;
    try {
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
      final ids = _wrongWordIds();
      // 틀린 단어가 여러 개여도 한 번에 모은다 (순차 await면 개수만큼 느려진다).
      final lists = await Future.wait(ids.map(repo.tagsForWord));
      if (!mounted) return;
      setState(() {
        _tags = {for (var i = 0; i < ids.length; i++) ids[i]: lists[i]};
        _finished = true;
        _failed = false;
      });
      HapticFeedback.lightImpact();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _finished = false;
      });
    }
  }

  void _retry() {
    setState(() {
      _finishStarted = false;
      _failed = false;
    });
    _finish();
  }

  Future<void> _startNextSet() async {
    if (_busy) return;
    setState(() => _busy = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(todayStudySetProvider.notifier).appendNextSet();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('학습을 시작하지 못했습니다. 잠시 후 다시 시도해 주세요.')),
      );
      return;
    }
    if (!mounted) return;
    router.go('/quiz', extra: QuizMode.study);
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

  List<String> _wrongWordIds() =>
      _items().where((e) => e.$2 > 1).map((e) => e.$1).toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_failed) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '결과를 정리하지 못했다',
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
    if (!_finished) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final items = _items();
    final attempts = items.fold<int>(0, (s, e) => s + e.$2);
    // 한 번에 맞힌 것만 "정답"으로 센다 — 두 번째에 맞힌 건 복습 대상이다.
    final firstTry = items.where((e) => e.$2 == 1).length;
    final wrong = _wrongWordIds();
    final catalog = ref.read(wordCatalogProvider.notifier);
    final scheme = theme.colorScheme;

    // 틀린 단어 행은 본문 ListView 안에 그대로 얹는다 — 리스트를 중첩하면
    // 큰 글자 설정에서 본문이 잘린다.
    final wrongRows = <Widget>[];
    for (final id in wrong) {
      final w = catalog.wordById(id);
      if (w == null) continue;
      if (wrongRows.isNotEmpty) wrongRows.add(const Divider(height: 1));
      final tags = _tags[w.id] ?? [];
      // 가나만 있는 단어는 표기와 읽기가 같다 — 두 번 찍지 않는다.
      final title = w.expression.isEmpty || w.expression == w.reading
          ? w.reading
          : '${w.expression}  ${w.reading}';
      wrongRows.add(
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title, style: AppText.jaLabel(context)),
          subtitle: Text(w.meaningKo, style: theme.textTheme.bodySmall),
          trailing: Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final t in tags)
                Chip(
                  label: Text(t.label),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  labelStyle: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                  ),
                  backgroundColor: scheme.primaryContainer,
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              widget.mode == QuizMode.study ? '오늘 학습 완료' : '복습 완료',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('첫 시도 정답', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$firstTry', style: theme.textTheme.displayLarge),
                Text(
                  ' / ${items.length}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('시도 $attempts회', style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xl),
            if (wrong.isEmpty)
              Text('한 번에 다 맞혔다', style: theme.textTheme.bodyLarge)
            else
              Text('틀린 단어 ${wrong.length}개', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            ...wrongRows,
          ],
        ),
      ),
      // 버튼은 스크롤과 무관하게 늘 손 닿는 자리에 둔다.
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.mode == QuizMode.study) ...[
                ElevatedButton(
                  onPressed: _busy ? null : _startNextSet,
                  child: const Text('다음 학습 시작'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => context.go('/'),
                  child: const Text('홈으로'),
                ),
              ] else
                ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('홈으로'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
