package com.himorning.android.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.LocalIndication
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.BarChart
import androidx.compose.material.icons.outlined.DeleteOutline
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.Event
import androidx.compose.material.icons.outlined.ExpandMore
import androidx.compose.material.icons.outlined.ExpandLess
import androidx.compose.material.icons.outlined.PlayArrow
import androidx.compose.material.icons.outlined.Language
import androidx.compose.material.icons.outlined.Lightbulb
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material.icons.outlined.MoreVert
import androidx.compose.material.icons.outlined.Repeat
import androidx.compose.material.icons.outlined.VolumeUp
import androidx.compose.material.icons.outlined.WbSunny
import androidx.compose.material.icons.outlined.SwapHoriz
import androidx.compose.material.icons.outlined.WavingHand
import androidx.compose.material.icons.outlined.FitnessCenter
import androidx.compose.material3.IconButton
import androidx.compose.material3.Divider
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.himorning.android.R
import com.himorning.android.core.Alarm
import com.himorning.android.core.AlarmSound
import com.himorning.android.core.AppState
import com.himorning.android.core.AppLanguage
import com.himorning.android.core.ChallengeKind
import com.himorning.android.core.Journey
import com.himorning.android.core.MorningEntry
import com.himorning.android.core.MorningFocus
import com.himorning.android.core.ScheduleState
import com.himorning.android.core.WakeMode
import com.himorning.android.core.WakeOutcome
import com.himorning.android.core.mission
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Date
import java.util.Locale
import kotlin.math.min

@Composable
internal fun MorningHomeScreen(
    state: AppState,
    previewDays: Int,
    purposeChosen: Boolean,
    suggestedMission: Alarm,
    onAdd: () -> Unit,
    onEdit: (Alarm, AlarmEditorScope) -> Unit,
    onToggle: (Alarm, Boolean) -> Unit,
    onDelete: (Alarm) -> Unit,
    onPractice: (Alarm) -> Unit,
    onExplore: () -> Unit,
    onProgress: () -> Unit,
    onPro: () -> Unit,
    onLanguage: () -> Unit,
    onPurpose: () -> Unit,
    onMissionPractice: () -> Unit,
    onMissionPlan: () -> Unit,
    onRestartJourney: () -> Unit,
    readiness: @Composable () -> Unit,
    errorContent: @Composable () -> Unit,
) {
    val colors = MorningTheme.colors
    Column(
        Modifier.fillMaxSize().morningBackdrop(colors.yellow).verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp).padding(top = 18.dp, bottom = 28.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        val locale = homeLocale()
        HomeHeader(onProgress, onPro, onLanguage)
        JourneyCard(state, previewDays, suggestedMission, purposeChosen, onPurpose, onMissionPractice, onMissionPlan, onRestartJourney, onProgress, onPro)
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.home_alarms), style = MaterialTheme.typography.headlineMedium, color = colors.ink)
                Spacer(Modifier.weight(1f))
                Text(DateTimeFormatter.ofPattern("EEE, MMM d", locale).format(java.time.LocalDate.now()),
                    style = MaterialTheme.typography.bodySmall, color = colors.muted)
            }
            if (state.alarms.isEmpty() && !purposeChosen) FirstMorningCard(onPractice = onMissionPractice)
            errorContent()
            readiness()
            state.alarms.sortedWith(compareBy<Alarm> { it.hour }.thenBy { it.minute }).forEach { alarm ->
                AlarmCard(alarm, state.entries, onEdit, onToggle, onDelete, onPractice)
            }
            MorningButton(
                text = stringResource(R.string.home_add_alarm), onClick = onAdd, leadingIcon = Icons.Outlined.Add,
            )
            MorningButton(
                text = stringResource(R.string.home_explore), onClick = onExplore, primary = false,
                leadingIcon = challengeIcon(ChallengeKind.READ_AND_CHOOSE),
            )
        }
        if (state.alarms.isNotEmpty() || state.entries.isNotEmpty()) RecentWinsCard(state.entries, onProgress)
        PreviewFooter(state, previewDays, onPro)
    }
}

