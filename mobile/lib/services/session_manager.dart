import 'dart:async';

import '../utils/answer_quality.dart';
import 'database_service.dart';
import 'gemma_runtime.dart';

enum JsonModelStatus { success, timeout, invalidJson, modelError }

class JsonModelResult {
  final JsonModelStatus status;
  final String raw;
  final Object? decoded;
  final int elapsedMs;

  const JsonModelResult({
    required this.status,
    required this.raw,
    required this.decoded,
    required this.elapsedMs,
  });

  bool get isSuccess => status == JsonModelStatus.success;
}

/// Manages a multi-turn conversation with the Gemma model via LiteRT-LM.
///
/// LiteRT-LM handles conversation history, prompt templating, and
/// turn management internally. This class wraps the runtime with
/// conversation lifecycle management and response cleanup.
class SessionManager {
  final GemmaRuntime _runtime;
  final String systemPrompt;
  final List<Map<String, String>> _history = [];

  /// Creates a new session.
  ///
  /// [runtime]      – an initialised [GemmaRuntime] instance.
  /// [systemPrompt] – the system-level instructions for Budi.
  SessionManager({required GemmaRuntime runtime, required this.systemPrompt})
    : _runtime = runtime;

  /// Read-only view of the conversation history.
  List<Map<String, String>> get history => List.unmodifiable(_history);

  /// Number of messages in the current conversation.
  int get messageCount => _history.length;

  // -----------------------------------------------------------------------
  // Session lifecycle
  // -----------------------------------------------------------------------

  /// Initializes a new LiteRT-LM conversation with the system prompt.
  ///
  /// Must be called before [chat]. The system instruction is passed to
  /// LiteRT-LM's ConversationConfig so the engine handles prompt
  /// templating internally.
  Future<void> startConversation() async {
    await _runtime.createConversation(systemInstruction: systemPrompt);
  }

  // -----------------------------------------------------------------------
  // Chat
  // -----------------------------------------------------------------------

  /// Sends [userMessage] to the model and returns the cleaned response.
  ///
  /// 1. Records the user message in local history.
  /// 2. Sends the message via LiteRT-LM conversation API.
  /// 3. Cleans up the response (strips stray tokens).
  /// 4. Records the model response in local history.
  /// 5. Trims history if it exceeds the limit.
  Future<String> chat(
    String userMessage, {
    int maxTokens = 160,
    String flowLabel = 'chat',
    String? topicForFallback,
    Duration? timeout,
  }) async {
    // Record user message
    _history.add({'role': 'user', 'content': userMessage});
    final stopwatch = Stopwatch()..start();

    // Send via LiteRT-LM conversation (engine handles history internally)
    var timedOut = false;
    final generation = _runtime.generate(userMessage, maxTokens: maxTokens);
    final rawResponse = timeout == null
        ? await generation
        : await generation.timeout(
            timeout,
            onTimeout: () {
              timedOut = true;
              return AnswerQualityValidator.fallbackLearningAnswer(
                topicForFallback ?? 'topik ini',
              );
            },
          );
    stopwatch.stop();
    unawaited(
      _saveChatMetrics(flowLabel, stopwatch.elapsedMilliseconds, timedOut),
    );

    // Clean up the response
    var cleaned = cleanResponse(rawResponse);
    if (!_looksLikeJson(cleaned) && topicForFallback != null) {
      cleaned = AnswerQualityValidator.enforceLearningAnswer(
        cleaned,
        topic: topicForFallback,
      );
    }

    // Record model response
    _history.add({'role': 'model', 'content': cleaned});

    // Keep local history bounded
    trimHistory();

    return cleaned;
  }

  Future<JsonModelResult> chatJson(
    String userMessage, {
    required Object? Function(String raw) decode,
    int maxTokens = 220,
    String flowLabel = 'json',
    Duration timeout = const Duration(seconds: 30),
  }) async {
    _history.add({'role': 'user', 'content': userMessage});
    final stopwatch = Stopwatch()..start();
    var timedOut = false;
    String raw;
    try {
      raw = await _runtime
          .generate(userMessage, maxTokens: maxTokens)
          .timeout(timeout, onTimeout: () {
            timedOut = true;
            return '';
          });
    } catch (e) {
      stopwatch.stop();
      await _saveChatMetrics(flowLabel, stopwatch.elapsedMilliseconds, false);
      return JsonModelResult(
        status: JsonModelStatus.modelError,
        raw: '$e',
        decoded: null,
        elapsedMs: stopwatch.elapsedMilliseconds,
      );
    }
    stopwatch.stop();
    await _saveChatMetrics(flowLabel, stopwatch.elapsedMilliseconds, timedOut);
    if (timedOut) {
      return JsonModelResult(
        status: JsonModelStatus.timeout,
        raw: raw,
        decoded: null,
        elapsedMs: stopwatch.elapsedMilliseconds,
      );
    }

    final cleaned = cleanResponse(raw);
    final decoded = decode(cleaned);
    if (decoded == null) {
      _history.add({'role': 'model', 'content': cleaned});
      trimHistory();
      return JsonModelResult(
        status: JsonModelStatus.invalidJson,
        raw: cleaned,
        decoded: null,
        elapsedMs: stopwatch.elapsedMilliseconds,
      );
    }
    _history.add({'role': 'model', 'content': cleaned});
    trimHistory();
    return JsonModelResult(
      status: JsonModelStatus.success,
      raw: cleaned,
      decoded: decoded,
      elapsedMs: stopwatch.elapsedMilliseconds,
    );
  }

  Future<void> _saveChatMetrics(
    String flowLabel,
    int elapsedMs,
    bool timedOut,
  ) async {
    try {
      await DatabaseService.instance.saveModelStatus(
        'last_chat_flow',
        flowLabel,
      );
      await DatabaseService.instance.saveModelStatus(
        'last_chat_total_time_ms',
        '$elapsedMs',
      );
      await DatabaseService.instance.saveModelStatus(
        'last_chat_timed_out',
        '$timedOut',
      );
    } catch (_) {}
  }

  // -----------------------------------------------------------------------
  // History management
  // -----------------------------------------------------------------------

  /// Keeps only the last 10 messages in local history.
  ///
  /// Note: LiteRT-LM manages its own internal conversation state.
  /// This local history is for UI display and session tracking only.
  void trimHistory() {
    const maxMessages = 10;
    if (_history.length > maxMessages) {
      _history.removeRange(0, _history.length - maxMessages);
    }
  }

  /// Resets the conversation (both local history and LiteRT-LM state).
  Future<void> clearHistory() async {
    _history.clear();
    await _runtime.resetConversation();
  }

  // -----------------------------------------------------------------------
  // Internal helpers
  // -----------------------------------------------------------------------

  /// Strips Gemma control tokens, filler openings, and stray output.
  ///
  /// JSON-shaped responses are preserved because quiz/evaluation/memory
  /// prompts depend on exact structured output.
  static String cleanResponse(String raw) {
    final withoutTokens = raw
        .replaceAll('<end_of_turn>', '')
        .replaceAll('<start_of_turn>', '')
        .trim();

    if (_looksLikeJson(withoutTokens)) return withoutTokens;

    final normalized = withoutTokens
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    final cleaned = normalized
        .replaceFirst(
          RegExp(
            r'^\s*(?:hai|halo|oke|ok|baik|tentu|siap|wah|keren)[,!\.\s]+',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    return cleaned.length >= 12 ? cleaned : normalized;
  }

  static bool _looksLikeJson(String text) {
    final trimmed = text.trim();
    return (trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']'));
  }
}
