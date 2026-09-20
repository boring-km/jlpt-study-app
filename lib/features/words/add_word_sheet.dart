import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/database_provider.dart';
import '../../application/providers/progress_summary_provider.dart';
import '../../application/providers/word_catalog_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/word.dart';
import '../../domain/repositories/word_repository.dart';
import '../explore/explore_provider.dart';

final _jaRegex = RegExp(r'[぀-ヿ一-鿿]');
final _katakanaOnly = RegExp(r'^[゠-ヿー]+$');
final _kanji = RegExp(r'[一-鿿々]');

/// 클립보드 문자열이 "단어 하나"처럼 보이는지. 문장·본문 통째로 붙여넣는 걸
/// 막으려고 줄바꿈 없음 + 20자 이하로 제한한다.
bool looksJapanese(String text) {
  final t = text.trim();
  return t.isNotEmpty &&
      t.length <= 20 &&
      !t.contains('\n') &&
      _jaRegex.hasMatch(t);
}

Future<void> showAddWordSheet(
  BuildContext context, {
  String? initialExpression,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: AddWordSheet(initialExpression: initialExpression),
    ),
  );
}

class AddWordSheet extends ConsumerStatefulWidget {
  final String? initialExpression;

  const AddWordSheet({super.key, this.initialExpression});

  @override
  ConsumerState<AddWordSheet> createState() => _AddWordSheetState();
}

class _AddWordSheetState extends ConsumerState<AddWordSheet> {
  static const _debounceDuration = Duration(milliseconds: 300);

  late final TextEditingController _expression;
  final _reading = TextEditingController();
  final _meaning = TextEditingController();

  Timer? _debounce;
  Word? _existing;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _expression = TextEditingController(text: widget.initialExpression ?? '');
    if (_expression.text.trim().isNotEmpty) {
      _scheduleLookup(_expression.text);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _expression.dispose();
    _reading.dispose();
    _meaning.dispose();
    super.dispose();
  }

  void _onExpressionChanged(String value) {
    if (_existing != null || _error != null) {
      setState(() {
        _existing = null;
        _error = null;
      });
    }
    _scheduleLookup(value);
  }

  void _scheduleLookup(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () => _lookup(value.trim()));
  }

  Future<void> _lookup(String expression) async {
    if (expression.isEmpty) {
      if (mounted && _existing != null) setState(() => _existing = null);
      return;
    }
    final Word? found;
    try {
      final db = await ref.read(databaseProvider.future);
      found = await WordRepository(db).findByExpression(expression);
    } catch (_) {
      // 조회 실패로 입력을 막지 않는다 — 저장 시 중복이면 DB가 거른다.
      return;
    }
    if (!mounted) return;
    // 느린 조회가 돌아오는 사이 표기가 바뀌었으면 버린다.
    if (_expression.text.trim() != expression) return;
    setState(() {
      _existing = found;
      if (found != null) {
        _reading.text = found.reading;
        _meaning.text = found.meaningKo;
      }
    });
  }

  Future<void> _save() async {
    final expression = _expression.text.trim();
    final reading = _reading.text.trim();

    if (expression.isEmpty) {
      setState(() => _error = '표기를 입력하세요');
      return;
    }
    if (_kanji.hasMatch(expression) && reading.isEmpty) {
      setState(() => _error = '읽기를 입력하세요');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });

    final navigator = Navigator.of(context);
    // pop 이후엔 이 컨텍스트로 메신저를 못 찾으니 미리 붙잡아 둔다.
    final messenger = ScaffoldMessenger.maybeOf(context);
    // 시트가 닫힌 뒤에도 캐시는 갱신해야 하므로 ref 대신 컨테이너를 붙잡아 둔다.
    final container = ProviderScope.containerOf(context, listen: false);

    // 디바운스가 돌기 전에 저장을 누르면 중복 안내를 건너뛰게 된다.
    // expression에는 유니크 제약이 없어 DB도 못 막으니 여기서 직접 확인한다.
    _debounce?.cancel();
    final Word? duplicate;
    try {
      final db = await ref.read(databaseProvider.future);
      duplicate = await WordRepository(db).findByExpression(expression);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '저장하지 못했습니다. 잠시 후 다시 시도해 주세요';
      });
      return;
    }
    if (!mounted) return;
    if (duplicate != null) {
      setState(() {
        _saving = false;
        _existing = duplicate;
        _error = '이미 있는 단어';
      });
      return;
    }

    final word = Word(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      expression: expression,
      // 한자가 없으면 표기 자체가 읽기다 (カタカナ·ひらがな 단어).
      reading: reading.isEmpty ? expression : reading,
      meaningKo: _meaning.text.trim(),
      type: _katakanaOnly.hasMatch(expression)
          ? WordType.katakana
          : WordType.other,
      source: 'user',
    );

    try {
      await ref.read(wordCatalogProvider.notifier).addUserWord(word);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '저장하지 못했습니다. 잠시 후 다시 시도해 주세요';
      });
      return;
    }
    container.invalidate(progressSummaryProvider);
    container.invalidate(exploreProvider);
    if (!mounted) return;
    messenger?.showSnackBar(SnackBar(content: Text('$expression 추가됨')));
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSave = _existing == null && !_saving;
    // useSafeArea는 위쪽만 띄운다 — 홈 인디케이터가 저장 버튼을 덮지 않도록
    // 아래 여백은 직접 더한다.
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    // 키보드가 올라와도 저장 버튼까지 닿도록 본문은 스크롤한다.
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg + bottomSafe,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('단어 추가', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.base),
            TextField(
              key: const Key('add-expression'),
              controller: _expression,
              autofocus: widget.initialExpression == null,
              onChanged: _onExpressionChanged,
              // 한자가 한국식 자형으로 나오지 않도록 입력 글자도 일본어 폰트로.
              style: AppText.jaBody(context),
              decoration: const InputDecoration(
                labelText: '표기',
                hintText: '把握',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('add-reading'),
              controller: _reading,
              style: AppText.jaBody(context),
              decoration: const InputDecoration(
                labelText: '읽기',
                hintText: 'はあく',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('add-meaning'),
              controller: _meaning,
              decoration: const InputDecoration(labelText: '뜻', hintText: '파악'),
            ),
            if (_existing != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text('이미 있는 단어', style: theme.textTheme.bodySmall),
            ] else if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              key: const Key('add-save'),
              onPressed: canSave ? _save : null,
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}
