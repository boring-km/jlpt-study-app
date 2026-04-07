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
    final current = state.valueOrNull ?? AppSettings.defaults;
    state = AsyncData(AppSettings(
      examDate: date,
      themeMode: current.themeMode,
      seededAt: current.seededAt,
    ));
  }

  Future<void> updateThemeMode(AppThemeMode mode) async {
    final db = await ref.read(databaseProvider.future);
    await SettingsRepository(db).saveThemeMode(mode);
    final current = state.valueOrNull ?? AppSettings.defaults;
    state = AsyncData(AppSettings(
      examDate: current.examDate,
      themeMode: mode,
      seededAt: current.seededAt,
    ));
  }
}
