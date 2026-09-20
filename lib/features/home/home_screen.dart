import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/providers/progress_summary_provider.dart';
import '../../application/providers/today_study_set_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/today_study_set.dart';
import '../quiz/quiz_mode.dart';
import '../review/review_filter_sheet.dart';
import '../words/add_word_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(progressSummaryProvider);
    final setAsync = ref.watch(todayStudySetProvider);

    return Scaffold(
      body: SafeArea(
        child: summaryAsync.when(
          data: (summary) => _HomeBody(summary: summary, setAsync: setAsync),
          loading: () => const Center(child: CircularProgressIndicator()),
          // raw 예외 대신 사람 말 + 재시도.
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '홈을 불러오지 못했다',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => ref.invalidate(progressSummaryProvider),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends ConsumerStatefulWidget {
  final ProgressSummary summary;
  final AsyncValue<TodayStudySet?> setAsync;

  const _HomeBody({required this.summary, required this.setAsync});

  @override
  ConsumerState<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends ConsumerState<_HomeBody>
    with WidgetsBindingObserver {
  bool _clipboardAvailable = false;

  /// 비동기 탭 핸들러가 도는 동안 다른 탭을 무시한다. 빠른 더블탭은 오늘 세트를
  /// 두 번 만들어 UNIQUE 제약 예외를 던지기 때문. (설정 화면의 `_backupBusy`와
  /// 같은 패턴.)
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshClipboardHint();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshClipboardHint();
  }

  /// iOS 붙여넣기 알림을 띄우지 않으려고 내용은 읽지 않고 존재 여부만 본다.
  /// 실제 읽기는 칩을 눌렀을 때뿐.
  Future<void> _refreshClipboardHint() async {
    final hasStrings = await Clipboard.hasStrings();
    if (!mounted || hasStrings == _clipboardAvailable) return;
    setState(() => _clipboardAvailable = hasStrings);
  }

  Future<void> _addFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted) return;
    // 한 번 눌렀으면 칩은 치운다 — 같은 내용으로 계속 권하지 않도록.
    setState(() => _clipboardAvailable = false);
    if (!looksJapanese(text)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('클립보드에 일본어 단어가 없다')));
      return;
    }
    await showAddWordSheet(context, initialExpression: text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = widget.summary;
    final set = widget.setAsync.valueOrNull;
    final todayCompleted = set?.completedCount ?? 0;
    final todayTarget = set?.targetCount ?? summary.dailyTarget;
    final isSetCompleted = set?.status == StudyStage.completed;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.base,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 큰 글자 설정에서도 かな 알약·설정 아이콘 옆을 넘치지 않게 줄인다.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    summary.daysUntilExam >= 0
                        ? 'D-${summary.daysUntilExam}'
                        : 'D+${summary.daysUntilExam.abs()}',
                    maxLines: 1,
                    style: theme.textTheme.displayLarge,
                  ),
                ),
              ),
              Row(
                children: [
                  const _KanaPillButton(),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: '설정',
                    onPressed: () => context.push('/settings'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '오늘 $todayCompleted / $todayTarget 완료',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              semanticsLabel: 'N2 진행률',
              // 시맨틱 값은 숫자 문자열이어야 한다 — 퍼센트로 준다.
              semanticsValue: summary.totalCount > 0
                  ? '${(summary.completedCount * 100 / summary.totalCount).round()}%'
                  : '0%',
              value: summary.totalCount > 0
                  ? summary.completedCount / summary.totalCount
                  : 0,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'N2 ${summary.completedCount} / ${summary.totalCount}',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton(
            onPressed: isSetCompleted
                ? null
                : () => _startStudy(context, ref, set),
            child: Text(
              set == null
                  ? '학습 시작'
                  : isSetCompleted
                  ? '오늘 학습 완료 ✓'
                  : '이어하기',
            ),
          ),
          if (isSetCompleted) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: () => _startNextStudy(context, ref),
              child: const Text('다음 학습 시작'),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _SmallCard(
                  label: '복습',
                  icon: Icons.replay_outlined,
                  enabled: summary.completedCount > 0,
                  // 비활성 타일은 왜 눌리지 않는지 말해 준다.
                  subtitle: summary.completedCount == 0
                      ? '학습 후 열림'
                      : summary.weakCount > 0
                      ? '약점 ${summary.weakCount}개'
                      : null,
                  onTap: () => _openReview(context),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _SmallCard(
                  label: '단어 추가',
                  icon: Icons.add_circle_outline,
                  enabled: true,
                  onTap: () => showAddWordSheet(context),
                ),
              ),
            ],
          ),
          if (_clipboardAvailable) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: const Icon(Icons.content_paste, size: 18),
                label: const Text('클립보드에서 단어 추가'),
                onPressed: _addFromClipboard,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 진행 중인 핸들러가 있으면 아무것도 하지 않고, 실패하면 스낵바로 알린다.
  Future<void> _guard(
    Future<void> Function() action, {
    required String errorMessage,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startNextStudy(BuildContext context, WidgetRef ref) =>
      _guard(() async {
        await ref.read(todayStudySetProvider.notifier).appendNextSet();
        if (!context.mounted) return;
        context.push('/quiz', extra: QuizMode.study);
      }, errorMessage: '학습을 시작하지 못했습니다. 잠시 후 다시 시도해 주세요.');

  Future<void> _startStudy(
    BuildContext context,
    WidgetRef ref,
    TodayStudySet? currentSet,
  ) => _guard(() async {
    if (currentSet == null) {
      await ref.read(todayStudySetProvider.notifier).createTodaySet();
    }
    if (!context.mounted) return;
    context.push('/quiz', extra: QuizMode.study);
  }, errorMessage: '학습을 시작하지 못했습니다. 잠시 후 다시 시도해 주세요.');

  Future<void> _openReview(BuildContext context) => _guard(
    () => showReviewFilterSheet(context),
    errorMessage: '복습을 시작하지 못했습니다. 잠시 후 다시 시도해 주세요.',
  );
}

/// 가나 표로 가는 작은 알약 버튼. 아이콘보다 글자가 뜻을 더 빨리 전한다.
class _KanaPillButton extends StatelessWidget {
  const _KanaPillButton();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: '가나 표',
      child: TextButton(
        onPressed: () => context.push('/kana'),
        style: TextButton.styleFrom(
          backgroundColor: colors.surfaceContainer,
          foregroundColor: colors.onSurface,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
        child: Text(
          'かな',
          style: AppText.jaCaption(context, color: colors.onSurface),
        ),
      ),
    );
  }
}

class _SmallCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final String? subtitle;
  final VoidCallback onTap;

  const _SmallCard({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 흐리게(Opacity) 처리하면 보조 문구가 4.5:1을 못 넘는다 — 색으로만 구분한다.
    final mutedColor = theme.colorScheme.onSurfaceVariant;
    final card = Material(
      color: theme.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 88),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: enabled ? theme.colorScheme.primary : mutedColor,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  style: enabled
                      ? theme.textTheme.labelLarge
                      : theme.textTheme.labelLarge?.copyWith(color: mutedColor),
                  textAlign: TextAlign.center,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: enabled ? theme.colorScheme.primary : mutedColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: subtitle == null ? label : '$label, $subtitle',
      onTap: enabled ? onTap : null,
      // 안쪽 Text가 라벨을 한 번 더 읽지 않도록 자식 시맨틱스는 감춘다.
      excludeSemantics: true,
      child: card,
    );
  }
}
