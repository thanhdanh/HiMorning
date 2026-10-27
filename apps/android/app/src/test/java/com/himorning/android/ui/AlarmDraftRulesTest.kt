package com.himorning.android.ui

import com.himorning.android.core.*
import org.junit.Assert.*
import org.junit.Test

class AlarmDraftRulesTest {
    @Test fun scopedEditsKeepHiddenScheduleSoundAndChallengeChoices() {
        val original = Alarm(hour = 6, minute = 15, weekdays = setOf(2, 4), label = "Early shift", sound = AlarmSound.SAX_GLOW,
            mode = WakeMode.FOCUSED, challenge = ChallengeKind.PUSH_UPS, repetitions = 15, enabled = false)
        val edited = original.copy(hour = 9, minute = 45, weekdays = setOf(1), label = "Weekend", sound = AlarmSound.SYSTEM,
            mode = WakeMode.GENTLE, challenge = ChallengeKind.WAVE_HAND, repetitions = 3, seated = true)
        val schedule = mergeAlarmEdits(original, edited, AlarmEditorScope.SCHEDULE)
        assertEquals("Weekend", schedule.label)
        assertEquals(9, schedule.hour)
        assertEquals(45, schedule.minute)
        assertEquals(setOf(1), schedule.weekdays)
        assertEquals(AlarmSound.SAX_GLOW, schedule.sound)
        assertEquals(ChallengeKind.PUSH_UPS, schedule.challenge)
        assertEquals(15, schedule.repetitions)
        assertFalse(schedule.enabled)
        val challenge = mergeAlarmEdits(original, edited, AlarmEditorScope.CHALLENGE)
        assertEquals(ChallengeKind.WAVE_HAND, challenge.challenge)
        assertEquals(WakeMode.GENTLE, challenge.mode)
        assertTrue(challenge.seated)
        assertEquals(6, challenge.hour)
        assertEquals(setOf(2, 4), challenge.weekdays)
        assertEquals("Early shift", challenge.label)
        assertEquals(AlarmSound.SAX_GLOW, challenge.sound)
        assertFalse(challenge.enabled)
    }
}
