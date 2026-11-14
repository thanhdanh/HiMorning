package com.himorning.android.core

import android.content.Context
import android.util.AtomicFile
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.time.Instant
import java.time.ZoneId
import java.util.UUID
import kotlin.math.ceil

/** Local first repository. AtomicFile prevents torn writes; decode errors are surfaced without replacing the file. */
class AppRepository(context: Context) {
    private val file = AtomicFile(File(context.filesDir, "himorning-state.json"))
    private var cachedState: AppState = synchronized(repositoryLock) { read() }
    val state: AppState get() = synchronized(repositoryLock) { cachedState = read(); cachedState }

    fun saveAlarm(alarm: Alarm) = synchronized(repositoryLock) {
        cachedState = read()
        val saved = alarm.copy(label = alarm.label.trim(), state = ScheduleState.PENDING, enabled = true,
            scheduledAt = if (alarm.weekdays.isEmpty()) alarm.nextAfter(Instant.now(), ZoneId.systemDefault()).toEpochMilli() else null)
        require(cachedState.alarms.none { it.id == saved.id }) { "Alarm already exists" }
        commit(cachedState.copy(alarms = cachedState.alarms + saved))
    }

    fun updateAlarm(alarm: Alarm) = synchronized(repositoryLock) {
        cachedState = read()
        val old = cachedState.alarms.firstOrNull { it.id == alarm.id } ?: error("Alarm not found")
        val changed = old.hour != alarm.hour || old.minute != alarm.minute || old.weekdays != alarm.weekdays || old.sound != alarm.sound
        val updated = alarm.copy(enabled = old.enabled, state = if (changed && old.enabled) ScheduleState.PENDING else old.state,
            scheduledAt = if (!changed) old.scheduledAt else if (alarm.weekdays.isEmpty()) alarm.nextAfter(Instant.now(), ZoneId.systemDefault()).toEpochMilli() else null)
        commit(cachedState.copy(alarms = cachedState.alarms.map { if (it.id == alarm.id) updated else it }))
    }

    /** Keep the native registration ID when cancellation is uncertain; restore only this alarm's fields. */
    internal fun rollbackAlarmSave(id: String, previous: Alarm?, registrationUncertain: Boolean) = synchronized(repositoryLock) {
        cachedState = read()
        require(previous == null || previous.id == id) { "Alarm recovery ID mismatch" }
        val current = cachedState.alarms.firstOrNull { it.id == id }
        if (previous != null && current != null) {
            val restored = previous.copy(state = if (registrationUncertain) ScheduleState.NEEDS_REVIEW else previous.state)
            commit(cachedState.copy(alarms = cachedState.alarms.map { if (it.id == id) restored else it }))
        } else if (previous == null && current != null) {
            commit(cachedState.copy(alarms = if (registrationUncertain) cachedState.alarms.map {
                if (it.id == id) it.copy(state = ScheduleState.NEEDS_REVIEW) else it
            } else cachedState.alarms.filterNot { it.id == id }))
        }
    }

    fun removeAlarm(id: String) = synchronized(repositoryLock) {
        cachedState = read()
        require(cachedState.alarms.any { it.id == id }) { "Alarm not found" }
        commit(cachedState.copy(alarms = cachedState.alarms.filterNot { it.id == id }))
    }

    fun updateAlarmState(id: String, scheduleState: ScheduleState, scheduledAt: Long? = null) = synchronized(repositoryLock) {
        cachedState = read()
        require(cachedState.alarms.any { it.id == id }) { "Alarm not found" }
        commit(cachedState.copy(alarms = cachedState.alarms.map { if (it.id == id) it.copy(state = scheduleState, scheduledAt = scheduledAt ?: it.scheduledAt) else it }))
        if (scheduleState == ScheduleState.CONFIRMED && cachedState.previewStartedAt == null) {
            val now = System.currentTimeMillis()
            commit(cachedState.copy(previewStartedAt = now, previewLastSeenAt = now))
        }
    }

    fun setAlarmEnabled(id: String, enabled: Boolean) = synchronized(repositoryLock) {
        cachedState = read()
        require(cachedState.alarms.any { it.id == id }) { "Alarm not found" }
        val now = Instant.now()
        commit(cachedState.copy(alarms = cachedState.alarms.map { alarm ->
            if (alarm.id != id) alarm else alarm.copy(enabled = enabled, state = ScheduleState.PENDING,
                scheduledAt = if (enabled && alarm.weekdays.isEmpty()) alarm.nextAfter(now, ZoneId.systemDefault()).toEpochMilli() else alarm.scheduledAt)
        }))
    }