@Composable
private fun HomeHeader(onProgress: () -> Unit, onPro: () -> Unit, onLanguage: () -> Unit) {
    val stack = LocalDensity.current.fontScale >= 1.3f
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MorningSunrise(size = 26.dp)
            Text("HiMorning.", style = MaterialTheme.typography.titleLarge.copy(fontSize = 20.sp), fontWeight = FontWeight.Bold,
                color = MorningTheme.colors.ink, maxLines = 1)
            if (!stack) {
                Spacer(Modifier.weight(1f))
                HomeHeaderActions(onProgress, onPro, onLanguage)
            }
        }
        if (stack) Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End,
            verticalAlignment = Alignment.CenterVertically) { HomeHeaderActions(onProgress, onPro, onLanguage) }
    }
}

@Composable
private fun HomeHeaderActions(onProgress: () -> Unit, onPro: () -> Unit, onLanguage: () -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
        MorningIconButton(Icons.Outlined.BarChart, stringResource(R.string.home_progress), onProgress)
        MorningIconButton(Icons.Outlined.WbSunny, stringResource(R.string.home_pro), onPro)
        MorningIconButton(Icons.Outlined.Language, stringResource(R.string.language), onLanguage)
    }
}

@Composable
private fun JourneyCard(
    state: AppState,
    previewDays: Int,
    suggestedMission: Alarm,
    purposeChosen: Boolean,
    onPurpose: () -> Unit,
    onPractice: () -> Unit,
    onPlan: () -> Unit,
    onRestartJourney: () -> Unit,
    onProgress: () -> Unit,
    onPro: () -> Unit,
) {
    val journey = state.journey
    val colors = MorningTheme.colors
    val completed = journey.completions.size.coerceIn(0, 7)
    val todayComplete = journey.completedToday()
    val missionIndex = journey.missionIndex()
    val hasFullAccess = previewDays > 0
    val mission = if (todayComplete || journey.complete) journey.focus.mission(missionIndex, hasFullAccess) else suggestedMission.challenge
    var reflectionOpen by remember { mutableStateOf(false) }

    Column(
        Modifier.fillMaxWidth().morningSurface(colors.soft, radius = 24.dp, tint = colors.yellow, elevated = false).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(13.dp),
    ) {
        if (purposeChosen) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Icon(focusIcon(journey.focus), contentDescription = null, tint = colors.ink, modifier = Modifier.size(28.dp))
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(stringResource(focusText(journey.focus)), style = MaterialTheme.typography.titleLarge, color = colors.ink)
                    Text(stringResource(R.string.home_journey_count, completed), style = MaterialTheme.typography.bodyLarge, color = colors.ink)
                }
                MorningIconButton(Icons.Outlined.Edit, stringResource(R.string.home_change_purpose), onPurpose)
            }
            val journeyDescription = stringResource(R.string.home_journey_count, completed)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.semantics { contentDescription = journeyDescription }) {
                (0 until 7).forEach { day ->
                    Box(Modifier.size(28.dp).clip(CircleShape).background(if (day < completed) colors.success else Color.Transparent)
                        .border(if (day < completed) 0.dp else 1.5.dp, if (day < completed) colors.success else colors.muted, CircleShape),
                        contentAlignment = Alignment.Center) {
                        if (day < completed) Icon(Icons.Outlined.CheckCircle, contentDescription = null, tint = Color.White, modifier = Modifier.size(20.dp))
                    }
                }
            }
        }
        if (!purposeChosen) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                MorningSun(size = 48.dp)
                Text(stringResource(R.string.home_give_tomorrow_reason), style = MaterialTheme.typography.headlineSmall, color = colors.ink)
            }
            Text(stringResource(R.string.home_choose_purpose_intro), style = MaterialTheme.typography.bodyLarge, color = colors.ink)
            MorningButton(stringResource(R.string.home_choose_purpose), onPurpose, primary = true)
        } else if (journey.complete) {
            Text(stringResource(R.string.home_journey_complete), style = MaterialTheme.typography.headlineSmall, color = colors.ink)
            Text(stringResource(R.string.home_journey_complete_detail), style = MaterialTheme.typography.bodyMedium, color = colors.muted)
            MorningButton(stringResource(R.string.home_restart_journey), onRestartJourney, primary = true)
        } else if (todayComplete) {
            Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Icon(Icons.Outlined.CheckCircle, contentDescription = null, tint = colors.success, modifier = Modifier.size(30.dp))
                Text(stringResource(R.string.home_journey_today), style = MaterialTheme.typography.headlineSmall, color = colors.ink)
            }
            if (completed == 3) Text(stringResource(R.string.home_journey_three), style = MaterialTheme.typography.bodyLarge, color = colors.ink)
            Text(stringResource(R.string.home_tomorrow_mission, stringResource(challengeText(journey.focus.mission(completed, hasFullAccess)))),
                style = MaterialTheme.typography.bodyLarge, color = colors.ink)
            MorningButton(stringResource(R.string.home_prepare_mission), onPlan, primary = true)
            Text(stringResource(R.string.home_current_alarm_kept), style = MaterialTheme.typography.bodySmall, color = colors.muted)
        } else {
            Text(stringResource(R.string.home_suggested_mission), style = MaterialTheme.typography.labelLarge, color = colors.muted)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Icon(challengeIcon(mission), contentDescription = null, tint = challengeColor(mission), modifier = Modifier.size(25.dp))
                Text(stringResource(challengeText(mission)), style = MaterialTheme.typography.titleLarge, color = colors.ink)
            }
            Text(missionReason(mission, journey), style = MaterialTheme.typography.bodyMedium, color = colors.ink)
            if (journey.focus == MorningFocus.ENERGIZE && !hasFullAccess) {
                Text(stringResource(R.string.home_path_preview_ended), style = MaterialTheme.typography.bodySmall, color = colors.muted)
            }
            MorningButton(stringResource(R.string.home_try_mission), onPractice, primary = false,
                leadingIcon = Icons.Outlined.PlayArrow)
            MorningButton(stringResource(R.string.home_plan_mission), onPlan, primary = true)
            Text(stringResource(R.string.home_no_streak), style = MaterialTheme.typography.bodySmall, color = colors.muted)
        }
        if (purposeChosen) {
            val reflectionLabel = stringResource(R.string.home_reflection)
            val reflectionInteractions = remember { MutableInteractionSource() }
            Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).morningPress(reflectionInteractions)
                .clickable(interactionSource = reflectionInteractions, indication = LocalIndication.current) { reflectionOpen = !reflectionOpen }
                .semantics { role = Role.Button; contentDescription = reflectionLabel }
                .padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.home_reflection), modifier = Modifier.weight(1f), style = MaterialTheme.typography.titleMedium, color = colors.ink)
                Icon(if (reflectionOpen) Icons.Outlined.ExpandLess else Icons.Outlined.ExpandMore, contentDescription = null, tint = colors.ink)
            }
            if (reflectionOpen) {
                val days = completedDays(state.entries, 30)
                if (hasFullAccess) {
                    Text(stringResource(R.string.home_reflection_days, days), style = MaterialTheme.typography.bodyMedium, color = colors.ink)
                    val kind = favoriteChallenge(state.entries)
                    if (kind != null) Text(stringResource(R.string.home_reflection_pattern, stringResource(challengeText(kind))), style = MaterialTheme.typography.bodyMedium, color = colors.ink)
                    Text(stringResource(R.string.home_reflection_scope), style = MaterialTheme.typography.bodySmall, color = colors.muted)
                    TextButton(onClick = onProgress) { Text(stringResource(R.string.home_30day_progress)) }
                } else {
                    Text(stringResource(R.string.home_pro_explainer), style = MaterialTheme.typography.bodySmall, color = colors.muted)
                    TextButton(onClick = onPro) { Text(stringResource(R.string.home_explore_pro)) }
                }
            }
        }
    }
}

