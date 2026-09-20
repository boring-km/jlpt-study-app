import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/application/providers/database_provider.dart';
import 'package:jlpt/application/providers/word_catalog_provider.dart';
import 'package:jlpt/core/db/database.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:jlpt/domain/models/word.dart';
import 'package:jlpt/domain/repositories/progress_repository.dart';
import 'package:jlpt/domain/repositories/settings_repository.dart';
import 'package:jlpt/domain/repositories/word_repository.dart';
import 'package:jlpt/features/explore/explore_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// n2 2개 + 사용자 단어 2개. 'さん'은 n2_0001(せいさん)과 user_1(さんぎょう)에
/// 걸리므로 검색과 출처 필터를 겹쳐 확인할 수 있다.
const _words = [
  Word(
    id: 'n2_0001',
    expression: '生産',
    reading: 'せいさん',
    meaningKo: '생산',
    type: WordType.on,
  ),
  Word(
    id: 'n2_0002',
    expression: '把握',
    reading: 'はあく',
    meaningKo: '파악',
    type: WordType.on,
  ),
  Word(
    id: 'user_1',
    expression: '産業',
    reading: 'さんぎょう',
    meaningKo: '산업',
    type: WordType.on,
    source: 'user',
  ),
  Word(
    id: 'user_2',
    expression: 'コーヒー',
    reading: 'コーヒー',
    meaningKo: '커피',
    type: WordType.katakana,
    source: 'user',
  ),
];

void main() {
  // wordCatalogProvider가 rootBundle을 건드릴 수 있어 바인딩이 필요하다.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  /// 시딩을 건너뛴 DB에 [_words]를 넣고 n2 1개 + 사용자 1개를 완료로 표시.
  Future<ProviderContainer> setup() async {
    final db = await AppDatabase.openForTest();
    await SettingsRepository(db).setDataVersion(AppDatabase.kDataVersion);
    await WordRepository(db).insertAll(_words);
    final progress = ProgressRepository(db);
    await progress.markCompleted('n2_0001');
    await progress.markCompleted('user_1');

    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) async => db),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);
    await container.read(exploreProvider.future);
    return container;
  }

  Future<List<String>> idsAfter(
    ProviderContainer container,
    ExploreFilter filter,
  ) async {
    await container.read(exploreProvider.notifier).updateFilter(filter);
    return (container.read(exploreProvider).value!.results)
        .map((w) => w.id)
        .toList();
  }

  test('starts with the whole catalog and the completed ids', () async {
    final container = await setup();
    final state = container.read(exploreProvider).value!;
    expect(state.results, hasLength(4));
    expect(state.completedWordIds, {'n2_0001', 'user_1'});
    expect(state.isLoading, isFalse);
  });

  test('query alone goes through search', () async {
    final container = await setup();
    expect(
      await idsAfter(container, const ExploreFilter(query: 'さん')),
      ['n2_0001', 'user_1'],
    );
    expect(
      await idsAfter(container, const ExploreFilter(query: '커피')),
      ['user_2'],
    );
  });

  test('source filter alone keeps only user words', () async {
    final container = await setup();
    expect(
      await idsAfter(container, const ExploreFilter(sourceFilter: 'user')),
      ['user_1', 'user_2'],
    );
  });

  test('completed filter alone keeps only completed words', () async {
    final container = await setup();
    expect(
      await idsAfter(container, const ExploreFilter(completedFilter: true)),
      ['n2_0001', 'user_1'],
    );
  });

  test('source and completed filters combine', () async {
    final container = await setup();
    expect(
      await idsAfter(
        container,
        const ExploreFilter(sourceFilter: 'user', completedFilter: false),
      ),
      ['user_2'],
    );
  });

  test('query and source filter combine', () async {
    final container = await setup();
    expect(
      await idsAfter(
        container,
        const ExploreFilter(query: 'さん', sourceFilter: 'user'),
      ),
      ['user_1'],
    );
  });

  test('keeps the filter when the catalog changes and shows the new word',
      () async {
    final container = await setup();
    // '추가한 단어' 칩을 켠 상태에서 단어를 추가하면, 목록이 전체로
    // 되돌아가지 않고 필터가 유지된 채 새 단어가 보여야 한다.
    await container
        .read(exploreProvider.notifier)
        .updateFilter(const ExploreFilter(sourceFilter: 'user'));

    await container.read(wordCatalogProvider.notifier).addUserWord(
          const Word(
            id: 'user_3',
            expression: '新語',
            reading: 'しんご',
            meaningKo: '신어',
            type: WordType.on,
          ),
        );

    final state = await container.read(exploreProvider.future);
    expect(state.filter.sourceFilter, 'user');
    expect(state.results.map((w) => w.id), ['user_1', 'user_2', 'user_3']);
  });

  test('clearing the filters restores the whole catalog', () async {
    final container = await setup();
    await idsAfter(container, const ExploreFilter(sourceFilter: 'user'));
    expect(
      await idsAfter(container, const ExploreFilter()),
      ['n2_0001', 'n2_0002', 'user_1', 'user_2'],
    );
  });
}
