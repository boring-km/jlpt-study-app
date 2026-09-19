import 'package:jlpt/domain/models/enums.dart';

final _kanjiRegex = RegExp(r'[一-鿿々]');

class WordExample {
  final String ja;
  final String reading;
  final String ko;

  const WordExample({required this.ja, required this.reading, required this.ko});

  factory WordExample.fromJson(Map<String, dynamic> json) => WordExample(
        ja: json['ja'] as String,
        reading: json['reading'] as String,
        ko: json['ko'] as String,
      );

  Map<String, dynamic> toJson() => {'ja': ja, 'reading': reading, 'ko': ko};
}

class Word {
  final String id;
  final String expression;
  final String reading;
  final String meaningKo;
  final WordType type;
  final bool isTrap;
  final String source; // 'n2' | 'user'
  final WordExample? example;

  const Word({
    required this.id,
    required this.expression,
    required this.reading,
    required this.meaningKo,
    this.type = WordType.other,
    this.isTrap = false,
    this.source = 'n2',
    this.example,
  });

  bool get hasKanji => _kanjiRegex.hasMatch(expression);

  factory Word.fromAssetJson(Map<String, dynamic> json) {
    final rawId = json['id'] as int;
    final exampleJson = json['example'];
    return Word(
      id: 'n2_${rawId.toString().padLeft(4, '0')}',
      expression: (json['expression'] as String?) ?? (json['reading'] as String),
      reading: json['reading'] as String,
      meaningKo: json['meaning_ko'] as String,
      type: wordTypeFromDb((json['type'] as String?) ?? 'other'),
      isTrap: (json['is_trap'] as bool?) ?? false,
      source: 'n2',
      example: exampleJson != null
          ? WordExample.fromJson(exampleJson as Map<String, dynamic>)
          : null,
    );
  }

  factory Word.fromDbMap(Map<String, dynamic> map) {
    final exampleJa = map['example_ja'] as String?;
    final exampleReading = map['example_reading'] as String?;
    final exampleKo = map['example_ko'] as String?;
    final reading = map['reading'] as String;
    return Word(
      id: map['id'] as String,
      expression: (map['expression'] as String?) ?? reading,
      reading: reading,
      meaningKo: map['meaning_ko'] as String,
      type: wordTypeFromDb((map['type'] as String?) ?? 'other'),
      isTrap: ((map['is_trap'] as int?) ?? 0) == 1,
      source: (map['source'] as String?) ?? 'n2',
      example: exampleJa != null && exampleReading != null && exampleKo != null
          ? WordExample(ja: exampleJa, reading: exampleReading, ko: exampleKo)
          : null,
    );
  }

  Map<String, dynamic> toDbMap() => {
        'id': id,
        'jlpt_level': 'N2',
        'expression': expression,
        'reading': reading,
        'meaning_ko': meaningKo,
        'type': wordTypeToDb(type),
        'is_trap': isTrap ? 1 : 0,
        'source': source,
        'example_ja': example?.ja,
        'example_reading': example?.reading,
        'example_ko': example?.ko,
        'created_at': DateTime.now().toIso8601String(),
      };

  Word copyWith({
    String? expression,
    String? reading,
    String? meaningKo,
    WordType? type,
    bool? isTrap,
    String? source,
    WordExample? example,
  }) =>
      Word(
        id: id,
        expression: expression ?? this.expression,
        reading: reading ?? this.reading,
        meaningKo: meaningKo ?? this.meaningKo,
        type: type ?? this.type,
        isTrap: isTrap ?? this.isTrap,
        source: source ?? this.source,
        example: example ?? this.example,
      );
}