@Composable
private fun FirstMorningCard(onPractice: () -> Unit) {
    Column(Modifier.fillMaxWidth().morningSurface(MorningTheme.colors.hero, radius = 24.dp, tint = MorningTheme.colors.yellow).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(13.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            MorningSun(size = 64.dp)
            Text(stringResource(R.string.home_first_title), style = MaterialTheme.typography.headlineSmall, color = MorningTheme.colors.onYellow)
        }
        Text(stringResource(R.string.home_first_subtitle), style = MaterialTheme.typography.bodyLarge, color = MorningTheme.colors.onYellow)
        Column(verticalArrangement = Arrangement.spacedBy(7.dp)) {
            Text(stringResource(R.string.home_first_step1), color = MorningTheme.colors.onYellow, style = MaterialTheme.typography.bodyMedium)
            Text(stringResource(R.string.home_first_step2), color = MorningTheme.colors.onYellow, style = MaterialTheme.typography.bodyMedium)
            Text(stringResource(R.string.home_first_step3), color = MorningTheme.colors.onYellow, style = MaterialTheme.typography.bodyMedium)
        }
        MorningButton(stringResource(R.string.home_try_reading), onPractice, primary = false, leadingIcon = Icons.Outlined.PlayArrow)
        Text(stringResource(R.string.home_no_permissions_practice), style = MaterialTheme.typography.bodySmall, color = MorningTheme.colors.onYellow.copy(alpha = .75f))
    }
}

