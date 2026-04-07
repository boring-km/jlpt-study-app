import 'package:jlpt/domain/models/enums.dart';

class WordExample {
  final String ja;
  final String reading;
  final String ko;

  const WordExample({
    required this.ja,
    required this.reading,
    required this.ko,
  });

  factory WordExample.fromJson(Map<String, dynamic> json) {
    return WordExample(
      ja: json['ja'] as String,
      reading: json['reading'] as String,
      ko: json['ko'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'ja': ja,
        'reading': reading,
        'ko': ko,
      };
}

class Word {
  final String id;
  final JlptLevel jlptLevel;
  final String? expression;
  final String reading;
  final String meaningKo;
  final WordExample? example;

  const Word({
    required this.id,
    required this.jlptLevel,
    this.expression,
    required this.reading,
    required this.meaningKo,
    this.example,
  });

  bool get hasKanji => expression != null && expression != reading;

  factory Word.fromAssetJson(Map<String, dynamic> json, JlptLevel level) {
    final rawId = json['id'] as int;
    final prefix = level == JlptLevel.n3 ? 'n3' : 'n2';
    final id = '${prefix}_${rawId.toString().padLeft(4, '0')}';

    final exampleJson = json['example'];
    final example = exampleJson != null
        ? WordExample.fromJson(exampleJson as Map<String, dynamic>)
        : null;

    return Word(
      id: id,
      jlptLevel: level,
      expression: json['expression'] as String?,
      reading: json['reading'] as String,
      meaningKo: json['meaning_ko'] as String,
      example: example,
    );
  }

  factory Word.fromDbMap(Map<String, dynamic> map) {
    final levelStr = map['jlpt_level'] as String;
    final level = levelStr == 'N3' ? JlptLevel.n3 : JlptLevel.n2;

    final exampleJa = map['example_ja'] as String?;
    final exampleReading = map['example_reading'] as String?;
    final exampleKo = map['example_ko'] as String?;

    final example = exampleJa != null && exampleReading != null && exampleKo != null
        ? WordExample(ja: exampleJa, reading: exampleReading, ko: exampleKo)
        : null;

    return Word(
      id: map['id'] as String,
      jlptLevel: level,
      expression: map['expression'] as String?,
      reading: map['reading'] as String,
      meaningKo: map['meaning_ko'] as String,
      example: example,
    );
  }

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'jlpt_level': jlptLevel == JlptLevel.n3 ? 'N3' : 'N2',
        'expression': expression,
        'reading': reading,
        'meaning_ko': meaningKo,
        'example_ja': example?.ja,
        'example_reading': example?.reading,
        'example_ko': example?.ko,
        'created_at': DateTime.now().toIso8601String(),
      };
}
