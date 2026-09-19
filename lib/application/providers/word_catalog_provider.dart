import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/database.dart';
import '../../domain/models/word.dart';
import '../../domain/repositories/word_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import 'database_provider.dart';

final wordCatalogProvider =
    AsyncNotifierProvider<WordCatalogNotifier, List<Word>>(
  WordCatalogNotifier.new,
);

class WordCatalogNotifier extends AsyncNotifier<List<Word>> {
  @override
  Future<List<Word>> build() async {
    final db = await ref.watch(databaseProvider.future);
    final wordRepo = WordRepository(db);
    final settingsRepo = SettingsRepository(db);

    if (await settingsRepo.dataVersion() < AppDatabase.kDataVersion) {
      await _seedFromAssets(wordRepo, settingsRepo);
    }
    return wordRepo.getAll();
  }

  Future<void> _seedFromAssets(
    WordRepository wordRepo,
    SettingsRepository settingsRepo,
  ) async {
    final json = await rootBundle.loadString('assets/data/n2_words.json');
    final words = (jsonDecode(json) as List)
        .map((e) => Word.fromAssetJson(e as Map<String, dynamic>))
        .toList();
    await wordRepo.upsertAll(words);
    await wordRepo.deleteN2NotIn(words.map((w) => w.id).toSet());
    await settingsRepo.setDataVersion(AppDatabase.kDataVersion);
  }

  Word? wordById(String id) {
    final list = state.valueOrNull;
    if (list == null) return null;
    for (final w in list) {
      if (w.id == id) return w;
    }
    return null;
  }

  Future<void> addUserWord(Word word) async {
    final db = await ref.read(databaseProvider.future);
    await WordRepository(db).insertUserWord(word);
    final current = state.valueOrNull ?? [];
    state = AsyncData([...current, word]);
  }
}