@Composable
private fun AlarmCard(
    alarm: Alarm,
    entries: List<MorningEntry>,
    onEdit: (Alarm, AlarmEditorScope) -> Unit,
    onToggle: (Alarm, Boolean) -> Unit,
    onDelete: (Alarm) -> Unit,
    onPractice: (Alarm) -> Unit,
) {
    val colors = MorningTheme.colors
    val tryLabel = stringResource(R.string.home_try_challenge)
    val toggleLabel = stringResource(if (alarm.enabled) R.string.home_turn_off else R.string.home_turn_on)
    val optionsLabel = stringResource(R.string.home_alarm_options)
    val density = LocalDensity.current
    val stack = density.fontScale >= 1.3f || LocalConfiguration.current.screenWidthDp < 380
    val card = if (alarm.enabled) colors.alarmCard else colors.soft
    val ink = if (alarm.enabled) colors.onYellow else colors.muted
    val now = System.currentTimeMillis()
    val completeToday = entries.any { it.alarmId == alarm.id && isSuccessful(it.outcome) && sameLocalDay(it.date, now) }
    var menuExpanded by remember { mutableStateOf(false) }
    val cardInteractions = remember { MutableInteractionSource() }
    val playInteractions = remember { MutableInteractionSource() }
    val menuInteractions = remember { MutableInteractionSource() }

    Column(
        Modifier.fillMaxWidth()
            .morningPress(cardInteractions)
            .morningSurface(card, radius = 26.dp, tint = colors.yellow, elevated = alarm.enabled)
            .clickable(interactionSource = cardInteractions, indication = LocalIndication.current) { onEdit(alarm, AlarmEditorScope.ALL) }
            .padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        if (stack) {
            AlarmScheduleContent(alarm, ink, onEdit)
            ChallengeSummary(alarm, ink, onEdit, stacked = true)
        } else {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.Top) {
                Box(Modifier.weight(1f)) { AlarmScheduleContent(alarm, ink, onEdit) }
                ChallengeSummary(alarm, ink, onEdit, stacked = false, modifier = Modifier.widthIn(max = 138.dp))
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Icon(Icons.Outlined.VolumeUp, contentDescription = null, tint = ink, modifier = Modifier.size(18.dp))
            Text(stringResource(soundText(alarm.sound)), style = MaterialTheme.typography.bodySmall, color = ink)
        }
        Divider(color = colors.onYellow.copy(alpha = if (alarm.enabled) .12f else 0f), thickness = 1.dp)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                when {
                    alarm.state == ScheduleState.NEEDS_REVIEW -> Text(stringResource(stateText(ScheduleState.NEEDS_REVIEW)), style = MaterialTheme.typography.labelMedium, color = ink)
                    alarm.state == ScheduleState.PENDING -> Text(stringResource(stateText(ScheduleState.PENDING)), style = MaterialTheme.typography.labelMedium, color = ink)
                    alarm.enabled -> Text(nextOccurrence(alarm), style = MaterialTheme.typography.bodySmall, color = ink.copy(alpha = .8f))
                    else -> Text(stringResource(stateText(ScheduleState.OFF)), style = MaterialTheme.typography.bodySmall, color = ink)
                }
                if (completeToday) Text(stringResource(R.string.home_completed_today), style = MaterialTheme.typography.bodySmall, color = ink)
            }
            if (alarm.enabled && alarm.challenge != ChallengeKind.NONE) {
                IconButton(onClick = { onPractice(alarm) }, interactionSource = playInteractions,
                    modifier = Modifier.size(48.dp).morningPress(playInteractions)
                    .semantics { contentDescription = tryLabel }) {
                    Icon(Icons.Outlined.PlayArrow, contentDescription = null, tint = ink, modifier = Modifier.size(26.dp))
                }
            }
            Switch(checked = alarm.enabled, onCheckedChange = { onToggle(alarm, it) }, colors = androidx.compose.material3.SwitchDefaults.colors(
                checkedThumbColor = Color.White, checkedTrackColor = Color(0xFF44634A), checkedBorderColor = Color.Transparent,
                uncheckedThumbColor = colors.muted, uncheckedTrackColor = colors.surface, uncheckedBorderColor = colors.muted), modifier = Modifier.semantics {
                contentDescription = toggleLabel
            })
            Box {
                IconButton(onClick = { menuExpanded = true }, interactionSource = menuInteractions,
                    modifier = Modifier.size(48.dp).morningPress(menuInteractions)
                    .semantics { contentDescription = optionsLabel }) {
                    Icon(Icons.Outlined.MoreVert, contentDescription = null, tint = ink)
                }
                DropdownMenu(expanded = menuExpanded, onDismissRequest = { menuExpanded = false }) {
                    DropdownMenuItem(text = { Text(stringResource(R.string.home_edit_alarm)) }, leadingIcon = { Icon(Icons.Outlined.Edit, null) },
                        onClick = { menuExpanded = false; onEdit(alarm, AlarmEditorScope.ALL) })
                    DropdownMenuItem(text = { Text(stringResource(R.string.home_delete_alarm)) }, leadingIcon = { Icon(Icons.Outlined.DeleteOutline, null) },
                        onClick = { menuExpanded = false; onDelete(alarm) })
                }
            }
        }
    }
}

