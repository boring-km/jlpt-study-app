import 'dart:math';
import '../models/error_tag.dart';

class Distractor {
  final String reading;
  final ErrorTag tag;
  const Distractor(this.reading, this.tag);
}

/// 정답 읽기를 장음·촉음·탁음 규칙으로 변형해 시험형 오답을 만든다.
class DistractorGenerator {
  final Random _random;
  DistractorGenerator({Random? random}) : _random = random ?? Random();

  static const _oRow = 'おこそとのほもよろをごぞどぼぽょ';
  static const _eRow = 'えけせてねへめれげぜでべぺ';
  static const _sokuonTargets = 'かきくけこさしすせそたちつてとぱぴぷぺぽ';
  static const _dakutenPairs = {
    'か': 'が', 'き': 'ぎ', 'く': 'ぐ', 'け': 'げ', 'こ': 'ご',
    'さ': 'ざ', 'し': 'じ', 'す': 'ず', 'せ': 'ぜ', 'そ': 'ぞ',
    'た': 'だ', 'ち': 'ぢ', 'つ': 'づ', 'て': 'で', 'と': 'ど',
    'は': 'ば', 'ひ': 'び', 'ふ': 'ぶ', 'へ': 'べ', 'ほ': 'ぼ',
  };
  static const _handakutenPairs = {
    'は': 'ぱ', 'ひ': 'ぴ', 'ふ': 'ぷ', 'へ': 'ぺ', 'ほ': 'ぽ',
    'ば': 'ぱ', 'び': 'ぴ', 'ぶ': 'ぷ', 'べ': 'ぺ', 'ぼ': 'ぽ',
  };
  static final _katakana = RegExp(r'[゠-ヺ]');

  List<String> longVowelVariants(String r) {
    final out = <String>{};
    final chars = r.split('');
    for (var i = 0; i < chars.length; i++) {
      final c = chars[i];
      final prev = i > 0 ? chars[i - 1] : '';
      // 삭제
      if (c == 'ー' ||
          (i > 0 && c == 'う' && _oRow.contains(prev)) ||
          (i > 0 && c == 'い' && _eRow.contains(prev))) {
        out.add((List.of(chars)..removeAt(i)).join());
      }
      // 추가
      final next = i + 1 < chars.length ? chars[i + 1] : '';
      if (_oRow.contains(c) && next != 'う') {
        out.add((List.of(chars)..insert(i + 1, 'う')).join());
      }
      if (_eRow.contains(c) && next != 'い') {
        out.add((List.of(chars)..insert(i + 1, 'い')).join());
      }
    }
    out.remove(r);
    return out.toList();
  }

  List<String> sokuonVariants(String r) {
    final out = <String>{};
    final chars = r.split('');
    for (var i = 0; i < chars.length; i++) {
      if (chars[i] == 'っ') {
        out.add((List.of(chars)..removeAt(i)).join());
      } else if (i > 0 && _sokuonTargets.contains(chars[i]) && chars[i - 1] != 'っ') {
        out.add((List.of(chars)..insert(i, 'っ')).join());
      }
    }
    out.remove(r);
    return out.toList();
  }

  List<String> dakutenVariants(String r) {
    final out = <String>{};
    final chars = r.split('');
    final reverse = {for (final e in _dakutenPairs.entries) e.value: e.key};
    final reverseHan = {for (final e in _handakutenPairs.entries) e.value: e.key};
    for (var i = 0; i < chars.length; i++) {
      final c = chars[i];
      for (final swap in [
        _dakutenPairs[c],
        reverse[c],
        _handakutenPairs[c],
        reverseHan[c],
      ]) {
        if (swap != null) {
          out.add((List.of(chars)..[i] = swap).join());
        }
      }
    }
    out.remove(r);
    return out.toList();
  }

  List<Distractor> generate({
    required String correct,
    Set<String> exclude = const {},
    List<String> pool = const [],
    int count = 3,
  }) {
    final banned = {correct, ...exclude};
    final result = <Distractor>[];
    final used = <String>{};

    void take(Distractor d) {
      if (result.length >= count) return;
      if (banned.contains(d.reading) || !used.add(d.reading)) return;
      result.add(d);
    }

    if (!_katakana.hasMatch(correct)) {
      final buckets = <ErrorTag, List<String>>{
        ErrorTag.longVowel: longVowelVariants(correct)..shuffle(_random),
        ErrorTag.sokuon: sokuonVariants(correct)..shuffle(_random),
        ErrorTag.dakuten: dakutenVariants(correct)..shuffle(_random),
      };
      // 카테고리 순환: 각 태그에서 하나씩 돌아가며 뽑아 태그 다양성 확보
      var progressed = true;
      while (result.length < count && progressed) {
        progressed = false;
        for (final entry in buckets.entries) {
          if (entry.value.isEmpty) continue;
          take(Distractor(entry.value.removeLast(), entry.key));
          progressed = true;
        }
      }
    }

    final shuffledPool = List.of(pool)..shuffle(_random);
    for (final p in shuffledPool) {
      take(Distractor(p, ErrorTag.other));
    }
    return result;
  }
}
