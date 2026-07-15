package com.myassistant.app.data

import com.myassistant.app.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

@Serializable data class ChatMessage(val role: String, val content: String)
@Serializable data class ChatRequest(val messages: List<ChatMessage>, val language: String = "auto")
@Serializable data class ChatResponse(val reply: String, val sources: List<String> = emptyList())

/**
 * The app never holds AI provider keys. All AI traffic goes through
 * the backend (Section 5 of the scope doc), which routes to at least
 * two AI providers and enforces safety rules server-side.
 */
object ChatApi {
    private val client = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .build()
    private val json = Json { ignoreUnknownKeys = true }
    private val jsonMedia = "application/json; charset=utf-8".toMediaType()

    suspend fun send(history: List<ChatMessage>): ChatResponse = withContext(Dispatchers.IO) {
        val body = json.encodeToString(ChatRequest(history)).toRequestBody(jsonMedia)
        val req = Request.Builder()
            .url("${BuildConfig.BASE_URL}/chat")
            .post(body)
            .build()
        client.newCall(req).execute().use { resp ->
            if (!resp.isSuccessful) error("Server error ${resp.code}")
            json.decodeFromString(resp.body!!.string())
        }
    }
}
