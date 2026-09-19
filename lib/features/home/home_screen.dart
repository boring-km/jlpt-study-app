import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/providers/progress_summary_provider.dart';
import '../../application/providers/settings_provider.dart';
import '../../application/providers/today_study_set_provider.dart';
import '../../domain/models/app_settings.dart';
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
          error: (e, _) => Center(child: Text('오류: $e')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('클립보드에 일본어 단어가 없다')),
      );
      return;
    }
    await showAddWordSheet(context, initialExpression: text);
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final set = widget.setAsync.valueOrNull;
    final todayCompleted = set?.completedCount ?? 0;
    final todayTarget = set?.targetCount ?? summary.dailyTarget;
    final isSetCompleted = set?.status == StudyStage.completed;
    final settings = ref.watch(settingsProvider);
    final themeMode = settings.valueOrNull?.themeMode ?? AppThemeMode.light;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                summary.daysUntilExam >= 0
                    ? 'D-${summary.daysUntilExam}'
                    : 'D+${summary.daysUntilExam.abs()}',
                style: Theme.of(context).textTheme.displayLarge,
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.grid_view_outlined),
                    tooltip: 'ひらがな·カタカナ 표',
                    onPressed: () => context.push('/kana'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: '설정',
                    onPressed: () => context.push('/settings'),
                  ),
                  IconButton(
                    icon: Icon(switch (themeMode) {
                      AppThemeMode.light => Icons.light_mode_outlined,
                      AppThemeMode.dark => Icons.dark_mode_outlined,
                    }),
                    tooltip: switch (themeMode) {
                      AppThemeMode.light => '라이트 모드',
                      AppThemeMode.dark => '다크 모드',
                    },
                    onPressed: () {
                      final next = switch (themeMode) {
                        AppThemeMode.light => AppThemeMode.dark,
                        AppThemeMode.dark => AppThemeMode.light,
                      };
                      ref.read(settingsProvider.notifier).updateThemeMode(next);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '오늘 $todayCompleted / $todayTarget 완료',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'N2 ${summary.completedCount} / ${summary.totalCount}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: summary.totalCount > 0
                  ? summary.completedCount / summary.totalCount
                  : 0,
              minHeight: 6,
              backgroundColor: Theme.of(context).dividerColor,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed:
                  isSetCompleted ? null : () => _startStudy(context, ref, set),
              child: Text(
                set == null
                    ? '학습 시작'
                    : isSetCompleted
                    ? '오늘 학습 완료 ✓'
                    : '이어하기',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (isSetCompleted)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2.0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => _startNextStudy(context, ref),
                  child: const Text(
                    '다음 학습 시작',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SmallCard(
                  label: '복습',
                  icon: Icons.replay_outlined,
                  enabled: summary.completedCount > 0,
                  subtitle: summary.weakCount > 0
                      ? '약점 ${summary.weakCount}개'
                      : null,
                  onTap: () => showReviewFilterSheet(context),
                ),
              ),
              const SizedBox(width: 12),
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
            const SizedBox(height: 12),
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

  Future<void> _startNextStudy(BuildContext context, WidgetRef ref) async {
    await ref.read(todayStudySetProvider.notifier).appendNextSet();
    if (!context.mounted) return;
    context.push('/quiz', extra: QuizMode.study);
  }

  Future<void> _startStudy(
    BuildContext context,
    WidgetRef ref,
    TodayStudySet? currentSet,
  ) async {
    if (currentSet == null) {
      await ref.read(todayStudySetProvider.notifier).createTodaySet();
    }
    if (!context.mounted) return;
    context.push('/quiz', extra: QuizMode.study);
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
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enabled
                ? Theme.of(context).dividerColor
                : Theme.of(context).dividerColor.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: enabled
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: enabled
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 11,
                  color: enabled
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