    fun record(sessionId: String, alarmId: String?, mode: WakeMode?, challenge: ChallengeKind?, outcome: WakeOutcome, practice: Boolean = false, now: Long = System.currentTimeMillis()): Boolean = synchronized(repositoryLock) {
        cachedState = read()
        val id = runCatching { UUID.fromString(sessionId) }.getOrNull() ?: return false
        val date = now
        if (practice || date > now || date < now - 30L * 86_400_000) return false
        val entry = MorningEntry(id.toString(), alarmId, mode, challenge, date, outcome)
        val entries = reconcileWake(cachedState.entries.filter { it.date >= now - 30L * 86_400_000 }, entry) ?: return false
        val journey = cachedState.journey.record(entry, rehearsal = false, now = now)
        commit(cachedState.copy(entries = entries, journey = journey))
        true
    }

    fun setGoal(goal: Int) = synchronized(repositoryLock) { cachedState = read(); require(goal in 1..7); commit(cachedState.copy(weeklyGoal = goal)) }
    fun setFocus(focus: MorningFocus) = synchronized(repositoryLock) { cachedState = read(); commit(cachedState.copy(journey = cachedState.journey.copy(focus = focus))) }
    fun setLanguage(language: AppLanguage) = synchronized(repositoryLock) { cachedState = read(); commit(cachedState.copy(language = language)) }

    fun restartJourney(now: Long = System.currentTimeMillis()): Boolean = synchronized(repositoryLock) {
        cachedState = read()
        val journey = cachedState.journey
        val last = journey.lastCompletionAt ?: journey.startedAt
        if (!journey.complete || now < last) return false
        commit(cachedState.copy(journey = Journey(journey.focus, now, emptyList(), journey.completedJourneys + 1, last)))
        true
    }

    /** Once started, time cannot move backward to restore preview days. */
    fun remainingPreviewDays(now: Long = System.currentTimeMillis()): Int = synchronized(repositoryLock) {
        cachedState = read()
        val started = cachedState.previewStartedAt ?: return 30
        val effectiveNow = maxOf(now, cachedState.previewLastSeenAt ?: started, started)
        if (effectiveNow != cachedState.previewLastSeenAt) commit(cachedState.copy(previewLastSeenAt = effectiveNow))
        ceil((started + 30L * 86_400_000 - effectiveNow).coerceAtLeast(0) / 86_400_000.0).toInt()
    }

    private fun commit(next: AppState) {
        write(next)
        cachedState = next
    }

    private fun write(next: AppState) {
        val bytes = encode(next).toString().toByteArray(Charsets.UTF_8)
        var stream: java.io.FileOutputStream? = null
        try {
            stream = file.startWrite(); stream.write(bytes); file.finishWrite(stream)
        } catch (error: Exception) { if (stream != null) file.failWrite(stream); throw error }
    }

    private fun read(): AppState {
        return try { file.openRead().bufferedReader().use { decode(JSONObject(it.readText())) } }
        catch (missing: java.io.FileNotFoundException) { AppState(journey = Journey(startedAt = System.currentTimeMillis())) }
    }

    companion object { private val repositoryLock = Any() }

    private fun encode(value: AppState) = JSONObject().apply {
        put("schemaVersion", 1)
        put("alarms", JSONArray().also { a -> value.alarms.forEach { alarm -> a.put(JSONObject().apply {
            put("id", alarm.id); put("hour", alarm.hour); put("minute", alarm.minute); put("weekdays", JSONArray(alarm.weekdays.sorted()))
            put("mode", alarm.mode.name); put("sound", alarm.sound.name); put("challenge", alarm.challenge.name); put("repetitions", alarm.repetitions)
            put("seated", alarm.seated); put("label", alarm.label); put("enabled", alarm.enabled); put("state", alarm.state.name)
            alarm.scheduledAt?.let { put("scheduledAt", it) }
        }) } })
        put("entries", JSONArray().also { a -> value.entries.forEach { entry -> a.put(JSONObject().apply {
            put("sessionId", entry.sessionId); entry.alarmId?.let { put("alarmId", it) }; entry.mode?.let { put("mode", it.name) }
            entry.challenge?.let { put("challenge", it.name) }; put("date", entry.date); put("outcome", entry.outcome.name)
        }) } })
        put("weeklyGoal", value.weeklyGoal); put("journey", JSONObject().apply {
            put("focus", value.journey.focus.name); put("startedAt", value.journey.startedAt); put("completions", JSONArray(value.journey.completions)); put("completedJourneys", value.journey.completedJourneys)
            value.journey.lastCompletionAt?.let { put("lastCompletionAt", it) }
        })
        value.previewStartedAt?.let { put("previewStartedAt", it) }; value.previewLastSeenAt?.let { put("previewLastSeenAt", it) }; put("language", value.language.name)
    }

