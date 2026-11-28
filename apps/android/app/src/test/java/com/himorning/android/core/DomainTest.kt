package com.himorning.android.core

import org.junit.Assert.*
import org.junit.Test
import org.json.JSONObject
import java.time.Instant
import java.time.ZoneId
import java.util.UUID

class DomainTest {
    private fun alarm(hour: Int = 7, minute: Int = 0, weekdays: Set<Int> = emptySet()) = Alarm(
        id = "00000000-0000-0000-0000-000000000001", hour = hour, minute = minute, weekdays = weekdays)

    @Test fun rejectsInvalidAlarmFieldsAndFindsNextLocalOccurrence() {
        assertThrows(IllegalArgumentException::class.java) { alarm(24) }
        assertThrows(IllegalArgumentException::class.java) { Alarm(hour = 7, minute = 0, weekdays = setOf(8)) }
        val zone = ZoneId.of("Asia/Ho_Chi_Minh")
        assertEquals(Instant.parse("2026-10-28T00:00:00Z"), alarm(7).nextAfter(Instant.parse("2026-10-27T23:00:00Z"), zone))
        assertEquals(Instant.parse("2026-11-02T00:00:00Z"), alarm(7, weekdays = setOf(2)).nextAfter(Instant.parse("2026-10-27T01:00:00Z"), zone))
        val ny = ZoneId.of("America/New_York")
        assertEquals(Instant.parse("2026-03-08T07:00:00Z"), alarm(2, 30).nextAfter(Instant.parse("2026-03-08T06:00:00Z"), ny))
        assertEquals(Instant.parse("2026-11-01T05:30:00Z"), alarm(1, 30).nextAfter(Instant.parse("2026-11-01T05:00:00Z"), ny))
        assertEquals(Instant.parse("2026-10-28T00:00:00Z"), alarm(7).nextAfter(Instant.parse("2026-10-27T00:01:00Z"), zone))
    }

    @Test fun wakeSessionHonorsSnoozeBudgetAndIgnoresStaleVerification() {
        val session = WakeSession(WakeMode.BALANCED)
        val token = session.beginVerification()
        assertTrue(session.snooze())
        assertFalse(session.applyVerified(token))
        assertTrue(session.snooze().not())
        assertTrue(session.completeLocally())
        assertFalse(session.snooze())
    }

    @Test fun speechUsesEditDistanceAndPreservesVietnameseDiacritics() {
        assertEquals(1.0, RecognizedWordMatch.score("Hello, morning!", "hello morning", AppLanguage.ENGLISH), 0.0)
        assertTrue(RecognizedWordMatch.score("Chào buổi sáng", "Chào buổi sáng", AppLanguage.VIETNAMESE) >= RecognizedWordMatch.PASSING_SCORE)
        assertTrue(RecognizedWordMatch.score("ban", "bạn", AppLanguage.VIETNAMESE) < 1.0)
        assertTrue(RecognizedWordMatch.score("we start the day with a calm plan", "we start the day with a plan", AppLanguage.ENGLISH) >= RecognizedWordMatch.PASSING_SCORE)
        assertTrue(RecognizedWordMatch.score("we start the day with a calm plan", "we plan", AppLanguage.ENGLISH) < RecognizedWordMatch.PASSING_SCORE)
    }

    @Test fun wakeModeRulesMatchTheSharedContractFixture() {
        val modes = JSONObject(javaClass.getResourceAsStream("/wake-modes.json")!!.bufferedReader().use { it.readText() })
        mapOf("gentle" to WakeMode.GENTLE, "balanced" to WakeMode.BALANCED, "focused" to WakeMode.FOCUSED).forEach { (name, mode) ->
            assertEquals(modes.getJSONObject(name).getInt("reps"), mode.repetitions)
            assertEquals(modes.getJSONObject(name).getInt("snoozes"), mode.snoozes)
        }
    }

