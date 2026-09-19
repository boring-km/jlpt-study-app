import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt/domain/models/error_tag.dart';

void main() {
  test('dbValue round-trips', () {
    for (final tag in ErrorTag.values) {
      expect(errorTagFromDb(tag.dbValue), tag);
    }
  });

  test('labels are Korean', () {
    expect(ErrorTag.longVowel.label, '장음');
    expect(ErrorTag.sokuon.label, '촉음');
    expect(ErrorTag.dakuten.label, '탁음');
    expect(ErrorTag.meaning.label, '뜻');
    expect(ErrorTag.other.label, '기타');
  });

  test('unknown db value falls back to other', () {
    expect(errorTagFromDb('garbage'), ErrorTag.other);
  });
}
