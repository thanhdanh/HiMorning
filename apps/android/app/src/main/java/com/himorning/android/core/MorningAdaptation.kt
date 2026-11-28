package com.himorning.android.core

enum class MorningAdaptationAction {
    STEP_DOWN_TO_INCLINE_PUSH_UPS,
    STEP_DOWN_TO_SQUATS,
    STEP_UP_REPS,
    KEEP_STEADY,
}

data class MorningAdaptationRecommendation(
    val action: MorningAdaptationAction,
    val suggestedRepetitions: Int? = null,
    val consecutiveStruggles: Int = 0,
    val consecutiveFastWins: Int = 0,
)

/**
 * 100% offline deterministic habit adaptation engine.
 * Mirrors iOS HiMorningCore MorningAdaptationEngine thresholds 1:1.
 */
object MorningAdaptationEngine {
    const val STRUGGLE_THRESHOLD = 2
    const val FAST_WIN_THRESHOLD = 5
    const val FAST_COMPLETION_MAX_SEC = 25
    const val MAX_REPETITIONS = 50

    fun evaluate(
        entries: List<MorningEntry>,
        currentAlarm: Alarm? = null,
    ): MorningAdaptationRecommendation {
        val ordered = entries.sortedByDescending { it.date }
        val pushUpEntries = ordered.filter { it.challenge == ChallengeKind.PUSH_UPS }

        var consecutivePushUpStruggles = 0
        for (entry in pushUpEntries) {
            if (entry.outcome == WakeOutcome.SELF_CONFIRMED || entry.outcome == WakeOutcome.DISMISSED) {
                consecutivePushUpStruggles++
            } else {
                break
            }
        }

        if (consecutivePushUpStruggles >= STRUGGLE_THRESHOLD) {
            val currentVariant = currentAlarm?.pushUpVariant ?: PushUpVariant.STANDARD
            return if (currentVariant == PushUpVariant.STANDARD) {
                MorningAdaptationRecommendation(
                    action = MorningAdaptationAction.STEP_DOWN_TO_INCLINE_PUSH_UPS,
                    suggestedRepetitions = minOf(currentAlarm?.repetitions ?: 10, 10),
                    consecutiveStruggles = consecutivePushUpStruggles,
                )
            } else {
                MorningAdaptationRecommendation(
                    action = MorningAdaptationAction.STEP_DOWN_TO_SQUATS,
                    suggestedRepetitions = 10,
                    consecutiveStruggles = consecutivePushUpStruggles,
                )
            }
        }

        val movementKinds = setOf(ChallengeKind.PUSH_UPS, ChallengeKind.SQUATS, ChallengeKind.JUMPING_JACKS)
        val movementEntries = ordered.filter { it.challenge in movementKinds }

        var consecutiveFastWins = 0
        for (entry in movementEntries) {
            val succeeded = entry.outcome == WakeOutcome.LOCAL_COMPLETED || entry.outcome == WakeOutcome.AI_VERIFIED
            val duration = entry.completionDurationSec
            if (!succeeded || duration == null || duration <= 0 || duration > FAST_COMPLETION_MAX_SEC) {
                break
            }
            consecutiveFastWins++
        }

        if (consecutiveFastWins >= FAST_WIN_THRESHOLD) {
            val baseReps = currentAlarm?.repetitions ?: 10
            val nextReps = (baseReps + 2).coerceAtMost(MAX_REPETITIONS)
            if (nextReps > baseReps) {
                return MorningAdaptationRecommendation(
                    action = MorningAdaptationAction.STEP_UP_REPS,
                    suggestedRepetitions = nextReps,
                    consecutiveFastWins = consecutiveFastWins,
                )
            }
        }

        return MorningAdaptationRecommendation(
            action = MorningAdaptationAction.KEEP_STEADY,
            consecutiveStruggles = consecutivePushUpStruggles,
            consecutiveFastWins = consecutiveFastWins,
        )
    }
}
