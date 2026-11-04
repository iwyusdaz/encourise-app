import 'dart:convert';

import '../services/difficulty_adapter.dart';

/// Snapshot of a tutoring session's state.
///
/// This is serialised to JSON and injected into every Gemma 4 prompt so
/// the model can adapt its responses to the student's current performance.
class SessionState {
  /// Unique session identifier.
  final String sessionId;

  /// The topic being studied (e.g. "pecahan" / "bilangan_bulat").
  final String topic;

  /// Student's grade level (1–12).
  final int grade;

  /// Subject key (e.g. "math", "ipa", "bahasa").
  final String subject;

  /// Current difficulty level (1 = easy, 2 = medium, 3 = hard).
  int currentLevel;

  /// Consecutive correct answers.
  int correctStreak;

  /// Consecutive wrong answers.
  int wrongStreak;

  /// Total questions answered so far.
  int totalQuestions;

  /// Total correct answers so far.
  int correctAnswers;

  /// Whether the topic has been flagged as weak.
  bool isFlagged;

  SessionState({
    required this.sessionId,
    required this.topic,
    required this.grade,
    required this.subject,
    this.currentLevel = 1,
    this.correctStreak = 0,
    this.wrongStreak = 0,
    this.totalQuestions = 0,
    this.correctAnswers = 0,
    this.isFlagged = false,
  });

  /// Current accuracy (0.0–1.0).
  double get accuracy =>
      totalQuestions > 0 ? correctAnswers / totalQuestions : 0.0;

  /// Syncs this state from a [DifficultyAdapter] after each answer.
  void syncFromAdapter(DifficultyAdapter adapter) {
    currentLevel = adapter.currentLevel;
    correctStreak = adapter.correctStreak;
    wrongStreak = adapter.wrongStreak;
    totalQuestions = adapter.totalQuestions;
    correctAnswers = adapter.correctAnswers;
    isFlagged = adapter.isFlagged;
  }

  /// Serialises the full session state to a JSON-compatible map.
  ///
  /// This map is injected into the Gemma 4 system prompt so the model
  /// knows the student's current performance context.
  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'topic': topic,
    'grade': grade,
    'subject': subject,
    'currentLevel': currentLevel,
    'correctStreak': correctStreak,
    'wrongStreak': wrongStreak,
    'totalQuestions': totalQuestions,
    'correctAnswers': correctAnswers,
    'accuracy': double.parse(accuracy.toStringAsFixed(2)),
    'isFlagged': isFlagged,
  };

  /// Returns a compact JSON string for prompt injection.
  String toJsonString() => jsonEncode(toJson());

  /// Creates a [SessionState] from a JSON map.
  factory SessionState.fromJson(Map<String, dynamic> json) {
    return SessionState(
      sessionId: json['sessionId'] as String,
      topic: json['topic'] as String,
      grade: json['grade'] as int,
      subject: json['subject'] as String,
      currentLevel: json['currentLevel'] as int? ?? 1,
      correctStreak: json['correctStreak'] as int? ?? 0,
      wrongStreak: json['wrongStreak'] as int? ?? 0,
      totalQuestions: json['totalQuestions'] as int? ?? 0,
      correctAnswers: json['correctAnswers'] as int? ?? 0,
      isFlagged: json['isFlagged'] as bool? ?? false,
    );
  }
}
