import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'application/providers/settings_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'domain/models/app_settings.dart';

void main() {
  runApp(const ProviderScope(child: JlptApp()));
}

class JlptApp extends ConsumerWidget {
  const JlptApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final themeMode = settingsAsync.valueOrNull?.themeMode ?? AppThemeMode.system;

    return MaterialApp.router(
      title: 'JLPT',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (themeMode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.system => ThemeMode.system,
      },
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
    );
  }
}
