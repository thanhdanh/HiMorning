package com.himorning.android.ui

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import kotlin.math.roundToInt
import com.himorning.android.R
import com.himorning.android.core.AppLanguage
import com.himorning.android.core.RecognizedWordMatch
import com.himorning.android.core.RecognizedWordMatch.WordStatus

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun ReadingPassage(passage: String, transcript: String, finished: Boolean) {
    val words = remember(passage) { passage.trim().split(Regex("\\s+")) }
    val tokenCounts = remember(words) { words.map { RecognizedWordMatch.tokens(it, AppLanguage.ENGLISH).size } }
    val feedback = remember(passage, transcript, finished) {
        RecognizedWordMatch.feedback(passage, transcript, AppLanguage.ENGLISH, finished && transcript.isNotBlank())
    }
    val statusLabels = mapOf(
        WordStatus.CORRECT to stringResource(R.string.word_correct),
        WordStatus.INCORRECT to stringResource(R.string.word_incorrect),
        WordStatus.PENDING to stringResource(R.string.word_pending),
    )
    val description = if (transcript.isBlank()) passage else "$passage " +
        feedback.words.joinToString(", ") { "${it.text}: ${statusLabels[it.status]}" }

    FlowRow(
        modifier = Modifier.fillMaxWidth().padding(top = 4.dp).clearAndSetSemantics { contentDescription = description },
        horizontalArrangement = Arrangement.spacedBy(5.dp, Alignment.CenterHorizontally),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        var firstToken = 0
        words.forEachIndexed { index, word ->
            val statuses = feedback.words.subList(firstToken, firstToken + tokenCounts[index])
            firstToken += tokenCounts[index]
            val status = when {
                statuses.any { it.status == WordStatus.INCORRECT } -> WordStatus.INCORRECT
                statuses.isNotEmpty() && statuses.all { it.status == WordStatus.CORRECT } -> WordStatus.CORRECT
                else -> WordStatus.PENDING
            }
            key(index, transcript.isBlank()) { ReadingWord(word, status) }
        }
    }
    if (transcript.isNotBlank()) {
        Text(stringResource(R.string.reading_score, (feedback.score * 100).roundToInt()))
        Text(transcript, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun ReadingWord(word: String, status: WordStatus) {
    val bounced = remember { mutableStateOf(false) }
    val offset = remember { Animatable(0f) }
    val matched = status == WordStatus.CORRECT
    LaunchedEffect(matched || bounced.value) {
        if (matched && !bounced.value) {
            bounced.value = true
            offset.animateTo(-4f, tween(90))
            offset.animateTo(0f, tween(170))
        }
    }
    val color = when (status) {
        WordStatus.CORRECT -> MorningTheme.colors.correctWord
        WordStatus.INCORRECT -> MaterialTheme.colorScheme.error
        WordStatus.PENDING -> MaterialTheme.colorScheme.onSurfaceVariant
    }
    Text(
        word,
        style = MaterialTheme.typography.headlineSmall,
        color = color,
        textDecoration = if (status == WordStatus.INCORRECT) TextDecoration.Underline else TextDecoration.None,
        modifier = Modifier.graphicsLayer { translationY = offset.value.dp.toPx() },
    )
}
