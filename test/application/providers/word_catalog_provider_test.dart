import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jlpt/core/db/database.dart';
import 'package:jlpt/application/providers/database_provider.dart';
import 'package:jlpt/application/providers/word_catalog_provider.dart';
import 'package:jlpt/domain/models/word.dart';
import 'package:jlpt/domain/repositories/settings_repository.dart';

void main() {
  // rootBundle 에셋 로딩에 바인딩이 필요하다.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('seeds from asset when data_version is stale and records version', () async {
    final db = await AppDatabase.openForTest();
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) async => db),
    ]);
    addTearDown(container.dispose);
    final words = await container.read(wordCatalogProvider.future);
    expect(words.length, greaterThan(1000));
    expect(words.every((w) => w.id.startsWith('n2_')), isTrue);
    expect(await SettingsRepository(db).dataVersion(), AppDatabase.kDataVersion);
    await db.close();
  });

  test('addUserWord inserts and updates state', () async {
    final db = await AppDatabase.openForTest();
    await SettingsRepository(db).setDataVersion(AppDatabase.kDataVersion); // 시딩 스킵
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) async => db),
    ]);
    addTearDown(container.dispose);
    await container.read(wordCatalogProvider.future);
    await container.read(wordCatalogProvider.notifier).addUserWord(
          const Word(
            id: 'user_1',
            expression: '把握',
            reading: 'はあく',
            meaningKo: '파악',
            source: 'user',
          ),
        );
    final words = await container.read(wordCatalogProvider.future);
    expect(words.map((w) => w.id), contains('user_1'));
    await db.close();
  });
}
