package com.himorning.android.ui

import android.animation.ValueAnimator
import android.graphics.SurfaceTexture
import android.media.MediaPlayer
import android.media.PlaybackParams
import android.view.Surface
import android.view.TextureView
import androidx.annotation.DrawableRes
import androidx.annotation.RawRes
import androidx.annotation.StringRes
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.himorning.android.R
import com.himorning.android.core.ChallengeKind
import kotlinx.coroutines.delay

private val StudioBg = Color(0xFF11161F)
private val HudDark = Color(0xCC0B0D12)
private val BiomechEmerald = Color(0xFF34D399)
private val BiomechEmeraldText = Color(0xFF6EE7B7)
private val TempoGold = Color(0xFFE8C97A)

internal data class StudioMotionSpec(
    @RawRes val videoRes: Int,
    @DrawableRes val posterRes: Int,
    @StringRes val phase1Cue: Int,
    @StringRes val phase2Cue: Int,
)

internal fun studioMotionSpec(kind: ChallengeKind, seated: Boolean): StudioMotionSpec? = when (kind) {
    ChallengeKind.PUSH_UPS -> StudioMotionSpec(
        R.raw.motion_push_ups, R.drawable.motion_push_ups_poster,
        R.string.motion_cue_high_plank, R.string.motion_cue_lower_90,
    )
    ChallengeKind.SQUATS -> StudioMotionSpec(
        R.raw.motion_rhythm_standing, R.drawable.motion_rhythm_standing_poster,
        R.string.motion_cue_stand_tall, R.string.motion_cue_bend_knees,
    )
    ChallengeKind.WAVE_HAND -> StudioMotionSpec(
        R.raw.motion_wave_hand, R.drawable.motion_wave_hand_poster,
        R.string.motion_cue_wave_left, R.string.motion_cue_wave_right,
    )
    ChallengeKind.NECK_ROTATION -> StudioMotionSpec(
        R.raw.motion_neck_rotation, R.drawable.motion_neck_rotation_poster,
        R.string.motion_cue_turn_left, R.string.motion_cue_turn_right,
    )
    ChallengeKind.JUMPING_JACKS -> StudioMotionSpec(
        R.raw.motion_jumping_jacks, R.drawable.motion_jumping_jacks_poster,
        R.string.motion_cue_feet_together, R.string.motion_cue_jump_open,
    )
    ChallengeKind.STRETCHING -> StudioMotionSpec(
        R.raw.motion_stretching, R.drawable.motion_stretching_poster,
        R.string.motion_cue_arms_down, R.string.motion_cue_reach_high,
    )
    ChallengeKind.GUIDED_RHYTHM -> if (seated) {
        StudioMotionSpec(
            R.raw.motion_rhythm_seated, R.drawable.motion_rhythm_seated_poster,
            R.string.motion_cue_arms_down, R.string.motion_cue_lift_arms,
        )
    } else {
        StudioMotionSpec(
            R.raw.motion_rhythm_standing, R.drawable.motion_rhythm_standing_poster,
            R.string.motion_cue_stand_tall, R.string.motion_cue_bend_knees,
        )
    }
    else -> null
}

/**
 * Unobstructed 16:9 Studio Motion Stage modeled after go-tall:
 * - Hardware-decoded looping MP4 + studio biomechanical poster backdrop
 * - Slim non-occluding top HUD with step/vector cue, 1x/0.7x speed toggle, and pause/play
 */
