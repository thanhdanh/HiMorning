package com.himorning.android.ui

import android.media.MediaPlayer
import android.provider.Settings
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.MusicNote
import androidx.compose.material.icons.outlined.PlayArrow
import androidx.compose.material.icons.outlined.Stop
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.himorning.android.R
import com.himorning.android.core.AlarmSound
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AlarmSoundPicker(
    selected: AlarmSound,
    fullAccess: Boolean,
    onDismiss: () -> Unit,
    onSelect: (AlarmSound) -> Unit,
) {
    val context = LocalContext.current
    val colors = MorningTheme.colors
    var player by remember { mutableStateOf<MediaPlayer?>(null) }
    var playing by remember { mutableStateOf<AlarmSound?>(null) }
    var previewError by remember { mutableStateOf(false) }
    fun stop() {
        val previous = player
        player = null
        playing = null
        previous?.let { media ->
            media.setOnCompletionListener(null)
            runCatching { media.stop() }
            runCatching { media.release() }
        }
    }
    fun preview(sound: AlarmSound) {
        stop()
        previewError = false
        runCatching {
            val id = context.resources.getIdentifier(sound.name.lowercase(Locale.ROOT), "raw", context.packageName)
            player = if (id != 0) MediaPlayer.create(context, id) else MediaPlayer.create(context, Settings.System.DEFAULT_ALARM_ALERT_URI)
            checkNotNull(player) { "No preview player is available" }
            player?.setOnCompletionListener { stop() }
            player?.start()
        }.onSuccess { playing = sound }.onFailure { stop(); previewError = true }
    }
    val lifecycle = LocalLifecycleOwner.current
    DisposableEffect(lifecycle) {
        val observer = LifecycleEventObserver { _, event -> if (event == Lifecycle.Event.ON_STOP) stop() }
        lifecycle.lifecycle.addObserver(observer)
        onDispose { lifecycle.lifecycle.removeObserver(observer); stop() }
    }
    val sounds = AlarmSound.entries
    val groups = sounds.groupBy { sound ->
        when {
            sound in listOf(AlarmSound.SYSTEM, AlarmSound.SUNRISE, AlarmSound.SOFT_CHIME) -> R.string.composer_sound_classic
            sound.name.startsWith("PIZZICATO") -> R.string.composer_sound_piano
            sound.name.startsWith("STEEL") -> R.string.composer_sound_bells
            else -> R.string.composer_sound_sax
        }
    }
    ModalBottomSheet(onDismissRequest = { stop(); onDismiss() }, containerColor = colors.canvas, contentColor = colors.ink, dragHandle = { BottomSheetDefaults.DragHandle(color = colors.muted) }) {
        MorningSystemBars()
        Column(Modifier.fillMaxWidth().navigationBarsPadding().padding(horizontal = 20.dp)) {
            Row(Modifier.fillMaxWidth().padding(bottom = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(stringResource(R.string.sound), style = MaterialTheme.typography.titleLarge)
                    Text(stringResource(R.string.composer_set_mood), color = colors.muted)
                    if (previewError) Text(stringResource(R.string.composer_sound_preview_error), color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                }
                TextButton(onClick = { stop(); onDismiss() }) { Text(stringResource(R.string.done)) }
            }
            LazyColumn(contentPadding = PaddingValues(bottom = 18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                groups.forEach { (group, choices) ->
                    item { Text(stringResource(group), Modifier.padding(top = 8.dp, bottom = 2.dp), color = colors.muted, style = MaterialTheme.typography.labelLarge) }
                    items(choices) { sound ->
                        val locked = !fullAccess && sound != AlarmSound.SYSTEM
                        val active = selected == sound
                        Row(Modifier.fillMaxWidth().morningSurface(base = colors.surface.copy(alpha = .82f), radius = 18.dp, tint = colors.accent.copy(alpha = .12f), elevated = true), verticalAlignment = Alignment.CenterVertically) {
                            val selectInteractions = remember(sound) { MutableInteractionSource() }
                            Row(Modifier.weight(1f).morningPress(selectInteractions, enabled = !locked)
                                .clickable(interactionSource = selectInteractions, indication = null, enabled = !locked) { stop(); onSelect(sound) }
                                .padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                                Box(Modifier.size(42.dp).clip(RoundedCornerShape(14.dp)), contentAlignment = Alignment.Center) { Icon(Icons.Outlined.MusicNote, null, tint = colors.accent) }
                                Column(Modifier.weight(1f).padding(start = 10.dp)) {
                                    Text(stringResource(soundText(sound)), style = MaterialTheme.typography.bodyLarge)
                                    if (locked) Text(stringResource(R.string.preview_locked), color = colors.muted, style = MaterialTheme.typography.bodySmall)
                                }
                                if (active) Icon(Icons.Outlined.Check, null, tint = colors.accent, modifier = Modifier.padding(start = 5.dp))
                            }
                            val previewInteractions = remember(sound) { MutableInteractionSource() }
                            IconButton(onClick = { if (playing == sound) stop() else if (!locked) preview(sound) }, enabled = !locked,
                                interactionSource = previewInteractions, modifier = Modifier.morningPress(previewInteractions, enabled = !locked)) {
                                Icon(if (playing == sound) Icons.Outlined.Stop else Icons.Outlined.PlayArrow, stringResource(R.string.preview_sound), tint = colors.accent)
                            }
                        }
                    }
                }
            }
        }
    }
}
