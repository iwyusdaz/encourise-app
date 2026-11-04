package com.encourise.encourise_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Flutter ↔ Android bridge for LiteRT-LM inference.
 *
 * Registers a [MethodChannel] named `com.encourise/litertlm` and delegates
 * all inference calls to [LitertLmService].
 *
 * Supported methods:
 *   - `initialize`        → loads the model
 *   - `createConversation` → sets up system instruction & sampling
 *   - `sendMessage`       → sends a user message, returns model response
 *   - `resetConversation` → resets conversation history
 *   - `warmup`            → primes KV cache for faster first response
 *   - `getBackendInfo`    → returns engine state info
 *   - `dispose`           → releases all native resources
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.encourise/litertlm"
    }

    private val service = LitertLmService()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                handleMethodCall(call, result)
            }
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                val modelPath = call.argument<String>("modelPath")
                if (modelPath == null) {
                    result.error("INVALID_ARG", "modelPath is required", null)
                    return
                }
                val cacheDir = context.cacheDir.path
                scope.launch {
                    try {
                        val info = service.initialize(modelPath, cacheDir)
                        result.success(info)
                    } catch (e: Exception) {
                        result.error("INIT_FAILED", e.message, null)
                    }
                }
            }

            "createConversation" -> {
                val systemInstruction = call.argument<String>("systemInstruction")
                try {
                    service.createConversation(systemInstruction)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("CONVERSATION_FAILED", e.message, null)
                }
            }

            "sendMessage" -> {
                val message = call.argument<String>("message")
                if (message == null) {
                    result.error("INVALID_ARG", "message is required", null)
                    return
                }
                val maxTokens = call.argument<Int>("maxTokens")
                scope.launch {
                    try {
                        val response = service.sendMessage(message, maxTokens)
                        result.success(response)
                    } catch (e: Exception) {
                        result.error("GENERATE_FAILED", e.message, null)
                    }
                }
            }

            "resetConversation" -> {
                try {
                    service.resetConversation()
                    result.success(true)
                } catch (e: Exception) {
                    result.error("RESET_FAILED", e.message, null)
                }
            }

            "getBackendInfo" -> {
                try {
                    val info = service.getBackendInfo()
                    result.success(info)
                } catch (e: Exception) {
                    result.error("INFO_FAILED", e.message, null)
                }
            }

            "warmup" -> {
                scope.launch {
                    try {
                        val info = service.warmup()
                        result.success(info)
                    } catch (e: Exception) {
                        result.error("WARMUP_FAILED", e.message, null)
                    }
                }
            }

            "dispose" -> {
                service.dispose()
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

    override fun onDestroy() {
        service.dispose()
        scope.cancel()
        super.onDestroy()
    }
}
