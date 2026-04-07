# Explore / Stats / Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 탐색(단어 리스트 + 플래시카드 브라우저), 통계, 히라가나/가타카나 표, 설정 화면을 구현한다.

**Architecture:** study-flow 플랜이 완료된 상태를 전제로 한다. 탐색은 모드 선택 후 단어 리스트 또는 플래시카드 브라우저로 분기한다. 통계는 DB 집계 쿼리로 계산한다.

**Tech Stack:** Flutter, Riverpod 2.x, sqflite

**전제 조건:** `docs/superpowers/plans/2026-04-07-study-flow.md` 완료

---

## File Structure

```
lib/
  features/
    explore/
      explore_screen.dart           # 탐색 모드 선택 화면
      word_list_screen.dart         # 단어 리스트 (검색/필터)
      explore_flashcard_screen.dart # 플래시카드 브라우저
      explore_provider.dart         # 검색/필터 상태
    stats/
      stats_screen.dart             # 통계 화면
      stats_provider.dart           # 통계 데이터 Provider
    kana/
      kana_screen.dart              # 히라가나/가타카나 표
    settings/
      settings_screen.dart          # 설정 화면
  core/
    router/
      app_router.dart               # 탐색/통계/설정 플레이스홀더 교체
```

---

### Task 1: 탐색 — 모드 선택 + 단어 리스트

**Files:**
- Create: `lib/features/explore/explore_provider.dart`
- Create: `lib/features/explore/explore_screen.dart`
- Create: `lib/features/explore/word_list_screen.dart`
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: explore_provider.dart 작성**

```dart
// lib/features/explore/explore_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/word.dart';
import '../../domain/models/enums.dart';
import '../../domain/repositories/word_repository.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../application/providers/database_provider.dart';
import '../../application/providers/word_catalog_provider.dart';

class ExploreFilter {
  final String query;
  final JlptLevel? levelFilter; // null = 전체
  final bool? completedFilter; // null = 전체, true = 완료, false = 미완료

  const ExploreFilter({
    this.query = '',
    this.levelFilter,
    this.completedFilter,
  });

  ExploreFilter copyWith({
    String? query,
    Object? levelFilter = _sentinel,
    Object? completedFilter = _sentinel,
  }) =>
      ExploreFilter(
        query: query ?? this.query,
        levelFilter: levelFilter == _sentinel
            ? this.levelFilter
            : levelFilter as JlptLevel?,
        completedFilter: completedFilter == _sentinel
            ? this.completedFilter
            : completedFilter as bool?,
      );
}

const _sentinel = Object();

class ExploreState {
  final ExploreFilter filter;
  final List<Word> results;
  final Set<String> completedWordIds;
  final bool isLoading;

  const ExploreState({
    required this.filter,
    required this.results,
    required this.completedWordIds,
    required this.isLoading,
  });

  ExploreState copyWith({
    ExploreFilter? filter,
    List<Word>? results,
    Set<String>? completedWordIds,
    bool? isLoading,
  }) =>
      ExploreState(
        filter: filter ?? this.filter,
        results: results ?? this.results,
        completedWordIds: completedWordIds ?? this.completedWordIds,
        isLoading: isLoading ?? this.isLoading,
      );
}

final exploreProvider =
    AsyncNotifierProvider<ExploreNotifier, ExploreState>(ExploreNotifier.new);

class ExploreNotifier extends AsyncNotifier<ExploreState> {
  @override
  Future<ExploreState> build() async {
    final db = await ref.watch(databaseProvider.future);
    final catalog = await ref.watch(wordCatalogProvider.future);
    final progressRepo = ProgressRepository(db);
    final n3Ids = (await progressRepo.getCompletedWordIds(JlptLevel.n3)).toSet();
    final n2Ids = (await progressRepo.getCompletedWordIds(JlptLevel.n2)).toSet();
    final completedIds = {...n3Ids, ...n2Ids};

    return ExploreState(
      filter: const ExploreFilter(),
      results: catalog,
      completedWordIds: completedIds,
      isLoading: false,
    );
  }

  Future<void> updateFilter(ExploreFilter filter) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(isLoading: true, filter: filter));

    final db = await ref.read(databaseProvider.future);
    final wordRepo = WordRepository(db);

    List<Word> results;
    if (filter.query.isNotEmpty) {
      results = await wordRepo.search(filter.query);
    } else {
      results = filter.levelFilter != null
          ? await wordRepo.getByLevel(filter.levelFilter!)
          : await wordRepo.getAll();
    }

    // 레벨 필터 (검색 쿼리 있을 때도 적용)
    if (filter.levelFilter != null && filter.query.isNotEmpty) {
      results = results
          .where((w) => w.jlptLevel == filter.levelFilter)
          .toList();
    }

    // 완료/미완료 필터
    if (filter.completedFilter != null) {
      results = results.where((w) {
        final isCompleted = current.completedWordIds.contains(w.id);
        return filter.completedFilter! ? isCompleted : !isCompleted;
      }).toList();
    }

    state = AsyncData(
      current.copyWith(
        filter: filter,
        results: results,
        isLoading: false,
      ),
    );
  }
}
```