@Composable
private fun AlarmScheduleContent(alarm: Alarm, ink: Color, onEdit: (Alarm, AlarmEditorScope) -> Unit) {
    val scheduleLabel = stringResource(R.string.home_edit_schedule)
    val interactions = remember { MutableInteractionSource() }
    Column(Modifier.fillMaxWidth().morningPress(interactions)
        .clickable(interactionSource = interactions, indication = LocalIndication.current) { onEdit(alarm, AlarmEditorScope.SCHEDULE) }
        .semantics { role = Role.Button; contentDescription = scheduleLabel }
        .padding(vertical = 3.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        if (alarm.label.isNotBlank()) Text(alarm.label, style = MaterialTheme.typography.titleSmall, color = ink, maxLines = 2, overflow = TextOverflow.Ellipsis)
        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            val hour = alarm.hour % 12
            val displayHour = if (hour == 0) 12 else hour
            Text("%02d:%02d".format(displayHour, alarm.minute), style = MaterialTheme.typography.displaySmall.copy(fontSize = 48.sp, fontWeight = FontWeight.Medium, fontFeatureSettings = "tnum"), color = ink, maxLines = 1)
            Text(if (alarm.hour < 12) stringResource(R.string.home_am) else stringResource(R.string.home_pm), style = MaterialTheme.typography.labelMedium, color = ink, modifier = Modifier.padding(bottom = 5.dp))
        }
        if (alarm.enabled) {
            Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                Icon(if (alarm.weekdays.isEmpty()) Icons.Outlined.Event else Icons.Outlined.Repeat, null, tint = ink.copy(alpha = .8f), modifier = Modifier.size(16.dp))
                Text(repeatSummary(alarm), style = MaterialTheme.typography.bodySmall, color = ink.copy(alpha = .82f))
            }
        }
    }
}

