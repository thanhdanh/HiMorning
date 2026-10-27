package com.himorning.android.core

import android.content.Context
import android.content.ContextWrapper
import android.util.AtomicFile
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.UUID

@RunWith(AndroidJUnit4::class)
class AppRepositoryTest {
    private lateinit var directory: File
    private lateinit var context: Context
    private val storage get() = File(directory, "himorning-state.json")

    @Before fun setUp() {
        val base = InstrumentationRegistry.getInstrumentation().targetContext
        directory = File(base.cacheDir, "repository-test-${UUID.randomUUID()}").apply { mkdirs() }
        context = object : ContextWrapper(base) { override fun getFilesDir() = directory }
    }

    @After fun tearDown() { directory.deleteRecursively() }

    @Test fun reloadsBeforeWritesSoIndependentInstancesPreserveEachOthersChanges() {
        val first = AppRepository(context)
        val second = AppRepository(context)
        val alarm1 = Alarm(hour = 7, minute = 30)
        val alarm2 = Alarm(hour = 8, minute = 15)

        first.saveAlarm(alarm1)
        second.saveAlarm(alarm2)
        second.setGoal(5)

        val saved = AppRepository(context).state
        assertEquals(setOf(alarm1.id, alarm2.id), saved.alarms.map { it.id }.toSet())
        assertEquals(5, saved.weeklyGoal)
        assertNull(saved.previewStartedAt)
        AppRepository(context).updateAlarmState(alarm1.id, ScheduleState.CONFIRMED)
        assertNotNull(AppRepository(context).state.previewStartedAt)
    }

    @Test fun corruptJsonFailsClosedWithoutReplacingUserData() {
        storage.writeText("{}")
        val error = runCatching { AppRepository(context) }.exceptionOrNull()
        assertNotNull("Malformed state must be surfaced", error)
        assertEquals("{}", storage.readText())
    }

    @Test fun atomicFileRestoresPreviousStateAfterInterruptedWrite() {
        val original = Alarm(hour = 6, minute = 45)
        AppRepository(context).saveAlarm(original)
        val atomic = AtomicFile(storage)
        val interrupted = atomic.startWrite()
        interrupted.write("{\"partial\":".toByteArray())
        interrupted.close() // Leave AtomicFile's backup in place to model process death mid-write.

        val recovered = AppRepository(context)
        assertEquals(listOf(original.id), recovered.state.alarms.map { it.id })
        assertTrue(storage.readText().contains(original.id))
        assertFalse(File(storage.path + ".bak").exists())
    }
    @Test fun failedSavesRestoreExistingSettingsAndRetainOnlyUncertainNewRegistrations() {
        val repo = AppRepository(context)
        val alarm = Alarm(hour = 7, minute = 15, label = "Original", sound = AlarmSound.SAX_GLOW)
        val other = Alarm(hour = 8, minute = 30, label = "Keep me")
        repo.saveAlarm(alarm); repo.saveAlarm(other)
        repo.updateAlarmState(alarm.id, ScheduleState.CONFIRMED)
        repo.setGoal(5)
        val enabled = repo.state.alarms.first { it.id == alarm.id }
        val unrelated = repo.state.alarms.first { it.id == other.id }
        repo.updateAlarm(enabled.copy(minute = 16, label = "Unsaved", sound = AlarmSound.SYSTEM))
        repo.rollbackAlarmSave(alarm.id, enabled, registrationUncertain = false)
        assertEquals(enabled, AppRepository(context).state.alarms.first { it.id == alarm.id })
        repo.setAlarmEnabled(alarm.id, false); repo.updateAlarmState(alarm.id, ScheduleState.OFF)
        val disabled = repo.state.alarms.first { it.id == alarm.id }
        repo.updateAlarm(disabled.copy(minute = 17, label = "Also unsaved"))
        repo.rollbackAlarmSave(alarm.id, disabled, registrationUncertain = false)
        assertEquals(disabled, repo.state.alarms.first { it.id == alarm.id })
        repo.updateAlarm(disabled.copy(minute = 18))
        repo.rollbackAlarmSave(alarm.id, disabled, registrationUncertain = true)
        assertEquals(disabled.copy(state = ScheduleState.NEEDS_REVIEW), repo.state.alarms.first { it.id == alarm.id })
        val canceledNew = Alarm(hour = 9, minute = 0)
        repo.saveAlarm(canceledNew)
        repo.rollbackAlarmSave(canceledNew.id, null, registrationUncertain = false)
        assertFalse(repo.state.alarms.any { it.id == canceledNew.id })
        val uncertainNew = Alarm(hour = 10, minute = 0)
        repo.saveAlarm(uncertainNew)
        repo.rollbackAlarmSave(uncertainNew.id, null, registrationUncertain = true)
        assertEquals(ScheduleState.NEEDS_REVIEW, repo.state.alarms.first { it.id == uncertainNew.id }.state)
        assertEquals(unrelated, repo.state.alarms.first { it.id == other.id })
        assertEquals(5, repo.state.weeklyGoal)
    }

}
