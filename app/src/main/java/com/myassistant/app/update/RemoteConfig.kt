package com.myassistant.app.update

import com.myassistant.app.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import okhttp3.OkHttpClient
import okhttp3.Request

/**
 * SERVER-DRIVEN FEATURES — how "updates without rebuilding" works.
 *
 * The app fetches this config from YOUR backend on every launch.
 * When you ship a new AI capability on the server (a new tool, a new
 * language, a new card type), you flip its flag here and every
 * installed app picks it up instantly — no Play Store release needed.
 *
 * What CAN be updated this way (Play-policy safe):
 *   - AI behaviour, prompts, models, new assistant capabilities (all server-side)
 *   - Feature flags: show/hide screens and buttons already in the app
 *   - Announcements, changelog text, quality settings
 *
 * What CANNOT (requires a Play Store release):
 *   - New native code / screens that don't exist in the APK yet.
 *     Downloading and executing code outside Play violates Google Play
 *     policy and will get the app removed. For those, UpdateManager
 *     triggers the official Play in-app update flow instead.
 */
@Serializable
data class RemoteConfig(
    val latestVersionCode: Int = 1,
    val latestVersionName: String = "0.1.0",
    val forceUpdateBelow: Int = 0,          // versions below this must update
    val changelog: List<String> = emptyList(),
    val announcement: String? = null,        // e.g. "New: Malayalam voice is live!"
    val features: Map<String, Boolean> = emptyMap() // e.g. "voice_mode" to true
)

object ConfigRepository {
    private val client = OkHttpClient()
    private val json = Json { ignoreUnknownKeys = true }

    @Volatile var current: RemoteConfig = RemoteConfig()
        private set

    suspend fun refresh(): RemoteConfig = withContext(Dispatchers.IO) {
        try {
            val req = Request.Builder()
                .url("${BuildConfig.BASE_URL}/config?v=${BuildConfig.VERSION_CODE}")
                .build()
            client.newCall(req).execute().use { resp ->
                if (resp.isSuccessful) {
                    current = json.decodeFromString<RemoteConfig>(resp.body!!.string())
                }
            }
        } catch (_: Exception) {
            // Offline or server down — keep last known config. Never crash on config.
        }
        current
    }

    fun isEnabled(feature: String): Boolean = current.features[feature] == true
}
