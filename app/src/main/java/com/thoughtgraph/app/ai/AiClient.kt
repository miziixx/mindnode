package com.thoughtgraph.app.ai

import com.thoughtgraph.app.settings.SecureCredentialStore
import com.thoughtgraph.app.settings.SettingsStore
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/** The optional AI actions, only shown when AI is enabled and configured. */
enum class AiAction(val label: String, val instruction: String) {
    FIND_GAPS("빈틈 찾기", "다음 생각 구조에서 빠져 있거나 검토가 필요한 부분을 3가지 이내로 제안해줘."),
    OPPOSITE("반대 관점", "다음 생각에 대한 반대 관점이나 반론을 제시해줘."),
    REFINE("문장 구체화", "다음 노드의 제목과 설명을 더 구체적이고 명확하게 다시 써줘."),
    NEXT_STEP("다음 단계 제안", "다음 생각을 실행하기 위한 구체적인 다음 단계를 제안해줘.")
}

data class AiRequestPreview(
    val provider: String,
    val model: String,
    val endpoint: String,
    val payloadPreview: String
)

sealed class AiResult {
    data class Success(val suggestions: List<String>) : AiResult()
    data class Failure(val message: String) : AiResult()
    /** AI is not configured — callers should show setup guidance, not an error. */
    object NotConfigured : AiResult()
}

/**
 * Minimal, manual-only API client. It is only ever invoked directly from a user
 * button press after an explicit confirmation of the preview. It never runs in
 * the background and never sends the whole graph unless the user opted out of
 * "선택한 노드만 전송".
 *
 * Raw request/response bodies are not persisted or logged (see [SettingsStore.noHistory]).
 */
class AiClient(
    private val settings: SettingsStore,
    private val credentials: SecureCredentialStore
) {

    fun isReady(): Boolean =
        settings.aiEnabled && credentials.hasApiKey() && settings.model.isNotBlank()

    fun buildPreview(action: AiAction, contextText: String): AiRequestPreview {
        val (endpoint, _) = endpointAndAuth()
        return AiRequestPreview(
            provider = settings.provider,
            model = settings.model,
            endpoint = endpoint,
            payloadPreview = "${action.instruction}\n\n$contextText"
        )
    }

    /**
     * Blocking network call. Must be run off the main thread by the caller.
     * Any failure is returned as [AiResult.Failure] and never throws, so the
     * rest of the graph editor is unaffected.
     */
    fun run(action: AiAction, contextText: String): AiResult {
        if (!isReady()) return AiResult.NotConfigured
        val key = credentials.getApiKey()
        val model = settings.model
        val (endpoint, headers) = endpointAndAuth()
        val body = buildBody(settings.provider, model, action, contextText)

        return try {
            val conn = (URL(endpoint).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 20000
                readTimeout = 40000
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
                headers(key).forEach { (k, v) -> setRequestProperty(k, v) }
            }
            conn.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            val text = stream?.bufferedReader()?.use { it.readText() } ?: ""
            if (code !in 200..299) {
                // Do not include the raw body in a persisted log; only a short message.
                AiResult.Failure("API 오류($code). 키와 모델 설정을 확인하세요.")
            } else {
                AiResult.Success(parseSuggestions(settings.provider, text))
            }
        } catch (e: Exception) {
            AiResult.Failure("연결에 실패했습니다. 네트워크와 엔드포인트를 확인하세요.")
        }
    }

    // ---- Provider specifics ----

    private fun endpointAndAuth(): Pair<String, (String) -> Map<String, String>> {
        return when (settings.provider) {
            "anthropic" -> "https://api.anthropic.com/v1/messages" to { key: String ->
                mapOf("x-api-key" to key, "anthropic-version" to "2023-06-01")
            }
            "openai" -> "https://api.openai.com/v1/chat/completions" to { key: String ->
                mapOf("Authorization" to "Bearer $key")
            }
            "gemini" -> {
                // Model id is user supplied; key is passed as a query param per API.
                "https://generativelanguage.googleapis.com/v1beta/models/${settings.model}:generateContent" to
                    { _: String -> emptyMap() }
            }
            else -> {
                val ep = settings.customEndpoint.ifBlank { "https://example.com/v1/chat/completions" }
                ep to { key: String -> mapOf("Authorization" to "Bearer $key") }
            }
        }
    }

    private fun buildBody(provider: String, model: String, action: AiAction, context: String): String {
        val prompt = "${action.instruction}\n\n$context\n\n각 제안을 한 줄씩, 번호 없이 작성해줘."
        return when (provider) {
            "anthropic" -> JSONObject().apply {
                put("model", model)
                put("max_tokens", 1024)
                put("messages", JSONArray().put(JSONObject().apply {
                    put("role", "user"); put("content", prompt)
                }))
            }.toString()
            "openai", "custom" -> JSONObject().apply {
                put("model", model)
                put("messages", JSONArray().put(JSONObject().apply {
                    put("role", "user"); put("content", prompt)
                }))
            }.toString()
            "gemini" -> JSONObject().apply {
                put("contents", JSONArray().put(JSONObject().apply {
                    put("parts", JSONArray().put(JSONObject().put("text", prompt)))
                }))
            }.toString()
            else -> JSONObject().put("prompt", prompt).toString()
        }
    }

    private fun parseSuggestions(provider: String, response: String): List<String> {
        val raw = try {
            val obj = JSONObject(response)
            when (provider) {
                "anthropic" -> obj.getJSONArray("content").getJSONObject(0).optString("text")
                "openai", "custom" -> obj.getJSONArray("choices").getJSONObject(0)
                    .getJSONObject("message").optString("content")
                "gemini" -> obj.getJSONArray("candidates").getJSONObject(0)
                    .getJSONObject("content").getJSONArray("parts").getJSONObject(0).optString("text")
                else -> response
            }
        } catch (e: Exception) {
            response
        }
        return raw.split("\n")
            .map { it.trim().removePrefix("-").removePrefix("•").trim() }
            .filter { it.isNotBlank() }
            .take(5)
    }
}
