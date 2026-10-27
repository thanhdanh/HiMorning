package com.himorning.android.platform

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.himorning.android.core.AppRepository
import com.himorning.android.core.ScheduleState

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        runCatching {
            val id = intent.getStringExtra(EXTRA_ID) ?: return
            val at = intent.getLongExtra(EXTRA_AT, -1)
            val alarm = AppRepository(context).state.alarms.firstOrNull { it.id == id } ?: return
            val wake = if (intent.getBooleanExtra("recovery", false)) {
                WakeRecovery.consume(context, id, intent.getStringExtra("session") ?: return,
                    intent.getLongExtra("occurrence", -1), intent.getIntExtra("index", -1), at) ?: return
            } else {
                val now = System.currentTimeMillis()
                if (!alarm.enabled || alarm.state != ScheduleState.CONFIRMED || alarm.scheduledAt != at || now !in at..(at + WakeRecovery.WINDOW)) return
                WakeRecovery.begin(context, alarm, at)
            }
            RingingService.start(context, wake.alarmId, wake.sessionId)
            if (!intent.getBooleanExtra("recovery", false) && alarm.weekdays.isNotEmpty()) AlarmScheduler(context).schedule(alarm)
        }.onFailure { android.util.Log.e("HiMorning", "Alarm delivery needs review", it) }
    }
    companion object { const val EXTRA_ID = "alarmId"; const val EXTRA_AT = "scheduledAt" }
}

class RescheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action !in setOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED,
                Intent.ACTION_MY_PACKAGE_REPLACED, "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED")) return
        runCatching {
            val scheduler = AlarmScheduler(context)
            scheduler.rescheduleAll()
            if (scheduler.canScheduleExactAlarms()) WakeRecovery.reschedule(context)
        }.onFailure { android.util.Log.e("HiMorning", "Alarm recovery needs review", it) }
    }
}
