import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/domain/models/enums.dart';
import 'package:jlpt/domain/models/word.dart';

void main() {
  test('fromAssetJson builds n2 id and reads type/is_trap', () {
    final w = Word.fromAssetJson({
      'id': 7,
      'expression': '工夫',
      'reading': 'くふう',
      'meaning_ko': '궁리, 고안',
      'type': 'on',
      'is_trap': true,
      'example': {'ja': 'a', 'reading': 'b', 'ko': 'c'},
    });
    expect(w.id, 'n2_0007');
    expect(w.type, WordType.on);
    expect(w.isTrap, isTrue);
    expect(w.source, 'n2');
    expect(w.example?.ja, 'a');
  });

  test('fromAssetJson defaults type/is_trap when missing', () {
    final w = Word.fromAssetJson({
      'id': 1,
      'expression': 'やかん',
      'reading': 'やかん',
      'meaning_ko': '주전자',
    });
    expect(w.type, WordType.other);
    expect(w.isTrap, isFalse);
    expect(w.example, isNull);
  });

  test('hasKanji detects CJK ideographs', () {
    expect(const Word(id: 'a', expression: '補う', reading: 'おぎなう', meaningKo: 'x').hasKanji, isTrue);
    expect(const Word(id: 'b', expression: 'コンピューター', reading: 'コンピューター', meaningKo: 'x').hasKanji, isFalse);
    expect(const Word(id: 'c', expression: '～位', reading: 'い', meaningKo: 'x').hasKanji, isTrue);
  });

  test('toDbMap/fromDbMap round-trip', () {
    const w = Word(
      id: 'user_1',
      expression: '把握',
      reading: 'はあく',
      meaningKo: '파악',
      type: WordType.on,
      isTrap: false,
      source: 'user',
    );
    final map = w.toDbMap();
    expect(map['jlpt_level'], 'N2');
    expect(map['type'], 'on');
    expect(map['is_trap'], 0);
    expect(map['source'], 'user');
    final back = Word.fromDbMap({...map, 'is_trap': 0});
    expect(back.id, 'user_1');
    expect(back.type, WordType.on);
    expect(back.source, 'user');
  });
}
