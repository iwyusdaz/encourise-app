import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/session_manager.dart';
import '../services/difficulty_adapter.dart';
import '../services/gemma_runtime.dart';
import '../services/database_service.dart';
import '../services/structured_tutor_service.dart';
import '../services/tutor_capability.dart';
import '../models/learning_models.dart';
import '../models/session_state.dart';
import '../utils/prompt_builder.dart';
import '../utils/key_concepts.dart';
import '../utils/text_utils.dart';
import '../utils/encourise_theme.dart';
import 'session_summary_screen.dart';

typedef TutorAnswerEvaluator = Future<TutorTurnResult> Function(String answer);

/// Full-screen tutoring session with tutor Budi.
class TutoringScreen extends StatefulWidget {
  final String subject;
  final String topic;
  final int grade;
  final TutoringCapability capability;
  final String teachingMode;
  final String? initialGreeting;
  final TutorAnswerEvaluator? answerEvaluator;
  final bool disablePersistence;
  final String testStudentId;

  const TutoringScreen({
    super.key,
    required this.subject,
    required this.topic,
    required this.grade,
    this.capability = TutoringCapability.socratic,
    this.teachingMode = 'jelaskan',
    this.initialGreeting,
    this.answerEvaluator,
    this.disablePersistence = false,
    this.testStudentId = 'test_student',
  });

  @override
  State<TutoringScreen> createState() => _TutoringScreenState();
}

class _TutoringScreenState extends State<TutoringScreen> {
  // ── Services ────────────────────────────────────────────────────────────
  late final SessionManager _session;
  late final DifficultyAdapter _adapter;
  late final SessionState _state;

  // ── UI state ────────────────────────────────────────────────────────────
  final List<_ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  bool _isLoading = false;
  bool _showHint = false;
  bool _sessionFinished = false;
  String? _pendingRetryAnswer;
  String _hintText = '';
  String _studentId = 'unknown';
  String _currentSkillTag = 'general';
  String _keyConcepts = '';
  int _exchangeCount = 0;
  int _minExchanges = 5; // set dynamically from grade

  // Session result (set on finish)
  int _earnedXp = 0;

  // Multiple-choice state
  List<String>? _mcOptions;
  int? _selectedIndex;
  int? _correctIndex;
  bool _mcAnswered = false;

  /// Whether the student can end the session (enough exchanges done).
  bool get _canEndSession => _exchangeCount >= _minExchanges;

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

    _startSession();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Session lifecycle
  // -----------------------------------------------------------------------

  Future<void> _startSession() async {
    setState(() => _isLoading = true);

    // Set minimum exchanges based on grade level
    _minExchanges = getMinExchanges(widget.grade);

    if (widget.initialGreeting != null) {
      _studentId = widget.testStudentId;
      setState(() {
        _messages.add(
          _ChatMessage(role: 'model', text: widget.initialGreeting!),
        );
        _isLoading = false;
      });
      _scrollToBottom();
      _focusAnswerInput();
      return;
    }

    // Load student profile from database
    final db = DatabaseService.instance;
    final student = await db.getStudent();
    final studentName = student?['name'] as String? ?? 'Siswa';
    final studentId = student?['id'] as String? ?? 'unknown';
    _studentId = studentId;
    final teachingStyle =
        student?['teaching_style'] as String? ?? 'encouraging';

    // Load learner memory
    final memory = await db.getLearnerMemory(studentId);
    final memorySummary = memory?['summary_text'] as String? ?? '';
    final profile = LearnerProfile.fromJsonString(
      memory?['profile_json'] as String? ?? '{}',
    );
    final memoryContext = [
      if (memorySummary.isNotEmpty) memorySummary,
      profile.toPromptContext(topic: widget.topic),
    ].where((item) => item.trim().isNotEmpty).join('\n');

    // Load key concepts for this topic
    final concepts = getKeyConcepts(widget.subject, widget.grade, widget.topic);
    _keyConcepts = concepts;

    final systemPrompt = buildSystemPrompt(
      grade: widget.grade,
      subject: widget.subject,
      studentName: studentName,
      keyConcepts: concepts,
      teachingStyle: teachingStyle,
      learnerMemory: memoryContext,
    );

    _session = SessionManager(
      runtime: GemmaRuntime.instance,
      systemPrompt: systemPrompt,
    );

    // Initialize LiteRT-LM conversation with system instruction
    await _session.startConversation();

    setState(() {
      _messages.add(_ChatMessage(role: 'model', text: _buildInstantGreeting()));
      _isLoading = false;
    });
    _scrollToBottom();
    _focusAnswerInput();
  }

