import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/features/settings/settings_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
}
