enum WordType { on, kun, katakana, other }

WordType wordTypeFromDb(String value) {
  switch (value) {
    case 'on':
      return WordType.on;
    case 'kun':
      return WordType.kun;
    case 'katakana':
      return WordType.katakana;
    default:
      return WordType.other;
  }
}

String wordTypeToDb(WordType type) => type.name;

enum StudyStage { quiz, completed }

/// 구버전 값(flashcard, quiz_reading, quiz_meaning)은 전부 quiz로 매핑.
StudyStage studyStageFromDb(String value) =>
    value == 'completed' ? StudyStage.completed : StudyStage.quiz;

String studyStageToDb(StudyStage stage) => stage.name;