  String _buildInstantGreeting() {
    if (widget.teachingMode == 'tanya') {
      return 'Pertanyaan: menurutmu, apa arti ${widget.topic}? Jawab dengan contoh sederhana jika bisa.';
    }
    return 'Konsep: ${_conceptIntroForTopic()} '
        'Contoh: ${_exampleForTopic()} '
        'Tugas: jelaskan dengan kata-katamu sendiri, apa arti ${widget.topic}?';
  }

  String _conceptIntroForTopic() {
    final topic = widget.topic.toLowerCase();
    if (topic.contains('pecahan') && topic.contains('bilangan')) {
      return 'Bilangan bulat menunjukkan nilai utuh seperti -2, 0, dan 5; pecahan menunjukkan bagian dari satu utuh.';
    }
    if (topic.contains('pecahan')) {
      return 'Pecahan menunjukkan bagian dari satu utuh.';
    }
    if (topic.contains('himpunan')) {
      return 'Himpunan adalah kumpulan benda atau angka yang anggotanya jelas.';
    }
    if (topic.contains('aljabar')) {
      return 'Aljabar memakai huruf seperti x untuk mewakili nilai yang belum diketahui.';
    }
    final firstConcept = _keyConcepts
        .split(RegExp(r'[,.]'))
        .map((part) => part.trim())
        .firstWhere((part) => part.length > 6, orElse: () => widget.topic);
    return '$firstConcept adalah inti awal untuk memahami ${widget.topic}.';
  }

  String _exampleForTopic() {
    final topic = widget.topic.toLowerCase();
    if (topic.contains('pecahan')) {
      return '3/8 berarti 3 dari 8 bagian yang sama besar.';
    }
    if (topic.contains('bilangan')) {
      return '-2 berada di kiri 0 pada garis bilangan.';
    }
    if (topic.contains('himpunan')) {
      return 'A = {2, 4, 6} adalah himpunan bilangan genap kecil.';
    }
    if (topic.contains('aljabar')) {
      return 'Pada 3x + 2, x adalah variabel dan 3 adalah koefisien.';
    }
    return 'Ambil satu contoh sederhana, tulis informasi pentingnya, lalu jelaskan hubungannya.';
  }

  // -----------------------------------------------------------------------
  // Answer handling
  // -----------------------------------------------------------------------

  Future<void> _submitTextAnswer(String answer) async {
    if (answer.trim().isEmpty || _isLoading || _sessionFinished) return;

    _inputController.clear();
    await _evaluateTextAnswer(answer, addUserMessage: true);
  }

  Future<void> _retryPendingTextAnswer() async {
    final answer = _pendingRetryAnswer;
    if (answer == null || _isLoading || _sessionFinished) return;
    setState(() => _pendingRetryAnswer = null);
    await _evaluateTextAnswer(answer, addUserMessage: false);
  }

