package com.himorning.android.platform

import android.app.AlarmManager
import android.content.Context
import android.content.ContextWrapper
import android.content.SharedPreferences
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.himorning.android.core.Alarm
import org.junit.Assert.*
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID

@RunWith(AndroidJUnit4::class)
class WakeRecoveryTest {
    @Test fun independentOccurrencesAndStaleTokensCannotResolveAnotherWake() {
        val target = InstrumentationRegistry.getInstrumentation().targetContext
        assumeTrue(target.getSystemService(AlarmManager::class.java).canScheduleExactAlarms())
        val prefix = UUID.randomUUID().toString()
        val context = object : ContextWrapper(target) {
            override fun getSharedPreferences(name: String, mode: Int): SharedPreferences = super.getSharedPreferences("$prefix-$name", mode)
        }
        val first = Alarm(hour = 7, minute = 0)
        val second = Alarm(hour = 8, minute = 0)
        val at = System.currentTimeMillis()
        try {
            val a = WakeRecovery.begin(context, first, at)
            val b = WakeRecovery.begin(context, second, at)
            assertEquals(2, WakeRecovery.all(context).size)
            assertTrue(a.inWindow(at + WakeRecovery.WINDOW))
            assertFalse(a.inWindow(at + WakeRecovery.WINDOW + 1))
            assertNull(WakeRecovery.consume(context, first.id, b.sessionId, at, 1, at + 120_000))
            WakeRecovery.resolve(context, first.id, b.sessionId)
            assertNotNull(WakeRecovery.get(context, first.id, a.sessionId))
            WakeRecovery.resolve(context, first.id, a.sessionId)
            assertNull(WakeRecovery.get(context, first.id))
            assertNotNull(WakeRecovery.get(context, second.id, b.sessionId))
            assertFalse(WakeRecovery.snooze(context, b, 0))
            assertTrue(WakeRecovery.snooze(context, b, 1))
            assertFalse(WakeRecovery.snooze(context, b, 1))
        } finally {
            WakeRecovery.resolve(context, first.id); WakeRecovery.resolve(context, second.id)
            target.deleteSharedPreferences("$prefix-wake-recovery-v1")
        }
    }
}
