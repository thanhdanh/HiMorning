package com.himorning.android.core

import android.content.Context
import org.json.JSONObject
import java.util.concurrent.ThreadLocalRandom

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
                    RecognizedWordMatch.tokens(text, if (language == "vi") AppLanguage.VIETNAMESE else AppLanguage.ENGLISH).size !in 18..30)) continue
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

/** Uses the same reviewed bilingual prompt pack as iOS; bundled content works offline. */
class ContentCatalog(context: Context) {
    private val items = context.assets.open("challenge-content.json").bufferedReader().use { decodePromptPack(it.readText()) }
    private val recentlyUsed = mutableMapOf<Pair<String, String>, String>()

    @Synchronized fun prompt(kind: ChallengeKind, language: AppLanguage): Prompt? {
        val kindName = when (kind) { ChallengeKind.READ_ALOUD -> "readAloud"; ChallengeKind.READ_AND_CHOOSE -> "readAndChoose"; ChallengeKind.RIDDLE -> "riddle"; else -> return null }
        val lang = if (language == AppLanguage.VIETNAMESE) "vi" else "en"
        val pool = items.filter { it.language == lang && it.kind == kindName }
        val key = kindName to lang
        val available = pool.filterNot { it.id == recentlyUsed[key] }.ifEmpty { pool }
        val selected = available.getOrNull(ThreadLocalRandom.current().nextInt(available.size)) ?: return null
        recentlyUsed[key] = selected.id
        return selected
    }
}