    @Test fun bundledContentIsBilingualCuratedAndValid() {
        val json = javaClass.getResourceAsStream("/challenge-content.json")!!.bufferedReader().use { it.readText() }
        val rows = JSONObject(json).getJSONArray("items")
        val prompts = decodePromptPack(json)
        assertEquals(204, prompts.size)
        assertEquals(36, prompts.count { it.kind == "readAloud" && it.language == "en" })
        assertEquals(36, prompts.count { it.kind == "readAloud" && it.language == "vi" })
        assertTrue(prompts.filter { it.kind == "readAloud" && it.language == "en" }.all {
            RecognizedWordMatch.tokens(it.text, AppLanguage.ENGLISH).size in 28..36
        })
        val pack = parsePromptPack(json)
        assertTrue(pack.copy(items = prompts.filterNot { it.kind == "readAloud" && it.language == "vi" }).complete)
        assertFalse(pack.copy(items = prompts.filterNot { it.kind == "readAloud" && it.language == "en" }).complete)
        assertEquals(34, prompts.count { it.kind == "readAndChoose" && it.language == "en" })
        assertEquals(34, prompts.count { it.kind == "readAndChoose" && it.language == "vi" })
        assertEquals(32, prompts.count { it.kind == "riddle" && it.language == "en" })
        assertEquals(32, prompts.count { it.kind == "riddle" && it.language == "vi" })
        for (prompt in prompts.filter { it.correctIndex != null }) assertTrue(prompt.correctIndex!! in prompt.choices.indices)
        val first = rows.getJSONObject(0)
        first.put("license", "unreviewed")
        assertEquals(203, decodePromptPack(JSONObject(json).put("items", rows).toString()).size)
    }

    @Test fun dismissedWakeCanBePromotedOnceAndSuccessfulOutcomeCannotRegress() {
        val dismissed = MorningEntry("wake", "alarm", WakeMode.BALANCED, ChallengeKind.READ_AND_CHOOSE, 100L, WakeOutcome.DISMISSED)
        val success = dismissed.copy(outcome = WakeOutcome.LOCAL_COMPLETED, date = 200L)
        assertEquals(listOf(success), reconcileWake(listOf(dismissed), success))
        assertNull(reconcileWake(listOf(dismissed), dismissed))
        assertNull(reconcileWake(listOf(success), dismissed))
        assertNull(reconcileWake(listOf(success), success.copy(outcome = WakeOutcome.SELF_CONFIRMED)))
    }

    @Test fun journeyRecordsOneSuccessfulLocalDayAndExcludesSelfConfirmedAndPractice() {
        val zone = ZoneId.of("Asia/Ho_Chi_Minh")
        val day = Instant.parse("2026-10-27T00:00:00Z").toEpochMilli()
        var journey = Journey(startedAt = day - 86_400_000)
        val practice = MorningEntry(UUID.randomUUID().toString(), null, null, null, day, WakeOutcome.LOCAL_COMPLETED)
        assertEquals(journey, journey.record(practice, true, day + 10, zone))
        val selfConfirmed = practice.copy(sessionId = UUID.randomUUID().toString(), outcome = WakeOutcome.SELF_CONFIRMED)
        assertEquals(journey, journey.record(selfConfirmed, false, day + 10, zone))
        assertEquals(journey, journey.record(practice.copy(challenge = ChallengeKind.NONE), false, day + 10, zone))
        val completion = practice.copy(challenge = ChallengeKind.READ_AND_CHOOSE)
        journey = journey.record(completion, false, day + 10, zone)
        assertEquals(1, journey.completions.size)
        assertEquals(journey, journey.record(completion.copy(sessionId = UUID.randomUUID().toString(), date = day + 3_600_000), false, day + 3_600_000, zone))
    }
    @Test fun modeCatalogKeepsOnlyItsChoicesAndAnExistingLegacySelection() {
        assertEquals(listOf(ChallengeKind.NONE, ChallengeKind.WAVE_HAND, ChallengeKind.NECK_ROTATION, ChallengeKind.MORNING_LIGHT), WakeMode.GENTLE.availableChallenges())
        assertEquals(listOf(ChallengeKind.READ_ALOUD, ChallengeKind.READ_AND_CHOOSE, ChallengeKind.RIDDLE), WakeMode.BALANCED.availableChallenges())
        assertEquals(listOf(ChallengeKind.PUSH_UPS, ChallengeKind.SQUATS, ChallengeKind.JUMPING_JACKS, ChallengeKind.STRETCHING), WakeMode.FOCUSED.availableChallenges())
        assertEquals(5, WakeMode.GENTLE.availableChallenges(ChallengeKind.GUIDED_RHYTHM).size)
        assertEquals(4, WakeMode.GENTLE.availableChallenges(ChallengeKind.NONE).size)
    }

