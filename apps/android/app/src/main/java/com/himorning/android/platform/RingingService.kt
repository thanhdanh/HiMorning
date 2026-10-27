package com.himorning.android.platform

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import com.himorning.android.MainActivity
import com.himorning.android.R
import com.himorning.android.core.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.util.Locale

class RingingService : Service() {
    private var player: MediaPlayer? = null
    private var current: PendingWake? = null
    override fun attachBaseContext(base: Context) {
        val language = runCatching { AppRepository(base).state.language }.getOrDefault(AppLanguage.SYSTEM)
        val locale = when (language) { AppLanguage.ENGLISH -> Locale.ENGLISH; AppLanguage.VIETNAMESE -> Locale.forLanguageTag("vi"); AppLanguage.SYSTEM -> null }
        super.attachBaseContext(if (locale == null) base else base.createConfigurationContext(android.content.res.Configuration(base.resources.configuration).apply { setLocale(locale) }))
    }
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val id = intent?.getStringExtra(EXTRA_ID)
        val session = intent?.getStringExtra(EXTRA_SESSION)
        if (id == null || session == null) { if (current == null) stopSelf(); return START_NOT_STICKY }
        if (intent.action in setOf(STOP, COMPLETE, CANCEL) && current?.sessionId == session) stopCurrent(current!!)
        if (intent.action == CANCEL) {
            runCatching { WakeRecovery.resolve(this, id, session) }; stopIfIdle(); return START_NOT_STICKY
        }
        val wake = runCatching { WakeRecovery.get(this, id, session) }.getOrNull()
        if (wake == null) { if (current == null) stopSelf(); return START_NOT_STICKY }
        when (intent.action) {
            START -> begin(wake)
            STOP -> finish(wake, WakeOutcome.DISMISSED)
            COMPLETE -> finish(wake, WakeOutcome.LOCAL_COMPLETED)
            CONFIRM -> if (System.currentTimeMillis() >= wake.occurrence + 300_000) finish(wake, WakeOutcome.SELF_CONFIRMED)
            SNOOZE -> snooze(wake)
            CANCEL -> { stopCurrent(wake); runCatching { WakeRecovery.resolve(this, id, session) }; stopIfIdle() }
        }
        if (current == null) stopSelf()
        return START_NOT_STICKY
    }

    private fun effective(alarm: Alarm, repo: AppRepository): Alarm = if (repo.remainingPreviewDays() > 0) alarm else alarm.copy(
        mode = if (alarm.mode == WakeMode.FOCUSED) WakeMode.BALANCED else alarm.mode,
        sound = AlarmSound.SYSTEM, repetitions = if (alarm.challenge == ChallengeKind.PUSH_UPS) minOf(5, alarm.repetitions) else alarm.repetitions)

    private fun begin(wake: PendingWake) {
        if (!wake.inWindow(System.currentTimeMillis())) return
        val repo = AppRepository(this)
        val saved = repo.state.alarms.firstOrNull { it.id == wake.alarmId } ?: return
        if (current?.sessionId == wake.sessionId && player?.isPlaying == true) return
        player?.release(); player = null
        current = wake
        val alarm = effective(saved, repo)
        publish(wake)
        startForeground(NOTIFICATION_ID, notification(wake, alarm))
        player = createPlayer(alarm.sound)
        audioFailure.value = player == null
    }

    private fun createPlayer(sound: AlarmSound): MediaPlayer? {
        val resource = resources.getIdentifier(sound.name.lowercase(Locale.ROOT), "raw", packageName)
        val uri = if (resource == 0) android.provider.Settings.System.DEFAULT_ALARM_ALERT_URI else Uri.parse("android.resource://$packageName/$resource")
        for (candidate in listOf(uri, android.provider.Settings.System.DEFAULT_ALARM_ALERT_URI).distinct()) {
            val media = MediaPlayer()
            try {
                media.setWakeMode(this, PowerManager.PARTIAL_WAKE_LOCK)
                media.setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
                media.setDataSource(this, candidate); media.isLooping = true; media.prepare(); media.start()
                return media
            } catch (error: Exception) { media.release(); android.util.Log.e("HiMorning", "Alarm sound unavailable", error) }
        }
        return null
    }

    private fun snooze(wake: PendingWake) {
        val repo = AppRepository(this)
        val alarm = repo.state.alarms.firstOrNull { it.id == wake.alarmId } ?: return
        runCatching {
            if (WakeRecovery.snooze(this, wake, effective(alarm, repo).mode.snoozes)) stopCurrent(wake)
        }.onFailure { android.util.Log.e("HiMorning", "Snooze could not be scheduled", it) }
        stopIfIdle()
    }

    private fun finish(wake: PendingWake, outcome: WakeOutcome) {
        // Sound stops before storage operations, including corrupted/full local storage.
        stopCurrent(wake)
        val repo = runCatching { AppRepository(this) }.getOrNull()
        if (outcome != WakeOutcome.DISMISSED) runCatching { WakeRecovery.resolve(this, wake.alarmId, wake.sessionId) }
        runCatching {
            val alarm = repo?.state?.alarms?.firstOrNull { it.id == wake.alarmId }
            if (alarm != null) {
                if (alarm.weekdays.isEmpty()) {
                    repo.setAlarmEnabled(alarm.id, false); repo.updateAlarmState(alarm.id, ScheduleState.OFF)
                }
                repo.record(wake.sessionId, alarm.id, alarm.mode, alarm.challenge, outcome)
            }
        }.onFailure { android.util.Log.e("HiMorning", "Morning progress could not be written", it) }
        stopIfIdle()
    }

    private fun stopCurrent(wake: PendingWake) {
        if (current?.sessionId == wake.sessionId) {
            player?.release(); player = null; current = null
            stopForeground(STOP_FOREGROUND_REMOVE)
        }
        if (activeSession.value == wake.sessionId) { activeId.value = null; activeSession.value = null; activeStarted.value = null; activeSnoozes.value = 0 }
    }
    private fun stopIfIdle() { if (current == null) stopSelf() }

    private fun notification(wake: PendingWake, alarm: Alarm): android.app.Notification {
        val channel = "himorning_alarm"
        getSystemService(NotificationManager::class.java).createNotificationChannel(NotificationChannel(channel, getString(R.string.app_name), NotificationManager.IMPORTANCE_HIGH).apply {
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC; setSound(null, null)
        })
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java).setData(Uri.parse("himorning://ringing/${wake.sessionId}")), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = NotificationCompat.Builder(this, channel).setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(getString(R.string.good_morning)).setContentText(alarm.label.ifBlank { getString(R.string.app_name) })
            .setCategory(NotificationCompat.CATEGORY_ALARM).setPriority(NotificationCompat.PRIORITY_MAX).setOngoing(true)
            .setContentIntent(open).setFullScreenIntent(open, true)
            .addAction(0, getString(R.string.stop), action(wake, STOP))
        if (wake.snoozes < alarm.mode.snoozes) builder.addAction(0, getString(R.string.snooze), action(wake, SNOOZE))
        return builder.build()
    }
    private fun action(wake: PendingWake, action: String) = PendingIntent.getService(this, 0,
        command(this, action, wake.alarmId, wake.sessionId).setData(Uri.parse("himorning://action/${wake.sessionId}/$action")), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    override fun onDestroy() { player?.release(); player = null; super.onDestroy() }
    companion object {
        private const val START = "start"
        private const val STOP = "stop"
        private const val COMPLETE = "complete"
        private const val CONFIRM = "confirm"
        private const val SNOOZE = "snooze"
        private const val CANCEL = "cancel"
        private const val EXTRA_ID = "alarmId"
        private const val EXTRA_SESSION = "sessionId"
        private const val NOTIFICATION_ID = 365
        private val activeId = MutableStateFlow<String?>(null)
        private val activeSession = MutableStateFlow<String?>(null)
        private val activeStarted = MutableStateFlow<Long?>(null)
        private val activeSnoozes = MutableStateFlow(0)
        private val audioFailure = MutableStateFlow(false)
        val activeAlarmId: StateFlow<String?> = activeId
        val activeSessionId: StateFlow<String?> = activeSession
        val activeStartedAt: StateFlow<Long?> = activeStarted
        val activeSnoozesUsed: StateFlow<Int> = activeSnoozes
        val audioFailed: StateFlow<Boolean> = audioFailure
        private fun publish(wake: PendingWake) { activeId.value = wake.alarmId; activeSession.value = wake.sessionId; activeStarted.value = wake.occurrence; activeSnoozes.value = wake.snoozes }
        fun restoreState(context: Context) { if (activeId.value == null) runCatching { WakeRecovery.oldest(context)?.let(::publish) } }
        private fun command(context: Context, action: String, id: String?, session: String?) = Intent(context, RingingService::class.java).setAction(action).putExtra(EXTRA_ID, id).putExtra(EXTRA_SESSION, session)
        fun start(context: Context, id: String, session: String) { context.startForegroundService(command(context, START, id, session)) }
        fun stop(context: Context, id: String? = activeId.value, session: String? = activeSession.value) { context.startService(command(context, STOP, id, session)) }
        fun snooze(context: Context, id: String? = activeId.value, session: String? = activeSession.value) { context.startService(command(context, SNOOZE, id, session)) }
        fun complete(context: Context, id: String? = activeId.value, session: String? = activeSession.value) { context.startService(command(context, COMPLETE, id, session)) }
        fun selfConfirm(context: Context, id: String? = activeId.value, session: String? = activeSession.value) { context.startService(command(context, CONFIRM, id, session)) }
        fun cancel(context: Context, id: String) {
            val session = activeSession.value.takeIf { activeId.value == id }
            if (session != null) context.startService(command(context, CANCEL, id, session))
            WakeRecovery.resolve(context, id)
        }
    }
}
