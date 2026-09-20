import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/backup_service_provider.dart';
import '../../application/providers/database_provider.dart';
import '../../application/providers/settings_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/app_settings.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

/// 진행 중인 백업 작업 — 어느 행에 스피너를 붙일지 정한다.
enum _BackupAction { export, import }

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// 백업 내보내기/가져오기가 진행 중인 동안 두 타일을 모두 잠근다. 빠르게
  /// 두 번 탭하면 두 번째 호출이 스냅샷 디렉터리를 먼저 지워버려, 아직
  /// 공유 시트가 읽고 있는 첫 번째 호출의 파일이 사라질 수 있다.
  bool _backupBusy = false;
  _BackupAction? _runningAction;

  String _fmt(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  Future<void> _showResetDialog(BuildContext context) async {
    final colors = Theme.of(context).colorScheme;
    final didReset = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('데이터 초기화'),
        content: const Text('오늘 세트·오답 기록·완료 표시가 모두 지워진다. 추가한 단어는 남는다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: colors.error),
            onPressed: () async {
              HapticFeedback.heavyImpact();
              await ref.read(settingsProvider.notifier).resetProgress();
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('초기화'),
          ),
        ],
      ),
    );
    if (didReset == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('진행 상황을 초기화했습니다.')));
    }
  }

  Future<void> _exportBackup() async {
    if (_backupBusy) return;
    setState(() {
      _backupBusy = true;
      _runningAction = _BackupAction.export;
    });
    try {
      await ref.read(backupServiceProvider).export();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('백업 내보내기에 실패했습니다.')));
    } finally {
      if (mounted) {
        setState(() {
          _backupBusy = false;
          _runningAction = null;
        });
      }
    }
  }

  /// 가져오기는 현재 기록을 덮어쓰는 파괴적 동작이라 한 번 더 묻는다.
  Future<void> _confirmImport() async {
    if (_backupBusy) return;
    final colors = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('백업 가져오기'),
        content: const Text('현재 학습 기록이 백업 파일 내용으로 교체된다. 되돌릴 수 없다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: colors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('가져오기'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _importBackup();
  }

  Future<void> _importBackup() async {
    if (_backupBusy) return;
    setState(() {
      _backupBusy = true;
      _runningAction = _BackupAction.import;
    });
    try {
      final ok = await ref.read(backupServiceProvider).pickAndImport();
      if (!mounted) return;
      if (ok) {
        ref.invalidate(databaseProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('백업을 가져왔습니다. 앱을 다시 실행해 주세요.')),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('올바른 백업 파일이 아닙니다.')));
      }
    } catch (_) {
      if (!mounted) return;
      // 가져오기는 실패하기 전에 이미 DB를 닫았을 수 있다. 캐시된 닫힌 핸들을
      // 계속 쓰면 이후 모든 읽기·쓰기가 깨지므로 프로바이더를 무효화하고,
      // 재시작을 안내한다.
      ref.invalidate(databaseProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('백업 가져오기에 실패했습니다. 앱을 다시 실행해 주세요.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _backupBusy = false;
          _runningAction = null;
        });
      }
    }
  }

  Widget? _backupTrailing(_BackupAction action, IconData icon) {
    if (_runningAction == action) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Icon(icon);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final themeMode = settings.valueOrNull?.themeMode ?? AppThemeMode.system;
    final examDate =
        settings.valueOrNull?.examDate ?? AppSettings.defaults.examDate;
    final nextJlpt = AppSettings.nextJlptDate(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        // 홈 인디케이터 위로 마지막 섹션이 올라오도록 하단 여백을 더한다.
        padding: EdgeInsets.fromLTRB(
          AppSpacing.base,
          AppSpacing.base,
          AppSpacing.base,
          AppSpacing.base + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _SettingsSection(
            header: '시험',
            children: [
              ListTile(
                title: const Text('시험일'),
                subtitle: Text(_fmt(examDate)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: examDate.isBefore(now) ? now : examDate,
                    firstDate: DateTime(now.year, now.month, now.day),
                    lastDate: DateTime(now.year + 3, 12, 31),
                  );
                  if (picked != null) {
                    ref.read(settingsProvider.notifier).updateExamDate(picked);
                  }
                },
              ),
              ListTile(
                title: const Text('다음 JLPT로 설정'),
                subtitle: Text(_fmt(nextJlpt)),
                onTap: () => ref
                    .read(settingsProvider.notifier)
                    .updateExamDate(nextJlpt),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SettingsSection(
            header: '테마',
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<AppThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: AppThemeMode.system,
                        label: Text('시스템'),
                        icon: Icon(Icons.brightness_auto_outlined),
                      ),
                      ButtonSegment(
                        value: AppThemeMode.light,
                        label: Text('라이트'),
                        icon: Icon(Icons.light_mode_outlined),
                      ),
                      ButtonSegment(
                        value: AppThemeMode.dark,
                        label: Text('다크'),
                        icon: Icon(Icons.dark_mode_outlined),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (value) {
                      ref
                          .read(settingsProvider.notifier)
                          .updateThemeMode(value.first);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SettingsSection(
            header: '백업',
            children: [
              ListTile(
                title: const Text('백업 내보내기'),
                trailing: _backupTrailing(
                  _BackupAction.export,
                  Icons.ios_share,
                ),
                enabled: !_backupBusy,
                onTap: _backupBusy ? null : _exportBackup,
              ),
              ListTile(
                title: const Text('백업 가져오기'),
                trailing: _backupTrailing(
                  _BackupAction.import,
                  Icons.file_download_outlined,
                ),
                enabled: !_backupBusy,
                onTap: _backupBusy ? null : _confirmImport,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SettingsSection(
            children: [
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  '데이터 초기화',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                onTap: () => _showResetDialog(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// iOS 그룹 인셋 스타일 한 덩어리. 테두리 없이 면으로 묶고, 행 사이에만
/// 헤어라인을 둔다.
class _SettingsSection extends StatelessWidget {
  final String? header;
  final List<Widget> children;

  const _SettingsSection({this.header, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.base,
              bottom: AppSpacing.sm,
            ),
            child: Text(header!, style: theme.textTheme.titleSmall),
          ),
        Material(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: AppSpacing.base),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