    private fun decode(json: JSONObject): AppState {
        require(json.getInt("schemaVersion") == 1) { "Unsupported saved state" }
        val alarms = json.getJSONArray("alarms")
        val entries = json.getJSONArray("entries")
        val j = json.getJSONObject("journey")
        val result = AppState(
            alarms = (0 until alarms.length()).map { i -> alarms.getJSONObject(i).let { a -> Alarm(
                id = a.getString("id"), hour = a.getInt("hour"), minute = a.getInt("minute"),
                weekdays = a.getJSONArray("weekdays").let { days -> (0 until days.length()).map { days.getInt(it) }.toSet() },
                mode = WakeMode.valueOf(a.getString("mode")), sound = AlarmSound.valueOf(a.getString("sound")), challenge = ChallengeKind.valueOf(a.getString("challenge")),
                repetitions = a.getInt("repetitions"), seated = a.optBoolean("seated"), label = a.optString("label"), enabled = a.getBoolean("enabled"),
                state = ScheduleState.valueOf(a.getString("state")), scheduledAt = if (a.has("scheduledAt")) a.getLong("scheduledAt") else null,
            ) } },
            entries = (0 until entries.length()).map { i -> entries.getJSONObject(i).let { e -> MorningEntry(
                e.getString("sessionId"), e.optString("alarmId").ifEmpty { null }, e.optString("mode").takeIf(String::isNotEmpty)?.let(WakeMode::valueOf),
                e.optString("challenge").takeIf(String::isNotEmpty)?.let(ChallengeKind::valueOf), e.getLong("date"), WakeOutcome.valueOf(e.getString("outcome")),
            ) } },
            weeklyGoal = json.optInt("weeklyGoal", 3),
            journey = j.getJSONArray("completions").let { days ->
                val completions = (0 until days.length()).map { days.getLong(it) }
                Journey(MorningFocus.valueOf(j.getString("focus")), j.getLong("startedAt"), completions, j.getInt("completedJourneys"),
                    if (j.has("lastCompletionAt")) j.getLong("lastCompletionAt") else completions.maxOrNull())
            },
            previewStartedAt = if (json.has("previewStartedAt")) json.getLong("previewStartedAt") else null,
            previewLastSeenAt = if (json.has("previewLastSeenAt")) json.getLong("previewLastSeenAt") else null,
            language = AppLanguage.valueOf(json.optString("language", AppLanguage.SYSTEM.name)),
        )
        require(result.alarms.map { it.id }.distinct().size == result.alarms.size) { "Duplicate alarm IDs" }
        require(result.entries.map { it.sessionId }.distinct().size == result.entries.size) { "Duplicate session IDs" }
        require(result.entries.all { runCatching { UUID.fromString(it.sessionId) }.isSuccess && (it.alarmId == null || runCatching { UUID.fromString(it.alarmId) }.isSuccess) }) { "Invalid persisted session ID" }
        require(result.journey.completedJourneys >= 0 && result.journey.completions.size <= 7 && result.journey.completions == result.journey.completions.sorted() && result.journey.completions.all { it >= result.journey.startedAt }) { "Invalid journey progress" }
        val completionDays = result.journey.completions.map { Instant.ofEpochMilli(it).atZone(ZoneId.systemDefault()).toLocalDate() }
        require(completionDays.distinct().size == completionDays.size) { "Duplicate journey day" }
        require(result.journey.lastCompletionAt == null || result.journey.lastCompletionAt >= result.journey.startedAt || result.journey.completions.isEmpty()) { "Invalid journey completion date" }
        return result
    }
}