@Composable
private fun ChallengeSummary(alarm: Alarm, ink: Color, onEdit: (Alarm, AlarmEditorScope) -> Unit, stacked: Boolean, modifier: Modifier = Modifier) {
    val editChallengeLabel = stringResource(R.string.home_edit_challenge)
    val interactions = remember { MutableInteractionSource() }
    Column(modifier.widthIn(min = if (stacked) 0.dp else 100.dp).morningPress(interactions)
        .clickable(interactionSource = interactions, indication = LocalIndication.current) { onEdit(alarm, AlarmEditorScope.CHALLENGE) }
        .semantics { role = Role.Button; contentDescription = editChallengeLabel }
        .padding(2.dp), horizontalAlignment = if (stacked) Alignment.Start else Alignment.End,
        verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Icon(challengeIcon(alarm.challenge), contentDescription = null, tint = if (alarm.enabled) challengeColor(alarm.challenge, onYellow = true) else ink, modifier = Modifier.size(28.dp))
        Text(stringResource(challengeText(alarm.challenge)), style = MaterialTheme.typography.titleSmall, color = ink, maxLines = 2,
            overflow = TextOverflow.Ellipsis, textAlign = if (stacked) TextAlign.Start else TextAlign.End)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
            Icon(modeIcon(alarm.mode), contentDescription = null, tint = modeTint(alarm.mode, alarm.enabled), modifier = Modifier.size(17.dp))
            Text(stringResource(modeText(alarm.mode)), style = MaterialTheme.typography.labelMedium, color = modeTint(alarm.mode, alarm.enabled))
        }
    }
}

@Composable
private fun RecentWinsCard(entries: List<MorningEntry>, onProgress: () -> Unit) {
    val days = completedDays(entries, 7)
    Column(Modifier.fillMaxWidth().morningSurface(MorningTheme.colors.soft, radius = 22.dp, tint = MorningTheme.colors.yellow, elevated = false).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(stringResource(R.string.home_recent_wins), style = MaterialTheme.typography.titleMedium, color = MorningTheme.colors.ink)
        Text(stringResource(R.string.home_recent_count, days), style = MaterialTheme.typography.bodyLarge, color = MorningTheme.colors.ink)
        Text(stringResource(R.string.home_recent_note), style = MaterialTheme.typography.bodySmall, color = MorningTheme.colors.muted)
        if (days == 0) Text(stringResource(R.string.home_first_win), style = MaterialTheme.typography.bodyMedium, color = MorningTheme.colors.ink)
        TextButton(onClick = onProgress) { Text(stringResource(R.string.home_progress)) }
    }
}

@Composable
private fun PreviewFooter(state: AppState, days: Int, onPro: () -> Unit) {
    if (state.previewStartedAt == null && state.alarms.isEmpty()) return
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        when {
            state.previewStartedAt == null && days > 0 -> Text(stringResource(R.string.preview_not_started), color = MorningTheme.colors.muted, style = MaterialTheme.typography.bodySmall)
            days > 0 -> Text(stringResource(R.string.home_preview_days, days), color = MorningTheme.colors.muted, style = MaterialTheme.typography.bodySmall)
            else -> Text(stringResource(R.string.basic_access), color = MorningTheme.colors.muted, style = MaterialTheme.typography.bodySmall)
        }
        if (days > 0 && completedDays(state.entries, 30) >= 3) TextButton(onClick = onPro) { Text(stringResource(R.string.home_explore_pro)) }
    }
}

@Composable
private fun focusIcon(focus: MorningFocus): ImageVector = when (focus) {
    MorningFocus.CLEAR_START -> Icons.Outlined.Lightbulb
    MorningFocus.GENTLE_MOVEMENT -> Icons.Outlined.WavingHand
    MorningFocus.FIND_YOUR_VOICE -> Icons.Outlined.Mic
    MorningFocus.ENERGIZE -> Icons.Outlined.FitnessCenter
}

