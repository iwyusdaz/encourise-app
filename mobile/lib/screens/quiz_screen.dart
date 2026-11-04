import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/learning_models.dart';
import '../models/session_state.dart';
import '../services/database_service.dart';
import '../services/difficulty_adapter.dart';
import '../services/gemma_runtime.dart';
import '../services/session_manager.dart';
import '../services/structured_tutor_service.dart';
import '../services/tutor_capability.dart';
import '../utils/encourise_theme.dart';
import '../utils/key_concepts.dart';
import '../utils/prompt_builder.dart';
import '../utils/text_utils.dart';
import 'session_summary_screen.dart';

/// Deterministic self-test quiz screen.
class QuizScreen extends StatefulWidget {
  final String subject;
  final String topic;
  final int grade;
  final int questionCount;
  final List<QuizQuestion>? initialQuestions;
  final bool disablePersistence;
  final String testStudentId;

  const QuizScreen({
    super.key,
    required this.subject,
    required this.topic,
    required this.grade,
    this.questionCount = 3,
    this.initialQuestions,
    this.disablePersistence = false,
    this.testStudentId = 'test_student',
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  static const _capability = TutoringCapability.quiz;

  late final SessionManager _session;
  late final DifficultyAdapter _adapter;
  late final SessionState _state;

  final List<QuizQuestion> _questions = [];
  final List<Map<String, dynamic>> _answers = [];

  bool _isLoading = true;
  bool _isPrefetching = false;
  bool _sessionFinished = false;
  int _currentIndex = 0;
  int? _selectedIndex;
  String? _fillBlankAnswer;
  int _earnedXp = 0;
  String _studentId = 'unknown';
  String _explanation = '';
  String _keyConcepts = '';
  int _batchNumber = 1;
  String _loadingMessage = 'Membuat soal 1 dari 3';
  String? _quizError;
  Future<QuizQuestion?>? _nextQuestionFuture;
  final Set<String> _missedSkillTags = {};

  QuizQuestion? get _currentQuestion =>
      _currentIndex < _questions.length ? _questions[_currentIndex] : null;

  int get _targetQuestionCount =>
      widget.initialQuestions?.length ?? widget.questionCount;

  @override
  void initState() {
    super.initState();
    _adapter = DifficultyAdapter();
    _state = SessionState(
      sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
      topic: widget.topic,
      grade: widget.grade,
      subject: widget.subject,
    );
    if (widget.initialQuestions != null) {
      _studentId = widget.testStudentId;
      _questions.addAll(widget.initialQuestions!);
      _isLoading = false;
      return;
    }
    _startQuiz();
  }

  Future<void> _startQuiz() async {
    setState(() {
      _isLoading = true;
      _quizError = null;
      _loadingMessage = 'Membuat soal 1 dari $_targetQuestionCount';
    });

    final db = DatabaseService.instance;
    final student = await db.getStudent();
    final studentName = student?['name'] as String? ?? 'Siswa';
    _studentId = student?['id'] as String? ?? 'unknown';
    final teachingStyle =
        student?['teaching_style'] as String? ?? 'encouraging';
    final memory = await db.getLearnerMemory(_studentId);
    final memorySummary = memory?['summary_text'] as String? ?? '';
    final profile = LearnerProfile.fromJsonString(
      memory?['profile_json'] as String? ?? '{}',
    );
    final concepts = getKeyConcepts(widget.subject, widget.grade, widget.topic);
    _keyConcepts = concepts;

    _session = SessionManager(
      runtime: GemmaRuntime.instance,
      systemPrompt: buildSystemPrompt(
        grade: widget.grade,
        subject: widget.subject,
        studentName: studentName,
        keyConcepts: concepts,
        teachingStyle: teachingStyle,
        learnerMemory: [
          if (memorySummary.isNotEmpty) memorySummary,
          profile.toPromptContext(topic: widget.topic),
        ].where((item) => item.trim().isNotEmpty).join('\n'),
      ),
    );

    await _session.startConversation();
    final quizTimer = Stopwatch()..start();
    final generated = await _getOrGenerateQuestion(
      questionNumber: 1,
      preferCache: true,
    );
    quizTimer.stop();
    unawaited(
      DatabaseService.instance.saveModelStatus(
        'last_quiz_start_time_ms',
        '${quizTimer.elapsedMilliseconds}',
      ),
    );

    if (!mounted) return;
    setState(() {
      _questions
        ..clear()
        ..addAll(generated == null ? const [] : [generated]);
      _quizError = generated == null
          ? 'Budi belum bisa membuat soal. Coba lagi dengan koneksi model yang sama.'
          : null;
      _isLoading = false;
    });
    if (generated != null) _prefetchNextQuestion();
  }

  Future<void> _loadNextBatch() async {
    if (_questions.length >= widget.questionCount) {
      _endQuiz();
      return;
    }
    setState(() {
      _isLoading = true;
      _quizError = null;
      _loadingMessage =
          'Membuat soal ${_questions.length + 1} dari $_targetQuestionCount';
    });

    final generated =
        await (_nextQuestionFuture ??
            _getOrGenerateQuestion(
              questionNumber: _questions.length + 1,
              preferCache: true,
            ));
    _nextQuestionFuture = null;
    if (!mounted) return;
    if (generated == null) {
      setState(() {
        _quizError =
            'Budi belum bisa membuat soal berikutnya. Jawabanmu tetap tersimpan.';
        _isLoading = false;
      });
      return;
    }
    setState(() {
      _questions.add(generated);
      _currentIndex = _questions.length - 1;
      _selectedIndex = null;
      _fillBlankAnswer = null;
      _explanation = '';
      _isLoading = false;
    });
    _prefetchNextQuestion();
  }

  Future<QuizQuestion?> _getOrGenerateQuestion({
    required int questionNumber,
    required bool preferCache,
  }) async {
    if (preferCache) {
      final cached = await _getCachedQuestion();
      if (cached != null) {
        unawaited(
          DatabaseService.instance.saveModelStatus(
            'last_quiz_generation_source',
            'cache',
          ),
        );
        return cached;
      }
    }

    _batchNumber = questionNumber;
    final generated = await StructuredTutorService.generateQuizBatch(
      session: _session,
      topic: widget.topic,
      subject: widget.subject,
      grade: widget.grade,
      questionCount: 1,
      keyConcepts: _keyConcepts,
      batchNumber: _batchNumber,
      previousAccuracy: _adapter.accuracy,
      missedSkillTags: _missedSkillTags.toList(),
    );
    if (generated.isEmpty) return null;
    unawaited(
      DatabaseService.instance.saveQuizQuestionsToCache(
        subject: widget.subject,
        topicId: widget.topic,
        grade: widget.grade,
        questions: generated,
      ),
    );
    return generated.first;
  }

  Future<QuizQuestion?> _getCachedQuestion() {
    final excludeIds = _questions.map((question) => question.id).toSet();
    final excludePrompts = _questions
        .map((question) => question.prompt.trim())
        .where((prompt) => prompt.isNotEmpty)
        .toSet();
    return DatabaseService.instance.getCachedQuizQuestion(
      subject: widget.subject,
      topicId: widget.topic,
      grade: widget.grade,
      difficulty: _adapter.currentLevel,
      preferredSkillTags: _missedSkillTags.toList(),
      excludeIds: excludeIds,
      excludePrompts: excludePrompts,
    );
  }

  void _prefetchNextQuestion() {
    if (widget.initialQuestions != null ||
        _questions.length >= _targetQuestionCount ||
        _nextQuestionFuture != null) {
      return;
    }
    setState(() => _isPrefetching = true);
    // LiteRT-LM has a single active conversation; speculative background
    // generation can cancel the foreground prefill on some devices. Keep this
    // preload cache-only so it improves repeat topics without destabilizing
    // the current quiz.
    final future = _getCachedQuestion();
    _nextQuestionFuture = future;
    unawaited(
      future.whenComplete(() {
        if (!mounted || _nextQuestionFuture != future) return;
        setState(() => _isPrefetching = false);
      }),
    );
  }

  Future<void> _chooseAnswer(int index) async {
    final question = _currentQuestion;
    if (question == null || _selectedIndex != null || _sessionFinished) return;

    final isCorrect = index == question.correctIndex;
    await _recordAnswer(question, isCorrect, selectedIndex: index);
  }

  Future<void> _chooseFillBlank(String answer) async {
    final question = _currentQuestion;
    if (question == null ||
        _selectedIndex != null ||
        _fillBlankAnswer != null ||
        _sessionFinished) {
      return;
    }
    final normalized = _normalizeAnswer(answer);
    final isCorrect = question.acceptedAnswers
        .map(_normalizeAnswer)
        .contains(normalized);
    await _recordAnswer(question, isCorrect, fillBlankAnswer: answer);
  }

  Future<void> _recordAnswer(
    QuizQuestion question,
    bool isCorrect, {
    int? selectedIndex,
    String? fillBlankAnswer,
  }) async {
    if (!widget.disablePersistence) {
      unawaited(
        DatabaseService.instance
            .recordSkillAttempt(
              studentId: _studentId,
              topicId: widget.topic,
              skillTag: question.skillTag,
              isCorrect: isCorrect,
              hintUsed: false,
            )
            .then((_) {})
            .catchError((_) {}),
      );
    }

    _adapter.recordStructuredAnswer(
      isCorrect: isCorrect,
      confidence: 1.0,
      hintUsed: false,
    );
    _state.syncFromAdapter(_adapter);

    _answers.add({
      'question_id': question.id,
      'type': question.type,
      'prompt': question.prompt,
      'selected_index': selectedIndex,
      'fill_blank_answer': fillBlankAnswer,
      'correct_index': question.correctIndex,
      'accepted_answers': question.acceptedAnswers,
      'is_correct': isCorrect,
      'skill_tag': question.skillTag,
      'difficulty': question.difficulty,
    });

    if (!isCorrect) _missedSkillTags.add(question.skillTag);

    setState(() {
      _selectedIndex = selectedIndex ?? -1;
      _fillBlankAnswer = fillBlankAnswer;
      _explanation = question.explanation;
    });
  }

  Future<void> _nextQuestion() async {
    if (_currentIndex >= _questions.length - 1) {
      if (widget.initialQuestions != null) {
        _endQuiz();
        return;
      }
      await _loadNextBatch();
      return;
    }
    setState(() {
      _currentIndex++;
      _selectedIndex = null;
      _fillBlankAnswer = null;
      _explanation = '';
    });
  }

  void _endQuiz() {
    final xp = (_adapter.correctAnswers * 10) + (_adapter.currentLevel * 5);
    _earnedXp = xp;
    _saveSession(xp);
    setState(() => _sessionFinished = true);
  }

  void _goToSummary() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SessionSummaryScreen(
          subject: widget.subject,
          topic: widget.topic,
          grade: widget.grade,
          correctAnswers: _adapter.correctAnswers,
          totalQuestions: _adapter.totalQuestions,
          xpEarned: _earnedXp,
          finalLevel: _adapter.currentLevel,
          isFlagged: _adapter.isFlagged,
        ),
      ),
    );
  }

  Future<void> _saveSession(int xp) async {
    if (widget.disablePersistence) return;
    try {
      final db = DatabaseService.instance;
      final conversationJson = jsonEncode({
        'mode': _capability.sessionType,
        'questions': _questions.map((q) => q.toJson()).toList(),
        'answers': _answers,
        'skill_tags': _answers.map((a) => a['skill_tag']).toSet().toList(),
      });

      final sessionData = {
        'id': _state.sessionId,
        'student_id': _studentId,
        'topic_id': widget.topic,
        'started_at': DateTime.fromMillisecondsSinceEpoch(
          int.tryParse(_state.sessionId) ?? 0,
        ).toIso8601String(),
        'ended_at': DateTime.now().toIso8601String(),
        'questions': _adapter.totalQuestions,
        'correct': _adapter.correctAnswers,
        'xp_earned': xp,
        'mode': _capability.sessionType,
        'conversation_json': conversationJson,
      };

      await db.saveSession(sessionData);
      await db.upsertTopicProgress({
        'student_id': _studentId,
        'topic_id': widget.topic,
        'status': _adapter.isFlagged
            ? 'flagged'
            : (_adapter.accuracy >= 0.8 ? 'mastered' : 'in_progress'),
        'current_level': _adapter.currentLevel,
        'accuracy': _adapter.accuracy,
        'attempts': _adapter.totalQuestions,
        'mastered_at': _adapter.accuracy >= 0.8
            ? DateTime.now().toIso8601String()
            : null,
      });

      await db.addToSyncQueue({
        'id': 'sync_${_state.sessionId}',
        'payload_json': jsonEncode({
          'table': 'sessions_cloud',
          'data': {
            'id': _state.sessionId,
            'device_uuid': _studentId,
            'topic_id': widget.topic,
            'started_at': sessionData['started_at'],
            'correct': _adapter.correctAnswers,
            'accuracy': _adapter.accuracy,
            'xp': xp,
            'mode': _capability.sessionType,
          },
        }),
        'created_at': DateTime.now().toIso8601String(),
        'retry_count': 0,
      });
    } catch (e) {
      // ignore: avoid_print
      print('[QuizScreen] Failed to save session: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjectLabel = _subjectLabel(widget.subject);
    return Scaffold(
      backgroundColor: EncouriseColors.background,
      body: Column(
        children: [
          _buildTopBar(subjectLabel),
          _buildProgressBar(),
          Expanded(child: _buildContent()),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildTopBar(String subjectLabel) {
    return Container(
      decoration: const BoxDecoration(color: EncouriseColors.background),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 16, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                color: EncouriseColors.textPrimary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tes Diri • $subjectLabel',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: EncouriseColors.textPrimary,
                      ),
                    ),
                    Text(
                      widget.topic,
                      style: EncouriseTextStyles.bodySm,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const EncouriseStatusPill(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = _targetQuestionCount <= 0
        ? 0.0
        : (_questions.isEmpty ? 0 : _currentIndex + 1) / _targetQuestionCount;
    final currentLabel = _questions.isEmpty ? 0 : _currentIndex + 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(EncouriseRadius.pill),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: EncouriseColors.border,
                color: EncouriseColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Soal $currentLabel/$_targetQuestionCount',
            style: EncouriseTextStyles.labelSm,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: EncouriseColors.primary),
            const SizedBox(height: 16),
            Text(_loadingMessage, style: EncouriseTextStyles.bodySm),
          ],
        ),
      );
    }

    if (_sessionFinished) {
      return _buildFinishedView();
    }

    if (_questions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _quizError ?? 'Budi belum bisa menyiapkan kuis.',
                style: EncouriseTextStyles.h3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              EncouriseGradientButton(
                label: 'Coba Lagi',
                icon: Icons.refresh_rounded,
                onPressed: _startQuiz,
              ),
            ],
          ),
        ),
      );
    }
    final question = _currentQuestion;
    if (question == null) return _buildFinishedView();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        EncouriseCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pertanyaan',
                style: EncouriseTextStyles.labelSm.copyWith(
                  color: EncouriseColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                sanitizeLatex(question.prompt),
                style: EncouriseTextStyles.h3.copyWith(height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (question.isFillBlank)
          _buildFillBlank(question)
        else
          ...List.generate(question.options.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildOption(question, index),
            );
          }),
        if (_explanation.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildExplanation(question),
        ],
        if (_isPrefetching) ...[
          const SizedBox(height: 12),
          Text(
            'Budi menyiapkan soal berikutnya...',
            style: EncouriseTextStyles.bodySm,
          ),
        ],
      ],
    );
  }

  Widget _buildOption(QuizQuestion question, int index) {
    final answered = _selectedIndex != null;
    final isCorrect = index == question.correctIndex;
    final isSelected = index == _selectedIndex;
    Color borderColor = EncouriseColors.border;
    Color fillColor = EncouriseColors.surface;
    IconData? icon;

    if (answered && isCorrect) {
      borderColor = EncouriseColors.primary;
      fillColor = EncouriseColors.primarySurface;
      icon = Icons.check_circle_rounded;
    } else if (answered && isSelected) {
      borderColor = EncouriseColors.error;
      fillColor = EncouriseColors.errorLight;
      icon = Icons.cancel_rounded;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: answered ? null : () => _chooseAnswer(index),
        borderRadius: BorderRadius.circular(EncouriseRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(EncouriseRadius.lg),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: EncouriseShadows.soft,
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: borderColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  String.fromCharCode(65 + index),
                  style: EncouriseTextStyles.labelSm.copyWith(
                    color: borderColor == EncouriseColors.border
                        ? EncouriseColors.textPrimary
                        : borderColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  sanitizeLatex(question.options[index]),
                  style: EncouriseTextStyles.bodyMd,
                ),
              ),
              if (icon != null) Icon(icon, color: borderColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFillBlank(QuizQuestion question) {
    final controller = TextEditingController();
    final answered = _fillBlankAnswer != null;
    return EncouriseCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            enabled: !answered,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: answered
                  ? _fillBlankAnswer
                  : 'Tulis jawaban singkat...',
              border: const OutlineInputBorder(),
            ),
            onSubmitted: _chooseFillBlank,
          ),
          const SizedBox(height: 10),
          EncouriseGradientButton(
            label: answered ? 'Sudah Dijawab' : 'Periksa Jawaban',
            icon: answered ? Icons.check_rounded : Icons.check_circle_rounded,
            onPressed: answered
                ? null
                : () => _chooseFillBlank(controller.text),
          ),
        ],
      ),
    );
  }

  Widget _buildExplanation(QuizQuestion question) {
    final correct = question.isFillBlank
        ? question.acceptedAnswers
              .map(_normalizeAnswer)
              .contains(_normalizeAnswer(_fillBlankAnswer ?? ''))
        : _selectedIndex == question.correctIndex;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: correct
            ? EncouriseColors.primarySurface
            : EncouriseColors.warningLight,
        borderRadius: BorderRadius.circular(EncouriseRadius.lg),
        border: Border.all(
          color: correct
              ? EncouriseColors.primary.withValues(alpha: 0.25)
              : EncouriseColors.warning.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            correct
                ? Icons.check_circle_outline_rounded
                : Icons.lightbulb_outline_rounded,
            color: correct ? EncouriseColors.primary : EncouriseColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              sanitizeLatex(_explanation),
              style: EncouriseTextStyles.bodySm.copyWith(
                color: EncouriseColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    if (_isLoading) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: BoxDecoration(
        color: EncouriseColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: EncouriseShadows.bottomNav,
      ),
      child: SafeArea(
        top: false,
        child: EncouriseGradientButton(
          label: _sessionFinished
              ? 'Lihat Ringkasan'
              : (_currentIndex >= _questions.length - 1 &&
                        (widget.initialQuestions != null ||
                            _questions.length >= widget.questionCount)
                    ? 'Selesaikan Kuis'
                    : 'Soal Berikutnya'),
          onPressed: _sessionFinished
              ? _goToSummary
              : (_selectedIndex == null && _fillBlankAnswer == null
                    ? null
                    : _nextQuestion),
          icon: _sessionFinished
              ? Icons.assessment_rounded
              : Icons.arrow_forward_rounded,
        ),
      ),
    );
  }

  Widget _buildFinishedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: const BoxDecoration(
                color: EncouriseColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: EncouriseColors.primary,
                size: 42,
              ),
            ),
            const SizedBox(height: 18),
            Text('Kuis selesai!', style: EncouriseTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              'Benar ${_adapter.correctAnswers}/${_adapter.totalQuestions} • XP +$_earnedXp',
              style: EncouriseTextStyles.bodyMd,
            ),
          ],
        ),
      ),
    );
  }

  String _subjectLabel(String subject) {
    const names = {
      'math': 'Matematika',
      'matematika': 'Matematika',
      'bahasa': 'Bahasa Indonesia',
      'bahasa_indonesia': 'Bahasa Indonesia',
      'science': 'IPA',
      'ipa': 'IPA',
      'social': 'IPS',
      'ips': 'IPS',
    };
    return names[subject.toLowerCase()] ?? subject;
  }

  String _normalizeAnswer(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
