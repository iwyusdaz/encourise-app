import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/gemma_runtime.dart';
import '../services/session_manager.dart';
import '../utils/encourise_theme.dart';
import '../utils/prompt_builder.dart';
import '../utils/text_utils.dart';

/// Persistent Tanya hub. The tab shows saved conversations first, then opens
/// a local-Gemma chat when students start or continue a session.
class FreeChatScreen extends StatefulWidget {
  final int grade;
  final bool isTab;

  const FreeChatScreen({super.key, this.grade = 0, this.isTab = false});

  @override
  State<FreeChatScreen> createState() => _FreeChatScreenState();
}

class _FreeChatScreenState extends State<FreeChatScreen> {
  SessionManager? _session;
  final List<_ChatMsg> _messages = [];
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _inputCtrl = TextEditingController();

  List<Map<String, dynamic>> _sessions = [];
  String _studentId = 'unknown';
  String _studentName = 'Siswa';
  int _grade = 5;
  String? _activeSessionId;
  String _activeTitle = 'Tanya Budi';
  String _activeSummary = '';
  bool _isLoading = false;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _loadHub();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHub() async {
    setState(() => _isLoading = true);
    final db = DatabaseService.instance;
    final student = await db.getStudent();
    _studentId = student?['id'] as String? ?? 'unknown';
    _studentName = student?['name'] as String? ?? 'Siswa';
    _grade = widget.grade > 0 ? widget.grade : (student?['grade'] as int? ?? 5);
    final sessions = await db.getTanyaSessions(_studentId);
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _isLoading = false;
      _isReady = false;
    });
  }

  Future<void> _startNewSession() async {
    final now = DateTime.now().toIso8601String();
    final id = 'tanya_${DateTime.now().millisecondsSinceEpoch}';
    final greeting = _ChatMsg(
      role: 'model',
      text: 'Tulis pertanyaanmu. Budi akan jawab singkat dan jelas.',
      timestamp: now,
    );
    setState(() {
      _activeSessionId = id;
      _activeTitle = 'Tanya Budi';
      _activeSummary = '';
      _messages
        ..clear()
        ..add(greeting);
      _isReady = false;
      _isLoading = true;
    });
    await _startGemmaConversation(seedMessages: _messages);
    await _saveActiveSession();
    if (!mounted) return;
    setState(() {
      _isReady = true;
      _isLoading = false;
    });
    _scrollToBottom();
  }

  Future<void> _openSession(Map<String, dynamic> row) async {
    final raw = row['conversation_json'] as String? ?? '[]';
    final messages = _decodeMessages(raw);
    setState(() {
      _activeSessionId = row['id'] as String;
      _activeTitle = row['title'] as String? ?? 'Tanya Budi';
      _activeSummary = row['summary'] as String? ?? '';
      _messages
        ..clear()
        ..addAll(messages);
      _isReady = false;
      _isLoading = true;
    });
    await _startGemmaConversation(seedMessages: messages);
    if (!mounted) return;
    setState(() {
      _isReady = true;
      _isLoading = false;
    });
    _scrollToBottom();
  }

  Future<void> _startGemmaConversation({
    required List<_ChatMsg> seedMessages,
  }) async {
    final systemPrompt = '''
Kamu adalah Budi, tutor AI lokal yang membantu $_studentName, siswa Kelas $_grade.
$directLearningAnswerRules
Jawab langsung, konkret, dan mudah dipahami. Jika pertanyaan pelajaran, beri arti konsep, contoh sederhana, lalu satu langkah berikutnya.
Gunakan Bahasa Indonesia. Jangan pakai sapaan pembuka.
${_historyContext(seedMessages)}
''';
    _session = SessionManager(
      runtime: GemmaRuntime.instance,
      systemPrompt: systemPrompt,
    );
    await _session!.startConversation();
  }

  String _historyContext(List<_ChatMsg> messages) {
    final useful = messages
        .where((m) => m.role == 'user' || m.role == 'model')
        .take(10)
        .map((m) => '${m.role == 'user' ? 'Siswa' : 'Budi'}: ${m.text}')
        .join('\n');
    return useful.isEmpty ? '' : '\n[KONTEKS SESI SEBELUMNYA]\n$useful';
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isLoading || !_isReady || _session == null) return;
    _inputCtrl.clear();
    final now = DateTime.now().toIso8601String();
    setState(() {
      _messages.add(_ChatMsg(role: 'user', text: trimmed, timestamp: now));
      _isLoading = true;
    });
    _scrollToBottom();

    final response = await _session!.chat(
      trimmed,
      maxTokens: 140,
      flowLabel: 'tanya_chat',
      topicForFallback: trimmed,
      timeout: const Duration(seconds: 75),
    );
    setState(() {
      _messages.add(
        _ChatMsg(
          role: 'model',
          text: response,
          timestamp: DateTime.now().toIso8601String(),
        ),
      );
      _isLoading = false;
    });
    if (_activeTitle == 'Tanya Budi' && _messages.where((m) => m.role == 'user').length == 1) {
      await _generateTitle();
    }
    await _saveActiveSession();
    _scrollToBottom();
  }

  Future<void> _generateTitle() async {
    final user = _messages.firstWhere((m) => m.role == 'user').text;
    final model = _messages.lastWhere((m) => m.role == 'model').text;
    final result = await _session?.chatJson(
      buildAskTitlePrompt(firstQuestion: user, firstAnswer: model),
      decode: (raw) {
        try {
          return jsonDecode(raw);
        } catch (_) {
          return null;
        }
      },
      maxTokens: 80,
      flowLabel: 'tanya_title',
      timeout: const Duration(seconds: 45),
    );
    if (result?.decoded is Map<String, dynamic>) {
      final decoded = result!.decoded! as Map<String, dynamic>;
      final title = decoded['title']?.toString().trim() ?? '';
      final summary = decoded['summary']?.toString().trim() ?? '';
      if (title.isNotEmpty && mounted) {
        setState(() {
          _activeTitle = title.length > 42 ? title.substring(0, 42) : title;
          _activeSummary = summary;
        });
      }
    } else {
      final fallback = user.length > 42 ? user.substring(0, 42) : user;
      if (mounted) setState(() => _activeTitle = fallback);
    }
  }

  Future<void> _saveActiveSession() async {
    final id = _activeSessionId;
    if (id == null) return;
    final now = DateTime.now().toIso8601String();
    final firstCreated = _sessions
        .where((s) => s['id'] == id)
        .map((s) => s['created_at'] as String? ?? now)
        .firstOrNull;
    await DatabaseService.instance.saveTanyaSession({
      'id': id,
      'student_id': _studentId,
      'title': _activeTitle,
      'summary': _activeSummary,
      'conversation_json': jsonEncode(_messages.map((m) => m.toJson()).toList()),
      'created_at': firstCreated ?? now,
      'updated_at': now,
    });
    unawaited(
      DatabaseService.instance.addToSyncQueue({
        'id': 'sync_$id',
        'payload_json': jsonEncode({
          'table': 'sessions_cloud',
          'data': {
            'id': id,
            'device_uuid': _studentId,
            'topic_id': 'Tanya Budi',
            'started_at': firstCreated ?? now,
            'correct': 0,
            'accuracy': 0.0,
            'xp': 0,
            'mode': 'tanya',
            'conversation_json': jsonEncode({
              'mode': 'tanya',
              'title': _activeTitle,
              'summary': _activeSummary,
              'updated_at': now,
            }),
          },
        }),
        'created_at': now,
        'retry_count': 0,
      }).catchError((_) {}),
    );
  }

  Future<void> _deleteSession(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus sesi Tanya?'),
        content: const Text('Percakapan ini akan dihapus dari perangkat ini.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DatabaseService.instance.deleteTanyaSession(row['id'] as String);
    await _loadHub();
  }

  Future<void> _saveNote(String content) async {
    await DatabaseService.instance.saveNote({
      'id': 'note_${DateTime.now().millisecondsSinceEpoch}',
      'student_id': _studentId,
      'topic_id': 'Tanya Budi',
      'content_text': content,
      'created_at': DateTime.now().toIso8601String(),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Disimpan ke Catatan')));
  }

  void _closeChat() {
    setState(() {
      _activeSessionId = null;
      _messages.clear();
      _isReady = false;
    });
    _loadHub();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_activeSessionId == null) return _buildSessionList();
    return _buildChat();
  }

  Widget _buildSessionList() {
    return Scaffold(
      backgroundColor: EncouriseColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Row(
                children: [
                  const BudiAvatar(size: 42),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Tanya Budi', style: EncouriseTextStyles.h2)),
                  EncouriseGradientButton(
                    label: 'Baru',
                    icon: Icons.add_rounded,
                    width: 116,
                    height: 44,
                    onPressed: _startNewSession,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _sessions.isEmpty
                  ? _buildEmptyList()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      itemBuilder: (_, index) => _buildSessionTile(_sessions[index]),
                      separatorBuilder: (_, index) => const SizedBox(height: 10),
                      itemCount: _sessions.length,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyList() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BudiAvatar(size: 64),
            const SizedBox(height: 16),
            Text('Belum ada sesi Tanya', style: EncouriseTextStyles.h3),
            const SizedBox(height: 8),
            Text(
              'Mulai sesi baru untuk bertanya ke Budi dan lanjutkan lagi nanti.',
              textAlign: TextAlign.center,
              style: EncouriseTextStyles.bodySm,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionTile(Map<String, dynamic> row) {
    final summary = row['summary'] as String? ?? '';
    return EncouriseCard(
      padding: const EdgeInsets.all(14),
      onTap: () => _openSession(row),
      child: Row(
        children: [
          const BudiAvatar(size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row['title'] as String? ?? 'Tanya Budi', style: EncouriseTextStyles.h3),
                const SizedBox(height: 4),
                Text(
                  summary.isEmpty ? 'Lanjutkan percakapan dengan Budi.' : summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: EncouriseTextStyles.bodySm,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Hapus sesi',
            onPressed: () => _deleteSession(row),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildChat() {
    return Scaffold(
      backgroundColor: EncouriseColors.background,
      body: Column(
        children: [
          _buildChatHeader(),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) return _buildTypingIndicator();
                return _buildBubble(_messages[index]);
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildChatHeader() {
    return Container(
      decoration: const BoxDecoration(color: EncouriseColors.background),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 16, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: _closeChat,
                icon: const Icon(Icons.arrow_back_rounded),
                color: EncouriseColors.textPrimary,
              ),
              const BudiAvatar(size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_activeTitle, style: EncouriseTextStyles.h3),
                    Text(_isReady ? 'AI siap' : 'Mempersiapkan...', style: EncouriseTextStyles.bodySm),
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

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      decoration: BoxDecoration(
        color: EncouriseColors.surface,
        boxShadow: EncouriseShadows.bottomNav,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                enabled: !_isLoading && _isReady,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                decoration: const InputDecoration(
                  hintText: 'Tanya apa saja...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: _send,
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              onPressed: _isLoading || !_isReady ? null : () => _send(_inputCtrl.text),
              icon: const Icon(Icons.arrow_upward_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(_ChatMsg msg) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[const BudiAvatar(size: 32), const SizedBox(width: 10)],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isUser ? EncouriseGradients.chatBubble : null,
                    color: isUser ? null : EncouriseColors.chatBot,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: isUser ? EncouriseColors.primaryLight : EncouriseColors.chatBotBorder),
                  ),
                  child: Text(sanitizeLatex(msg.text), style: EncouriseTextStyles.bodyMd),
                ),
                if (!isUser)
                  TextButton.icon(
                    onPressed: () => _saveNote(msg.text),
                    icon: const Icon(Icons.bookmark_outline_rounded, size: 14),
                    label: const Text('Simpan'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const BudiAvatar(size: 32),
          const SizedBox(width: 10),
          Text('Budi sedang menjawab...', style: EncouriseTextStyles.bodySm),
        ],
      ),
    );
  }

  List<_ChatMsg> _decodeMessages(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(_ChatMsg.fromJson)
            .toList();
      }
    } catch (_) {}
    return [
      _ChatMsg(
        role: 'model',
        text: 'Tulis pertanyaanmu. Budi akan jawab singkat dan jelas.',
        timestamp: DateTime.now().toIso8601String(),
      ),
    ];
  }
}

class _ChatMsg {
  final String role;
  final String text;
  final String timestamp;

  const _ChatMsg({
    required this.role,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'role': role,
    'text': text,
    'timestamp': timestamp,
  };

  factory _ChatMsg.fromJson(Map<String, dynamic> json) {
    return _ChatMsg(
      role: json['role']?.toString() ?? 'model',
      text: json['text']?.toString() ?? '',
      timestamp:
          json['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }
}
