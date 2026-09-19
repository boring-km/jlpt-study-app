import 'dart:math';
import '../models/enums.dart';
import '../repositories/progress_repository.dart';

/// 하루 세트에 반드시 포함할 훈독 단어 최소 수.
const int kKunMinPerDay = 6;

/// 하루 세트에 덧붙일 약점 단어 수.
const int kWeakPerDay = 5;

class StudySetBuilder {
  final ProgressRepository _repo;
  final Random _random;

  StudySetBuilder(this._repo, {Random? random}) : _random = random ?? Random();

  /// 사용자 단어 → 훈독 최소 보장 → 나머지 랜덤. 결과는 셔플.
  Future<List<String>> pickNewWordIds(int target, {Set<String> exclude = const {}}) async {
    if (target <= 0) return [];
    final picked = <String>[];
    final taken = <String>{...exclude};

    void addAll(Iterable<String> ids, int max) {
      for (final id in ids) {
        if (picked.length >= target || max <= 0) break;
        if (taken.add(id)) {
          picked.add(id);
          max--;
        }
      }
    }

    final userIds = await _repo.getUncompletedWordIds(source: 'user');
    addAll(userIds, target);

    final kunIds = await _repo.getUncompletedWordIds(type: WordType.kun)..shuffle(_random);
    addAll(kunIds, kKunMinPerDay);

    final allIds = await _repo.getUncompletedWordIds()..shuffle(_random);
    addAll(allIds, target);

    picked.shuffle(_random);
    return picked;
  }

  Future<List<String>> pickWeakWordIds({Set<String> exclude = const {}}) async {
    final weak = await _repo.getWeakWordIds(limit: kWeakPerDay + exclude.length);
    return weak.where((id) => !exclude.contains(id)).take(kWeakPerDay).toList();
  }
}
