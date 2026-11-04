package com.encourise.encourise_mobile

import android.util.Log
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.Conversation
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.google.ai.edge.litertlm.ExperimentalApi
import com.google.ai.edge.litertlm.ExperimentalFlags
import com.google.ai.edge.litertlm.Message
import com.google.ai.edge.litertlm.MessageCallback
import com.google.ai.edge.litertlm.SamplerConfig
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull

/**
 * Manages the LiteRT-LM Engine and Conversation lifecycle.
 *
 * - Initializes the Engine from a `.litertlm` model file.
 * - Creates and manages a [Conversation] for multi-turn chat.
 * - All long-running operations (init, generate) run on a background
 *   dispatcher to keep the UI thread free.
 *
 * Model source:
 *   https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm
 */
@OptIn(ExperimentalApi::class)
class LitertLmService {

    companion object {
        private const val TAG = "LitertLmService"
        private const val MAX_CONTEXT_TOKENS = 2048
        private const val STREAMING_TOKEN_LIMIT_THRESHOLD = 128
        private const val JSON_STREAMING_TOKEN_LIMIT_THRESHOLD = 700
        private const val MIN_STREAMING_CHAR_BUDGET = 120
        private const val MAX_STREAMING_CHAR_BUDGET = 300
        private const val MAX_JSON_STREAMING_CHAR_BUDGET = 2400
        private const val STREAMING_TIMEOUT_MS = 28_000L
        private const val JSON_STREAMING_TIMEOUT_MS = 55_000L
    }

    private var engine: Engine? = null
    private var conversation: Conversation? = null
    private var systemInstruction: String? = null

    val isInitialized: Boolean get() = engine != null

    // ─── Initialization ────────────────────────────────────────────────

    /**
     * Loads the LiteRT-LM model from [modelPath].
     *
     * Attempts GPU backend first; falls back to CPU if GPU is unavailable.
     * [cacheDir] should be `context.cacheDir.path` to speed up subsequent loads.
     *
     * @return a map with keys "success" (Boolean), "backend" (String),
     *         and "initTimeMs" (Long).
     */
    suspend fun initialize(
        modelPath: String,
        cacheDir: String? = null,
    ): Map<String, Any> = withContext(Dispatchers.IO) {
        val start = System.currentTimeMillis()

        try {
            ExperimentalFlags.enableSpeculativeDecoding = true
            Log.i(TAG, "Speculative decoding enabled for MTP-capable LiteRT-LM models")

            // Try GPU first, fall back to CPU
            val (eng, backendName) = try {
                val gpuConfig = EngineConfig(
                    modelPath = modelPath,
                    backend = Backend.GPU(),
                    maxNumTokens = MAX_CONTEXT_TOKENS,
                    cacheDir = cacheDir,
                )
                val e = Engine(gpuConfig)
                e.initialize()
                Log.i(TAG, "Engine initialized with GPU backend")
                e to "GPU"
            } catch (gpuEx: Exception) {
                Log.w(TAG, "GPU backend failed, falling back to CPU: ${gpuEx.message}")
                val cpuConfig = EngineConfig(
                    modelPath = modelPath,
                    backend = Backend.CPU(),
                    maxNumTokens = MAX_CONTEXT_TOKENS,
                    cacheDir = cacheDir,
                )
                val e = Engine(cpuConfig)
                e.initialize()
                Log.i(TAG, "Engine initialized with CPU backend")
                e to "CPU"
            }

            engine = eng
            val elapsed = System.currentTimeMillis() - start
            Log.i(TAG, "init completed in ${elapsed}ms (backend=$backendName)")

            mapOf("success" to true, "backend" to backendName, "initTimeMs" to elapsed)
        } catch (e: Exception) {
            Log.e(TAG, "Engine initialization failed", e)
            val elapsed = System.currentTimeMillis() - start
            mapOf(
                "success" to false,
                "backend" to "none",
                "initTimeMs" to elapsed,
                "error" to (e.message ?: "Unknown error"),
            )
        }
    }

    // ─── Conversation management ───────────────────────────────────────

    /**
     * Creates a new [Conversation] with the given [systemInstruction].
     *
     * Closes any existing conversation first.
     */
    fun createConversation(systemInstruction: String? = null) {
        val eng = engine ?: throw IllegalStateException("Engine not initialized")

        conversation?.close()
        this.systemInstruction = systemInstruction

        val config = if (systemInstruction != null) {
            ConversationConfig(
                systemInstruction = Contents.of(systemInstruction),
                samplerConfig = SamplerConfig(
                    topK = 8,
                    topP = 0.85,
                    temperature = 0.55,
                ),
            )
        } else {
            ConversationConfig()
        }

        conversation = eng.createConversation(config)
        Log.i(TAG, "Conversation created")
    }