- [ ] **Step 2: explore_screen.dart 작성 (모드 선택)**

```dart
// lib/features/explore/explore_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('탐색')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ModeCard(
              title: '단어 리스트',
              subtitle: '검색·필터로 단어 찾기',
              icon: Icons.list_alt_outlined,
              onTap: () => context.push('/explore/list'),
            ),
            const SizedBox(height: 16),
            _ModeCard(
              title: '플래시카드',
              subtitle: '카드 넘기며 단어 보기',
              icon: Icons.style_outlined,
              onTap: () => context.push('/explore/flashcard'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Icon(icon, size: 32, color: AppColors.primary),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondaryLight)),
                ],
              ),
              const Spacer(),
              const Icon(Icons.chevron_right, color: AppColors.textSecondaryLight),
            ],
          ),
        ),
      );
}
```

- [ ] **Step 3: word_list_screen.dart 작성**

```dart
// lib/features/explore/word_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/word.dart';
import '../../domain/models/enums.dart';
import '../../widgets/word_badge.dart';
import 'explore_provider.dart';

class WordListScreen extends ConsumerStatefulWidget {
  const WordListScreen({super.key});

  @override
  ConsumerState<WordListScreen> createState() => _WordListScreenState();
}

class _WordListScreenState extends ConsumerState<WordListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final current = ref.read(exploreProvider).valueOrNull?.filter ??
        const ExploreFilter();
    ref.read(exploreProvider.notifier).updateFilter(current.copyWith(query: query));
  }

  void _onLevelFilter(JlptLevel? level) {
    final current = ref.read(exploreProvider).valueOrNull?.filter ??
        const ExploreFilter();
    ref
        .read(exploreProvider.notifier)
        .updateFilter(current.copyWith(levelFilter: level));
  }

  void _onCompletedFilter(bool? completed) {
    final current = ref.read(exploreProvider).valueOrNull?.filter ??
        const ExploreFilter();
    ref
        .read(exploreProvider.notifier)
        .updateFilter(current.copyWith(completedFilter: completed));
  }

  @override
  Widget build(BuildContext context) {
    final exploreAsync = ref.watch(exploreProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('단어 리스트')),
      body: Column(
        children: [
          // 검색 바
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: '한자 · 히라가나 · 한국어로 검색',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                filled: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 필터 칩
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: exploreAsync.when(
              data: (state) => Row(
                children: [
                  _FilterChip(
                    label: '전체',
                    selected: state.filter.levelFilter == null,
                    onTap: () => _onLevelFilter(null),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'N3',
                    selected: state.filter.levelFilter == JlptLevel.n3,
                    onTap: () => _onLevelFilter(JlptLevel.n3),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'N2',
                    selected: state.filter.levelFilter == JlptLevel.n2,
                    onTap: () => _onLevelFilter(JlptLevel.n2),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: '완료',
                    selected: state.filter.completedFilter == true,
                    onTap: () => _onCompletedFilter(
                        state.filter.completedFilter == true ? null : true),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: '미완료',
                    selected: state.filter.completedFilter == false,
                    onTap: () => _onCompletedFilter(
                        state.filter.completedFilter == false ? null : false),
                  ),
                ],
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 8),

          // 단어 목록
          Expanded(
            child: exploreAsync.when(
              data: (state) => state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: state.results.length,
                      itemBuilder: (context, index) {
                        final word = state.results[index];
                        final isCompleted =
                            state.completedWordIds.contains(word.id);
                        return _WordTile(
                          word: word,
                          isCompleted: isCompleted,
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('오류: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.borderLight,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: selected ? Colors.white : AppColors.textPrimaryLight,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      );
}

class _WordTile extends StatefulWidget {
  final Word word;
  final bool isCompleted;

  const _WordTile({required this.word, required this.isCompleted});

  @override
  State<_WordTile> createState() => _WordTileState();
}

class _WordTileState extends State<_WordTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  widget.word.expression.isNotEmpty
                      ? widget.word.expression
                      : widget.word.reading,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.word.reading,
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondaryLight),
                ),
                const Spacer(),
                WordBadge(level: widget.word.jlptLevel),
                if (widget.isCompleted) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.check_circle,
                      size: 16, color: AppColors.success),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(widget.word.meaningKo,
                style: TextStyle(
                    fontSize: 14, color: AppColors.textSecondaryLight)),
            if (_expanded && widget.word.example != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(widget.word.example!.ja,
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
              Text(widget.word.example!.reading,
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondaryLight)),
              const SizedBox(height: 2),
              Text(widget.word.example!.ko,
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondaryLight)),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: app_router.dart 탐색 브랜치 교체**

```dart
import '../../features/explore/explore_screen.dart';
import '../../features/explore/word_list_screen.dart';

