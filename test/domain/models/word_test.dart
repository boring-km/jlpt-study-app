import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/domain/models/word.dart';
import 'package:jlpt/domain/models/enums.dart';

void main() {
  group('WordExample', () {
    test('fromJson parses correctly', () {
      final json = {'ja': '例文', 'reading': 'れいぶん', 'ko': '예문'};
      final example = WordExample.fromJson(json);
      expect(example.ja, '例文');
      expect(example.reading, 'れいぶん');
      expect(example.ko, '예문');
    });

    test('toJson round-trips', () {
      const example = WordExample(ja: '例文', reading: 'れいぶん', ko: '예문');
      final json = example.toJson();
      expect(json['ja'], '例文');
      expect(json['reading'], 'れいぶん');
      expect(json['ko'], '예문');
    });
  });

  group('Word.fromAssetJson', () {
    test('generates n3 prefixed id', () {
      final json = {
        'id': 1,
        'expression': '作法',
        'reading': 'さほう',
        'meaning_ko': '예절',
        'example': {'ja': '食事の作法を学んだ。', 'reading': 'しょくじのさほうをまなんだ。', 'ko': '식사 예절을 배웠다.'},
      };
      final word = Word.fromAssetJson(json, JlptLevel.n3);
      expect(word.id, 'n3_0001');
      expect(word.jlptLevel, JlptLevel.n3);
      expect(word.expression, '作法');
      expect(word.reading, 'さほう');
      expect(word.meaningKo, '예절');
      expect(word.example, isNotNull);
    });

    test('generates n2 prefixed id', () {
      final json = {
        'id': 42,
        'expression': '題名',
        'reading': 'だいめい',
        'meaning_ko': '제목',
        'example': null,
      };
      final word = Word.fromAssetJson(json, JlptLevel.n2);
      expect(word.id, 'n2_0042');
      expect(word.example, isNull);
    });

    test('hasKanji returns true when expression differs from reading', () {
      final word = Word.fromAssetJson(
        {'id': 1, 'expression': '作法', 'reading': 'さほう', 'meaning_ko': '예절', 'example': null},
        JlptLevel.n3,
      );
      expect(word.hasKanji, isTrue);
    });

    test('hasKanji returns false when expression equals reading', () {
      final word = Word.fromAssetJson(
        {'id': 1, 'expression': 'さほう', 'reading': 'さほう', 'meaning_ko': '예절', 'example': null},
        JlptLevel.n3,
      );
      expect(word.hasKanji, isFalse);
    });
  });

  group('Word.fromDbMap / toDbMap', () {
    test('round-trips without example', () {
      final map = {
        'id': 'n3_0001',
        'jlpt_level': 'N3',
        'expression': '作法',
        'reading': 'さほう',
        'meaning_ko': '예절',
        'example_ja': null,
        'example_reading': null,
        'example_ko': null,
      };
      final word = Word.fromDbMap(map);
      expect(word.id, 'n3_0001');
      expect(word.jlptLevel, JlptLevel.n3);
      expect(word.example, isNull);
    });

    test('round-trips with example', () {
      final map = {
        'id': 'n3_0001',
        'jlpt_level': 'N3',
        'expression': '作法',
        'reading': 'さほう',
        'meaning_ko': '예절',
        'example_ja': '食事の作法を学んだ。',
        'example_reading': 'しょくじのさほうをまなんだ。',
        'example_ko': '식사 예절을 배웠다.',
      };
      final word = Word.fromDbMap(map);
      expect(word.example?.ja, '食事の作法を学んだ。');
    });

    test('toDbMap contains required keys', () {
      const word = Word(
        id: 'n3_0001',
        jlptLevel: JlptLevel.n3,
        expression: '作法',
        reading: 'さほう',
        meaningKo: '예절',
      );
      final map = word.toDbMap();
      expect(map['id'], 'n3_0001');
      expect(map['jlpt_level'], 'N3');
      expect(map.containsKey('created_at'), isTrue);
    });
  });
}