@Composable
internal fun MovementMotionStage(
    kind: ChallengeKind,
    seated: Boolean,
    compact: Boolean = false,
    modifier: Modifier = Modifier,
) {
    val spec = remember(kind, seated) { studioMotionSpec(kind, seated) } ?: return
    val animatorsEnabled = remember { ValueAnimator.areAnimatorsEnabled() }
    var paused by remember(kind, seated) { mutableStateOf(false) }
    var slowTempo by remember(kind, seated) { mutableStateOf(false) }
    var activePhase by remember(kind, seated) { mutableIntStateOf(1) }
    val playing = animatorsEnabled && !paused

    if (compact) {
        Row(
            modifier = modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(MorningTheme.colors.surface)
                .border(1.dp, MorningTheme.colors.line, RoundedCornerShape(18.dp))
                .padding(10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Box(
                Modifier
                    .width(112.dp)
                    .height(63.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(StudioBg)
                    .border(1.dp, Color.White.copy(alpha = 0.14f), RoundedCornerShape(12.dp)),
            ) {
                StudioMotionSurface(spec, playing = playing, slowTempo = slowTempo, onPhase = { activePhase = it })
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    stringResource(if (activePhase == 2 || !playing) spec.phase2Cue else spec.phase1Cue),
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = MorningTheme.colors.ink,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    stringResource(R.string.motion_follow_guide),
                    style = MaterialTheme.typography.bodySmall,
                    color = MorningTheme.colors.muted,
                    maxLines = 1,
                )
            }
            if (animatorsEnabled) {
                val label = stringResource(if (paused) R.string.motion_play else R.string.motion_pause)
                IconButton(onClick = { paused = !paused }) {
                    Icon(if (paused) Icons.Filled.PlayArrow else Icons.Filled.Pause, contentDescription = label, tint = MorningTheme.colors.ink)
                }
            }
        }
        return
    }

    val stepText = if (!playing || activePhase == 2) "2/2" else "1/2"
    val cueText = stringResource(if (!playing || activePhase == 2) spec.phase2Cue else spec.phase1Cue)
    val colors = MorningTheme.colors

    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(22.dp))
            .background(colors.surface)
            .border(1.dp, colors.line, RoundedCornerShape(22.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .aspectRatio(16f / 9f)
            .clip(RoundedCornerShape(18.dp))
            .background(StudioBg)
            .border(1.dp, Color.White.copy(alpha = 0.14f), RoundedCornerShape(18.dp)),
    ) {
        StudioMotionSurface(spec, playing = playing, slowTempo = slowTempo, onPhase = { activePhase = it })

        // Slim non-occluding top HUD
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.TopCenter)
                .padding(horizontal = 8.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Row(
                modifier = Modifier
                    .clip(RoundedCornerShape(999.dp))
                    .background(HudDark)
                    .border(1.dp, BiomechEmerald.copy(alpha = 0.42f), RoundedCornerShape(999.dp))
                    .padding(horizontal = 10.dp, vertical = 5.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(stepText, color = Color(0xFFF4F4F0), fontSize = 11.sp, fontWeight = FontWeight.Bold)
                Box(Modifier.size(4.dp).clip(CircleShape).background(BiomechEmerald))
                Text(cueText, color = BiomechEmeraldText, fontSize = 11.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }

            Spacer(Modifier.weight(1f))

            if (animatorsEnabled) {
                val speedLabel = stringResource(if (slowTempo) R.string.motion_speed_slow else R.string.motion_speed_normal)
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(999.dp))
                        .background(if (slowTempo) TempoGold.copy(alpha = 0.20f) else HudDark)
                        .border(1.dp, if (slowTempo) TempoGold else Color.White.copy(alpha = 0.20f), RoundedCornerShape(999.dp))
                        .clickable(role = Role.Button) { slowTempo = !slowTempo }
                        .padding(horizontal = 10.dp, vertical = 6.dp),
                ) {
                    Text(
                        speedLabel,
                        color = if (slowTempo) TempoGold else Color(0xFFE4E4E7),
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                    )
                }

                val pauseDesc = stringResource(if (paused) R.string.motion_play else R.string.motion_pause)
                Box(
                    modifier = Modifier
                        .size(30.dp)
                        .clip(CircleShape)
                        .background(HudDark)
                        .border(1.dp, Color.White.copy(alpha = 0.20f), CircleShape)
                        .clickable(role = Role.Button) { paused = !paused }
                        .semantics { contentDescription = pauseDesc },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        if (paused) Icons.Filled.PlayArrow else Icons.Filled.Pause,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(16.dp),
                    )
                }
            }
        }
    }
    Text(
        stringResource(R.string.motion_follow_guide),
        style = MaterialTheme.typography.labelMedium,
        fontWeight = FontWeight.SemiBold,
        color = colors.accent,
        modifier = Modifier.padding(horizontal = 4.dp),
    )
    }
}

