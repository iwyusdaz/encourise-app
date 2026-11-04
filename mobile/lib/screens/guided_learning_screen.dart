import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/session_manager.dart';
import '../services/gemma_runtime.dart';
import '../services/database_service.dart';
import '../services/structured_tutor_service.dart';
import '../services/tutor_capability.dart';
import '../models/learning_models.dart';
import '../utils/prompt_builder.dart';
import '../utils/key_concepts.dart';
import '../utils/text_utils.dart';
import '../utils/encourise_theme.dart';

/// Structured multi-step guided learning journey.
class GuidedLearningScreen extends StatefulWidget {
  final String subject;
  final String topic;
  final int grade;
  final List<Map<String, dynamic>>? initialSteps;

  const GuidedLearningScreen({
    super.key,
    required this.subject,
    required this.topic,
    required this.grade,
    this.initialSteps,
  });

  @override
  State<GuidedLearningScreen> createState() => _GuidedLearningScreenState();
}

class _GuidedLearningScreenState extends State<GuidedLearningScreen> {
  static const _capability = TutoringCapability.guided;

  late SessionManager _session;

  final List<_ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  bool _isLoading = true;
  bool _sessionFinished = false;
  String? _pendingRetryAnswer;

  // Guided session state
  String _guidedSessionId = '';
  String _studentId = 'unknown';
  String _startedAt = '';
  String _keyConcepts = '';
  List<Map<String, dynamic>> _steps = [];
  int _currentStep = 0;
  int _userMessagesInStep = 0;

