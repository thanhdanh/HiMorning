package com.himorning.android.core

import java.text.Normalizer
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.UUID

/** Weekday numbering follows iOS Calendar: Sunday = 1 through Saturday = 7. */
enum class WakeMode(val repetitions: Int, val snoozes: Int) { GENTLE(0, 2), BALANCED(5, 1), FOCUSED(10, 0) }
enum class AlarmSound { SYSTEM, SUNRISE, SOFT_CHIME, PIZZICATO_DAWN, PIZZICATO_STEPS, PIZZICATO_RISE, PIZZICATO_BLOOM, STEEL_SHIMMER, STEEL_BREEZE, STEEL_MORNING, STEEL_SPARKLE, SAX_HELLO, SAX_STROLL, SAX_GLOW, SAX_DAYBREAK }
enum class ScheduleState { PENDING, CONFIRMED, OFF, NEEDS_REVIEW }
enum class ChallengeKind { NONE, PUSH_UPS, READ_AND_CHOOSE, GUIDED_RHYTHM, READ_ALOUD, WAVE_HAND, NECK_ROTATION, RIDDLE, JUMPING_JACKS, STRETCHING }
enum class WakeOutcome { SELF_CONFIRMED, LOCAL_COMPLETED, AI_VERIFIED, DISMISSED }
enum class MorningFocus { CLEAR_START, GENTLE_MOVEMENT, FIND_YOUR_VOICE, ENERGIZE }
enum class AppLanguage { SYSTEM, ENGLISH, VIETNAMESE }

fun WakeMode.availableChallenges(legacy: ChallengeKind? = null): List<ChallengeKind> {
    val choices = when (this) {
        WakeMode.GENTLE -> listOf(ChallengeKind.NONE, ChallengeKind.WAVE_HAND, ChallengeKind.NECK_ROTATION)
        WakeMode.BALANCED -> listOf(ChallengeKind.READ_ALOUD, ChallengeKind.READ_AND_CHOOSE, ChallengeKind.RIDDLE)
        WakeMode.FOCUSED -> listOf(ChallengeKind.PUSH_UPS, ChallengeKind.JUMPING_JACKS, ChallengeKind.STRETCHING)
    }
    return if (legacy != null && legacy !in choices) choices + legacy else choices
}

fun MorningFocus.mission(index: Int, hasFullAccess: Boolean): ChallengeKind {
    val day = index.coerceIn(0, 6)
    return when (this) {
        MorningFocus.CLEAR_START -> if (day % 2 == 1) ChallengeKind.RIDDLE else ChallengeKind.READ_AND_CHOOSE
        MorningFocus.GENTLE_MOVEMENT -> when (day) { 0, 3 -> ChallengeKind.WAVE_HAND; 1, 5 -> ChallengeKind.NECK_ROTATION; else -> ChallengeKind.GUIDED_RHYTHM }
        MorningFocus.FIND_YOUR_VOICE -> when (day) { 1, 3, 5, 6 -> ChallengeKind.READ_ALOUD; 4 -> ChallengeKind.RIDDLE; else -> ChallengeKind.READ_AND_CHOOSE }
        MorningFocus.ENERGIZE -> if (!hasFullAccess) MorningFocus.GENTLE_MOVEMENT.mission(day, false) else when (day) {
            0 -> ChallengeKind.WAVE_HAND; 1, 4, 6 -> ChallengeKind.PUSH_UPS; 2 -> ChallengeKind.STRETCHING; 3 -> ChallengeKind.JUMPING_JACKS; else -> ChallengeKind.GUIDED_RHYTHM
        }
    }
}

