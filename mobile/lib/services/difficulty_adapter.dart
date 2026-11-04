/// Actions the UI should take after the adapter evaluates an answer.
enum AdapterAction {
  /// Student answered 3+ correct in a row — promote to next level.
  levelUp,

  /// Student answered 2+ wrong in a row — show a scaffolded hint.
  showHint,

  /// Accuracy below 50% after 6+ questions — flag topic as weak.
  flagWeak,

  /// No special action needed — continue normally.
  normal,
}

/// Tracks student performance within a single tutoring session and
/// decides when to level up, show hints, or flag weak topics.
///
/// State resets when a new session is started.
class DifficultyAdapter {
  /// Current difficulty level (1 = easy, 2 = medium, 3 = hard).
  int currentLevel;

  /// Consecutive correct answers (resets on a wrong answer).
  int correctStreak;

  /// Consecutive wrong answers (resets on a correct answer).
  int wrongStreak;

  /// Total questions answered in this session.
  int totalQuestions;

  /// Total correct answers in this session.
  int correctAnswers;

  /// Whether the topic has been flagged as weak.
  bool isFlagged;

  DifficultyAdapter({
    this.currentLevel = 1,
    this.correctStreak = 0,
    this.wrongStreak = 0,
    this.totalQuestions = 0,
    this.correctAnswers = 0,
    this.isFlagged = false,
  });

  /// Current accuracy as a value between 0.0 and 1.0.
  ///
  /// Returns 0.0 if no questions have been answered yet.
  double get accuracy =>
      totalQuestions > 0 ? correctAnswers / totalQuestions : 0.0;

  AdapterAction recordAnswer(bool correct) {
    return recordStructuredAnswer(isCorrect: correct);
  }

  /// Records a structured answer result and returns the next UI action.
  ///
  /// Low confidence and hint usage make the adapter more conservative even if
  /// the answer was technically correct.
  AdapterAction recordStructuredAnswer({
    required bool isCorrect,
    double confidence = 1.0,
    bool hintUsed = false,
    double? skillMastery,
  }) {
    totalQuestions++;

    final confidentCorrect = isCorrect && confidence >= 0.55 && !hintUsed;

    if (confidentCorrect) {
      correctAnswers++;
      correctStreak++;
      wrongStreak = 0;
    } else {
      wrongStreak++;
      correctStreak = 0;
    }

    // ── Evaluate in priority order ────────────────────────────────────
    final masteryReady = skillMastery == null || skillMastery >= 0.72;
    if (correctStreak >= 3 && currentLevel < 3 && masteryReady) {
      currentLevel++;
      correctStreak = 0; // reset after promotion
      return AdapterAction.levelUp;
    }

    if (totalQuestions >= 6 &&
        (accuracy < 0.50 || (skillMastery != null && skillMastery < 0.40))) {
      isFlagged = true;
      return AdapterAction.flagWeak;
    }

    if (wrongStreak >= 2 || (confidence < 0.45 && !isCorrect)) {
      return AdapterAction.showHint;
    }

    return AdapterAction.normal;
  }

  /// Resets all state for a new session.
  void reset() {
    currentLevel = 1;
    correctStreak = 0;
    wrongStreak = 0;
    totalQuestions = 0;
    correctAnswers = 0;
    isFlagged = false;
  }

  /// Serialises the adapter state to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'currentLevel': currentLevel,
    'correctStreak': correctStreak,
    'wrongStreak': wrongStreak,
    'totalQuestions': totalQuestions,
    'correctAnswers': correctAnswers,
    'accuracy': double.parse(accuracy.toStringAsFixed(2)),
    'isFlagged': isFlagged,
  };
}