// /explore branch
StatefulShellBranch(routes: [
  GoRoute(
    path: '/explore',
    builder: (_, __) => const ExploreScreen(),
    routes: [
      GoRoute(
        path: 'list',
        builder: (_, __) => const WordListScreen(),
      ),
      GoRoute(
        path: 'flashcard',
        builder: (_, __) => const _PlaceholderScreen('플래시카드 브라우저'),
      ),
    ],
  ),
]),
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/explore/ lib/core/router/app_router.dart
git commit -m "feat: add explore mode select and word list screen"
```

---

### Task 2: 탐색 — 플래시카드 브라우저

**Files:**
- Create: `lib/features/explore/explore_flashcard_screen.dart`
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: explore_flashcard_screen.dart 작성**

```dart
// lib/features/explore/explore_flashcard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/word.dart';
import '../../domain/models/enums.dart';
import '../../widgets/flip_card.dart';
import '../../widgets/word_badge.dart';
import 'explore_provider.dart';

class ExploreFlashcardScreen extends ConsumerStatefulWidget {
  const ExploreFlashcardScreen({super.key});

  @override
  ConsumerState<ExploreFlashcardScreen> createState() =>
      _ExploreFlashcardScreenState();
}

class _ExploreFlashcardScreenState
    extends ConsumerState<ExploreFlashcardScreen> {
  int _currentIndex = 0;
  bool _isFlipped = false;
  JlptLevel? _levelFilter;
  bool? _completedFilter;

  List<Word> _getFilteredWords(ExploreState state) {
    var words = state.results;
    if (_levelFilter != null) {
      words = words.where((w) => w.jlptLevel == _levelFilter).toList();
    }
    if (_completedFilter != null) {
      words = words.where((w) {
        final isCompleted = state.completedWordIds.contains(w.id);
        return _completedFilter! ? isCompleted : !isCompleted;
      }).toList();
    }
    return words;
  }

  @override
  Widget build(BuildContext context) {
    final exploreAsync = ref.watch(exploreProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('플래시카드 브라우저'),
        actions: [
          // 필터 버튼
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _currentIndex = 0;
                _isFlipped = false;
                switch (value) {
                  case 'all':
                    _levelFilter = null;
                    _completedFilter = null;
                  case 'n3':
                    _levelFilter = JlptLevel.n3;
                  case 'n2':
                    _levelFilter = JlptLevel.n2;
                  case 'completed':
                    _completedFilter = true;
                  case 'uncompleted':
                    _completedFilter = false;
                }
              });
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'all', child: Text('전체')),
              PopupMenuItem(value: 'n3', child: Text('N3')),
              PopupMenuItem(value: 'n2', child: Text('N2')),
              PopupMenuItem(value: 'completed', child: Text('완료')),
              PopupMenuItem(value: 'uncompleted', child: Text('미완료')),
            ],
          ),
        ],
      ),
      body: exploreAsync.when(
        data: (state) {
          final words = _getFilteredWords(state);
          if (words.isEmpty) {
            return const Center(child: Text('단어 없음'));
          }
          if (_currentIndex >= words.length) {
            _currentIndex = 0;
          }
          final word = words[_currentIndex];

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // 진도 + 뱃지
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${_currentIndex + 1} / ${words.length}',
                        style: Theme.of(context).textTheme.bodyMedium),
                    WordBadge(level: word.jlptLevel),
                  ],
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: FlipCard(
                    isFlipped: _isFlipped,
                    onTap: () => setState(() => _isFlipped = !_isFlipped),
                    front: _CardFace(
                      child: Center(
                        child: Text(
                          word.expression.isNotEmpty
                              ? word.expression
                              : word.reading,
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    back: _CardFace(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              word.reading,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(word.meaningKo,
                                style: const TextStyle(fontSize: 20),
                                textAlign: TextAlign.center),
                            if (word.example != null) ...[
                              const SizedBox(height: 24),
                              const Divider(),
                              const SizedBox(height: 12),
                              Text(word.example!.ja,
                                  style: const TextStyle(fontSize: 14),
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 4),
                              Text(word.example!.ko,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondaryLight),
                                  textAlign: TextAlign.center),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: _currentIndex > 0
                          ? () => setState(() {
                                _currentIndex--;
                                _isFlipped = false;
                              })
                          : null,
                      icon: const Icon(Icons.arrow_back_ios),
                    ),
                    IconButton(
                      onPressed: _currentIndex < words.length - 1
                          ? () => setState(() {
                                _currentIndex++;
                                _isFlipped = false;
                              })
                          : null,
                      icon: const Icon(Icons.arrow_forward_ios),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  final Widget child;
  const _CardFace({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );
}
```

- [ ] **Step 2: app_router.dart explore/flashcard 플레이스홀더 교체**

```dart
import '../../features/explore/explore_flashcard_screen.dart';

GoRoute(
  path: 'flashcard',
  builder: (_, __) => const ExploreFlashcardScreen(),
),
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/explore/explore_flashcard_screen.dart lib/core/router/app_router.dart
git commit -m "feat: add explore flashcard browser"
```

---

### Task 3: 통계 화면

**Files:**
- Create: `lib/features/stats/stats_provider.dart`
- Create: `lib/features/stats/stats_screen.dart`
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: stats_provider.dart 작성**

```dart
// lib/features/stats/stats_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../application/providers/database_provider.dart';
import '../../domain/repositories/study_set_repository.dart';

class DailyStudyCount {
  final String date;
  final int count;
  const DailyStudyCount({required this.date, required this.count});
}

class StatsOverview {
  final List<DailyStudyCount> dailyCounts; // 최근 14일
  final int currentStreak;
  final int totalCompleted;

  const StatsOverview({
    required this.dailyCounts,
    required this.currentStreak,
    required this.totalCompleted,
  });
}

final statsProvider = FutureProvider<StatsOverview>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final studyRepo = StudySetRepository(db);

  final streak = await studyRepo.currentStreak();
  final dailyCounts = await _getDailyCounts(db);
  final total = await _getTotalCompleted(db);

  return StatsOverview(
    dailyCounts: dailyCounts,
    currentStreak: streak,
    totalCompleted: total,
  );
});

Future<List<DailyStudyCount>> _getDailyCounts(Database db) async {
  final rows = await db.rawQuery('''
    SELECT study_date,
           COUNT(CASE WHEN reading_passed = 1 AND meaning_passed = 1 THEN 1 END) as cnt
    FROM daily_study_set_items
    GROUP BY study_date
    ORDER BY study_date DESC
    LIMIT 14
  ''');
  return rows
      .map((r) => DailyStudyCount(
            date: r['study_date'] as String,
            count: (r['cnt'] as int?) ?? 0,
          ))
      .toList()
      .reversed
      .toList();
}

Future<int> _getTotalCompleted(Database db) async {
  final result =
      await db.rawQuery('SELECT COUNT(*) as c FROM word_progress WHERE is_completed = 1');
  return result.first['c'] as int;
}
```

- [ ] **Step 2: stats_screen.dart 작성**

```dart
// lib/features/stats/stats_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../application/providers/progress_summary_provider.dart';
import 'stats_provider.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);
    final summaryAsync = ref.watch(progressSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('통계')),
      body: statsAsync.when(
        data: (stats) => summaryAsync.when(
          data: (summary) => _StatsBody(stats: stats, summary: summary),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('오류: $e')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  final StatsOverview stats;
  final ProgressSummary summary;

  const _StatsBody({required this.stats, required this.summary});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 핵심 수치
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: '연속 학습일',
                  value: '${stats.currentStreak}일',
                  icon: Icons.local_fire_department,
                  iconColor: AppColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: '총 완료 단어',
                  value: '${stats.totalCompleted}개',
                  icon: Icons.check_circle_outline,
                  iconColor: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 최근 14일 학습량 막대 그래프
          Text('최근 14일 학습량',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 18,
                  )),
          const SizedBox(height: 16),

          if (stats.dailyCounts.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('아직 학습 기록이 없습니다',
                    style: TextStyle(color: AppColors.textSecondaryLight)),
              ),
            )
          else
            _BarChart(dailyCounts: stats.dailyCounts),

          const SizedBox(height: 24),

          // 전체 진도
          Text('전체 진도',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 18,
                  )),
          const SizedBox(height: 12),
          _ProgressRow(
            label: summary.currentLevel.name.toUpperCase(),
            completed: summary.completedCount,
            total: summary.totalCount,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondaryLight)),
          ],
        ),
      );
}