data class Alarm(
    val id: String = UUID.randomUUID().toString(),
    val hour: Int,
    val minute: Int,
    val weekdays: Set<Int> = emptySet(),
    val mode: WakeMode = WakeMode.GENTLE,
    val sound: AlarmSound = AlarmSound.SYSTEM,
    val challenge: ChallengeKind = ChallengeKind.NONE,
    val repetitions: Int = 5,
    val seated: Boolean = false,
    val label: String = "",
    val enabled: Boolean = true,
    val state: ScheduleState = ScheduleState.PENDING,
    val scheduledAt: Long? = null,
) {
    init {
        require(hour in 0..23 && minute in 0..59) { "Invalid alarm time" }
        require(weekdays.all { it in 1..7 }) { "Invalid weekday" }
        require(repetitions in 1..50) { "Invalid challenge repetitions" }
        require(runCatching { UUID.fromString(id) }.isSuccess) { "Invalid alarm ID" }
    }

    fun nextAfter(now: Instant, zone: ZoneId): Instant {
        val localNow = now.atZone(zone)
        for (dayOffset in 0..7) {
            val date = localNow.toLocalDate().plusDays(dayOffset.toLong())
            val weekday = date.dayOfWeek.value % 7 + 1
            if (weekdays.isNotEmpty() && weekday !in weekdays) continue
            val wallTime = date.atTime(hour, minute)
            val offsets = zone.rules.getValidOffsets(wallTime)
            val occurrence = when {
                offsets.isNotEmpty() -> ZonedDateTime.ofLocal(wallTime, zone, offsets.first()).toInstant()
                else -> zone.rules.getTransition(wallTime).dateTimeAfter.atZone(zone).toInstant()
            }
            if (occurrence.isAfter(now)) return occurrence
        }
        error("Unable to find next alarm")
    }
}

data class MorningEntry(
    val sessionId: String,
    val alarmId: String?,
    val mode: WakeMode?,
    val challenge: ChallengeKind?,
    val date: Long,
    val outcome: WakeOutcome,
)

data class Journey(
    val focus: MorningFocus = MorningFocus.CLEAR_START,
    val startedAt: Long = 0L,
    val completions: List<Long> = emptyList(),
    val completedJourneys: Int = 0,
    val lastCompletionAt: Long? = completions.maxOrNull(),
) {
    val complete get() = completions.size == 7
    fun completedToday(now: Long = System.currentTimeMillis(), zone: ZoneId = ZoneId.systemDefault()): Boolean =
        lastCompletionAt?.let { Instant.ofEpochMilli(it).atZone(zone).toLocalDate() == Instant.ofEpochMilli(now).atZone(zone).toLocalDate() } ?: false
    fun missionIndex(now: Long = System.currentTimeMillis(), zone: ZoneId = ZoneId.systemDefault()): Int =
        if (completedToday(now, zone)) (completions.size - 1).coerceIn(0, 6) else completions.size.coerceAtMost(6)
    fun record(entry: MorningEntry, rehearsal: Boolean, now: Long, zone: ZoneId = ZoneId.systemDefault()): Journey {
        if (rehearsal || entry.outcome !in SUCCESSFUL || entry.date !in startedAt..now || completions.size >= 7) return this
        val day = Instant.ofEpochMilli(entry.date).atZone(zone).toLocalDate().toEpochDay()
        if (completions.any { Instant.ofEpochMilli(it).atZone(zone).toLocalDate().toEpochDay() == day } ||
            lastCompletionAt?.let { Instant.ofEpochMilli(it).atZone(zone).toLocalDate().toEpochDay() == day } == true) return this
        return copy(completions = (completions + entry.date).sorted(), lastCompletionAt = maxOf(lastCompletionAt ?: entry.date, entry.date))
    }

    companion object { private val SUCCESSFUL = setOf(WakeOutcome.LOCAL_COMPLETED, WakeOutcome.AI_VERIFIED) }
}

/** One durable wake row can be promoted from dismissal to a later verified recovery. */
internal fun reconcileWake(entries: List<MorningEntry>, next: MorningEntry): List<MorningEntry>? {
    val index = entries.indexOfFirst { it.sessionId == next.sessionId }
    if (index < 0) return entries + next
    if (entries[index].outcome != WakeOutcome.DISMISSED || next.outcome == WakeOutcome.DISMISSED) return null
    return entries.toMutableList().also { it[index] = next }
}

data class AppState(
    val alarms: List<Alarm> = emptyList(),
    val entries: List<MorningEntry> = emptyList(),
    val weeklyGoal: Int = 3,
    val journey: Journey = Journey(),
    val previewStartedAt: Long? = null,
    val previewLastSeenAt: Long? = null,
    val language: AppLanguage = AppLanguage.SYSTEM,
) { init { require(weeklyGoal in 1..7) } }

