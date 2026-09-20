import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/database_provider.dart';
import '../../application/providers/settings_provider.dart';
import '../../application/services/backup_service.dart';
import '../../domain/models/app_settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  String _fmt(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  Future<void> _showResetDialog(BuildContext context, WidgetRef ref) async {
    final didReset = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('데이터 초기화'),
        content: const Text('진행 상황이 모두 초기화됩니다. 계속하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(settingsProvider.notifier).resetProgress();
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (didReset == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('진행 상황을 초기화했습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final themeMode = settings.valueOrNull?.themeMode ?? AppThemeMode.light;
    final examDate = settings.valueOrNull?.examDate ?? AppSettings.defaults.examDate;

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton(
              onPressed: () => ref
                  .read(settingsProvider.notifier)
                  .updateExamDate(AppSettings.nextJlptDate(DateTime.now())),
              child: Text(
                '다음 JLPT (${_fmt(AppSettings.nextJlptDate(DateTime.now()))})',
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('테마', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<AppThemeMode>(
                  segments: const [
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
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text('백업', style: Theme.of(context).textTheme.titleSmall),
          ),
          ListTile(
            title: const Text('백업 내보내기'),
            trailing: const Icon(Icons.ios_share),
            onTap: () => BackupService().export(),
          ),
          ListTile(
            title: const Text('백업 가져오기'),
            trailing: const Icon(Icons.file_download_outlined),
            onTap: () async {
              final ok = await BackupService().pickAndImport();
              if (!context.mounted) return;
              if (ok) {
                ref.invalidate(databaseProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('백업을 가져왔습니다. 앱을 다시 실행해 주세요.'),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('올바른 백업 파일이 아닙니다.')),
                );
              }
            },
          ),
          const Divider(),
          ListTile(
            title: TextButton(
              onPressed: () => _showResetDialog(context, ref),
              child: Text(
                '데이터 초기화',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
