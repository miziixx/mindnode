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
        val (endpoint, _) = resolve(settings.provider, settings.model, settings.customEndpoint, credentials.getApiKey())
        return AiRequestPreview(
            provider = settings.provider,
            model = settings.model,
            endpoint = endpoint.substringBefore("?key="), // never surface the key

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
        val prompt = "${action.instruction}\n\n$contextText\n\n각 제안을 한 줄씩, 번호 없이 작성해줘."
        val body = buildBody(settings.provider, settings.model, prompt)
        val (url, headers) = resolve(settings.provider, settings.model, settings.customEndpoint, credentials.getApiKey())
        return when (val r = post(url, headers, body)) {
            is Http.Ok -> AiResult.Success(parseSuggestions(settings.provider, r.body))
            is Http.Err -> AiResult.Failure(r.message)
        }
    }

    /**
     * Performs a real minimal request to validate the given (possibly unsaved)
     * credentials. Returns a concrete success/failure — never a fake "OK".
     * Must be called off the main thread.
     */
    fun testConnection(provider: String, apiKey: String, model: String, customEndpoint: String): AiResult {
        if (apiKey.isBlank()) return AiResult.Failure("API 키를 입력하세요.")
        if (model.isBlank()) return AiResult.Failure("모델 ID를 입력하세요.")
        val body = buildBody(provider, model, "연결 확인용 테스트입니다. '확인'이라고만 답해줘.")
        val (url, headers) = resolve(provider, model, customEndpoint, apiKey)
        return when (val r = post(url, headers, body)) {
            is Http.Ok -> AiResult.Success(listOf("연결에 성공했습니다."))
            is Http.Err -> AiResult.Failure(r.message)
        }
    }

    // ---- HTTP ----

    private sealed class Http {
        data class Ok(val body: String) : Http()
        data class Err(val message: String) : Http()
    }

    private fun post(url: String, headers: Map<String, String>, body: String): Http {
        return try {
            val conn = (URL(url).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 20000
                readTimeout = 40000
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
                headers.forEach { (k, v) -> setRequestProperty(k, v) }
            }
            conn.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            val text = stream?.bufferedReader()?.use { it.readText() } ?: ""
            // Raw bodies are never persisted or logged.
            if (code in 200..299) Http.Ok(text)
            else Http.Err("API 오류($code). 키·모델·엔드포인트를 확인하세요.")
        } catch (e: Exception) {
            Http.Err("연결에 실패했습니다. 네트워크와 엔드포인트를 확인하세요.")
        }
    }

    // ---- Provider specifics ----

    private fun resolve(provider: String, model: String, customEndpoint: String, key: String): Pair<String, Map<String, String>> {
        return when (provider) {
            "anthropic" -> "https://api.anthropic.com/v1/messages" to
                mapOf("x-api-key" to key, "anthropic-version" to "2023-06-01")
            "openai" -> "https://api.openai.com/v1/chat/completions" to
                mapOf("Authorization" to "Bearer $key")
            "gemini" ->
                "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key" to emptyMap()
            else -> {
                val ep = customEndpoint.ifBlank { "https://example.com/v1/chat/completions" }
                ep to mapOf("Authorization" to "Bearer $key")
            }
        }
    }

    private fun buildBody(provider: String, model: String, prompt: String): String {
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
