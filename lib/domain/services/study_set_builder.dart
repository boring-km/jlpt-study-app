import 'dart:math';
import '../models/enums.dart';
import '../repositories/progress_repository.dart';

/// 하루 세트에 반드시 포함할 훈독 단어 최소 수.
const int kKunMinPerDay = 6;

/// 하루 세트에 덧붙일 약점 단어 수.
const int kWeakPerDay = 5;

/// 하루 신규 단어 목표의 상한. 남은 일수 기준 따라잡기 산식은 시험이 가까울수록
/// 폭발해서(D-1에 1,000개가 남으면 1,000) 하루에 끝낼 수 없는 세트를 만든다.
/// 넘치는 분량은 다음 날로 넘어간다.
const int kMaxDailyTarget = 40;

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
