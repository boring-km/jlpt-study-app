import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/word.dart';
import '../words/add_word_sheet.dart';
import 'explore_provider.dart';

class WordListScreen extends ConsumerStatefulWidget {
  const WordListScreen({super.key});

  @override
  ConsumerState<WordListScreen> createState() => _WordListScreenState();
}

class _WordListScreenState extends ConsumerState<WordListScreen> {
  static const _debounce = Duration(milliseconds: 250);

  final _searchController = TextEditingController();
  Timer? _searchTimer;

  /// 인덱스가 아니라 단어 id로 잡는다 — 디바운스·필터로 목록이 통째로
  /// 바뀌어도 엉뚱한 행이 펼쳐지지 않는다.
  String? _expandedWordId;

  @override
  void initState() {
    super.initState();
    // 필터는 화면 밖(exploreFilterProvider)에 살아남으므로, 검색창도 그 값에서
    // 시작해야 입력 내용과 실제 필터가 어긋나지 않는다.
    _searchController.text = ref.read(exploreFilterProvider).query;
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// 한 글자마다 DB를 치지 않도록 250ms 묶어서 보낸다.
  void _onSearch(String query) {
    // 지우기 버튼이 붙고 떨어지는 건 즉시 보여야 한다.
    setState(() {});
    _searchTimer?.cancel();
    _searchTimer = Timer(_debounce, () => _applyQuery(query));
  }

  void _applyQuery(String query) {
    final current =
        ref.read(exploreProvider).valueOrNull?.filter ?? const ExploreFilter();
    ref
        .read(exploreProvider.notifier)
        .updateFilter(current.copyWith(query: query));
  }

  void _clearSearch() {
    _searchTimer?.cancel();
    _searchController.clear();
    setState(() {});
    _applyQuery('');
  }

  void _resetFilters() {
    _searchTimer?.cancel();
    _searchController.clear();
    setState(() {});
    ref.read(exploreProvider.notifier).updateFilter(const ExploreFilter());
  }

  void _onSourceFilter(String? source) {
    final current =
        ref.read(exploreProvider).valueOrNull?.filter ?? const ExploreFilter();
    ref
        .read(exploreProvider.notifier)
        .updateFilter(current.copyWith(sourceFilter: source));
  }

  void _onCompletedFilter(bool? completed) {
    final current =
        ref.read(exploreProvider).valueOrNull?.filter ?? const ExploreFilter();
    ref
        .read(exploreProvider.notifier)
        .updateFilter(current.copyWith(completedFilter: completed));
  }

  @override
  Widget build(BuildContext context) {
    final exploreAsync = ref.watch(exploreProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('탐색'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '단어 추가',
            onPressed: () => showAddWordSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.style_outlined),
            tooltip: '플래시카드로 보기',
            // push여야 플래시카드 화면의 닫기(pop)가 이 목록으로 돌아온다.
            onPressed: () => context.push('/explore/flashcard'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.base,
              AppSpacing.sm,
              AppSpacing.base,
              0,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '한자 · 히라가나 · 한국어로 검색',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: '검색어 지우기',
                        onPressed: _clearSearch,
                      ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          exploreAsync.when(
            data: (state) => _FilterRow(
              filter: state.filter,
              onSource: _onSourceFilter,
              onCompleted: _onCompletedFilter,
            ),
            loading: () => const SizedBox.shrink(),
            error: (e, s) => const SizedBox.shrink(),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: exploreAsync.when(
              data: (state) {
                if (state.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.results.isEmpty) {
                  return _EmptyResults(
                    hasFilter: !_isUnfiltered(state.filter),
                    onReset: _resetFilters,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  itemCount: state.results.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    indent: AppSpacing.base,
                    endIndent: AppSpacing.base,
                  ),
                  itemBuilder: (context, index) {
                    final word = state.results[index];
                    return _WordTile(
                      word: word,
                      isCompleted: state.completedWordIds.contains(word.id),
                      isExpanded: _expandedWordId == word.id,
                      onTap: () => setState(() {
                        _expandedWordId = _expandedWordId == word.id
                            ? null
                            : word.id;
                      }),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '단어를 불러오지 못했다',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: () => ref.invalidate(exploreProvider),
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static bool _isUnfiltered(ExploreFilter filter) =>
      filter.query.isEmpty &&
      filter.sourceFilter == null &&
      filter.completedFilter == null;
}

/// 출처 축([전체][추가한 단어])과 진행 축([완료][미완료])을 헤어라인 하나로 가른다.
class _FilterRow extends StatelessWidget {
  final ExploreFilter filter;
  final ValueChanged<String?> onSource;
  final ValueChanged<bool?> onCompleted;

  const _FilterRow({
    required this.filter,
    required this.onSource,
    required this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    // 부모 Column이 칩 행을 가운데 놓지 않도록 왼쪽 정렬을 고정한다.
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FilterChip(
              label: '전체',
              selected: filter.sourceFilter == null,
              onTap: () => onSource(null),
            ),
            const SizedBox(width: AppSpacing.sm),
            _FilterChip(
              label: '추가한 단어',
              selected: filter.sourceFilter == 'user',
              onTap: () =>
                  onSource(filter.sourceFilter == 'user' ? null : 'user'),
            ),
            const SizedBox(width: AppSpacing.base),
            Container(
              width: 1,
              height: AppSpacing.base,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(width: AppSpacing.base),
            _FilterChip(
              label: '완료',
              selected: filter.completedFilter == true,
              onTap: () =>
                  onCompleted(filter.completedFilter == true ? null : true),
            ),
            const SizedBox(width: AppSpacing.sm),
            _FilterChip(
              label: '미완료',
              selected: filter.completedFilter == false,
              onTap: () =>
                  onCompleted(filter.completedFilter == false ? null : false),
            ),
          ],
        ),
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      // 안쪽 Text가 라벨을 한 번 더 읽지 않도록 자식 시맨틱스는 감춘다.
      excludeSemantics: true,
      child: Material(
        color: selected ? colorScheme.primary : colorScheme.surfaceContainer,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // 시각 높이는 36 남짓이지만 탭 영역은 44 이상으로 잡는다.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  final bool hasFilter;
  final VoidCallback onReset;

  const _EmptyResults({required this.hasFilter, required this.onReset});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '검색 결과가 없다',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (hasFilter) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: onReset, child: const Text('필터 지우기')),
          ],
        ],
      ),
    );
  }
}

class _WordTile extends StatelessWidget {
  final Word word;
  final bool isCompleted;
  final bool isExpanded;
  final VoidCallback onTap;

  const _WordTile({
    required this.word,
    required this.isCompleted,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final example = word.example;
    final animationDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 250);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: 14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  word.expression.isNotEmpty ? word.expression : word.reading,
                  style: AppText.jaLabel(context),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    word.reading,
                    style: AppText.jaCaption(context),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isCompleted)
                  Semantics(
                    label: '완료',
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: colorScheme.success,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              word.meaningKo,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            AnimatedSize(
              duration: animationDuration,
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: isExpanded && example != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.md),
                        Text(example.ja, style: AppText.jaBody(context)),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          example.reading,
                          style: AppText.jaCaption(context),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(example.ko, style: theme.textTheme.bodySmall),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
