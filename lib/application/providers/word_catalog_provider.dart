import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/word.dart';
import '../../domain/models/enums.dart';
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

    final seeded = await settingsRepo.isSeeded();
    if (!seeded) {
      await _seedFromAssets(wordRepo, settingsRepo);
    }
    return wordRepo.getAll();
  }

  Future<void> _seedFromAssets(
    WordRepository wordRepo,
    SettingsRepository settingsRepo,
  ) async {
    final n3Json = await rootBundle.loadString('assets/data/n3_words.json');
    final n2Json = await rootBundle.loadString('assets/data/n2_words.json');

    final n3List = (jsonDecode(n3Json) as List)
        .map((e) => Word.fromAssetJson(e as Map<String, dynamic>, JlptLevel.n3))
        .toList();
    final n2List = (jsonDecode(n2Json) as List)
        .map((e) => Word.fromAssetJson(e as Map<String, dynamic>, JlptLevel.n2))
        .toList();

    await wordRepo.insertAll([...n3List, ...n2List]);
    await settingsRepo.markSeeded();
  }
}