class _BarChart extends StatelessWidget {
  final List<DailyStudyCount> dailyCounts;

  const _BarChart({required this.dailyCounts});

  @override
  Widget build(BuildContext context) {
    final maxCount =
        dailyCounts.map((d) => d.count).fold(0, (a, b) => a > b ? a : b);

    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: dailyCounts.map((d) {
          final ratio = maxCount > 0 ? d.count / maxCount : 0.0;
          final date = d.date.substring(5); // MM-DD
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (d.count > 0)
                    Text('${d.count}',
                        style: const TextStyle(
                            fontSize: 9, color: AppColors.textSecondaryLight)),
                  const SizedBox(height: 2),
                  Flexible(
                    child: FractionallySizedBox(
                      heightFactor: ratio < 0.05 ? 0.05 : ratio,
                      child: Container(
                        decoration: BoxDecoration(
                          color: d.count > 0
                              ? AppColors.primary
                              : AppColors.borderLight,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(date,
                      style: const TextStyle(
                          fontSize: 9, color: AppColors.textSecondaryLight)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final int completed;
  final int total;

  const _ProgressRow({
    required this.label,
    required this.completed,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? completed / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('$completed / $total',
                style:
                    TextStyle(fontSize: 13, color: AppColors.textSecondaryLight)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: AppColors.borderLight,
            valueColor:
                const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: app_router.dart 통계 브랜치 교체**

```dart
import '../../features/stats/stats_screen.dart';

StatefulShellBranch(routes: [
  GoRoute(
    path: '/stats',
    builder: (_, __) => const StatsScreen(),
  ),
]),
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/stats/ lib/core/router/app_router.dart
git commit -m "feat: add stats screen with streak, total count, 14-day bar chart"
```

---

### Task 4: 히라가나/가타카나 표

**Files:**
- Create: `lib/features/kana/kana_screen.dart`
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: kana_screen.dart 작성**

```dart
// lib/features/kana/kana_screen.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class KanaScreen extends StatefulWidget {
  const KanaScreen({super.key});

  @override
  State<KanaScreen> createState() => _KanaScreenState();
}

class _KanaScreenState extends State<KanaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('히라가나 · 가타카나'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '히라가나'),
            Tab(text: '가타카나'),
          ],
          labelColor: AppColors.primary,
          indicatorColor: AppColors.primary,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _KanaTable(type: _KanaType.hiragana),
          _KanaTable(type: _KanaType.katakana),
        ],
      ),
    );
  }
}

enum _KanaType { hiragana, katakana }

class _KanaTable extends StatelessWidget {
  final _KanaType type;
  const _KanaTable({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final data = type == _KanaType.hiragana ? _hiragana : _katakana;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Table(
        border: TableBorder.all(color: AppColors.borderLight, width: 0.5),
        defaultColumnWidth: const FlexColumnWidth(),
        children: data.map((row) {
          return TableRow(
            children: row.map((cell) {
              if (cell == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(cell[0],
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w500)),
                    Text(cell[1],
                        style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondaryLight)),
                  ],
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}

// 히라가나 50음도 [문자, 로마자] 형태
const _hiragana = [
  [
    ['あ', 'a'], ['い', 'i'], ['う', 'u'], ['え', 'e'], ['お', 'o'],
  ],
  [
    ['か', 'ka'], ['き', 'ki'], ['く', 'ku'], ['け', 'ke'], ['こ', 'ko'],
  ],
  [
    ['さ', 'sa'], ['し', 'shi'], ['す', 'su'], ['せ', 'se'], ['そ', 'so'],
  ],
  [
    ['た', 'ta'], ['ち', 'chi'], ['つ', 'tsu'], ['て', 'te'], ['と', 'to'],
  ],
  [
    ['な', 'na'], ['に', 'ni'], ['ぬ', 'nu'], ['ね', 'ne'], ['の', 'no'],
  ],
  [
    ['は', 'ha'], ['ひ', 'hi'], ['ふ', 'fu'], ['へ', 'he'], ['ほ', 'ho'],
  ],
  [
    ['ま', 'ma'], ['み', 'mi'], ['む', 'mu'], ['め', 'me'], ['も', 'mo'],
  ],
  [
    ['や', 'ya'], null, ['ゆ', 'yu'], null, ['よ', 'yo'],
  ],
  [
    ['ら', 'ra'], ['り', 'ri'], ['る', 'ru'], ['れ', 're'], ['ろ', 'ro'],
  ],
  [
    ['わ', 'wa'], null, null, null, ['を', 'wo'],
  ],
  [
    ['ん', 'n'], null, null, null, null,
  ],
  [
    ['が', 'ga'], ['ぎ', 'gi'], ['ぐ', 'gu'], ['げ', 'ge'], ['ご', 'go'],
  ],
  [
    ['ざ', 'za'], ['じ', 'ji'], ['ず', 'zu'], ['ぜ', 'ze'], ['ぞ', 'zo'],
  ],
  [
    ['だ', 'da'], ['ぢ', 'di'], ['づ', 'du'], ['で', 'de'], ['ど', 'do'],
  ],
  [
    ['ば', 'ba'], ['び', 'bi'], ['ぶ', 'bu'], ['べ', 'be'], ['ぼ', 'bo'],
  ],
  [
    ['ぱ', 'pa'], ['ぴ', 'pi'], ['ぷ', 'pu'], ['ぺ', 'pe'], ['ぽ', 'po'],
  ],
];

// 가타카나 50음도
const _katakana = [
  [
    ['ア', 'a'], ['イ', 'i'], ['ウ', 'u'], ['エ', 'e'], ['オ', 'o'],
  ],
  [
    ['カ', 'ka'], ['キ', 'ki'], ['ク', 'ku'], ['ケ', 'ke'], ['コ', 'ko'],
  ],
  [
    ['サ', 'sa'], ['シ', 'shi'], ['ス', 'su'], ['セ', 'se'], ['ソ', 'so'],
  ],
  [
    ['タ', 'ta'], ['チ', 'chi'], ['ツ', 'tsu'], ['テ', 'te'], ['ト', 'to'],
  ],
  [
    ['ナ', 'na'], ['ニ', 'ni'], ['ヌ', 'nu'], ['ネ', 'ne'], ['ノ', 'no'],
  ],
  [
    ['ハ', 'ha'], ['ヒ', 'hi'], ['フ', 'fu'], ['ヘ', 'he'], ['ホ', 'ho'],
  ],
  [
    ['マ', 'ma'], ['ミ', 'mi'], ['ム', 'mu'], ['メ', 'me'], ['モ', 'mo'],
  ],
  [
    ['ヤ', 'ya'], null, ['ユ', 'yu'], null, ['ヨ', 'yo'],
  ],
  [
    ['ラ', 'ra'], ['リ', 'ri'], ['ル', 'ru'], ['レ', 're'], ['ロ', 'ro'],
  ],
  [
    ['ワ', 'wa'], null, null, null, ['ヲ', 'wo'],
  ],
  [
    ['ン', 'n'], null, null, null, null,
  ],
  [
    ['ガ', 'ga'], ['ギ', 'gi'], ['グ', 'gu'], ['ゲ', 'ge'], ['ゴ', 'go'],
  ],
  [
    ['ザ', 'za'], ['ジ', 'ji'], ['ズ', 'zu'], ['ゼ', 'ze'], ['ゾ', 'zo'],
  ],
  [
    ['ダ', 'da'], ['ヂ', 'di'], ['ヅ', 'du'], ['デ', 'de'], ['ド', 'do'],
  ],
  [
    ['バ', 'ba'], ['ビ', 'bi'], ['ブ', 'bu'], ['ベ', 'be'], ['ボ', 'bo'],
  ],
  [
    ['パ', 'pa'], ['ピ', 'pi'], ['プ', 'pu'], ['ペ', 'pe'], ['ポ', 'po'],
  ],
];
```

- [ ] **Step 2: app_router.dart kana 교체**

```dart
import '../../features/kana/kana_screen.dart';

GoRoute(
  path: 'kana',
  builder: (_, __) => const KanaScreen(),
),
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/kana/ lib/core/router/app_router.dart
git commit -m "feat: add hiragana/katakana table screen"
```

---

### Task 5: 설정 화면

**Files:**
- Create: `lib/features/settings/settings_screen.dart`
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: settings_screen.dart 작성**

```dart
// lib/features/settings/settings_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/settings_provider.dart';
import '../../application/providers/progress_summary_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/app_settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final summaryAsync = ref.watch(progressSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: settingsAsync.when(
        data: (settings) => _SettingsBody(
          settings: settings,
          dailyTarget: summaryAsync.valueOrNull?.dailyTarget ?? 0,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
      ),
    );
  }
}

class _SettingsBody extends ConsumerWidget {
  final AppSettings settings;
  final int dailyTarget;

  const _SettingsBody({required this.settings, required this.dailyTarget});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      children: [
        // 시험 날짜
        ListTile(
          title: const Text('시험 날짜'),
          subtitle: Text(
            '${settings.examDate.year}.${settings.examDate.month.toString().padLeft(2, '0')}.${settings.examDate.day.toString().padLeft(2, '0')}',
            style: TextStyle(color: AppColors.primary),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: settings.examDate,
              firstDate: DateTime.now(),
              lastDate: DateTime(2030),
            );
            if (picked != null) {
              ref.read(settingsProvider.notifier).updateExamDate(picked);
              ref.invalidate(progressSummaryProvider);
            }
          },
        ),
        const Divider(height: 1),

        // 하루 학습량 (읽기 전용)
        ListTile(
          title: const Text('하루 학습량'),
          subtitle: const Text('자동 계산'),
          trailing: Text(
            '$dailyTarget개',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
        const Divider(height: 1),

        // 다크모드
        ListTile(
          title: const Text('다크모드'),
          trailing: DropdownButton<AppThemeMode>(
            value: settings.themeMode,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(
                value: AppThemeMode.system,
                child: Text('시스템'),
              ),
              DropdownMenuItem(
                value: AppThemeMode.light,
                child: Text('라이트'),
              ),
              DropdownMenuItem(
                value: AppThemeMode.dark,
                child: Text('다크'),
              ),
            ],
            onChanged: (mode) {
              if (mode != null) {
                ref.read(settingsProvider.notifier).updateThemeMode(mode);
              }
            },
          ),
        ),
        const Divider(height: 1),

        // 앱 정보
        const ListTile(
          title: Text('버전'),
          trailing: Text(
            '1.0.0',
            style: TextStyle(color: AppColors.textSecondaryLight),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: app_router.dart 설정 브랜치 교체**

```dart
import '../../features/settings/settings_screen.dart';

StatefulShellBranch(routes: [
  GoRoute(
    path: '/settings',
    builder: (_, __) => const SettingsScreen(),
  ),
]),
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/settings/ lib/core/router/app_router.dart
git commit -m "feat: add settings screen (exam date, daily target, theme mode)"
```

---

### Task 6: 최종 빌드 및 검증

- [ ] **Step 1: flutter analyze**

```bash
flutter analyze
```

Expected: No issues

- [ ] **Step 2: iOS 빌드**

```bash
flutter build ios --simulator --no-codesign 2>&1 | tail -5
```

Expected: `Build complete.`

- [ ] **Step 3: 전체 앱 수동 검증 체크리스트**

탐색 탭:
- [ ] 탐색 탭 → 모드 선택 화면 표시
- [ ] 단어 리스트 → 검색어 입력 시 필터링
- [ ] N3/N2/완료/미완료 필터 칩 동작
- [ ] 단어 탭 → 예문 펼치기
- [ ] 플래시카드 브라우저 → 카드 플립, 이전/다음, 필터 동작

통계 탭:
- [ ] 연속 학습일, 총 완료 단어 표시
- [ ] 14일 막대 그래프 표시

설정 탭:
- [ ] 시험 날짜 변경 → D-Day 홈 화면 반영
- [ ] 다크모드 전환 → 앱 테마 즉시 변경
- [ ] 하루 학습량 자동 계산값 표시

가나표 (홈 → 히라가나·가타카나 표):
- [ ] 히라가나 탭 50음도 표시
- [ ] 가타카나 탭 전환

- [ ] **Step 4: Final commit**

```bash
git add .
git commit -m "chore: verify explore/stats/settings/kana build complete"
```

---

## Self-Review

**Spec coverage:**
- [x] 탐색 모드 선택 — Task 1 explore_screen
- [x] 단어 리스트 (검색 바, N2/N3/완료/미완료 필터, 예문 펼치기) — Task 1 word_list_screen
- [x] 플래시카드 브라우저 (필터, 플립, 이전/다음) — Task 2 explore_flashcard_screen
- [x] 통계 (날짜별 학습량 막대그래프, 연속 학습일, 전체 진도) — Task 3 stats_screen
- [x] 히라가나/가타카나 표 (탭 전환, 50음도, 로마자) — Task 4 kana_screen
- [x] 설정 (시험 날짜 Date Picker, 하루 학습량 읽기 전용, 다크모드, 버전) — Task 5 settings_screen

**Placeholder scan:** 없음

**Type consistency:**
- `AppThemeMode` — settings_provider, app_settings, settings_screen 모두 동일 타입 사용
- `ExploreFilter.copyWith` sentinel 패턴 — nullable 필드를 `null`로 명시 초기화할 수 있도록 구현
- `DailyStudyCount` — stats_provider와 stats_screen이 동일 타입 참조
