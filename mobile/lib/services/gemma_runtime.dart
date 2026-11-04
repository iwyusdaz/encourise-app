import 'dart:async';

import 'package:flutter/services.dart';

import 'database_service.dart';

/// Dart wrapper for on-device Gemma inference via LiteRT-LM.
///
/// Communicates with the Android Kotlin layer through a [MethodChannel].
/// All heavy work (model loading, inference) runs on the Android side
/// in background coroutines, so calls here are non-blocking.
///
/// Model source:
///   https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm
class GemmaRuntime {
  GemmaRuntime._();

  static GemmaRuntime? _instance;
  static GemmaRuntime get instance => _instance ??= GemmaRuntime._();

  static const _channel = MethodChannel('com.encourise/litertlm');

  bool _initialized = false;
  String? _backend;

  /// Whether the engine has been initialized.
  bool get isInitialized => _initialized;

  /// The active backend name (e.g. "GPU" or "CPU"), null before init.
  String? get backend => _backend;

  // -----------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------

  /// Loads the LiteRT-LM model at [modelPath].
  ///
  /// Returns `true` when the engine is ready for inference.
  Future<bool> init(String modelPath) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'initialize',
        {'modelPath': modelPath},
      );

      if (result == null) return false;

      final success = result['success'] as bool? ?? false;
      _backend = result['backend'] as String?;
      final initTime = result['initTimeMs'] as int? ?? 0;

      if (success) {
        _initialized = true;
        unawaited(_saveInitMetrics(initTime));
        // ignore: avoid_print
        print(
          '[GemmaRuntime] Engine initialized '
          '(backend=$_backend, ${initTime}ms)',
        );
      } else {
        final error = result['error'] as String? ?? 'unknown';
        // ignore: avoid_print
        print('[GemmaRuntime] Init failed: $error');
      }

      return success;
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('[GemmaRuntime] Init error: ${e.message}');
      return false;
    }
  }

  /// Creates a conversation with the given [systemInstruction].
  ///
  /// Must be called after [init] and before [generate].
  Future<bool> createConversation({String? systemInstruction}) async {
    try {
      final result = await _channel.invokeMethod<bool>('createConversation', {
        'systemInstruction': systemInstruction,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('[GemmaRuntime] createConversation error: ${e.message}');
      return false;
    }
  }

  // -----------------------------------------------------------------------
  // Generation
  // -----------------------------------------------------------------------

  /// Sends [prompt] to the model and returns the response.
  ///
  /// Sends a per-turn max token hint to LiteRT-LM. The backend may clamp or
  /// ignore the value on older runtimes, but Android 0.11.0 accepts it through
  /// the message context map.
  Future<String> generate(String prompt, {int maxTokens = 300}) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'sendMessage',
        {'message': prompt, 'maxTokens': maxTokens},
      );

      if (result == null) return '[error] null response';

      final success = result['success'] as bool? ?? false;
      final response = result['response'] as String? ?? '';
      final genTime = result['generateTimeMs'] as int? ?? 0;
      final decodeTokenCount = result['decodeTokenCount'] as int? ?? 0;
      final decodeTps = result['decodeTokensPerSecond'] as double? ?? 0;
      final timeToFirstToken =
          result['timeToFirstTokenSeconds'] as double? ?? 0;

      if (success) {
        unawaited(
          _saveGenerationMetrics(
            genTime,
            response.length,
            decodeTokenCount: decodeTokenCount,
            decodeTokensPerSecond: decodeTps,
            timeToFirstTokenSeconds: timeToFirstToken,
          ),
        );
        // ignore: avoid_print
        print(
          '[GemmaRuntime] Generated in ${genTime}ms '
          '(${response.length} chars, '
          '$decodeTokenCount tokens, ${decodeTps.toStringAsFixed(2)} tok/s)',
        );
      }

      return response;
    } on PlatformException catch (e) {
      return '[error] ${e.message}';
    }
  }

  Future<void> _saveInitMetrics(int initTime) async {
    try {
      await DatabaseService.instance.saveModelStatus(
        'backend',
        _backend ?? 'unknown',
      );
      await DatabaseService.instance.saveModelStatus(
        'init_time_ms',
        '$initTime',
      );
      await DatabaseService.instance.saveModelStatus('mtp_ready', 'true');
    } catch (_) {}
  }

  Future<void> _saveGenerationMetrics(
    int genTime,
    int responseChars, {
    int decodeTokenCount = 0,
    double decodeTokensPerSecond = 0,
    double timeToFirstTokenSeconds = 0,
  }) async {
    try {
      await DatabaseService.instance.saveModelStatus(
        'last_generate_time_ms',
        '$genTime',
      );
      await DatabaseService.instance.saveModelStatus(
        'last_response_chars',
        '$responseChars',
      );
      await DatabaseService.instance.saveModelStatus(
        'last_decode_token_count',
        '$decodeTokenCount',
      );
      await DatabaseService.instance.saveModelStatus(
        'last_decode_tokens_per_second',
        decodeTokensPerSecond.toStringAsFixed(2),
      );
      await DatabaseService.instance.saveModelStatus(
        'last_time_to_first_token_seconds',
        timeToFirstTokenSeconds.toStringAsFixed(2),
      );
    } catch (_) {}
  }

  // -----------------------------------------------------------------------
  // Conversation management
  // -----------------------------------------------------------------------

  /// Resets the conversation history while keeping the engine loaded.
  Future<void> resetConversation() async {
    try {
      await _channel.invokeMethod<bool>('resetConversation');
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('[GemmaRuntime] resetConversation error: ${e.message}');
    }
  }

  /// Warms up the engine by sending a short throwaway message.
  ///
  /// Primes the KV cache and JIT compilation to improve latency for
  /// the first real user message. The conversation is reset afterwards.
  Future<bool> warmup() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('warmup');
      final success = result?['success'] as bool? ?? false;
      final warmupTime = result?['warmupTimeMs'] as int? ?? 0;
      // ignore: avoid_print
      print(
        '[GemmaRuntime] Warmup ${success ? "OK" : "failed"} (${warmupTime}ms)',
      );
      return success;
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('[GemmaRuntime] warmup error: ${e.message}');
      return false;
    }
  }

  /// Returns backend info as a map.
  Future<Map<String, dynamic>> getBackendInfo() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'getBackendInfo',
      );
      return result ?? {};
    } on PlatformException {
      return {};
    }
  }

  /// Releases all native resources.
  Future<void> dispose() async {
    try {
      await _channel.invokeMethod<bool>('dispose');
      _initialized = false;
      _backend = null;
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('[GemmaRuntime] dispose error: ${e.message}');
    }
  }
}
