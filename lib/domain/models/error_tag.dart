enum ErrorTag { longVowel, sokuon, dakuten, meaning, other }

extension ErrorTagX on ErrorTag {
  String get dbValue => switch (this) {
        ErrorTag.longVowel => 'long_vowel',
        ErrorTag.sokuon => 'sokuon',
        ErrorTag.dakuten => 'dakuten',
        ErrorTag.meaning => 'meaning',
        ErrorTag.other => 'other',
      };

  String get label => switch (this) {
        ErrorTag.longVowel => '장음',
        ErrorTag.sokuon => '촉음',
        ErrorTag.dakuten => '탁음',
        ErrorTag.meaning => '뜻',
        ErrorTag.other => '기타',
      };
}

ErrorTag errorTagFromDb(String value) {
  for (final tag in ErrorTag.values) {
    if (tag.dbValue == value) return tag;
  }
  return ErrorTag.other;
}