  @override
  void initState() {
    super.initState();
    _initGuidedSession();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Initialization
  // -----------------------------------------------------------------------

  Future<void> _initGuidedSession() async {
    if (widget.initialSteps != null) {
      _studentId = 'test_student';
      _guidedSessionId = 'test_guided_session';
      _startedAt = DateTime.now().toIso8601String();
      _steps = widget.initialSteps!;
      final stepTitle = _steps.first['title'] ?? 'Langkah 1';
      setState(() {
        _messages.add(
          _ChatMessage(
            role: 'model',
            text: _buildStepIntro('Siswa', stepTitle, 1),
          ),
        );
        _isLoading = false;
      });
      _focusAnswerInput();
      return;
    }

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

    final systemPrompt = buildSystemPrompt(
      grade: widget.grade,
      subject: widget.subject,
      studentName: studentName,
      keyConcepts: concepts,
      teachingStyle: teachingStyle,
      learnerMemory: [
        if (memorySummary.isNotEmpty) memorySummary,
        profile.toPromptContext(topic: widget.topic),
      ].where((item) => item.trim().isNotEmpty).join('\n'),
    );

    _session = SessionManager(
      runtime: GemmaRuntime.instance,
      systemPrompt: systemPrompt,
    );
    await _session.startConversation();

    // Check for existing in-progress guided session
    final existing = await db.getOpenGuidedSession(_studentId, widget.topic);

    if (existing != null) {
      // Resume
      _guidedSessionId = existing['id'] as String;
      _currentStep = existing['current_step'] as int;
      _startedAt =
          existing['started_at'] as String? ?? DateTime.now().toIso8601String();
      try {
        _steps = (jsonDecode(existing['steps_json'] as String) as List)
            .cast<Map<String, dynamic>>();
      } catch (_) {
        _steps = _fallbackSteps();
      }

      // Show completed step markers so user sees their progress
      final resumeMessages = <_ChatMessage>[];
      for (int i = 0; i < _currentStep; i++) {
        final title = _steps[i]['title'] as String? ?? 'Langkah ${i + 1}';
        resumeMessages.add(
          _ChatMessage(
            role: 'system',
            text: 'Langkah ${i + 1}: $title selesai',
          ),
        );
      }
      final stepTitle =
          _steps[_currentStep]['title'] ?? 'Langkah ${_currentStep + 1}';
      resumeMessages.add(
        _ChatMessage(
          role: 'system',
          text: 'Melanjutkan Langkah ${_currentStep + 1}: $stepTitle',
        ),
      );

      setState(() {
        _messages.addAll(resumeMessages);
        _isLoading = true;
      });
      await _addStepIntro(studentName, stepTitle, _currentStep + 1);
      _scrollToBottom();
      _focusAnswerInput();
    } else {
      // New guided session — ask Gemma to generate steps
      _guidedSessionId = 'guided_${DateTime.now().millisecondsSinceEpoch}';
      _startedAt = DateTime.now().toIso8601String();

      _steps = await StructuredTutorService.generateGuidedPlan(
        session: _session,
        topic: widget.topic,
        grade: widget.grade,
        subject: widget.subject,
        keyConcepts: concepts,
      );
      if (_steps.isEmpty) {
        setState(() {
          _messages.add(
            const _ChatMessage(
              role: 'model',
              text:
                  'Budi belum bisa membuat jalur belajar. Coba buka ulang Jalur Belajar sebentar lagi.',
            ),
          );
          _isLoading = false;
        });
        return;
      }

      // Save guided session
      await db.saveGuidedSession({
        'id': _guidedSessionId,
        'student_id': _studentId,
        'topic_id': widget.topic,
        'steps_json': jsonEncode(_steps),
        'current_step': 0,
        'status': 'in_progress',
        'started_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Now start the first step
      final stepTitle = _steps[0]['title'] ?? 'Langkah 1';

      await _addStepIntro(studentName, stepTitle, 1);
      _scrollToBottom();
      _focusAnswerInput();
    }
  }

  Future<void> _addStepIntro(
    String studentName,
    Object? stepTitle,
    int stepNumber,
  ) async {
    final index = stepNumber - 1;
    final step = _steps[index];
    final cachedContent = step['content']?.toString().trim() ?? '';
    final generated = cachedContent.isNotEmpty
        ? cachedContent
        : await StructuredTutorService.generateGuidedStepContent(
            session: _session,
            topic: widget.topic,
            grade: widget.grade,
            stepNumber: stepNumber,
            stepTitle: stepTitle?.toString() ?? 'Langkah $stepNumber',
            stepDescription: step['description']?.toString() ?? widget.topic,
            keyConcepts: _keyConcepts,
          );
    if (generated != null && cachedContent.isEmpty) {
      _steps[index] = {...step, 'content': generated};
      unawaited(_saveCurrentGuidedState(status: 'in_progress'));
    }
    if (!mounted) return;
    setState(() {
      _messages.add(
        _ChatMessage(
          role: 'model',
          text:
              generated ??
              'Budi belum bisa menyiapkan isi langkah ini. Coba kembali lalu buka Jalur Belajar lagi.',
        ),
      );
      _isLoading = false;
    });
  }

  String _buildStepIntro(
    String studentName,
    Object? stepTitle,
    int stepNumber,
  ) {
    return _buildStepContent(stepTitle, stepNumber);
  }

  String _buildStepContent(Object? stepTitle, int stepNumber) {
    final title = stepTitle?.toString() ?? 'Langkah $stepNumber';
    return 'Konsep: $title adalah bagian untuk memahami ${widget.topic} secara bertahap.\n\n'
        'Contoh: ${_exampleForTopic()}\n\n'
        'Tugas: jelaskan satu contoh ${widget.topic} dengan caramu sendiri dalam 1-2 kalimat.';
  }

  String _exampleForTopic() {
    final topic = widget.topic.toLowerCase();
    if (topic.contains('pecahan')) {
      return '3/8 berarti 3 dari 8 bagian yang sama besar.';
    }
    if (topic.contains('perbandingan')) {
      return 'Jika 2 buku harganya Rp10.000, maka 1 buku harganya Rp5.000.';
    }
    if (topic.contains('plsv')) {
      return 'Pada x + 3 = 7, nilai x adalah 4.';
    }
    if (topic.contains('himpunan')) {
      return 'A = {2, 4, 6} adalah himpunan bilangan genap kecil.';
    }
    return 'Ambil satu soal sederhana, tulis informasi pentingnya, lalu selesaikan langkah demi langkah.';
  }

  List<Map<String, dynamic>> _fallbackSteps() {
    return [
      {
        'step': 1,
        'title': 'Pengertian Dasar',
        'description': 'Memahami konsep dasar ${widget.topic}',
      },
      {
        'step': 2,
        'title': 'Contoh dan Latihan',
        'description': 'Berlatih dengan contoh soal ${widget.topic}',
      },
      {
        'step': 3,
        'title': 'Pendalaman',
        'description':
            'Menguasai ${widget.topic} dengan soal yang lebih menantang',
      },
    ];
  }

  // -----------------------------------------------------------------------
  // Chat & Step navigation
  // -----------------------------------------------------------------------

  Future<void> _submitMessage(String text) async {
    if (text.trim().isEmpty || _isLoading || _sessionFinished) return;

    _inputController.clear();
    await _evaluateMessage(text, addUserMessage: true);
  }

  Future<void> _retryPendingMessage() async {
    final answer = _pendingRetryAnswer;
    if (answer == null || _isLoading || _sessionFinished) return;
    setState(() => _pendingRetryAnswer = null);
    await _evaluateMessage(answer, addUserMessage: false);
  }

  Future<void> _evaluateMessage(
    String text, {
    required bool addUserMessage,
  }) async {
    setState(() {
      if (addUserMessage) {
        _messages.add(_ChatMessage(role: 'user', text: text));
        _userMessagesInStep++;
      }
      _isLoading = true;
    });
    _scrollToBottom();

    final result = await StructuredTutorService.evaluateAnswer(
      session: _session,
      topic: widget.topic,
      studentAnswer: text,
      grade: widget.grade,
      difficulty: _currentStep + 1,
      skillTag: _steps[_currentStep]['title'] as String? ?? widget.topic,
      keyConcepts: _keyConcepts,
      teachingMode: 'guided',
    );
    final response = result.studentText;

    setState(() {
      _messages.add(_ChatMessage(role: 'model', text: response));
      _pendingRetryAnswer =
          result.rawResponse.startsWith('[timeout]') ||
              result.rawResponse.startsWith('[invalid_json]') ||
              result.rawResponse.startsWith('[model_error]')
          ? text
          : null;
      _isLoading = false;
    });
    _scrollToBottom();
    _focusAnswerInput();
  }

  Future<void> _nextStep() async {
    if (_currentStep >= _steps.length - 1) {
      // Last step — finish
      await _finishGuidedSession();
      return;
    }

    _currentStep++;
    _userMessagesInStep = 0;

    // Persist progress
    final db = DatabaseService.instance;
    final completedStep =
        _steps[_currentStep - 1]['title'] as String? ?? 'Langkah $_currentStep';
    await db.recordSkillAttempt(
      studentId: _studentId,
      topicId: widget.topic,
      skillTag: completedStep,
      isCorrect: true,
      hintUsed: false,
    );
    await _saveCurrentGuidedState(status: 'in_progress');

    setState(() => _isLoading = true);

    final stepTitle =
        _steps[_currentStep]['title'] ?? 'Langkah ${_currentStep + 1}';
    final cachedContent =
        _steps[_currentStep]['content']?.toString().trim() ?? '';
    final response = cachedContent.isNotEmpty
        ? cachedContent
        : await StructuredTutorService.generateGuidedStepContent(
                session: _session,
                topic: widget.topic,
                grade: widget.grade,
                stepNumber: _currentStep + 1,
                stepTitle: stepTitle.toString(),
                stepDescription:
                    _steps[_currentStep]['description']?.toString() ??
                    widget.topic,
                keyConcepts: _keyConcepts,
              ) ??
              'Budi belum bisa menyiapkan langkah berikutnya. Coba tekan Langkah Berikutnya lagi sebentar lagi.';
    if (cachedContent.isEmpty &&
        !response.startsWith('Budi belum bisa menyiapkan')) {
      _steps[_currentStep] = {..._steps[_currentStep], 'content': response};
      unawaited(_saveCurrentGuidedState(status: 'in_progress'));
    }

    setState(() {
      _messages.add(
        _ChatMessage(
          role: 'system',
          text: 'Langkah ${_currentStep + 1}: $stepTitle',
        ),
      );
      _messages.add(_ChatMessage(role: 'model', text: response));
      _isLoading = false;
    });
    _scrollToBottom();
    _focusAnswerInput();
  }

  Future<void> _saveCurrentGuidedState({required String status}) async {
    if (_guidedSessionId.isEmpty) return;
    await DatabaseService.instance.saveGuidedSession({
      'id': _guidedSessionId,
      'student_id': _studentId,
      'topic_id': widget.topic,
      'steps_json': jsonEncode(_steps),
      'current_step': _currentStep,
      'status': status,
      'started_at': _startedAt.isNotEmpty
          ? _startedAt
          : DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _finishGuidedSession() async {
    setState(() => _isLoading = true);

    final summaryResponse =
        '${widget.topic} sudah kamu latih lewat pengertian, contoh, dan pendalaman. '
        'Lanjutkan dengan 3 soal sejenis dan cek bagian yang masih membuat ragu.';

    // Mark guided session complete
    final db = DatabaseService.instance;
    final now = DateTime.now().toIso8601String();
    await db.saveGuidedSession({
      'id': _guidedSessionId,
      'student_id': _studentId,
      'topic_id': widget.topic,
      'steps_json': jsonEncode(_steps),
      'current_step': _currentStep,
      'status': 'completed',
      'started_at': _startedAt,
      'updated_at': now,
    });

    // Save a session record (same as tutoring/quiz) so it appears in history
    final xp = _steps.length * 15;
    for (final step in _steps) {
      await db.recordSkillAttempt(
        studentId: _studentId,
        topicId: widget.topic,
        skillTag: step['title'] as String? ?? widget.topic,
        isCorrect: true,
        hintUsed: false,
      );
    }
    await db.saveSession({
      'id': _guidedSessionId,
      'student_id': _studentId,
      'topic_id': widget.topic,
      'started_at': _startedAt.isNotEmpty ? _startedAt : now,
      'ended_at': now,
      'questions': _steps.length,
      'correct': _steps.length,
      'xp_earned': xp,
      'mode': _capability.sessionType,
    });

    // Queue for sync to teacher dashboard
    await db.addToSyncQueue({
      'id': 'sync_$_guidedSessionId',
      'payload_json': jsonEncode({
        'table': 'sessions_cloud',
        'data': {
          'id': _guidedSessionId,
          'device_uuid': _studentId,
          'topic_id': widget.topic,
          'started_at': _startedAt.isNotEmpty ? _startedAt : now,
          'correct': _steps.length,
          'accuracy': 1.0,
          'xp': xp,
          'mode': _capability.sessionType,
        },
      }),
      'created_at': now,
      'retry_count': 0,
    });

    setState(() {
      _messages.add(_ChatMessage(role: 'model', text: summaryResponse));
      _sessionFinished = true;
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _focusAnswerInput() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isLoading || _sessionFinished) {
        return;
      }
      _inputFocusNode.requestFocus();
    });
  }

  // -----------------------------------------------------------------------
  // UI
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EncouriseColors.background,
      body: Column(
        children: [
          _buildTopBar(),
          if (_steps.isNotEmpty) _buildStepper(),
          Expanded(child: _buildChatArea()),
          if (_pendingRetryAnswer != null) _buildRetryBox(),
          if (_sessionFinished) _buildFinishedBar() else _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final subjectNames = {
      'math': 'Matematika',
      'matematika': 'Matematika',
      'bahasa': 'Bahasa Indonesia',
      'bahasa_indonesia': 'Bahasa Indonesia',
      'science': 'IPA',
      'ipa': 'IPA',
      'social': 'IPS',
      'ips': 'IPS',
    };
    final subjectLabel =
        subjectNames[widget.subject.toLowerCase()] ?? widget.subject;

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
                      'Jalur Belajar • $subjectLabel',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: EncouriseColors.textPrimary,
                      ),
                    ),
                    Text(
                      widget.topic,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: EncouriseColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const EncouriseStatusPill(),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: EncouriseColors.warningLight,
                  borderRadius: BorderRadius.circular(EncouriseRadius.pill),
                ),
                child: Text(
                  'Langkah ${_currentStep + 1}/${_steps.isEmpty ? "?" : _steps.length}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: EncouriseColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepper() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        children: [
          Row(
            children: List.generate(_steps.length, (i) {
              final isCompleted = i < _currentStep;
              final isCurrent = i == _currentStep;
              final isLast = i == _steps.length - 1;

              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: isCompleted || isCurrent
                                  ? EncouriseColors.primary
                                  : EncouriseColors.divider,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: isCompleted
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  )
                                : Text(
                                    '${i + 1}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: isCurrent
                                          ? Colors.white
                                          : EncouriseColors.textMuted,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            _steps[i]['title'] as String? ?? 'Langkah ${i + 1}',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              color: isCurrent
                                  ? EncouriseColors.textPrimary
                                  : EncouriseColors.textMuted,
                              fontWeight: isCurrent
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 18,
                        height: 3,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? EncouriseColors.primary
                              : EncouriseColors.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          _buildCurrentStepCard(),
        ],
      ),
    );
  }

  Widget _buildCurrentStepCard() {
    final step = _steps[_currentStep];
    final title = step['title'] as String? ?? 'Langkah ${_currentStep + 1}';
    final description =
        step['description'] as String? ??
        'Pahami materi lalu kerjakan latihan bersama Budi.';
    final progress = (_currentStep + 1) / _steps.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EncouriseColors.primarySurface,
        borderRadius: BorderRadius.circular(EncouriseRadius.lg),
        border: Border.all(color: EncouriseColors.primaryLight),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(EncouriseRadius.md),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: EncouriseColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Langkah ${_currentStep + 1}: $title',
                  style: EncouriseTextStyles.h3,
                ),
                const SizedBox(height: 4),
                Text(description, style: EncouriseTextStyles.bodySm),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    color: EncouriseColors.primary,
                    backgroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    if (_messages.isEmpty && _isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: EncouriseColors.primary,
              backgroundColor: EncouriseColors.primary.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 16),
            Text(
              'Budi sedang merancang jalur belajar…',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: EncouriseColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) return _buildTypingIndicator();
        final msg = _messages[index];
        if (msg.role == 'system') return _buildSystemMessage(msg.text);
        return _buildMessageBubble(msg);
      },
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    final isModel = msg.role == 'model';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isModel
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          if (isModel) ...[
            const BudiAvatar(size: 34),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isModel ? null : EncouriseGradients.chatBubble,
                color: isModel ? EncouriseColors.chatBot : null,
                border: Border.all(
                  color: isModel
                      ? EncouriseColors.chatBotBorder
                      : EncouriseColors.primaryLight,
                ),
                boxShadow: isModel ? EncouriseShadows.soft : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isModel ? 6 : 20),
                  bottomRight: Radius.circular(isModel ? 20 : 6),
                ),
              ),
              child: Text(
                sanitizeLatex(msg.text),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  height: 1.55,
                  color: isModel
                      ? EncouriseColors.textPrimary
                      : EncouriseColors.textPrimary,
                ),
              ),
            ),
          ),
          if (!isModel) const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildSystemMessage(String text) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: EncouriseColors.primarySurface,
          borderRadius: BorderRadius.circular(EncouriseRadius.pill),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: EncouriseColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const BudiAvatar(size: 34),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: EncouriseColors.chatBot,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: EncouriseColors.border),
              boxShadow: EncouriseShadows.soft,
            ),
            child: SizedBox(
              width: 40,
              height: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  backgroundColor: EncouriseColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    EncouriseColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinishedBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: BoxDecoration(
        color: EncouriseColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: EncouriseShadows.bottomNav,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: EncouriseColors.primarySurface,
                borderRadius: BorderRadius.circular(EncouriseRadius.pill),
              ),
              child: Text(
                'Jalur belajar selesai!',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: EncouriseColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            EncouriseGradientButton(
              label: 'Kembali ke Beranda',
              icon: Icons.home_rounded,
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    if (_steps.isEmpty) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: EncouriseGradientButton(
            label: 'Coba Lagi',
            icon: Icons.refresh_rounded,
            onPressed: _initGuidedSession,
          ),
        ),
      );
    }
    final isLastStep = _currentStep >= _steps.length - 1;
    final nextLabel = isLastStep ? 'Selesai' : 'Langkah Berikutnya';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 14, 12),
      decoration: BoxDecoration(
        color: EncouriseColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: EncouriseShadows.bottomNav,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isLoading && _messages.isNotEmpty && _userMessagesInStep >= 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: _nextStep,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: EncouriseGradients.primary,
                        borderRadius: BorderRadius.circular(
                          EncouriseRadius.pill,
                        ),
                        boxShadow: EncouriseShadows.button,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isLastStep
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            nextLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (!_isLoading && !_sessionFinished) {
                        _inputFocusNode.requestFocus();
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: EncouriseColors.background,
                        borderRadius: BorderRadius.circular(
                          EncouriseRadius.pill,
                        ),
                      ),
                      child: TextField(
                        controller: _inputController,
                        focusNode: _inputFocusNode,
                        autofocus: true,
                        enabled: !_isLoading && !_sessionFinished,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _submitMessage,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: EncouriseColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Tanya Budi tentang langkah ini...',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            color: EncouriseColors.textMuted,
                            fontSize: 14,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          isDense: true,
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: (_isLoading || _sessionFinished)
                        ? null
                        : EncouriseGradients.primary,
                    color: (_isLoading || _sessionFinished)
                        ? EncouriseColors.border
                        : null,
                    boxShadow: (_isLoading || _sessionFinished)
                        ? null
                        : EncouriseShadows.button,
                  ),
                  child: IconButton(
                    onPressed: _isLoading || _sessionFinished
                        ? null
                        : () => _submitMessage(_inputController.text),
                    icon: const Icon(Icons.arrow_upward_rounded, size: 22),
                    color: Colors.white,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRetryBox() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EncouriseColors.errorLight,
        borderRadius: BorderRadius.circular(EncouriseRadius.lg),
      ),
      child: Row(
        children: [
          const Icon(Icons.refresh_rounded, color: EncouriseColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Jawabanmu belum dinilai. Ulangi penilaian dengan jawaban yang sama.',
              style: EncouriseTextStyles.bodySm,
            ),
          ),
          TextButton(
            onPressed: _isLoading || _pendingRetryAnswer == null
                ? null
                : _retryPendingMessage,
            child: const Text('Ulangi'),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String role;
  final String text;
  const _ChatMessage({required this.role, required this.text});
}