  Future<void> _evaluateTextAnswer(
    String answer, {
    required bool addUserMessage,
  }) async {
    if (addUserMessage) _exchangeCount++;

    setState(() {
      if (addUserMessage) {
        _messages.add(_ChatMessage(role: 'user', text: answer));
      }
      _isLoading = true;
      _showHint = false;
    });
    _scrollToBottom();

    final result = widget.answerEvaluator == null
        ? await StructuredTutorService.evaluateAnswer(
            session: _session,
            topic: widget.topic,
            studentAnswer: answer,
            grade: widget.grade,
            difficulty: _adapter.currentLevel,
            skillTag: _currentSkillTag,
            keyConcepts: _keyConcepts,
            teachingMode: widget.teachingMode,
          )
        : await widget.answerEvaluator!(answer);
    if (result.rawResponse == '[retry_needed]' ||
        result.rawResponse == '[timeout]' ||
        result.rawResponse == '[invalid_json]' ||
        result.rawResponse == '[model_error]') {
      setState(() {
        _messages.add(_ChatMessage(role: 'model', text: result.studentText));
        _pendingRetryAnswer = answer;
        _isLoading = false;
      });
      _scrollToBottom();
      return;
    }
    _currentSkillTag = result.skillTag;
    final hintUsed = result.hint.isNotEmpty && !result.isCorrect;
    final shouldScore =
        result.status == 'correct' || result.status == 'incorrect';
    if (!widget.disablePersistence && shouldScore) {
      unawaited(
        DatabaseService.instance
            .recordSkillAttempt(
              studentId: _studentId,
              topicId: widget.topic,
              skillTag: result.skillTag,
              isCorrect: result.isCorrect,
              hintUsed: hintUsed,
            )
            .then((_) {})
            .catchError((_) {}),
      );
    }

    if (shouldScore) {
      final action = _adapter.recordStructuredAnswer(
        isCorrect: result.isCorrect,
        confidence: result.confidence,
        hintUsed: hintUsed,
      );
      _state.syncFromAdapter(_adapter);
      _handleAction(action, hint: result.hint);
    } else {
      _showHint = false;
    }

    setState(() {
      _messages.add(_ChatMessage(role: 'model', text: result.studentText));
      _pendingRetryAnswer = null;
      _isLoading = false;
    });
    _scrollToBottom();
    _focusAnswerInput();
  }

