import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jlpt/core/db/database.dart';
import 'package:jlpt/application/providers/database_provider.dart';
import 'package:jlpt/application/providers/progress_summary_provider.dart';
import 'package:jlpt/application/providers/today_study_set_provider.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:jlpt/domain/models/error_tag.dart';
import 'package:jlpt/domain/models/today_study_set.dart';
import 'package:jlpt/domain/models/word.dart';
import 'package:jlpt/domain/repositories/progress_repository.dart';
import 'package:jlpt/domain/repositories/settings_repository.dart';
import 'package:jlpt/domain/repositories/study_set_repository.dart';
import 'package:jlpt/domain/repositories/word_repository.dart';
import 'package:jlpt/features/explore/explore_provider.dart';
import 'package:jlpt/features/stats/stats_provider.dart';

void main() {
  // wordCatalogProvider가 rootBundle을 건드릴 수 있어 바인딩이 필요하다.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<(Database, ProviderContainer)> setup({
    int dailyTarget = 5,
    TodayStudySetNotifier Function()? notifier,
  }) async {
    final db = await AppDatabase.openForTest();
    await SettingsRepository(db).setDataVersion(AppDatabase.kDataVersion);
    await WordRepository(db).insertAll([
      for (var i = 0; i < 12; i++)
        Word(id: 'n2_${i.toString().padLeft(4, '0')}', expression: '語$i', reading: 'ご$i', meaningKo: 'x', type: WordType.on),
    ]);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) async => db),
      progressSummaryProvider.overrideWith((ref) async => ProgressSummary(
            completedCount: 0, totalCount: 12, daysUntilExam: 10, dailyTarget: dailyTarget, weakCount: 0,
          )),
      if (notifier != null) todayStudySetProvider.overrideWith(notifier),
    ]);
    addTearDown(container.dispose);
    return (db, container);
  }

  test('returns null on fresh DB', () async {
    final (db, c) = await setup();
    expect(await c.read(todayStudySetProvider.future), isNull);
    await db.close();
  });

  test('createTodaySet picks dailyTarget items with status quiz', () async {
    final (db, c) = await setup();
    final set = await c.read(todayStudySetProvider.notifier).createTodaySet();
    expect(set.items.length, 5);
    expect(set.targetCount, 5);
    expect(set.status, StudyStage.quiz);
    await db.close();
  });

  test('updateItemResult wrong: attempts+1, miss_count+1, miss_log row', () async {
    final (db, c) = await setup();
    final n = c.read(todayStudySetProvider.notifier);
    final set = await n.createTodaySet();
    final id = set.items.first.wordId;
    await n.updateItemResult(id, passed: false, tag: ErrorTag.sokuon);
    final after = c.read(todayStudySetProvider).valueOrNull!;
    expect(after.items.first.passed, isFalse);
    expect(after.items.first.attempts, 1);
    expect((await ProgressRepository(db).get(id))!.missCount, 1);
    expect((await db.query('miss_log')).single['tag'], 'sokuon');
    await n.updateItemResult(id, passed: true);
    expect(c.read(todayStudySetProvider).valueOrNull!.items.first.passed, isTrue);
    await db.close();
  });

  test('finish marks passed words completed and status completed', () async {
    final (db, c) = await setup();
    final n = c.read(todayStudySetProvider.notifier);
    final set = await n.createTodaySet();
    for (final item in set.items) {
      await n.updateItemResult(item.wordId, passed: true);
    }
    await n.finish();
    expect(c.read(todayStudySetProvider).valueOrNull!.status, StudyStage.completed);
    expect(await ProgressRepository(db).countCompleted(), 5);
    await db.close();
  });

  test('finish refreshes 탐색·통계 so completion is not stale', () async {
    final (db, c) = await setup();
    // 세션 전: 완료 단어 없음.
    expect((await c.read(exploreProvider.future)).completedWordIds, isEmpty);
    expect((await c.read(statsProvider.future)).completed, 0);

    final n = c.read(todayStudySetProvider.notifier);
    final set = await n.createTodaySet();
    for (final item in set.items) {
      await n.updateItemResult(item.wordId, passed: true);
    }
    await n.finish();

    expect(
      (await c.read(exploreProvider.future)).completedWordIds,
      set.items.map((i) => i.wordId).toSet(),
    );
    expect((await c.read(statsProvider.future)).completed, set.items.length);
    await db.close();
  });

  test('appendNextSet keeps existing items and adds new ones', () async {
    final (db, c) = await setup();
    final n = c.read(todayStudySetProvider.notifier);
    final first = await n.createTodaySet();
    for (final item in first.items) {
      await n.updateItemResult(item.wordId, passed: true);
    }
    await n.finish();
    final second = await n.appendNextSet();
    expect(second.items.length, 10);
    expect(second.items.take(5).every((i) => i.passed), isTrue);
    expect(second.items.skip(5).every((i) => !i.passed), isTrue);
    expect(second.status, StudyStage.quiz);
    expect(second.items.map((i) => i.wordId).toSet().length, 10);
    expect(second.completedAt, isNull);
    final reloaded = await StudySetRepository(db).getByDate(second.studyDate);
    expect(reloaded!.status, StudyStage.quiz);
    expect(reloaded.completedAt, isNull);
    await db.close();
  });

  test('appendNextSet stamps appended items with the set date, not today', () async {
    // 자정을 넘겨 "어제" 세트가 state에 남아 있는 상황. 새 항목이 오늘 날짜로
    // 찍히면 부모 row(어제)와 어긋나 고아 항목이 된다.
    const setDate = '2026-09-19';
    final (db, c) = await setup(
      dailyTarget: 3,
      notifier: () => _FixedDateStudySetNotifier(setDate),
    );
    final createdAt = DateTime(2026, 9, 19, 23, 58);
    await StudySetRepository(db).createSet(TodayStudySet(
      studyDate: setDate,
      targetCount: 1,
      status: StudyStage.completed,
      items: [
        TodayStudyItem(
          studyDate: setDate,
          wordId: 'n2_0000',
          displayOrder: 0,
          passed: true,
          attempts: 1,
          updatedAt: createdAt,
        ),
      ],
      createdAt: createdAt,
      updatedAt: createdAt,
    ));

    final updated = await c.read(todayStudySetProvider.notifier).appendNextSet();

    expect(updated.studyDate, setDate);
    expect(updated.items.every((i) => i.studyDate == setDate), isTrue);
    final rows = await db.query('daily_study_set_items');
    expect(rows.length, updated.items.length);
    expect(rows.every((r) => r['study_date'] == setDate), isTrue);
    // 부모 row도 같은 날짜에서 target_count가 올라가야 한다.
    final reloaded = await StudySetRepository(db).getByDate(setDate);
    expect(reloaded!.items.length, updated.items.length);
    expect(reloaded.targetCount, updated.items.length);
    await db.close();
  });

  test('createTodaySet appends weak words on top of dailyTarget new words', () async {
    final (db, c) = await setup();
    final progressRepo = ProgressRepository(db);
    final weakIds = ['n2_0009', 'n2_0010', 'n2_0011'];
    for (final id in weakIds) {
      await progressRepo.markCompleted(id);
      await progressRepo.incrementMiss(id);
    }
    final set = await c.read(todayStudySetProvider.notifier).createTodaySet();
    expect(set.items.length, 8);
    expect(set.targetCount, set.items.length);
    final ids = set.items.map((i) => i.wordId).toList();
    expect(ids.toSet().length, 8);
    expect(ids.where(weakIds.contains).length, 3);
    await db.close();
  });
}

/// build()가 오늘이 아니라 고정된 [date]의 세트를 읽어오는 notifier —
/// 자정을 넘겨 어제 세트가 state에 남아 있는 상황을 재현한다.
class _FixedDateStudySetNotifier extends TodayStudySetNotifier {
  _FixedDateStudySetNotifier(this.date);

  final String date;

  @override
  Future<TodayStudySet?> build() async {
    final db = await ref.watch(databaseProvider.future);
    return StudySetRepository(db).getByDate(date);
  }
}