    /**
     * Sends [message] to the model and returns the full response (non-streaming).
     *
     * Runs on [Dispatchers.IO] to avoid blocking the UI thread.
     */
    suspend fun sendMessage(message: String, maxTokens: Int? = null): Map<String, Any> = withContext(Dispatchers.IO) {
        val conv = conversation
            ?: throw IllegalStateException("No active conversation. Call createConversation first.")

        val start = System.currentTimeMillis()
        try {
            val expectsJson = expectsJsonResponse(message)
            val useStreamingBudget = maxTokens != null &&
                maxTokens > 0 &&
                (maxTokens <= STREAMING_TOKEN_LIMIT_THRESHOLD ||
                    (expectsJson && maxTokens <= JSON_STREAMING_TOKEN_LIMIT_THRESHOLD))

            val generationContext = generationContext(maxTokens)
            val responseText = if (useStreamingBudget) {
                val charBudget = if (expectsJson) {
                    jsonStreamingCharBudget(maxTokens!!)
                } else {
                    streamingCharBudget(maxTokens!!)
                }
                sendMessageStreamingWithBudget(
                    conv,
                    message,
                    charBudget,
                    generationContext,
                    expectsJson,
                    maxTokens,
                )
            } else {
                conv.sendMessage(message, generationContext).toString() to false
            }
            val elapsed = System.currentTimeMillis() - start
            Log.i(
                TAG,
                "sendMessage completed in ${elapsed}ms " +
                    "(maxTokens=${maxTokens ?: "default"}, " +
                    "responseChars=${responseText.first.length}, " +
                    "truncated=${responseText.second})"
            )

            mapOf(
                "success" to true,
                "response" to responseText.first,
                "generateTimeMs" to elapsed,
            )
        } catch (e: Exception) {
            val elapsed = System.currentTimeMillis() - start
            Log.e(TAG, "sendMessage failed after ${elapsed}ms", e)
            mapOf(
                "success" to false,
                "response" to "[error] ${e.message}",
                "generateTimeMs" to elapsed,
            )
        }
    }

    private suspend fun sendMessageStreamingWithBudget(
        conv: Conversation,
        message: String,
        charBudget: Int,
        generationContext: Map<String, Any>,
        expectsJson: Boolean,
        maxTokens: Int?,
    ): Pair<String, Boolean> {
        val result = CompletableDeferred<Pair<String, Boolean>>()
        val completed = AtomicBoolean(false)
        var partial = ""

        fun finish(text: String, truncated: Boolean) {
            if (completed.compareAndSet(false, true)) {
                result.complete(text.trim() to truncated)
            }
        }

        conv.sendMessageAsync(
            message,
            object : MessageCallback {
                override fun onMessage(message: Message) {
                    val update = message.toString()
                    if (update.isBlank()) return

                    partial = mergeStreamText(partial, update)
                    val bounded = if (expectsJson) {
                        completeJsonPrefix(partial) ?: partial
                            .takeIf { it.length >= charBudget }
                            ?.take(charBudget)
                    } else {
                        completeSentenceWithinBudget(partial, charBudget)
                    }
                    if (bounded != null) {
                        finish(bounded, true)
                        try {
                            conv.cancelProcess()
                        } catch (e: Exception) {
                            Log.w(TAG, "cancel after streaming budget failed: ${e.message}")
                        }
                    }
                }

                override fun onDone() {
                    val finalText = if (expectsJson) {
                        completeJsonPrefix(partial) ?: partial
                    } else {
                        partial
                    }
                    finish(finalText, false)
                }

                override fun onError(error: Throwable) {
                    if (partial.isNotBlank()) {
                        finish(partial, true)
                    } else if (completed.compareAndSet(false, true)) {
                        result.completeExceptionally(error)
                    }
                }
            },
            generationContext,
        )

        val timeoutMs = if (expectsJson) {
            jsonStreamingTimeout(maxTokens)
        } else {
            STREAMING_TIMEOUT_MS
        }
        val response = withTimeoutOrNull(timeoutMs) {
            result.await()
        }

        if (response != null) {
            return response
        }

        try {
            conv.cancelProcess()
        } catch (e: Exception) {
            Log.w(TAG, "cancel after streaming timeout failed: ${e.message}")
        }

        val partialTrimmed = partial.trim()
        if (expectsJson) {
            return (completeJsonPrefix(partialTrimmed) ?: partialTrimmed.take(charBudget)) to true
        }
        val completePartial = bestCompleteSentence(partialTrimmed)
        val timeoutText = completePartial.ifBlank {
            if (partialTrimmed.endsWithSentencePunctuation()) partialTrimmed else ""
        }.ifBlank {
            "Budi butuh sedikit waktu lagi untuk menjawab. Coba ulangi dengan pertanyaan yang lebih pendek."
        }
        return timeoutText to true
    }

    private fun streamingCharBudget(maxTokens: Int): Int {
        return (maxTokens * 2)
            .coerceAtLeast(MIN_STREAMING_CHAR_BUDGET)
            .coerceAtMost(MAX_STREAMING_CHAR_BUDGET)
    }

