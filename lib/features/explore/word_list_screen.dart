import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  int? _expandedIndex;

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
      appBar: AppBar(
        title: const Text('단어 리스트'),
        actions: [
          IconButton(
            icon: const Icon(Icons.style_outlined),
            tooltip: '플래시카드로 보기',
            onPressed: () => context.go('/explore/flashcard'),
          ),
        ],
      ),
      body: Column(
        children: [
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
                  borderSide: BorderSide(color: Theme.of(context).dividerColor, width: 1.5),
                ),
                filled: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
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
              error: (e, s) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 8),
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
                          isExpanded: _expandedIndex == index,
                          onTap: () => setState(() {
                            _expandedIndex =
                                _expandedIndex == index ? null : index;
                          }),
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('오류: $e')),
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
            color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: selected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      );
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  (word.expression?.isNotEmpty ?? false)
                      ? word.expression!
                      : word.reading,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Text(
                  word.reading,
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const Spacer(),
                WordBadge(level: word.jlptLevel),
                if (isCompleted) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.check_circle,
                      size: 16, color: AppColors.success),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(word.meaningKo,
                style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: isExpanded && word.example != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(word.example!.ja,
                            style: const TextStyle(fontSize: 23)),
                        const SizedBox(height: 6),
                        Text(word.example!.reading,
                            style: TextStyle(
                                fontSize: 19,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Text(word.example!.ko,
                            style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
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
