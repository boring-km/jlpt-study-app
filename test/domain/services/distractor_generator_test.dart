import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/domain/models/error_tag.dart';
import 'package:jlpt/domain/services/distractor_generator.dart';

void main() {
  final g = DistractorGenerator(random: Random(42));

  group('longVowelVariants', () {
    test('removes う after o-row and い after e-row', () {
      expect(g.longVowelVariants('しょうり'), contains('しょり'));
      expect(g.longVowelVariants('せいさん'), contains('せさん'));
    });
    test('adds う after o-row kana lacking it', () {
      expect(g.longVowelVariants('ここく'), contains('こうこく'));
    });
    test('removes ー', () {
      expect(g.longVowelVariants('コーヒー'), contains('コヒー'));
    });
    test('never returns the input itself', () {
      expect(g.longVowelVariants('こうこく'), isNot(contains('こうこく')));
    });
  });

  group('sokuonVariants', () {
    test('removes っ', () {
      expect(g.sokuonVariants('いっち'), contains('いち'));
    });
    test('inserts っ before k/s/t/p row, not at index 0', () {
      final v = g.sokuonVariants('けか');
      expect(v, contains('けっか'));
      expect(v.every((s) => !s.startsWith('っ')), isTrue);
    });
  });

  group('dakutenVariants', () {
    test('toggles voiced/unvoiced', () {
      expect(g.dakutenVariants('がまん'), contains('かまん'));
      expect(g.dakutenVariants('かまん'), contains('がまん'));
    });
    test('toggles handakuten', () {
      expect(g.dakutenVariants('はあく'), contains('ぱあく'));
    });
  });

  group('generate', () {
    test('returns 3 distinct readings none equal to correct or excluded', () {
      final d = g.generate(correct: 'せいさん', exclude: {'せさん'});
      expect(d.length, 3);
      expect(d.map((x) => x.reading).toSet().length, 3);
      expect(d.every((x) => x.reading != 'せいさん' && x.reading != 'せさん'), isTrue);
    });
    test('covers different tags when possible', () {
      final d = g.generate(correct: 'けっこう');
      expect(d.map((x) => x.tag).toSet().length, greaterThanOrEqualTo(2));
    });
    test('falls back to pool with tag other when variants are scarce', () {
      final d = g.generate(correct: 'い', pool: ['いえ', 'いぬ', 'いし', 'いろ']);
      expect(d.length, 3);
      expect(d.where((x) => x.tag == ErrorTag.other).isNotEmpty, isTrue);
    });
    test('mixed katakana reading uses pool only', () {
      final d = g.generate(correct: 'ハンド', pool: ['ハンカチ', 'ハンバーグ', 'ハンサム']);
      expect(d.every((x) => x.tag == ErrorTag.other), isTrue);
    });
    test('returns fewer when nothing available', () {
      expect(g.generate(correct: 'い'), isEmpty);
    });
  });
}
