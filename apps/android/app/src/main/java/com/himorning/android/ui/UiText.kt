package com.himorning.android.ui

import android.content.Context
import android.text.format.DateFormat
import java.time.Instant
import java.util.Date
import com.himorning.android.R
import com.himorning.android.core.*

internal fun preferredMode(kind: ChallengeKind) = when (kind) { ChallengeKind.PUSH_UPS, ChallengeKind.SQUATS, ChallengeKind.JUMPING_JACKS, ChallengeKind.STRETCHING -> WakeMode.FOCUSED; ChallengeKind.READ_ALOUD, ChallengeKind.READ_AND_CHOOSE, ChallengeKind.RIDDLE -> WakeMode.BALANCED; else -> WakeMode.GENTLE }
internal fun modeText(mode: WakeMode) = when (mode) { WakeMode.GENTLE -> R.string.gentle; WakeMode.BALANCED -> R.string.balanced; WakeMode.FOCUSED -> R.string.focused }
internal fun stateText(state: ScheduleState) = when (state) { ScheduleState.PENDING -> R.string.pending; ScheduleState.CONFIRMED -> R.string.confirmed; ScheduleState.OFF -> R.string.off; ScheduleState.NEEDS_REVIEW -> R.string.needs_review }
internal fun challengeText(kind: ChallengeKind) = when (kind) { ChallengeKind.NONE -> R.string.none; ChallengeKind.PUSH_UPS -> R.string.push_ups; ChallengeKind.SQUATS -> R.string.squats; ChallengeKind.READ_AND_CHOOSE -> R.string.read_and_choose; ChallengeKind.GUIDED_RHYTHM -> R.string.guided_rhythm; ChallengeKind.READ_ALOUD -> R.string.read_aloud; ChallengeKind.WAVE_HAND -> R.string.wave_hand; ChallengeKind.NECK_ROTATION -> R.string.neck_rotation; ChallengeKind.RIDDLE -> R.string.riddle; ChallengeKind.JUMPING_JACKS -> R.string.jumping_jacks; ChallengeKind.STRETCHING -> R.string.stretching; ChallengeKind.MORNING_LIGHT -> R.string.morning_light }
internal fun soundText(sound: AlarmSound) = when (sound) { AlarmSound.SYSTEM -> R.string.system; AlarmSound.SUNRISE -> R.string.sunrise; AlarmSound.SOFT_CHIME -> R.string.soft_chime; AlarmSound.PIZZICATO_DAWN -> R.string.pizzicato_dawn; AlarmSound.PIZZICATO_STEPS -> R.string.pizzicato_steps; AlarmSound.PIZZICATO_RISE -> R.string.pizzicato_rise; AlarmSound.PIZZICATO_BLOOM -> R.string.pizzicato_bloom; AlarmSound.STEEL_SHIMMER -> R.string.steel_shimmer; AlarmSound.STEEL_BREEZE -> R.string.steel_breeze; AlarmSound.STEEL_MORNING -> R.string.steel_morning; AlarmSound.STEEL_SPARKLE -> R.string.steel_sparkle; AlarmSound.SAX_HELLO -> R.string.sax_hello; AlarmSound.SAX_STROLL -> R.string.sax_stroll; AlarmSound.SAX_GLOW -> R.string.sax_glow; AlarmSound.SAX_DAYBREAK -> R.string.sax_daybreak; AlarmSound.BRIGHT_KEYS -> R.string.bright_keys; AlarmSound.PIXEL_MORNING -> R.string.pixel_morning; AlarmSound.BRASS_RISE -> R.string.brass_rise; AlarmSound.GLASS_CHIME -> R.string.glass_chime; AlarmSound.WOOD_PLUCK -> R.string.wood_pluck; AlarmSound.SOFT_BONG -> R.string.soft_bong }
internal fun focusText(focus: MorningFocus) = when (focus) { MorningFocus.CLEAR_START -> R.string.clear_start; MorningFocus.GENTLE_MOVEMENT -> R.string.gentle_movement; MorningFocus.FIND_YOUR_VOICE -> R.string.find_your_voice; MorningFocus.ENERGIZE -> R.string.energize }
internal fun guideText(kind: ChallengeKind, seated: Boolean) = when (kind) {
    ChallengeKind.PUSH_UPS -> R.string.guide_push_ups
    ChallengeKind.SQUATS -> R.string.guide_squats
    ChallengeKind.WAVE_HAND -> R.string.guide_wave_hand
    ChallengeKind.NECK_ROTATION -> R.string.guide_neck_rotation
    ChallengeKind.JUMPING_JACKS -> R.string.guide_jumping_jacks
    ChallengeKind.STRETCHING -> R.string.guide_stretching
    ChallengeKind.MORNING_LIGHT -> R.string.guide_morning_light
    else -> if (seated) R.string.guide_rhythm_seated else R.string.guide_rhythm_standing
}

internal fun alarmTimeText(context: Context, alarm: Alarm): String {
    val clockTime = Date((alarm.hour * 60L + alarm.minute) * 60_000L)
    return DateFormat.getTimeFormat(context).apply { timeZone = java.util.TimeZone.getTimeZone("UTC") }
        .format(clockTime)
}

internal fun occurrenceTimeText(context: Context, occurrence: Instant): String =
    DateFormat.getTimeFormat(context).format(Date.from(occurrence))

internal fun practiceMethod(kind: ChallengeKind) = when (kind) {
    ChallengeKind.READ_AND_CHOOSE, ChallengeKind.RIDDLE, ChallengeKind.NONE -> R.string.explore_badge_no_camera
    ChallengeKind.READ_ALOUD -> R.string.explore_badge_voice
    ChallengeKind.MORNING_LIGHT -> R.string.explore_badge_window_light
    ChallengeKind.WAVE_HAND, ChallengeKind.NECK_ROTATION -> R.string.explore_badge_close_camera
    ChallengeKind.STRETCHING -> R.string.explore_badge_upper_body
    ChallengeKind.PUSH_UPS, ChallengeKind.SQUATS, ChallengeKind.JUMPING_JACKS -> R.string.explore_badge_whole_body
    ChallengeKind.GUIDED_RHYTHM -> R.string.composer_camera
}

internal fun challengeDisplayTitle(context: Context, alarm: Alarm): String = when (alarm.challenge) {
    ChallengeKind.PUSH_UPS -> context.getString(R.string.challenge_push_ups_count, alarm.repetitions)
    ChallengeKind.GUIDED_RHYTHM -> context.getString(
        if (alarm.seated) R.string.challenge_rhythm_seated_title else R.string.challenge_rhythm_standing_title,
    )
    else -> context.getString(challengeText(alarm.challenge))
}
