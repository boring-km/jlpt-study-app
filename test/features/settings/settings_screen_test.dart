import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/application/providers/backup_service_provider.dart';
import 'package:jlpt/application/providers/database_provider.dart';
import 'package:jlpt/application/providers/settings_provider.dart';
import 'package:jlpt/application/services/backup_service.dart';
import 'package:jlpt/core/db/database.dart';
import 'package:jlpt/domain/models/app_settings.dart';
import 'package:jlpt/features/settings/settings_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _ThrowingBackupService extends BackupService {
  @override
  Future<void> export() async => throw Exception('export failed');

  @override
  Future<bool> pickAndImport() async => throw Exception('import failed');
}

/// export()가 [completer]가 완료될 때까지 대기하는 가짜 — 재진입(더블탭)
/// 가드를 테스트하기 위해 "공유 시트가 아직 안 떴다"는 상태를 흉내낸다.
class _CompleterBackupService extends BackupService {
  final Completer<void> completer;
  int exportCallCount = 0;

  _CompleterBackupService(this.completer);

  @override
  Future<void> export() async {
    exportCallCount++;
    await completer.future;
  }
}

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

String _fmt(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('renders without crash', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // 실제 DB를 열러 가지 않도록 설정을 고정한다. 다른 테스트 파일과
        // 병렬로 돌 때 같은 DB 파일을 두고 다투면 간헐적으로 깨진다.
        overrides: [settingsProvider.overrideWith(_FixedSettingsNotifier.new)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('shows 설정 title', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // 실제 DB를 열러 가지 않도록 설정을 고정한다. 다른 테스트 파일과
        // 병렬로 돌 때 같은 DB 파일을 두고 다투면 간헐적으로 깨진다.
        overrides: [settingsProvider.overrideWith(_FixedSettingsNotifier.new)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('설정'), findsOneWidget);
  });

  testWidgets('shows 데이터 초기화 button', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // 실제 DB를 열러 가지 않도록 설정을 고정한다. 다른 테스트 파일과
        // 병렬로 돌 때 같은 DB 파일을 두고 다투면 간헐적으로 깨진다.
        overrides: [settingsProvider.overrideWith(_FixedSettingsNotifier.new)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('데이터 초기화'), findsOneWidget);
  });

  testWidgets('offers system, light and dark theme options', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // 실제 DB를 열러 가지 않도록 설정을 고정한다. 다른 테스트 파일과
        // 병렬로 돌 때 같은 DB 파일을 두고 다투면 간헐적으로 깨진다.
        overrides: [settingsProvider.overrideWith(_FixedSettingsNotifier.new)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('시스템'), findsOneWidget);
    expect(find.text('라이트'), findsOneWidget);
    expect(find.text('다크'), findsOneWidget);
  });

  testWidgets('shows confirmation dialog when reset tapped', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // 실제 DB를 열러 가지 않도록 설정을 고정한다. 다른 테스트 파일과
        // 병렬로 돌 때 같은 DB 파일을 두고 다투면 간헐적으로 깨진다.
        overrides: [settingsProvider.overrideWith(_FixedSettingsNotifier.new)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('데이터 초기화'));
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('shows 시험일 and the formatted exam date, opens date picker', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith(_FixedSettingsNotifier.new)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('시험일'), findsOneWidget);
    // 다음 JLPT 행도 같은 날짜를 보여줄 수 있으므로 시험일 행 안에서 찾는다.
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('시험일'),
          matching: find.byType(ListTile),
        ),
        matching: find.text('2026.12.06'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('시험일'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('shows the next JLPT row with the date it would set', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith(_FixedSettingsNotifier.new)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();

    final row = find.ancestor(
      of: find.text('다음 JLPT로 설정'),
      matching: find.byType(ListTile),
    );
    expect(row, findsOneWidget);
    expect(
      find.descendant(
        of: row,
        matching: find.text(_fmt(AppSettings.nextJlptDate(DateTime.now()))),
      ),
      findsOneWidget,
    );
  });

  testWidgets('백업 내보내기 / 백업 가져오기 tiles are shown', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // 실제 DB를 열러 가지 않도록 설정을 고정한다. 다른 테스트 파일과
        // 병렬로 돌 때 같은 DB 파일을 두고 다투면 간헐적으로 깨진다.
        overrides: [settingsProvider.overrideWith(_FixedSettingsNotifier.new)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('백업 내보내기'), findsOneWidget);
    expect(find.text('백업 가져오기'), findsOneWidget);
  });

  testWidgets('tapping 백업 내보내기 shows a failure snackbar instead of throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backupServiceProvider.overrideWithValue(_ThrowingBackupService()),
          settingsProvider.overrideWith(_FixedSettingsNotifier.new),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('백업 내보내기'));
    await tester.pumpAndSettle();

    expect(find.text('백업 내보내기에 실패했습니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping 백업 가져오기 shows a failure snackbar instead of throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backupServiceProvider.overrideWithValue(_ThrowingBackupService()),
          // 실패 시 databaseProvider가 무효화되므로, 실제 DB를 열러 가지
          // 않도록 설정 프로바이더를 고정한다.
          settingsProvider.overrideWith(() => _FixedSettingsNotifier()),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('백업 가져오기'));
    await tester.pumpAndSettle();
    // 덮어쓰기 경고를 확인해야 실제 가져오기가 돈다.
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('가져오기'));
    await tester.pumpAndSettle();

    expect(find.text('백업 가져오기에 실패했습니다. 앱을 다시 실행해 주세요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed import drops the cached database handle', (
    tester,
  ) async {
    // 실패 경로에서도 databaseProvider를 무효화하지 않으면, 이미 닫힌 DB
    // 핸들을 든 프로바이더들이 재시작 전까지 전부 깨진 채로 남는다.
    var databaseBuilds = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backupServiceProvider.overrideWithValue(_ThrowingBackupService()),
          databaseProvider.overrideWith((ref) async {
            databaseBuilds++;
            return AppDatabase.openForTest();
          }),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    container.read(databaseProvider);
    expect(databaseBuilds, 1);

    await tester.tap(find.text('백업 가져오기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('가져오기'));
    await tester.pumpAndSettle();

    container.read(databaseProvider);
    expect(databaseBuilds, 2);
  });

  testWidgets(
    'rapid double-tap on 백업 내보내기 only triggers export once, and the tile re-enables after it settles',
    (tester) async {
      final completer = Completer<void>();
      final fake = _CompleterBackupService(completer);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            backupServiceProvider.overrideWithValue(fake),
            settingsProvider.overrideWith(_FixedSettingsNotifier.new),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('백업 내보내기'));
      await tester.pump();

      ListTile exportTile() => tester.widget<ListTile>(
        find.ancestor(
          of: find.text('백업 내보내기'),
          matching: find.byType(ListTile),
        ),
      );
      expect(exportTile().enabled, isFalse);

      // 첫 탭의 export()가 아직 completer를 기다리는 동안 다시 탭해도 no-op.
      await tester.tap(find.text('백업 내보내기'), warnIfMissed: false);
      await tester.pump();

      expect(fake.exportCallCount, 1);

      completer.complete();
      await tester.pumpAndSettle();

      expect(exportTile().enabled, isTrue);
    },
  );

  testWidgets('tapping 데이터 초기화 → 초기화 calls resetProgress and closes dialog', (
    tester,
  ) async {
    final notifier = _RecordingSettingsNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith(() => notifier)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('데이터 초기화'));
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('초기화'));
    await tester.pumpAndSettle();

    expect(notifier.resetProgressCallCount, 1);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
