package com.himorning.android.ui

import com.himorning.android.core.ChallengeKind
import com.himorning.android.core.MorningEntry
import com.himorning.android.core.WakeOutcome
import java.time.Instant
import java.time.ZoneId

/** A repeated pattern needs distinct successful mornings, not repeated attempts. */
internal fun favoriteChallenge(entries: List<MorningEntry>, now: Long = System.currentTimeMillis(), zone: ZoneId = ZoneId.systemDefault()): ChallengeKind? {
    val start = Instant.ofEpochMilli(now).atZone(zone).toLocalDate().minusDays(29).atStartOfDay(zone).toInstant().toEpochMilli()
    val completed = entries.filter { it.date in start..now && it.outcome in setOf(WakeOutcome.LOCAL_COMPLETED, WakeOutcome.AI_VERIFIED) }
    fun day(entry: MorningEntry) = Instant.ofEpochMilli(entry.date).atZone(zone).toLocalDate()
    if (completed.map(::day).distinct().size < 3) return null
    return completed.filter { it.challenge != null && it.challenge != ChallengeKind.NONE }.groupBy { it.challenge!! }
        .mapValues { (_, attempts) -> attempts.map(::day).distinct().size }
        .filterValues { it >= 2 }.entries
        .sortedWith(compareByDescending<Map.Entry<ChallengeKind, Int>> { it.value }.thenBy { it.key.name })
        .firstOrNull()?.key
}