@Composable
private fun repeatSummary(alarm: Alarm): String {
    if (alarm.weekdays.isEmpty()) {
        val date = alarm.scheduledAt?.let { Instant.ofEpochMilli(it).atZone(ZoneId.systemDefault()).toLocalDate() } ?: return stringResource(R.string.once)
        val today = java.time.LocalDate.now()
        return when (date) {
            today -> stringResource(R.string.home_once_today)
            today.plusDays(1) -> stringResource(R.string.home_once_tomorrow)
            else -> DateTimeFormatter.ofPattern("EEE, MMM d", homeLocale()).format(date)
        }
    }
    if (alarm.weekdays.size == 7) return stringResource(R.string.home_every_day)
    val names = listOf(stringResource(R.string.home_sun), stringResource(R.string.home_mon), stringResource(R.string.home_tue),
        stringResource(R.string.home_wed), stringResource(R.string.home_thu), stringResource(R.string.home_fri), stringResource(R.string.home_sat))
    return (1..7).filter { it in alarm.weekdays }.joinToString(", ") { names[it - 1] }
}

@Composable
private fun nextOccurrence(alarm: Alarm): String {
    val instant = runCatching {
        if (alarm.weekdays.isEmpty()) alarm.scheduledAt?.let(Instant::ofEpochMilli) ?: alarm.nextAfter(Instant.now(), ZoneId.systemDefault())
        else alarm.nextAfter(Instant.now(), ZoneId.systemDefault())
    }.getOrNull() ?: return ""
    val date = instant.atZone(ZoneId.systemDefault()).toLocalDate()
    val today = java.time.LocalDate.now()
    val label = when (date) {
        today -> stringResource(R.string.home_today)
        today.plusDays(1) -> stringResource(R.string.home_tomorrow)
        else -> DateTimeFormatter.ofPattern("EEE, MMM d", homeLocale()).format(date)
    }
    return stringResource(R.string.home_next, label)
}

@Composable
private fun homeLocale(): Locale {
    val locales = LocalConfiguration.current.locales
    return if (locales.size() == 0) Locale.US else locales[0]
}

private fun isSuccessful(outcome: WakeOutcome) = outcome == WakeOutcome.LOCAL_COMPLETED || outcome == WakeOutcome.AI_VERIFIED
private fun sameLocalDay(a: Long, b: Long): Boolean {
    val zone = ZoneId.systemDefault()
    return Instant.ofEpochMilli(a).atZone(zone).toLocalDate() == Instant.ofEpochMilli(b).atZone(zone).toLocalDate()
}
private fun completedDays(entries: List<MorningEntry>, days: Int): Int {
    val zone = ZoneId.systemDefault()
    val now = java.time.LocalDate.now(zone)
    val start = now.minusDays((days - 1).toLong())
    return entries.asSequence().filter { isSuccessful(it.outcome) }
        .map { Instant.ofEpochMilli(it.date).atZone(zone).toLocalDate() }
        .filter { it >= start && it <= now }.distinct().count().toInt()
}
@Composable
private fun modeTint(mode: WakeMode, enabled: Boolean): Color {
    val darkSurface = androidx.compose.foundation.isSystemInDarkTheme() && !enabled
    return when (mode) {
        WakeMode.GENTLE -> if (darkSurface) Color(0xFF7BD4A3) else Color(0xFF1F5738)
        WakeMode.BALANCED -> if (darkSurface) Color(0xFFC7A8F0) else Color(0xFF5C387A)
        WakeMode.FOCUSED -> if (darkSurface) Color(0xFFFFA66B) else Color(0xFF85331A)
    }
}

@Composable
private fun missionReason(kind: ChallengeKind, journey: Journey): String = stringResource(when (kind) {
    ChallengeKind.READ_AND_CHOOSE -> R.string.home_reason_attention
    ChallengeKind.RIDDLE -> R.string.home_reason_curiosity
    ChallengeKind.READ_ALOUD -> R.string.home_reason_voice
    ChallengeKind.WAVE_HAND -> R.string.home_reason_hello
    ChallengeKind.NECK_ROTATION -> R.string.home_reason_gentle
    ChallengeKind.GUIDED_RHYTHM -> if (journey.focus == MorningFocus.GENTLE_MOVEMENT) R.string.home_reason_seated else R.string.home_reason_standing
    else -> R.string.home_reason_move
})
