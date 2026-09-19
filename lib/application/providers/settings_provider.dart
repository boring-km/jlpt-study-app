import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import 'database_provider.dart';

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final db = await ref.watch(databaseProvider.future);
    return SettingsRepository(db).load();
  }

  Future<void> updateExamDate(DateTime date) async {
    final db = await ref.read(databaseProvider.future);
    await SettingsRepository(db).saveExamDate(date);
    state = AsyncData(
      (state.valueOrNull ?? AppSettings.defaults).copyWith(examDate: date),
    );
  }

  Future<void> updateThemeMode(AppThemeMode mode) async {
    final db = await ref.read(databaseProvider.future);
    await SettingsRepository(db).saveThemeMode(mode);
    state = AsyncData(
      (state.valueOrNull ?? AppSettings.defaults).copyWith(themeMode: mode),
    );
  }
}