  Future<void> _submitMcAnswer(int index) async {
    if (_mcAnswered || _isLoading || _sessionFinished) return;

    _exchangeCount++;
    final answer = _mcOptions![index];
    final correct = index == _correctIndex;

    setState(() {
      _mcAnswered = true;
      _selectedIndex = index;
      _showHint = false;
    });

    final action = _adapter.recordAnswer(correct);
    _state.syncFromAdapter(_adapter);
    _handleAction(action);

    // Send answer text to model
    setState(() => _isLoading = true);
    final response = await _session.chat(
      answer,
      maxTokens: 120,
      flowLabel: 'tutoring_choice_feedback',
      topicForFallback: widget.topic,
      timeout: const Duration(seconds: 18),
    );

    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: answer));
      _messages.add(_ChatMessage(role: 'model', text: response));
      _mcOptions = null;
      _mcAnswered = false;
      _selectedIndex = null;
      _correctIndex = null;
      _isLoading = false;
    });
    _scrollToBottom();
    _focusAnswerInput();
  }

  void _handleAction(AdapterAction action, {String hint = ''}) {
    switch (action) {
      case AdapterAction.levelUp:
        setState(() {
          _messages.add(
            _ChatMessage(
              role: 'system',
              text: 'Level naik. Sekarang Level ${_adapter.currentLevel}.',
            ),
          );
        });
        break;
      case AdapterAction.showHint:
        setState(() {
          _showHint = true;
          _hintText = hint.trim().isEmpty
              ? 'Coba pikirkan lagi. Budi akan memberimu petunjuk…'
              : hint.trim();
        });
        break;
      case AdapterAction.flagWeak:
        setState(() {
          _messages.add(
            _ChatMessage(
              role: 'system',
              text: 'Topik ini ditandai untuk review nanti.',
            ),
          );
        });
        break;
      case AdapterAction.normal:
        break;
    }
  }

  void _endSession() {
    final xp = (_adapter.correctAnswers * 10) + (_adapter.currentLevel * 5);
    _earnedXp = xp;

    // Save session to SQLite
    _saveSession(xp);

    // Mark session as finished — show "Lihat Ringkasan" button
    // instead of auto-navigating, so user can read the last AI reply
    setState(() {
      _sessionFinished = true;
    });
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
      final student = await db.getStudent();
      final studentId = student?['id'] as String? ?? 'unknown';

      // Serialize conversation for session continuity
      final conversationJson = jsonEncode(
        _messages.map((m) => {'role': m.role, 'text': m.text}).toList(),
      );

      final sessionData = {
        'id': _state.sessionId,
        'student_id': studentId,
        'topic_id': widget.topic,
        'started_at': DateTime.fromMillisecondsSinceEpoch(
          int.tryParse(_state.sessionId) ?? 0,
        ).toIso8601String(),
        'ended_at': DateTime.now().toIso8601String(),
        'questions': _adapter.totalQuestions,
        'correct': _adapter.correctAnswers,
        'xp_earned': xp,
        'mode': widget.capability.sessionType,
        'conversation_json': conversationJson,
      };

      await db.saveSession(sessionData);

      // Update topic progress
      await db.upsertTopicProgress({
        'student_id': studentId,
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

      // Queue for sync to teacher dashboard
      await db.addToSyncQueue({
        'id': 'sync_${_state.sessionId}',
        'payload_json': jsonEncode({
          'table': 'sessions_cloud',
          'data': {
            'id': _state.sessionId,
            'device_uuid': studentId,
            'topic_id': widget.topic,
            'started_at': sessionData['started_at'],
            'correct': _adapter.correctAnswers,
            'accuracy': _adapter.accuracy,
            'xp': xp,
            'mode': widget.capability.sessionType,
          },
        }),
        'created_at': DateTime.now().toIso8601String(),
        'retry_count': 0,
      });
    } catch (e) {
      // Don't crash the UI if saving fails
      // ignore: avoid_print
      print('[TutoringScreen] Failed to save session: $e');
    }
  }

  Future<void> _saveNote(String content) async {
    if (widget.disablePersistence) return;
    try {
      final db = DatabaseService.instance;
      final student = await db.getStudent();
      final studentId = student?['id'] as String? ?? 'unknown';

      await db.saveNote({
        'id': 'note_${DateTime.now().millisecondsSinceEpoch}',
        'student_id': studentId,
        'topic_id': widget.topic,
        'content_text': content,
        'skill_tag': _currentSkillTag,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Disimpan ke Catatan'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('[TutoringScreen] Failed to save note: $e');
    }
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
      if (!mounted || _isLoading || _sessionFinished || _mcOptions != null) {
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

    return Scaffold(
      backgroundColor: EncouriseColors.background,
      body: Column(
        children: [
          _buildTopBar(subjectLabel),
          _buildProgressBar(),
          Expanded(child: _buildChatArea()),
          if (_showHint) _buildHintBox(),
          if (_pendingRetryAnswer != null) _buildRetryBox(),
          if (_sessionFinished)
            _buildFinishedBar()
          else if (_mcOptions != null)
            _buildMcGrid()
          else
            _buildInputBar(),
        ],
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────

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
                onPressed: () {
                  if (_exchangeCount > 0 && !_sessionFinished) {
                    _showExitConfirmDialog();
                  } else {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.arrow_back_rounded),
                color: EncouriseColors.textPrimary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pahami • $subjectLabel',
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
                  'Lv ${_adapter.currentLevel}',
                  style: GoogleFonts.plusJakartaSans(
                    color: EncouriseColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_canEndSession && !_sessionFinished) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _endSession,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: EncouriseColors.primary,
                      borderRadius: BorderRadius.circular(EncouriseRadius.pill),
                    ),
                    child: Text(
                      'Selesai',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: EncouriseColors.textOnPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
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
        border: Border.all(color: EncouriseColors.error.withValues(alpha: 0.2)),
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
                : _retryPendingTextAnswer,
            child: const Text('Ulangi'),
          ),
        ],
      ),
    );
  }

  void _showExitConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EncouriseColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EncouriseRadius.lg),
        ),
        title: Text(
          'Keluar dari sesi?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: EncouriseColors.textPrimary,
          ),
        ),
        content: Text(
          _canEndSession
              ? 'Sesi akan disimpan dan kamu bisa lihat ringkasan.'
              : 'Kamu belum menyelesaikan minimum $_minExchanges pertanyaan. Progress tidak akan disimpan.',
          style: GoogleFonts.plusJakartaSans(
            color: EncouriseColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Lanjut Pahami',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: EncouriseColors.primary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (_canEndSession) {
                _endSession();
              } else {
                Navigator.pop(context);
              }
            },
            child: Text(
              'Keluar',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: EncouriseColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Progress info ─────────────────────────────────────────────────

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Row(
        children: [
          ...List.generate(3, (i) {
            final filled = i < _adapter.currentLevel;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: filled ? 24 : 8,
              height: 8,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                gradient: filled ? EncouriseGradients.primary : null,
                color: filled ? null : EncouriseColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: EncouriseColors.primarySurface,
              borderRadius: BorderRadius.circular(EncouriseRadius.pill),
            ),
            child: Text(
              '${_adapter.correctStreak} benar beruntun',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: EncouriseColors.primary,
              ),
            ),
          ),
          const Spacer(),
          Text(
            '$_exchangeCount pertanyaan',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: EncouriseColors.textSecondary,
            ),
          ),
          if (!_canEndSession) ...[
            const SizedBox(width: 6),
            Text(
              '(min. $_minExchanges)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                color: EncouriseColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Chat area ──────────────────────────────────────────────────────────

  Widget _buildChatArea() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return _buildTypingIndicator();
        }
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    if (msg.role == 'system') {
      return _buildSystemMessage(msg.text);
    }

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
            child: Column(
              crossAxisAlignment: isModel
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
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
                if (isModel)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: GestureDetector(
                      onTap: () => _saveNote(msg.text),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: EncouriseColors.primarySurface,
                          borderRadius: BorderRadius.circular(
                            EncouriseRadius.pill,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.bookmark_border_rounded,
                              size: 13,
                              color: EncouriseColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Simpan',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: EncouriseColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
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
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DotPulse(),
                SizedBox(width: 5),
                _DotPulse(delay: Duration(milliseconds: 200)),
                SizedBox(width: 5),
                _DotPulse(delay: Duration(milliseconds: 400)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Hint box ───────────────────────────────────────────────────────────

  Widget _buildHintBox() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: EncouriseColors.warningLight,
        borderRadius: BorderRadius.circular(EncouriseRadius.lg),
        border: Border.all(
          color: EncouriseColors.warning.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE8A838), Color(0xFFF0C060)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Petunjuk',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: EncouriseColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _hintText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: EncouriseColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Multiple choice grid ───────────────────────────────────────────────

  Widget _buildMcGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.8,
        children: List.generate(_mcOptions!.length, (i) {
          Color bgColor;
          Color textColor = EncouriseColors.textPrimary;
          List<BoxShadow>? shadow = EncouriseShadows.card;

          if (_mcAnswered) {
            if (i == _correctIndex) {
              bgColor = EncouriseColors.successLight;
              textColor = EncouriseColors.success;
            } else if (i == _selectedIndex) {
              bgColor = EncouriseColors.errorLight;
              textColor = EncouriseColors.error;
            } else {
              bgColor = EncouriseColors.surface;
              shadow = EncouriseShadows.soft;
            }
          } else {
            bgColor = EncouriseColors.surface;
          }

          return GestureDetector(
            onTap: () => _submitMcAnswer(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(EncouriseRadius.lg),
                boxShadow: shadow,
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                _mcOptions![i],
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Finished bar ─────────────────────────────────────────────────

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
                'Benar: ${_adapter.correctAnswers}/${_adapter.totalQuestions} • XP: +$_earnedXp',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: EncouriseColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            EncouriseGradientButton(
              label: 'Lihat Ringkasan',
              onPressed: _goToSummary,
              icon: Icons.assessment_rounded,
            ),
          ],
        ),
      ),
    );
  }

  // ── Text input bar ─────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 14, 12),
      decoration: BoxDecoration(
        color: EncouriseColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: EncouriseShadows.bottomNav,
      ),
      child: SafeArea(
        top: false,
        child: Row(
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
                    borderRadius: BorderRadius.circular(EncouriseRadius.pill),
                  ),
                  child: TextField(
                    controller: _inputController,
                    focusNode: _inputFocusNode,
                    autofocus: true,
                    enabled: !_isLoading && !_sessionFinished,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _submitTextAnswer,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: EncouriseColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ketik jawabanmu...',
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
                    : () => _submitTextAnswer(_inputController.text),
                icon: const Icon(Icons.arrow_upward_rounded, size: 22),
                color: Colors.white,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// Helper classes
// =========================================================================

class _ChatMessage {
  final String role; // 'user', 'model', or 'system'
  final String text;
  const _ChatMessage({required this.role, required this.text});
}

/// Animated dot for the typing indicator.
class _DotPulse extends StatefulWidget {
  final Duration delay;
  const _DotPulse({this.delay = Duration.zero});

  @override
  State<_DotPulse> createState() => _DotPulseState();
}

class _DotPulseState extends State<_DotPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _opacity = Tween(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: EncouriseColors.primary.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