    private fun jsonStreamingCharBudget(maxTokens: Int): Int {
        return (maxTokens * 4)
            .coerceAtLeast(MIN_STREAMING_CHAR_BUDGET)
            .coerceAtMost(MAX_JSON_STREAMING_CHAR_BUDGET)
    }

    private fun jsonStreamingTimeout(maxTokens: Int?): Long {
        return if (maxTokens != null && maxTokens <= 260) 32_000L else JSON_STREAMING_TIMEOUT_MS
    }

    private fun generationContext(maxTokens: Int?): Map<String, Any> {
        if (maxTokens == null || maxTokens <= 0) return emptyMap()
        return mapOf("maxNumTokens" to maxTokens)
    }

    private fun expectsJsonResponse(message: String): Boolean {
        return message.contains("Balas JSON", ignoreCase = true) ||
            message.contains("JSON valid", ignoreCase = true)
    }

    private fun mergeStreamText(current: String, update: String): String {
        if (current.isEmpty()) return update
        if (update.startsWith(current)) return update
        if (current.endsWith(update)) return current

        val maxOverlap = minOf(current.length, update.length)
        for (overlap in maxOverlap downTo 1) {
            if (current.endsWith(update.take(overlap))) {
                return current + update.drop(overlap)
            }
        }

        return current + update
    }

    private fun completeSentenceWithinBudget(text: String, charBudget: Int): String? {
        if (text.length < charBudget) return null
        val capped = text.take((charBudget + 80).coerceAtMost(text.length))
        return bestCompleteSentence(capped).takeIf { it.length >= MIN_STREAMING_CHAR_BUDGET }
    }

    private fun bestCompleteSentence(text: String): String {
        val trimmed = text.trim()
        val lastEnd = listOf('.', '!', '?').map { trimmed.lastIndexOf(it) }.maxOrNull() ?: -1
        if (lastEnd < 0) return ""
        return trimmed.take(lastEnd + 1).trim()
    }

    private fun completeJsonPrefix(text: String): String? {
        val start = text.indexOfFirst { it == '{' || it == '[' }
        if (start < 0) return null

        val opening = text[start]
        val closing = if (opening == '{') '}' else ']'
        var curlyDepth = 0
        var squareDepth = 0
        var inString = false
        var escaping = false

        for (i in start until text.length) {
            val ch = text[i]
            if (escaping) {
                escaping = false
                continue
            }
            if (ch == '\\' && inString) {
                escaping = true
                continue
            }
            if (ch == '"') {
                inString = !inString
                continue
            }
            if (inString) continue

            when (ch) {
                '{' -> curlyDepth++
                '}' -> curlyDepth--
                '[' -> squareDepth++
                ']' -> squareDepth--
            }

            if (ch == closing && curlyDepth == 0 && squareDepth == 0) {
                return text.substring(start, i + 1).trim()
            }
            if (curlyDepth < 0 || squareDepth < 0) return null
        }

        return null
    }

    private fun String.endsWithSentencePunctuation(): Boolean {
        val trimmed = trim()
        return trimmed.endsWith(".") || trimmed.endsWith("!") || trimmed.endsWith("?")
    }

    /** Resets the conversation (closes current and creates a new one). */
    fun resetConversation() {
        createConversation(systemInstruction)
    }

    /** Returns basic engine/backend info. */
    fun getBackendInfo(): Map<String, Any> {
        return mapOf(
            "initialized" to isInitialized,
            "hasConversation" to (conversation != null),
        )
    }

    /**
     * Warms up the engine by sending a short throwaway message.
     *
     * This primes the KV cache and JIT compilation, improving latency
     * for the first real user message. After warm-up the conversation
     * is reset so the throwaway turn does not pollute the history.
     */
    suspend fun warmup(): Map<String, Any> = withContext(Dispatchers.IO) {
        val start = System.currentTimeMillis()
        try {
            val conv = conversation
                ?: throw IllegalStateException("No conversation to warm up")
            conv.sendMessage("Hi")
            // Reset so the warm-up turn is discarded
            resetConversation()
            val elapsed = System.currentTimeMillis() - start
            Log.i(TAG, "warmup completed in ${elapsed}ms")
            mapOf("success" to true, "warmupTimeMs" to elapsed)
        } catch (e: Exception) {
            val elapsed = System.currentTimeMillis() - start
            Log.w(TAG, "warmup failed after ${elapsed}ms: ${e.message}")
            mapOf("success" to false, "warmupTimeMs" to elapsed, "error" to (e.message ?: "unknown"))
        }
    }

    /** Releases all native resources. */
    fun dispose() {
        conversation?.close()
        conversation = null
        engine?.close()
        engine = null
        Log.i(TAG, "Engine and conversation disposed")
    }
}
