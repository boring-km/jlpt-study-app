import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/application/providers/settings_provider.dart';
import 'package:jlpt/domain/models/app_settings.dart';
import 'package:jlpt/features/settings/settings_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FixedSettingsNotifier extends SettingsNotifier {
  @override
  Future<AppSettings> build() async => AppSettings(
        examDate: DateTime(2026, 12, 6),
        themeMode: AppThemeMode.light,
      );
}

class _RecordingSettingsNotifier extends SettingsNotifier {
  int resetProgressCallCount = 0;

  @override
  Future<AppSettings> build() async => AppSettings(
        examDate: DateTime(2026, 12, 6),
        themeMode: AppThemeMode.light,
      );

  @override
  Future<void> resetProgress() async {
    resetProgressCallCount++;
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('renders without crash', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );
    await tester.pump();
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('shows 설정 title', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );
    await tester.pump();
    expect(find.text('설정'), findsOneWidget);
  });

  testWidgets('shows 데이터 초기화 button', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );
    await tester.pump();
    expect(find.text('데이터 초기화'), findsOneWidget);
  });

  testWidgets('shows only light and dark theme options', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );
    await tester.pump();
    expect(find.text('라이트'), findsOneWidget);
    expect(find.text('다크'), findsOneWidget);
    expect(find.text('시스템'), findsNothing);
  });

  testWidgets('shows confirmation dialog when reset tapped', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );
    await tester.pump();
    await tester.tap(find.text('데이터 초기화'));
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('shows 시험일 and the formatted exam date, opens date picker',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_FixedSettingsNotifier.new),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('시험일'), findsOneWidget);
    expect(find.text('2026.12.06'), findsOneWidget);

    await tester.tap(find.text('시험일'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('shows next JLPT shortcut button', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_FixedSettingsNotifier.new),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();

    final buttonFinder = find.byWidgetPredicate(
      (widget) =>
          widget is TextButton &&
          widget.child is Text &&
          (widget.child as Text).data?.startsWith('다음 JLPT (') == true,
    );
    expect(buttonFinder, findsOneWidget);
  });

  testWidgets('백업 내보내기 / 백업 가져오기 tiles are shown', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );
    await tester.pump();

    expect(find.text('백업 내보내기'), findsOneWidget);
    expect(find.text('백업 가져오기'), findsOneWidget);
  });

  testWidgets('tapping 데이터 초기화 → 확인 calls resetProgress and closes dialog',
      (tester) async {
    final notifier = _RecordingSettingsNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(() => notifier),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('데이터 초기화'));
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(notifier.resetProgressCallCount, 1);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
