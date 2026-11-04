import 'dart:convert';

String _asString(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  return value.toString();
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _asDouble(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _asBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  final text = value?.toString().toLowerCase();
  if (text == 'true' || text == 'benar' || text == 'yes') return true;
  if (text == 'false' || text == 'salah' || text == 'no') return false;
  return fallback;
}

List<String> _asStringList(Object? value) {
  if (value is List) {
    return value
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();
  }
  return const [];
}

class TutorTurnResult {
  final String status;
  final bool isCorrect;
  final double confidence;
  final String feedback;
  final String hint;
  final String nextQuestion;
  final String skillTag;
  final int difficulty;
  final bool shouldAdvance;
  final String rawResponse;

  const TutorTurnResult({
    this.status = 'incorrect',
    required this.isCorrect,
    required this.confidence,
    required this.feedback,
    required this.hint,
    required this.nextQuestion,
    required this.skillTag,
    required this.difficulty,
    required this.shouldAdvance,
    required this.rawResponse,
  });

  String get studentText {
    final parts = [
      feedback.trim(),
      if (hint.trim().isNotEmpty && !isCorrect) 'Petunjuk: ${hint.trim()}',
      nextQuestion.trim(),
    ].where((part) => part.isNotEmpty).toList();
    return parts.isEmpty ? rawResponse : parts.join('\n\n');
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'is_correct': isCorrect,
    'confidence': confidence,
    'feedback': feedback,
    'hint': hint,
    'next_question': nextQuestion,
    'skill_tag': skillTag,
    'difficulty': difficulty,
    'should_advance': shouldAdvance,
    'raw_response': rawResponse,
  };

  factory TutorTurnResult.fromJson(
    Map<String, dynamic> json, {
    String rawResponse = '',
  }) {
    final rawStatus = _asString(
      json['status'] ??
          json['s'] ??
          json['evaluation_status'] ??
          json['result'],
    ).toLowerCase();
    final status = switch (rawStatus) {
      'correct' || 'benar' => 'correct',
      'partial' || 'partly_correct' || 'sebagian' => 'partial',
      'unclear' || 'vague' || 'tidak_jelas' => 'unclear',
      'incorrect' || 'wrong' || 'salah' => 'incorrect',
      _ =>
        _asBool(json['is_correct'] ?? json['c'] ?? json['correct'])
            ? 'correct'
            : 'incorrect',
    };
    final isCorrect = status == 'correct';
    return TutorTurnResult(
      status: status,
      isCorrect: isCorrect,
      confidence: _asDouble(
        json['confidence'] ?? json['conf'],
        fallback: isCorrect ? 0.75 : 0.65,
      ).clamp(0.0, 1.0),
      feedback: _asString(json['feedback'] ?? json['f'], fallback: rawResponse),
      hint: _asString(json['hint'] ?? json['h']),
      nextQuestion: _asString(
        json['next_question'] ?? json['nextQuestion'] ?? json['n'],
      ),
      skillTag: normalizeSkillTag(
        _asString(
          json['skill_tag'] ?? json['skillTag'] ?? json['skill'],
          fallback: 'general',
        ),
      ),
      difficulty: _asInt(
        json['difficulty'] ?? json['d'],
        fallback: 1,
      ).clamp(1, 3),
      shouldAdvance: _asBool(
        json['should_advance'] ?? json['shouldAdvance'] ?? json['adv'],
        fallback: isCorrect,
      ),
      rawResponse: rawResponse,
    );
  }

  factory TutorTurnResult.fallback({
    required String rawResponse,
    required String topic,
    required int difficulty,
  }) {
    final lower = rawResponse.toLowerCase();
    final wrong =
        lower.contains('salah') ||
        lower.contains('kurang tepat') ||
        lower.contains('belum benar') ||
        lower.contains('coba lagi');
    return TutorTurnResult(
      status: wrong ? 'incorrect' : 'unclear',
      isCorrect: !wrong,
      confidence: 0.45,
      feedback: rawResponse.trim().isEmpty
          ? 'Budi belum bisa menilai jawaban ini dengan yakin.'
          : rawResponse.trim(),
      hint: wrong ? 'Coba perhatikan kembali bagian penting dari soal.' : '',
      nextQuestion: '',
      skillTag: normalizeSkillTag(topic),
      difficulty: difficulty.clamp(1, 3),
      shouldAdvance: !wrong,
      rawResponse: rawResponse,
    );
  }

  factory TutorTurnResult.retryNeeded({
    required String topic,
    required int difficulty,
    String rawResponse = '[retry_needed]',
  }) {
    return TutorTurnResult(
      status: 'unclear',
      isCorrect: false,
      confidence: 0.0,
      feedback:
          'Budi belum bisa menilai jawaban ini. Coba tekan ulangi agar Budi menilai jawaban yang sama.',
      hint: '',
      nextQuestion: '',
      skillTag: normalizeSkillTag(topic),
      difficulty: difficulty.clamp(1, 3),
      shouldAdvance: false,
      rawResponse: rawResponse,
    );
  }
}

class QuizQuestion {
  final String type;
  final String id;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final List<String> acceptedAnswers;
  final String explanation;
  final String skillTag;
  final int difficulty;

  const QuizQuestion({
    this.type = 'multiple_choice',
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    this.acceptedAnswers = const [],
    required this.explanation,
    required this.skillTag,
    required this.difficulty,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'prompt': prompt,
    'options': options,
    'correct_index': correctIndex,
    'accepted_answers': acceptedAnswers,
    'explanation': explanation,
    'skill_tag': skillTag,
    'difficulty': difficulty,
  };

  factory QuizQuestion.fromJson(
    Map<String, dynamic> json, {
    required int index,
    required String topic,
  }) {
    final type = _normalizeQuestionType(
      json['type'] ?? json['t'] ?? json['question_type'],
    );
    final options = type == 'true_false'
        ? const ['Benar', 'Salah']
        : _asStringList(json['options'] ?? json['o']);
    final normalizedOptions = type == 'fill_blank'
        ? const <String>[]
        : options.length >= 4
        ? options.take(4).toList()
        : [
            ...options,
            'Pilihan A',
            'Pilihan B',
            'Pilihan C',
            'Pilihan D',
          ].take(type == 'true_false' ? 2 : 4).toList();
    final rawCorrectIndex = _asInt(
      json['correct_index'] ?? json['correctIndex'] ?? json['answer_index'],
      fallback: _asInt(json['a'], fallback: 0),
    ).clamp(0, normalizedOptions.isEmpty ? 0 : normalizedOptions.length - 1);
    final acceptedAnswers = _asStringList(
      json['accepted_answers'] ??
          json['acceptedAnswers'] ??
          json['answers'] ??
          json['ans'],
    );
    final prompt = _asString(
      json['prompt'] ?? json['question'] ?? json['q'],
      fallback: 'Soal ${index + 1} tentang $topic',
    );
    final repairedAnswer = _repairIntegerArithmeticKey(
      prompt: prompt,
      options: normalizedOptions,
      originalIndex: rawCorrectIndex,
    );
    final rawExplanation = _asString(json['explanation'] ?? json['ex']);
    final fallbackExplanation = type == 'fill_blank'
        ? 'Jawaban benar karena sesuai konsep $topic.'
        : type == 'true_false'
        ? 'Pernyataan ini ${rawCorrectIndex == 0 ? 'benar' : 'salah'}, jadi jawaban yang tepat adalah ${normalizedOptions[rawCorrectIndex]}.'
        : 'Jawaban yang benar adalah ${normalizedOptions[rawCorrectIndex]}.';

    return QuizQuestion(
      type: type,
      id: _asString(json['id'], fallback: 'q_${index + 1}'),
      prompt: prompt,
      options: normalizedOptions,
      correctIndex: repairedAnswer.index,
      acceptedAnswers: acceptedAnswers,
      explanation: repairedAnswer.wasRepaired
          ? 'Karena hasil perhitungannya adalah ${normalizedOptions[repairedAnswer.index]}.'
          : _isClippedExplanation(rawExplanation)
          ? fallbackExplanation
          : rawExplanation,
      skillTag: normalizeSkillTag(
        _asString(
          json['skill_tag'] ?? json['skillTag'] ?? json['skill'],
          fallback: topic,
        ),
      ),
      difficulty: _asInt(
        json['difficulty'] ?? json['d'],
        fallback: 1,
      ).clamp(1, 3),
    );
  }

  static List<QuizQuestion> listFromJson(
    Object? decoded, {
    required String topic,
    int desiredCount = 5,
    bool allowFallback = true,
  }) {
    final rawList = decoded is Map<String, dynamic>
        ? decoded['questions']
        : decoded;
    if (rawList is! List) {
      return allowFallback
          ? fallbackList(topic: topic, count: desiredCount)
          : const [];
    }
    final questions = <QuizQuestion>[];
    for (var i = 0; i < rawList.length; i++) {
      final item = rawList[i];
      if (item is Map<String, dynamic>) {
        final question = QuizQuestion.fromJson(item, index: i, topic: topic);
        if (question.isValidObjective) questions.add(question);
      }
    }
    if (questions.isEmpty) {
      return allowFallback
          ? fallbackList(topic: topic, count: desiredCount)
          : const [];
    }
    return questions.take(desiredCount).toList();
  }

  static List<QuizQuestion> fallbackList({
    required String topic,
    int count = 5,
  }) {
    return List.generate(count, (i) {
      return QuizQuestion(
        type: 'multiple_choice',
        id: 'fallback_${i + 1}',
        prompt: 'Manakah pernyataan yang benar tentang $topic?',
        options: const [
          'Konsep ini bisa dipahami dengan contoh sederhana.',
          'Topik ini tidak perlu dipelajari.',
          'Semua jawaban selalu sama.',
          'Tidak ada hubungan dengan pelajaran.',
        ],
        correctIndex: 0,
        acceptedAnswers: const [],
        explanation:
            'Jawaban benar karena $topic dapat dipahami bertahap dengan contoh dan latihan.',
        skillTag: normalizeSkillTag(topic),
        difficulty: 1,
      );
    });
  }

  bool get isFillBlank => type == 'fill_blank';

  bool get isValidObjective {
    if (prompt.trim().isEmpty || explanation.trim().isEmpty) return false;
    if (type == 'fill_blank') {
      return acceptedAnswers.any((answer) => answer.trim().length >= 2);
    }
    if (type == 'true_false') return options.length == 2 && correctIndex < 2;
    return type == 'multiple_choice' &&
        options.length == 4 &&
        options.toSet().length == 4 &&
        correctIndex >= 0 &&
        correctIndex < 4;
  }
}

bool _isClippedExplanation(String value) {
  final trimmed = value.trim();
  if (trimmed.length < 20) return true;
  return !RegExp(r'[.!?]$').hasMatch(trimmed);
}

({int index, bool wasRepaired}) _repairIntegerArithmeticKey({
  required String prompt,
  required List<String> options,
  required int originalIndex,
}) {
  if (options.isEmpty) return (index: originalIndex, wasRepaired: false);
  final lower = prompt.toLowerCase();
  final start = lower.indexOf('dari ');
  if (!lower.contains('hasil') || start == -1) {
    return (index: originalIndex, wasRepaired: false);
  }
  final afterStart = lower.substring(start + 5);
  final endCandidates = [
    afterStart.indexOf(' adalah'),
    afterStart.indexOf(' berapa'),
    afterStart.indexOf('?'),
  ].where((value) => value >= 0).toList();
  final end = endCandidates.isEmpty
      ? afterStart.length
      : endCandidates.reduce((a, b) => a < b ? a : b);
  var expression = afterStart.substring(0, end);
  expression = expression
      .replaceAllMapped(RegExp(r'\((-?\d+)\)'), (match) => match.group(1)!)
      .replaceAll(RegExp(r'[^0-9+\-]'), '');
  if (expression.isEmpty || RegExp(r'[*/:]').hasMatch(expression)) {
    return (index: originalIndex, wasRepaired: false);
  }
  while (expression.contains('--') ||
      expression.contains('+-') ||
      expression.contains('-+')) {
    expression = expression
        .replaceAll('--', '+')
        .replaceAll('+-', '-')
        .replaceAll('-+', '-');
  }
  final signedExpression =
      expression.startsWith('-') || expression.startsWith('+')
      ? expression
      : '+$expression';
  final terms = RegExp(r'[+-]\d+')
      .allMatches(signedExpression)
      .map((match) => int.tryParse(match.group(0)!))
      .whereType<int>()
      .toList();
  if (terms.isEmpty) return (index: originalIndex, wasRepaired: false);
  final expected = terms.fold<int>(0, (sum, term) => sum + term);
  final optionIndex = options.indexWhere(
    (option) => int.tryParse(option.trim()) == expected,
  );
  if (optionIndex == -1 || optionIndex == originalIndex) {
    return (index: originalIndex, wasRepaired: false);
  }
  return (index: optionIndex, wasRepaired: true);
}

String _normalizeQuestionType(Object? value) {
  final raw = value?.toString().toLowerCase().trim() ?? '';
  if (raw == 'tf' || raw.contains('true') || raw.contains('benar_salah')) {
    return 'true_false';
  }
  if (raw == 'fb' ||
      raw.contains('fill') ||
      raw.contains('blank') ||
      raw.contains('isian')) {
    return 'fill_blank';
  }
  return 'multiple_choice';
}

class LearnerSkillMastery {
  final String skillTag;
  final String topicId;
  final int attempts;
  final int correct;
  final int hintCount;
  final double masteryScore;
  final String lastPracticedAt;

  const LearnerSkillMastery({
    required this.skillTag,
    required this.topicId,
    required this.attempts,
    required this.correct,
    required this.hintCount,
    required this.masteryScore,
    required this.lastPracticedAt,
  });

  factory LearnerSkillMastery.fromRow(Map<String, dynamic> row) {
    return LearnerSkillMastery(
      skillTag: _asString(row['skill_tag'], fallback: 'general'),
      topicId: _asString(row['topic_id']),
      attempts: _asInt(row['attempts']),
      correct: _asInt(row['correct']),
      hintCount: _asInt(row['hint_count']),
      masteryScore: _asDouble(row['mastery_score']).clamp(0.0, 1.0),
      lastPracticedAt: _asString(row['last_practiced_at']),
    );
  }
}

class LearnerProfile {
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> preferredExamples;
  final String tone;
  final List<String> reviewTopics;

  const LearnerProfile({
    this.strengths = const [],
    this.weaknesses = const [],
    this.preferredExamples = const [],
    this.tone = 'encouraging',
    this.reviewTopics = const [],
  });

  Map<String, dynamic> toJson() => {
    'strengths': strengths,
    'weaknesses': weaknesses,
    'preferred_examples': preferredExamples,
    'tone': tone,
    'review_topics': reviewTopics,
  };

  String toPromptContext({String? topic}) {
    final filteredReview = topic == null || topic.isEmpty
        ? reviewTopics
        : reviewTopics
              .where((item) => item.toLowerCase().contains(topic.toLowerCase()))
              .toList();
    final review = filteredReview.isEmpty
        ? reviewTopics.take(3).toList()
        : filteredReview.take(3).toList();
    return [
      if (strengths.isNotEmpty) 'Kekuatan: ${strengths.take(3).join(", ")}.',
      if (weaknesses.isNotEmpty)
        'Perlu bantuan: ${weaknesses.take(3).join(", ")}.',
      if (preferredExamples.isNotEmpty)
        'Contoh yang disukai: ${preferredExamples.take(3).join(", ")}.',
      if (review.isNotEmpty) 'Topik review: ${review.join(", ")}.',
      'Nada belajar: $tone.',
    ].join(' ');
  }

  factory LearnerProfile.fromJsonString(String jsonText) {
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is Map<String, dynamic>) {
        return LearnerProfile.fromJson(decoded);
      }
    } catch (_) {}
    return const LearnerProfile();
  }

  factory LearnerProfile.fromJson(Map<String, dynamic> json) {
    return LearnerProfile(
      strengths: _asStringList(json['strengths']),
      weaknesses: _asStringList(json['weaknesses']),
      preferredExamples: _asStringList(
        json['preferred_examples'] ?? json['preferredExamples'],
      ),
      tone: _asString(json['tone'], fallback: 'encouraging'),
      reviewTopics: _asStringList(
        json['review_topics'] ?? json['reviewTopics'],
      ),
    );
  }
}

String normalizeSkillTag(String input) {
  final normalized = input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9A-Z\u00C0-\u024F]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return normalized.isEmpty ? 'general' : normalized;
}