@Composable
private fun StudioMotionSurface(
    spec: StudioMotionSpec,
    playing: Boolean,
    slowTempo: Boolean,
    onPhase: (Int) -> Unit,
) {
    val context = LocalContext.current
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    var lifecycleResumed by remember { mutableStateOf(true) }
    var player by remember(spec.videoRes) { mutableStateOf<MediaPlayer?>(null) }
    var surfaceRef by remember(spec.videoRes) { mutableStateOf<Surface?>(null) }
    var videoReady by remember(spec.videoRes) { mutableStateOf(false) }

    DisposableEffect(lifecycle) {
        val obs = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) lifecycleResumed = true
            else if (event == Lifecycle.Event.ON_PAUSE) lifecycleResumed = false
        }
        lifecycle.addObserver(obs)
        onDispose { lifecycle.removeObserver(obs) }
    }

    val shouldPlay = playing && lifecycleResumed

    LaunchedEffect(player, shouldPlay, slowTempo, videoReady) {
        val mp = player ?: return@LaunchedEffect
        if (!videoReady) return@LaunchedEffect
        runCatching {
            val rate = if (slowTempo) 0.7f else 1.0f
            if (shouldPlay) {
                mp.playbackParams = PlaybackParams().setSpeed(rate)
                if (!mp.isPlaying) mp.start()
            } else if (mp.isPlaying) {
                mp.pause()
            }
        }
    }

    LaunchedEffect(player, shouldPlay, videoReady) {
        if (!shouldPlay || !videoReady) return@LaunchedEffect
        while (true) {
            delay(180)
            val pos = runCatching { player?.currentPosition ?: 0 }.getOrDefault(0)
            onPhase(if (pos >= 2300) 2 else 1)
        }
    }

    DisposableEffect(spec.videoRes) {
        onDispose {
            runCatching { player?.stop() }
            runCatching { player?.release() }
            player = null
            surfaceRef?.release()
            surfaceRef = null
            videoReady = false
        }
    }

    Box(Modifier.fillMaxSize()) {
        Image(
            painter = painterResource(spec.posterRes),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier.fillMaxSize(),
        )
        if (playing) {
            AndroidView(
                factory = { ctx ->
                    TextureView(ctx).apply {
                        isOpaque = false
                        surfaceTextureListener = object : TextureView.SurfaceTextureListener {
                            override fun onSurfaceTextureAvailable(st: SurfaceTexture, width: Int, height: Int) {
                                val s = Surface(st)
                                surfaceRef = s
                                runCatching {
                                    val afd = context.resources.openRawResourceFd(spec.videoRes)
                                    val mp = MediaPlayer().apply {
                                        setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                                        afd.close()
                                        setSurface(s)
                                        isLooping = true
                                        setVolume(0f, 0f)
                                        setOnPreparedListener { readyMp ->
                                            videoReady = true
                                            if (shouldPlay) {
                                                runCatching {
                                                    readyMp.playbackParams = PlaybackParams().setSpeed(if (slowTempo) 0.7f else 1.0f)
                                                    readyMp.start()
                                                }
                                            }
                                        }
                                        prepareAsync()
                                    }
                                    player = mp
                                }
                            }
                            override fun onSurfaceTextureSizeChanged(st: SurfaceTexture, w: Int, h: Int) = Unit
                            override fun onSurfaceTextureUpdated(st: SurfaceTexture) = Unit
                            override fun onSurfaceTextureDestroyed(st: SurfaceTexture): Boolean {
                                runCatching { player?.stop() }
                                runCatching { player?.release() }
                                player = null
                                surfaceRef?.release()
                                surfaceRef = null
                                videoReady = false
                                return true
                            }
                        }
                    }
                },
                modifier = Modifier.fillMaxSize(),
            )
        }
    }
}
