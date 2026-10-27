package com.himorning.android.platform

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import com.himorning.android.core.Alarm
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

internal data class PendingWake(val alarmId: String, val sessionId: String, val occurrence: Long, val snoozes: Int = 0, val snoozeAt: Long? = null) {
    fun inWindow(now: Long) = now in occurrence..(occurrence + WakeRecovery.WINDOW)
}

/** Occurrence tokens keep independent alarms and late notification actions isolated. */
internal object WakeRecovery {
    const val INTERVAL = 120_000L
    const val COUNT = 15
    const val WINDOW = 1_800_000L
    private val lock = Any()
    private fun prefs(context: Context) = context.getSharedPreferences("wake-recovery-v1", Context.MODE_PRIVATE)
    private fun read(context: Context): List<PendingWake> = JSONArray(prefs(context).getString("wakes", "[]")).let { rows ->
        (0 until rows.length()).map { i -> rows.getJSONObject(i).let {
            PendingWake(it.getString("alarm"), it.getString("session"), it.getLong("occurrence"), it.getInt("snoozes"), if (it.has("snoozeAt")) it.getLong("snoozeAt") else null)
        } }
    }
    private fun write(context: Context, wakes: List<PendingWake>) {
        val rows = JSONArray().also { rows -> wakes.forEach { wake -> rows.put(JSONObject().apply {
            put("alarm", wake.alarmId); put("session", wake.sessionId); put("occurrence", wake.occurrence); put("snoozes", wake.snoozes)
            wake.snoozeAt?.let { put("snoozeAt", it) }
        }) } }
        check(prefs(context).edit().putString("wakes", rows.toString()).commit()) { "Could not save wake recovery" }
    }
    fun limited(context: Context) = prefs(context).getBoolean("limited", false)
    fun all(context: Context): List<PendingWake> = synchronized(lock) { read(context) }
    fun get(context: Context, id: String, session: String? = null): PendingWake? = all(context).firstOrNull { it.alarmId == id && (session == null || it.sessionId == session) }
    fun oldest(context: Context): PendingWake? = all(context).filter { it.inWindow(System.currentTimeMillis()) && (it.snoozeAt ?: 0) <= System.currentTimeMillis() }.minByOrNull { it.occurrence }

    fun begin(context: Context, alarm: Alarm, occurrence: Long): PendingWake = synchronized(lock) {
        val existing = read(context).firstOrNull { it.alarmId == alarm.id && it.occurrence == occurrence }
        if (existing != null) return existing
        val wake = PendingWake(alarm.id, UUID.randomUUID().toString(), occurrence)
        val before = read(context)
        before.filter { it.alarmId == alarm.id }.forEach { cancelPending(context, it) }
        write(context, before.filter { it.alarmId != alarm.id && it.inWindow(System.currentTimeMillis()) } + wake)
        scheduleBackups(context, wake)
        wake
    }

    fun resolve(context: Context, id: String, session: String? = null) = synchronized(lock) {
        val before = read(context)
        val removed = before.filter { it.alarmId == id && (session == null || it.sessionId == session) }
        // Persist resolution before cancellation; a delivered stale broadcast then fails validation.
        write(context, before - removed.toSet())
        removed.forEach { cancelPending(context, it) }
    }

    fun snooze(context: Context, wake: PendingWake, budget: Int): Boolean = synchronized(lock) {
        val current = get(context, wake.alarmId, wake.sessionId) ?: return false
        if (current.snoozes >= budget || !current.inWindow(System.currentTimeMillis())) return false
        val at = minOf(System.currentTimeMillis() + 300_000, current.occurrence + WINDOW)
        val next = current.copy(snoozes = current.snoozes + 1, snoozeAt = at)
        val before = read(context)
        write(context, before.map { if (it.sessionId == current.sessionId) next else it })
        try { manager(context).setAlarmClock(AlarmManager.AlarmClockInfo(at, null), pending(context, next, 0, at)) }
        catch (error: Exception) { write(context, before); throw error }
        true
    }

    fun consume(context: Context, id: String, session: String, occurrence: Long, index: Int, at: Long): PendingWake? = synchronized(lock) {
        val wake = get(context, id, session) ?: return null
        val now = System.currentTimeMillis()
        if (wake.occurrence != occurrence || !wake.inWindow(now) || now < at - 1000) return null
        if (index == 0) {
            if (wake.snoozeAt != at) return null
            val next = wake.copy(snoozeAt = null)
            write(context, read(context).map { if (it.sessionId == session) next else it })
            next
        } else {
            if (index !in 1..COUNT || at != occurrence + index * INTERVAL || (wake.snoozeAt ?: 0) > now) return null
            wake
        }
    }

    fun reschedule(context: Context) = synchronized(lock) {
        val now = System.currentTimeMillis()
        val before = read(context)
        val alarms = com.himorning.android.core.AppRepository(context).state.alarms.map { it.id }.toSet()
        val valid = before.filter { it.inWindow(now) && it.alarmId in alarms }
        write(context, valid)
        (before - valid.toSet()).forEach { cancelPending(context, it) }
        prefs(context).edit().putBoolean("limited", false).commit()
        valid.forEach { wake ->
            scheduleBackups(context, wake)
            wake.snoozeAt?.takeIf { it > now }?.let { manager(context).setAlarmClock(AlarmManager.AlarmClockInfo(it, null), pending(context, wake, 0, it)) }
        }
    }

    private fun scheduleBackups(context: Context, wake: PendingWake) {
        for (index in 1..COUNT) {
            val at = wake.occurrence + index * INTERVAL
            if (at > System.currentTimeMillis()) {
                try { manager(context).setAlarmClock(AlarmManager.AlarmClockInfo(at, null), pending(context, wake, index, at)) }
                catch (error: Exception) {
                    prefs(context).edit().putBoolean("limited", true).commit()
                    android.util.Log.e("HiMorning", "Wake reminders could not all be scheduled", error)
                    return
                }
            }
        }
    }
    private fun cancelPending(context: Context, wake: PendingWake) {
        for (index in 0..COUNT) manager(context).cancel(pending(context, wake, index, wake.snoozeAt ?: 0))
    }
    private fun manager(context: Context) = context.getSystemService(AlarmManager::class.java)
    private fun pending(context: Context, wake: PendingWake, index: Int, at: Long) = PendingIntent.getBroadcast(context, 0,
        Intent(context, AlarmReceiver::class.java).setData(Uri.parse("himorning://wake/${wake.alarmId}/${wake.sessionId}/$index"))
            .putExtra(AlarmReceiver.EXTRA_ID, wake.alarmId).putExtra("session", wake.sessionId).putExtra("occurrence", wake.occurrence)
            .putExtra("index", index).putExtra(AlarmReceiver.EXTRA_AT, at).putExtra("recovery", true),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
}
