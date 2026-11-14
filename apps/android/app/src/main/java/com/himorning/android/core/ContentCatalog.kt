package com.himorning.android.core

import android.content.Context
import android.util.AtomicFile
import com.himorning.android.BuildConfig
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.InputStream
import java.net.URI
import javax.net.ssl.HttpsURLConnection

data class Prompt(val id: String, val text: String, val kind: String, val language: String, val choices: List<String> = emptyList(), val correctIndex: Int? = null, val explanation: String? = null, val theme: String? = null)

internal fun decodePromptPack(json: String): List<Prompt> {
    val rows = JSONObject(json).getJSONArray("items")
    val prompts = buildList {
        for (i in 0 until rows.length()) {
            val item = rows.getJSONObject(i)
            val kind = item.optString("kind"); val id = item.optString("id"); val text = item.optString("text")
            val language = item.optString("language"); val theme = item.optString("theme").takeIf { it.isNotBlank() }
            val choices = item.optJSONArray("choices")?.let { array -> (0 until array.length()).map(array::getString) }.orEmpty()
            val answer = if (item.has("answerIndex")) item.getInt("answerIndex") else null
            if (item.optString("source") != "himorning" || item.optString("license") != "original" ||
                language !in setOf("en", "vi") || id.isBlank() || text.isBlank() ||
                (theme != null && theme !in THEMES) || (item.has("explanation") && item.optString("explanation").isBlank())) continue
            if (kind == "readAloud" && (item.has("choices") || item.has("answerIndex") ||
                    RecognizedWordMatch.tokens(text, if (language == "vi") AppLanguage.VIETNAMESE else AppLanguage.ENGLISH).size !in 18..36)) continue
            if (kind != "readAloud" && (choices.size != 3 || choices.any { it.isBlank() } ||
                    choices.map { it.trim().lowercase() }.distinct().size != choices.size || answer == null || answer !in choices.indices)) continue
            if (kind !in KINDS) continue
            add(Prompt(id, text, kind, language, choices, answer, item.optString("explanation").takeIf { it.isNotBlank() }, theme))
        }
    }
    return prompts.distinctBy { it.id }.distinctBy { item ->
        val language = if (item.language == "vi") AppLanguage.VIETNAMESE else AppLanguage.ENGLISH
        "${item.language}|${RecognizedWordMatch.tokens(item.text, language).joinToString(" ")}"
    }
}

private val THEMES = setOf("workAndStudy", "everydayLife", "peopleAndPlans", "creativeBreaks", "cityAndTravel", "curiosity")
private val KINDS = setOf("readAloud", "readAndChoose", "riddle")

internal data class PromptPack(val version: Int, val items: List<Prompt>) {
    val complete: Boolean get() = KINDS.all { kind ->
        val languages = if (kind == "readAloud") listOf("en") else listOf("en", "vi")
        languages.all { language -> items.any { it.kind == kind && it.language == language } }
    }
}

internal fun parsePromptPack(json: String) = PromptPack(JSONObject(json).getInt("version"), decodePromptPack(json))

/** Keeps a validated copy of the bilingual pack and rotates prompts independently for each exercise and language. */
class ContentCatalog(context: Context) {
    private val bundled = context.assets.open(PACK_NAME).bufferedReader().use { parsePromptPack(it.readText()) }
    private val preferences = context.getSharedPreferences("challenge-content", Context.MODE_PRIVATE)
    private val cache = AtomicFile(File(context.filesDir, PACK_NAME))
    private var pack = readCachedPack() ?: bundled
    private var refreshing = false

