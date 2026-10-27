package com.himorning.android.platform

/** Debounces measured poses and resets an unfinished sequence after tracking loss. */
internal class PoseCycleCounter(private val sequences: List<List<Int>>) {
    private var candidate: Int? = null
    private var candidateSince = 0L
    private var lastAccepted: Int? = null
    private var lastTimestamp: Long? = null
    private var lostSince: Long? = null
    private val history = mutableListOf<Int>()
    var completed: Int = 0
        private set

    fun observe(state: Int?, timestamp: Long, holdMillis: Long = 220): Int {
        val previous = lastTimestamp
        if (timestamp < 0 || (previous != null && timestamp <= previous)) { resetSequence(); lastTimestamp = timestamp.takeIf { it >= 0 }; return completed }
        if (previous != null && timestamp - previous > 2_000) resetSequence()
        lastTimestamp = timestamp
        if (state == null) {
            val lost = lostSince ?: timestamp
            lostSince = lost
            if (timestamp - lost > 600) resetSequence(keepLoss = true)
            candidate = null
            return completed
        }
        if (lostSince?.let { timestamp - it > 600 } == true) resetSequence()
        lostSince = null
        if (state != candidate) { candidate = state; candidateSince = timestamp; return completed }
        if (state == lastAccepted || timestamp - candidateSince < holdMillis) return completed
        lastAccepted = state
        history += state
        if (sequences.any { sequence -> history.size >= sequence.size && history.takeLast(sequence.size) == sequence }) {
            completed++
            history.clear()
            history += state
        } else if (history.size > (sequences.maxOfOrNull { it.size } ?: 1)) {
            history.removeAt(0)
        }
        return completed
    }

    private fun resetSequence(keepLoss: Boolean = false) {
        candidate = null; lastAccepted = null; history.clear()
        if (!keepLoss) lostSince = null
    }
}