    @Test fun adaptationEngineStepsDownOnRepeatedPushUpFrictionAndStepsUpOnFastWins() {
        val standardAlarm = Alarm(hour = 7, minute = 0, mode = WakeMode.FOCUSED, challenge = ChallengeKind.PUSH_UPS, repetitions = 10, pushUpVariant = PushUpVariant.STANDARD)
        val frictionEntries = listOf(
            MorningEntry(UUID.randomUUID().toString(), standardAlarm.id, WakeMode.FOCUSED, ChallengeKind.PUSH_UPS, 2_000L, WakeOutcome.SELF_CONFIRMED),
            MorningEntry(UUID.randomUUID().toString(), standardAlarm.id, WakeMode.FOCUSED, ChallengeKind.PUSH_UPS, 1_000L, WakeOutcome.DISMISSED),
        )
        val stepDownIncline = MorningAdaptationEngine.evaluate(frictionEntries, standardAlarm)
        assertEquals(MorningAdaptationAction.STEP_DOWN_TO_INCLINE_PUSH_UPS, stepDownIncline.action)
        assertEquals(2, stepDownIncline.consecutiveStruggles)

        val inclineAlarm = standardAlarm.copy(pushUpVariant = PushUpVariant.INCLINE_OR_KNEE)
        val stepDownSquats = MorningAdaptationEngine.evaluate(frictionEntries, inclineAlarm)
        assertEquals(MorningAdaptationAction.STEP_DOWN_TO_SQUATS, stepDownSquats.action)

        val fastWins = (1..5).map { day ->
            MorningEntry(UUID.randomUUID().toString(), standardAlarm.id, WakeMode.FOCUSED, ChallengeKind.PUSH_UPS, day * 86_400_000L, WakeOutcome.LOCAL_COMPLETED, completionDurationSec = 18, avgRomScore = 0.92)
        }
        val stepUp = MorningAdaptationEngine.evaluate(fastWins, standardAlarm)
        assertEquals(MorningAdaptationAction.STEP_UP_REPS, stepUp.action)
        assertEquals(12, stepUp.suggestedRepetitions)
        assertEquals(5, stepUp.consecutiveFastWins)
    }

    @Test fun readingFeedbackDistinguishesMisreadWordsFromAnUnreadSuffix() {
        val partial = RecognizedWordMatch.feedback("Small steps create steady progress", "small steps", AppLanguage.ENGLISH, false)
        assertEquals(listOf(RecognizedWordMatch.WordStatus.CORRECT, RecognizedWordMatch.WordStatus.CORRECT, RecognizedWordMatch.WordStatus.PENDING, RecognizedWordMatch.WordStatus.PENDING, RecognizedWordMatch.WordStatus.PENDING), partial.words.map { it.status })
        val repeated = RecognizedWordMatch.feedback("The rain crossed the valley.", "the", AppLanguage.ENGLISH, false)
        assertEquals(0, repeated.words.indexOfLast { it.status == RecognizedWordMatch.WordStatus.CORRECT })
        val finished = RecognizedWordMatch.feedback("Small steps create steady progress", "small steps make steady progress", AppLanguage.ENGLISH, true)
        assertEquals(RecognizedWordMatch.WordStatus.INCORRECT, finished.words[2].status)
        assertEquals(.8, finished.score, .00001)
        assertEquals(RecognizedWordMatch.WordStatus.INCORRECT, RecognizedWordMatch.feedback("hello morning", "hello", AppLanguage.ENGLISH, true).words.last().status)
    }

}