    @Synchronized
    fun prompt(kind: ChallengeKind, language: AppLanguage): Prompt? {
        val kindName = when (kind) {
            ChallengeKind.READ_ALOUD -> "readAloud"
            ChallengeKind.READ_AND_CHOOSE -> "readAndChoose"
            ChallengeKind.RIDDLE -> "riddle"
            else -> return null
        }
        val lang = if (kind != ChallengeKind.READ_ALOUD && language == AppLanguage.VIETNAMESE) "vi" else "en"
        val pool = pack.items.filter { it.language == lang && it.kind == kindName }
        if (pool.isEmpty()) return null

        val key = "$kindName.$lang"
        val stored = runCatching { JSONArray(preferences.getString(key, null) ?: "[]") }.getOrElse { JSONArray() }
        val history = (0 until stored.length()).map { stored.optString(it) }.takeLast(128)
        val recent = history.toHashSet()
        val unseen = pool.filterNot { it.id in recent }
        val exhausted = unseen.isEmpty()
        val candidates = if (exhausted) {
            pool.filterNot { it.id == history.lastOrNull() }.ifEmpty { pool }
        } else unseen
        val lastTheme = pool.firstOrNull { it.id == history.lastOrNull() }?.theme
        val differentTheme = if (lastTheme == null) emptyList() else candidates.filter { it.theme != null && it.theme != lastTheme }
        val selected = differentTheme.ifEmpty { candidates }.random()
        val next = ((if (exhausted) emptyList() else history) + selected.id).takeLast(128)
        preferences.edit().putString(key, JSONArray(next).toString()).apply()
        return selected
    }

    fun refreshIfDue() {
        val origin = BuildConfig.CONTENT_ORIGIN
        if (origin.isEmpty()) return
        val now = System.currentTimeMillis()
        synchronized(this) {
            val last = preferences.getLong("lastRefresh", 0)
            if (refreshing || now - last in 0 until 86_400_000L) return
            refreshing = true
        }
        try {
            val endpoint = URI(origin.trimEnd('/') + "/content/v1/$PACK_NAME")
            val connection = endpoint.toURL().openConnection() as HttpsURLConnection
            try {
                connection.connectTimeout = 10_000
                connection.readTimeout = 10_000
                connection.instanceFollowRedirects = false
                val cached = synchronized(this) { pack.version > bundled.version }
                val etag = preferences.getString("etag", null)
                if (cached && etag != null) connection.setRequestProperty("If-None-Match", etag)
                when (connection.responseCode) {
                    304 -> if (cached) preferences.edit().putLong("lastRefresh", now).apply()
                    200 -> {
                        val bytes = connection.inputStream.use { it.readPackBytes() }
                        val incoming = parsePromptPack(bytes.toString(Charsets.UTF_8))
                        val currentVersion = synchronized(this) { pack.version }
                        if (!incoming.complete || incoming.version < currentVersion) return
                        if (incoming.version > currentVersion) {
                            val stream = cache.startWrite()
                            try {
                                stream.write(bytes)
                                cache.finishWrite(stream)
                            } catch (error: Exception) {
                                cache.failWrite(stream)
                                throw error
                            }
                            synchronized(this) { pack = incoming }
                        }
                        preferences.edit().putLong("lastRefresh", now)
                            .putString("etag", connection.getHeaderField("ETag")).apply()
                    }
                }
            } finally {
                connection.disconnect()
            }
        } catch (failure: Exception) {
            android.util.Log.w("ContentCatalog", "Could not refresh challenge content", failure)
        } finally {
            synchronized(this) { refreshing = false }
        }
    }

    private fun readCachedPack(): PromptPack? = runCatching {
        val bytes = cache.openRead().use { it.readPackBytes() }
        parsePromptPack(bytes.toString(Charsets.UTF_8)).takeIf { it.version > bundled.version && it.complete }
    }.getOrNull()

    private fun InputStream.readPackBytes(): ByteArray {
        val output = ByteArrayOutputStream()
        val buffer = ByteArray(8_192)
        while (true) {
            val read = read(buffer)
            if (read < 0) return output.toByteArray()
            require(output.size() + read <= MAX_PACK_BYTES) { "Challenge content exceeds the size limit." }
            output.write(buffer, 0, read)
        }
    }

    private companion object {
        const val PACK_NAME = "challenge-content.json"
        const val MAX_PACK_BYTES = 1_048_576
    }
}
