import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _dailyWordCount = 10;

  Future<void> _showResetDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('데이터 초기화'),
        content: const Text('진행 상황이 모두 초기화됩니다. 계속하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('다크 모드'),
            subtitle: const Text('시스템 설정을 따릅니다'),
            value: false,
            onChanged: null,
          ),
          ListTile(
            title: const Text('오늘 학습 단어 수'),
            trailing: DropdownButton<int>(
              value: _dailyWordCount,
              items: const [
                DropdownMenuItem(value: 5, child: Text('5개')),
                DropdownMenuItem(value: 10, child: Text('10개')),
                DropdownMenuItem(value: 20, child: Text('20개')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _dailyWordCount = value);
                }
              },
            ),
          ),
          const Divider(),
          ListTile(
            title: TextButton(
              onPressed: _showResetDialog,
              child: const Text(
                '데이터 초기화',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
