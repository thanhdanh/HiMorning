package com.himorning.android.ui

import com.himorning.android.core.*
import org.junit.Assert.*
import org.junit.Test
import java.time.Instant
import java.time.ZoneId
import java.util.UUID

class ReflectionPresentationTest {
    @Test fun aPatternNeedsThreeCompletedDaysAndTwoDistinctDaysForTheSameChallenge() {
        val now = Instant.parse("2026-10-27T04:00:00Z").toEpochMilli()
        val zone = ZoneId.of("Asia/Ho_Chi_Minh")
        fun entry(daysAgo: Int, kind: ChallengeKind) = MorningEntry(UUID.randomUUID().toString(), null, null, kind, now - daysAgo * 86_400_000L, WakeOutcome.LOCAL_COMPLETED)
        val today = entry(0, ChallengeKind.READ_AND_CHOOSE)
        assertNull(favoriteChallenge(listOf(today), now, zone))
        val varied = listOf(today, entry(0, ChallengeKind.READ_AND_CHOOSE), entry(0, ChallengeKind.READ_AND_CHOOSE),
            entry(1, ChallengeKind.RIDDLE), entry(2, ChallengeKind.READ_ALOUD))
        assertNull(favoriteChallenge(varied, now, zone))
        assertNull(favoriteChallenge(varied + entry(31, ChallengeKind.READ_AND_CHOOSE), now, zone))
        assertNull(favoriteChallenge(varied + entry(0, ChallengeKind.RIDDLE).copy(date = now + 30_000), now, zone))
        assertNull(favoriteChallenge(varied + entry(1, ChallengeKind.READ_AND_CHOOSE).copy(outcome = WakeOutcome.DISMISSED), now, zone))
        assertEquals(ChallengeKind.READ_AND_CHOOSE, favoriteChallenge(varied + entry(1, ChallengeKind.READ_AND_CHOOSE), now, zone))
    }
}