class WakeSession(val mode: WakeMode) {
    var outcome: WakeOutcome? = null; private set
    var snoozesUsed = 0; private set
    var generation = 0; private set
    private var pending = false
    fun beginVerification() = (++generation).also { pending = outcome == null }
    fun applyVerified(token: Int): Boolean {
        if (!pending || outcome != null || token != generation) return false
        pending = false; outcome = WakeOutcome.AI_VERIFIED; return true
    }
    fun interruptVerification() { generation++; pending = false }
    fun completeLocally(): Boolean {
        if (outcome != null) return false
        generation++; pending = false; outcome = WakeOutcome.LOCAL_COMPLETED; return true
    }
    fun selfConfirm() { generation++; pending = false; if (outcome == null) outcome = WakeOutcome.SELF_CONFIRMED }
    fun stop() { generation++; pending = false; if (outcome == null) outcome = WakeOutcome.DISMISSED }
    fun snooze(): Boolean {
        if (outcome != null || snoozesUsed >= mode.snoozes) return false
        snoozesUsed++; generation++; pending = false; return true
    }
}

object RecognizedWordMatch {
    const val PASSING_SCORE = .8
    fun tokens(text: String, language: AppLanguage): List<String> {
        val lower = text.lowercase(if (language == AppLanguage.VIETNAMESE) java.util.Locale("vi", "VN") else java.util.Locale.US)
        val normalized = if (language == AppLanguage.VIETNAMESE) lower else Normalizer.normalize(lower, Normalizer.Form.NFD).replace("\\p{Mn}+".toRegex(), "")
        return "[\\p{L}\\p{N}]+".toRegex().findAll(normalized).map { it.value }.toList()
    }
    enum class WordStatus { CORRECT, INCORRECT, PENDING }
    data class Word(val text: String, val status: WordStatus)
    data class Feedback(val words: List<Word>, val extraWords: List<String>, val score: Double)
    fun score(target: String, recognized: String, language: AppLanguage): Double = feedback(target, recognized, language, true).score
    fun feedback(target: String, recognized: String, language: AppLanguage, finished: Boolean): Feedback {
        val expected = tokens(target, language)
        val actual = tokens(recognized, language)
        if (expected.isEmpty()) return Feedback(emptyList(), actual, 0.0)
        val distance = Array(expected.size + 1) { IntArray(actual.size + 1) }
        for (i in expected.indices) distance[i + 1][0] = i + 1
        for (j in actual.indices) distance[0][j + 1] = j + 1
        for (i in expected.indices) for (j in actual.indices) {
            distance[i + 1][j + 1] = minOf(distance[i][j + 1] + 1, distance[i + 1][j] + 1, distance[i][j] + if (expected[i] == actual[j]) 0 else 1)
        }
        val words = expected.map { Word(it, WordStatus.PENDING) }.toMutableList()
        val extras = mutableListOf<String>()
        var i = expected.size
        var j = actual.size
        var laterSpeech = false
        while (i > 0 || j > 0) {
            when {
                i > 0 && j > 0 && expected[i - 1] == actual[j - 1] && distance[i][j] == distance[i - 1][j - 1] -> {
                    words[i - 1] = Word(expected[i - 1], WordStatus.CORRECT); laterSpeech = true; i--; j--
                }
                i > 0 && distance[i][j] == distance[i - 1][j] + 1 -> {
                    words[i - 1] = Word(expected[i - 1], if (finished || laterSpeech) WordStatus.INCORRECT else WordStatus.PENDING); i--
                }
                i > 0 && j > 0 && distance[i][j] == distance[i - 1][j - 1] + 1 -> {
                    words[i - 1] = Word(expected[i - 1], WordStatus.INCORRECT); laterSpeech = true; i--; j--
                }
                else -> { extras += actual[j - 1]; j-- }
            }
        }
        val score = maxOf(0.0, 1.0 - distance.last().last().toDouble() / maxOf(expected.size, actual.size))
        return Feedback(words, extras.reversed(), score)
    }
}
