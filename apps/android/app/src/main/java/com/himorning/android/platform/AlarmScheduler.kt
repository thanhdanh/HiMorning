package com.himorning.android.platform

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import com.himorning.android.core.Alarm
import com.himorning.android.core.AppRepository
import com.himorning.android.core.ScheduleState
import java.time.Instant
import java.time.ZoneId
import com.himorning.android.MainActivity

class AlarmScheduler(private val context: Context) {
    private val manager = context.getSystemService(AlarmManager::class.java)
    private val repository = AppRepository(context)

    fun canScheduleExactAlarms(): Boolean = Build.VERSION.SDK_INT < 31 || manager.canScheduleExactAlarms()

    fun exactAlarmSettingsIntent(): Intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply { data = android.net.Uri.parse("package:${context.packageName}") }

    fun schedule(alarm: Alarm) {
        require(alarm.enabled)
        check(canScheduleExactAlarms()) { "Exact alarm access is required" }
        val now = System.currentTimeMillis()
        val fireAt = if (alarm.weekdays.isEmpty()) alarm.scheduledAt?.takeIf { it > now } ?: if (alarm.scheduledAt == null) alarm.nextAfter(Instant.ofEpochMilli(now), ZoneId.systemDefault()).toEpochMilli() else error("One-time alarm expired")
        else alarm.nextAfter(Instant.ofEpochMilli(now), ZoneId.systemDefault()).toEpochMilli()
        try {
            manager.setAlarmClock(AlarmManager.AlarmClockInfo(fireAt, launchIntent(alarm.id)), pending(alarm.id, fireAt))
            if (alarm.state == ScheduleState.PENDING) WakeRecovery.get(context, alarm.id)?.takeIf { it.occurrence != fireAt }?.let { RingingService.cancel(context, alarm.id) }
            repository.updateAlarmState(alarm.id, ScheduleState.CONFIRMED, fireAt)
        } catch (error: Exception) {
            repository.updateAlarmState(alarm.id, ScheduleState.NEEDS_REVIEW)
            throw error
        }
    }

    fun cancel(id: String) {
        manager.cancel(pending(id, null))
        RingingService.cancel(context, id)
        repository.state.alarms.firstOrNull { it.id == id }?.let { repository.updateAlarmState(id, ScheduleState.OFF, null) }
    }

    fun rescheduleAll() {
        if (!canScheduleExactAlarms()) {
            repository.state.alarms.filter { it.enabled }.forEach { repository.updateAlarmState(it.id, ScheduleState.NEEDS_REVIEW) }
            return
        }
        repository.state.alarms.filter { it.enabled }.forEach { alarm ->
            if (alarm.weekdays.isEmpty() && (alarm.scheduledAt ?: Long.MIN_VALUE) <= System.currentTimeMillis()) {
                if (WakeRecovery.get(context, alarm.id) == null) {
                    repository.setAlarmEnabled(alarm.id, false)
                    repository.updateAlarmState(alarm.id, ScheduleState.OFF)
                }
                return@forEach
            }
            try { schedule(alarm) }
            catch (_: Exception) { repository.updateAlarmState(alarm.id, ScheduleState.NEEDS_REVIEW) }
        }
    }

    private fun pending(id: String, at: Long?): PendingIntent {
        val intent = Intent(context, AlarmReceiver::class.java).setData(android.net.Uri.parse("himorning://alarm/$id"))
            .putExtra(AlarmReceiver.EXTRA_ID, id).apply { if (at != null) putExtra(AlarmReceiver.EXTRA_AT, at) }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0
        return PendingIntent.getBroadcast(context, 0, intent, flags)
    }

    private fun launchIntent(id: String) = PendingIntent.getActivity(context, id.hashCode(),
        Intent(context, MainActivity::class.java).setData(android.net.Uri.parse("himorning://alarm/$id")),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
}
