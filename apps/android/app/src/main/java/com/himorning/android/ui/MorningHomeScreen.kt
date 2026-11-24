package com.himorning.android.ui

import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
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
import androidx.compose.material3.SwitchDefaults
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
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
import com.himorning.android.core.completedChallenge
import com.himorning.android.core.mission
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.min

@Composable
internal fun MorningHomeScreen(
    state: AppState,
    purposeChosen: Boolean,
    suggestedMission: Alarm,
    onAdd: () -> Unit,
    onEdit: (Alarm, AlarmEditorScope) -> Unit,
    onToggle: (Alarm, Boolean) -> Unit,
    onDelete: (Alarm) -> Unit,
    onPractice: (Alarm) -> Unit,
    onExplore: () -> Unit,
    onProgress: () -> Unit,
    onLanguage: () -> Unit,
    onPurpose: () -> Unit,
    onQuickPractice: () -> Unit,
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
        HomeHeader(onProgress, onLanguage)
        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(R.string.home_alarms), style = MaterialTheme.typography.headlineMedium, fontFamily = quicksandFont, color = colors.ink)
                Spacer(Modifier.weight(1f))
                Text(DateTimeFormatter.ofPattern("EEE, MMM d", locale).format(java.time.LocalDate.now()),
                    style = MaterialTheme.typography.bodySmall, color = colors.muted)
            }
            val now = Instant.now()
            state.alarms.sortedWith(compareBy<Alarm> { alarm ->
                if (alarm.enabled && alarm.state == ScheduleState.CONFIRMED)
                    alarm.scheduledAt?.let(Instant::ofEpochMilli)?.takeIf { it > now } ?: Instant.MAX
                else Instant.MAX
            }.thenBy { it.hour }.thenBy { it.minute }).forEach { alarm ->
                AlarmCard(alarm, state.entries, onEdit, onToggle, onDelete, onPractice)
            }
            MorningButton(
                text = stringResource(if (state.alarms.isEmpty()) R.string.set_an_alarm else R.string.home_add_alarm), onClick = onAdd, leadingIcon = Icons.Outlined.Add,
            )
            if (state.alarms.isEmpty()) FirstMorningCard(onPractice = onQuickPractice)
            errorContent()
            readiness()
            MorningButton(
                text = stringResource(R.string.home_explore), onClick = onExplore, primary = false,
                leadingIcon = challengeIcon(ChallengeKind.READ_AND_CHOOSE),
            )
        }
        JourneyCard(state, suggestedMission, purposeChosen, onPurpose, onMissionPractice, onMissionPlan, onRestartJourney, onProgress)
        if (state.alarms.isNotEmpty() || state.entries.isNotEmpty()) RecentWinsCard(state.entries, onProgress)
    }
}

@Composable
private fun HomeHeader(onProgress: () -> Unit, onLanguage: () -> Unit) {
    val stack = LocalDensity.current.fontScale >= 1.3f
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MorningSunrise(size = 26.dp)
            Text("HiMorning.", style = MaterialTheme.typography.titleLarge.copy(fontSize = 20.sp), fontFamily = quicksandFont, fontWeight = FontWeight.Bold,
                color = MorningTheme.colors.ink, maxLines = 1)
            if (!stack) {
                Spacer(Modifier.weight(1f))
                HomeHeaderActions(onProgress, onLanguage)
            }
        }
        if (stack) Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End,
            verticalAlignment = Alignment.CenterVertically) { HomeHeaderActions(onProgress, onLanguage) }
    }
}

@Composable
private fun HomeHeaderActions(onProgress: () -> Unit, onLanguage: () -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
        MorningIconButton(Icons.Outlined.BarChart, stringResource(R.string.home_progress), onProgress)
        MorningIconButton(Icons.Outlined.Language, stringResource(R.string.language), onLanguage)
    }
}

@Composable
private fun JourneyCard(
    state: AppState,
    suggestedMission: Alarm,
    purposeChosen: Boolean,
    onPurpose: () -> Unit,
    onPractice: () -> Unit,
    onPlan: () -> Unit,
    onRestartJourney: () -> Unit,
    onProgress: () -> Unit,
) {
    val journey = state.journey
    val colors = MorningTheme.colors
    val completed = journey.completions.size.coerceIn(0, 7)
    val todayComplete = journey.completedToday()
    val missionIndex = journey.missionIndex()
    val mission = if (todayComplete || journey.complete) journey.focus.mission(missionIndex, true) else suggestedMission.challenge
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
                    Text(stringResource(R.string.morning_round, completed), style = MaterialTheme.typography.bodyLarge, color = colors.ink)
                }
                TextButton(onClick = onPurpose) { Text(stringResource(R.string.home_change_purpose)) }
            }
        }
        if (!purposeChosen) {
            Text(stringResource(R.string.home_choose_purpose_intro), style = MaterialTheme.typography.bodyMedium, color = colors.muted)
            TextButton(onClick = onPurpose) { Text(stringResource(R.string.home_choose_purpose)) }
        } else if (journey.complete) {
            Text(stringResource(R.string.home_journey_complete), style = MaterialTheme.typography.headlineSmall, color = colors.ink)
            Text(stringResource(R.string.home_journey_complete_detail), style = MaterialTheme.typography.bodyMedium, color = colors.muted)
            MorningButton(stringResource(R.string.home_restart_journey), onRestartJourney, primary = true)
        } else if (todayComplete) {
            Text(stringResource(R.string.home_journey_today), style = MaterialTheme.typography.titleSmall, color = colors.success)
            MorningButton(stringResource(R.string.home_prepare_mission), onPlan, primary = false)
        } else {
            Text(stringResource(R.string.home_suggested_mission), style = MaterialTheme.typography.labelLarge, color = colors.muted)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Icon(challengeIcon(mission), contentDescription = null, tint = MorningTheme.modeAccent(preferredMode(mission)), modifier = Modifier.size(25.dp))
                Text(stringResource(challengeText(mission)), style = MaterialTheme.typography.titleLarge, color = colors.ink)
            }
            MorningButton(stringResource(R.string.home_try_mission), onPractice, primary = false,
                leadingIcon = Icons.Outlined.PlayArrow)
            MorningButton(stringResource(R.string.home_plan_mission), onPlan, primary = false)
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
                Text(stringResource(R.string.home_reflection_days, days), style = MaterialTheme.typography.bodyMedium, color = colors.ink)
                favoriteChallenge(state.entries)?.let { kind ->
                    Text(stringResource(R.string.home_reflection_pattern, stringResource(challengeText(kind))), style = MaterialTheme.typography.bodyMedium, color = colors.ink)
                }
                TextButton(onClick = onProgress) { Text(stringResource(R.string.home_30day_progress)) }
            }
        }
    }
}

@Composable
private fun FirstMorningCard(onPractice: () -> Unit) {
    val colors = MorningTheme.colors
    Column(
        Modifier.fillMaxWidth().morningSurface(colors.soft, radius = 24.dp, tint = colors.yellow, elevated = false).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(stringResource(R.string.home_first_title), style = MaterialTheme.typography.titleMedium, color = colors.ink)
        Text(stringResource(R.string.home_first_subtitle), style = MaterialTheme.typography.bodyMedium, color = colors.muted)
        TextButton(onClick = onPractice) { Text(stringResource(R.string.home_try_reading)) }
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
    val now = System.currentTimeMillis()
    val confirmedAt = alarm.scheduledAt?.takeIf { it > now }?.let(Instant::ofEpochMilli)
    val armed = alarm.enabled && alarm.state == ScheduleState.CONFIRMED && confirmedAt != null
    val needsReview = alarm.state == ScheduleState.NEEDS_REVIEW ||
        (alarm.state == ScheduleState.CONFIRMED && alarm.enabled && confirmedAt == null)
    val compactDisabled = !alarm.enabled && !needsReview
    val toggleLabel = stringResource(if (armed) R.string.home_turn_off else R.string.home_turn_on)
    val optionsLabel = stringResource(R.string.home_alarm_options)
    val density = LocalDensity.current
    val stack = density.fontScale >= 1.3f || LocalConfiguration.current.screenWidthDp < 380
    val ink = if (armed) colors.onYellow else colors.ink
    val detailInk = if (armed) MorningTheme.alarmDetailOnYellow else colors.muted
    val clockInk = if (alarm.enabled) ink else colors.alarmClockOff
    val shape = RoundedCornerShape(26.dp)
    val completeToday = entries.any { it.alarmId == alarm.id && it.completedChallenge && sameLocalDay(it.date, now) }
    var menuExpanded by remember { mutableStateOf(false) }
    val cardInteractions = remember { MutableInteractionSource() }
    val playInteractions = remember { MutableInteractionSource() }
    val menuInteractions = remember { MutableInteractionSource() }

    Column(
        Modifier.fillMaxWidth()
            .animateContentSize(spring(dampingRatio = 0.85f, stiffness = Spring.StiffnessMediumLow))
            .morningPress(cardInteractions)
            .clip(shape)
            .then(if (armed) Modifier.background(Brush.linearGradient(listOf(MorningTheme.alarmCardHighlight, colors.yellow)))
                else Modifier.background(colors.surface))
            .border(1.dp, if (armed) MorningTheme.alarmCardEdge else colors.line, shape)
            .clickable(interactionSource = cardInteractions, indication = LocalIndication.current) { onEdit(alarm, AlarmEditorScope.ALL) }
            .padding(horizontal = 18.dp, vertical = if (compactDisabled) 12.dp else 18.dp),
        verticalArrangement = Arrangement.spacedBy(if (compactDisabled) 4.dp else 12.dp),
    ) {
        if (compactDisabled) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    if (alarm.label.isNotBlank()) {
                        Text(alarm.label, style = MaterialTheme.typography.titleSmall, color = detailInk, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                    Text(
                        alarmTimeText(LocalContext.current, alarm),
                        style = MaterialTheme.typography.headlineMedium.copy(fontSize = 34.sp, fontWeight = FontWeight.Medium, fontFeatureSettings = "tnum"),
                        color = clockInk,
                        maxLines = 1,
                    )
                    Text(stringResource(stateText(ScheduleState.OFF)), style = MaterialTheme.typography.bodySmall, color = detailInk)
                    if (completeToday) {
                        Text(stringResource(R.string.home_completed_today), style = MaterialTheme.typography.bodySmall, color = colors.success)
                    }
                }
                Switch(
                    checked = armed,
                    enabled = alarm.state != ScheduleState.PENDING,
                    onCheckedChange = { onToggle(alarm, it) },
                    colors = SwitchDefaults.colors(
                        checkedThumbColor = Color.White, checkedTrackColor = MorningTheme.alarmSwitchOn, checkedBorderColor = Color.Transparent,
                        uncheckedThumbColor = colors.muted, uncheckedTrackColor = colors.surface, uncheckedBorderColor = colors.muted,
                    ),
                    modifier = Modifier.semantics { contentDescription = toggleLabel },
                )
                Box {
                    IconButton(onClick = { menuExpanded = true }, interactionSource = menuInteractions,
                        modifier = Modifier.size(44.dp).morningPress(menuInteractions)
                        .semantics { contentDescription = optionsLabel }) {
                        Icon(Icons.Outlined.MoreVert, contentDescription = null, tint = detailInk)
                    }
                    DropdownMenu(expanded = menuExpanded, onDismissRequest = { menuExpanded = false }) {
                        DropdownMenuItem(text = { Text(stringResource(R.string.home_edit_alarm)) }, leadingIcon = { Icon(Icons.Outlined.Edit, null) },
                            onClick = { menuExpanded = false; onEdit(alarm, AlarmEditorScope.ALL) })
                        DropdownMenuItem(text = { Text(stringResource(R.string.home_delete_alarm)) }, leadingIcon = { Icon(Icons.Outlined.DeleteOutline, null) },
                            onClick = { menuExpanded = false; onDelete(alarm) })
                    }
                }
            }
            return@Column
        }
        if (stack) {
            AlarmTimeColumn(alarm, ink, clockInk, detailInk, onEdit)
            ChallengeSummary(alarm, ink, onEdit, stacked = true, onYellow = armed)
        } else {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.Top) {
                Box(Modifier.weight(1f)) { AlarmTimeColumn(alarm, ink, clockInk, detailInk, onEdit) }
                ChallengeSummary(alarm, ink, onEdit, stacked = false, onYellow = armed, modifier = Modifier.widthIn(max = 138.dp))
            }
        }
        val status = when {
            needsReview -> stringResource(stateText(ScheduleState.NEEDS_REVIEW))
            alarm.state == ScheduleState.PENDING -> stringResource(stateText(ScheduleState.PENDING))
            armed -> nextOccurrence(confirmedAt)
            else -> stringResource(stateText(ScheduleState.OFF))
        }
        Divider(color = ink.copy(alpha = .14f), thickness = 1.dp)
        val statusLabels: @Composable () -> Unit = {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(status, style = MaterialTheme.typography.bodySmall, color = if (needsReview) ink else detailInk)
                if (completeToday) Text(stringResource(R.string.home_completed_today), style = MaterialTheme.typography.bodySmall,
                    color = if (armed) MorningTheme.successOnYellow else colors.success)
            }
        }
        if (stack) statusLabels()
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            if (stack) Spacer(Modifier.weight(1f)) else Box(Modifier.weight(1f)) { statusLabels() }
            if (alarm.enabled && alarm.challenge != ChallengeKind.NONE) {
                IconButton(onClick = { onPractice(alarm) }, interactionSource = playInteractions,
                    modifier = Modifier.size(48.dp).morningPress(playInteractions)
                    .semantics { contentDescription = tryLabel }) {
                    Icon(Icons.Outlined.PlayArrow, contentDescription = null, tint = ink, modifier = Modifier.size(26.dp))
                }
            }
            if (needsReview) {
                TextButton(onClick = { onToggle(alarm, alarm.enabled) }) {
                    Text(stringResource(if (alarm.enabled) R.string.retry_alarm_schedule else R.string.retry_alarm_off))
                }
            } else Switch(checked = armed, enabled = alarm.state != ScheduleState.PENDING, onCheckedChange = { onToggle(alarm, it) }, colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White, checkedTrackColor = MorningTheme.alarmSwitchOn, checkedBorderColor = Color.Transparent,
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
                    if (alarm.enabled && needsReview) {
                        DropdownMenuItem(text = { Text(stringResource(R.string.home_turn_off)) },
                            onClick = { menuExpanded = false; onToggle(alarm, false) })
                    }
                    DropdownMenuItem(text = { Text(stringResource(R.string.home_delete_alarm)) }, leadingIcon = { Icon(Icons.Outlined.DeleteOutline, null) },
                        onClick = { menuExpanded = false; onDelete(alarm) })
                }
            }
        }
    }
}

@Composable
private fun AlarmTimeColumn(alarm: Alarm, ink: Color, clockInk: Color, detailInk: Color, onEdit: (Alarm, AlarmEditorScope) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        AlarmScheduleContent(alarm, ink, clockInk, detailInk, onEdit)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Icon(Icons.Outlined.VolumeUp, contentDescription = null, tint = detailInk, modifier = Modifier.size(16.dp))
            Text(stringResource(soundText(alarm.sound)), style = MaterialTheme.typography.bodySmall, color = detailInk)
        }
    }
}

@Composable
private fun AlarmScheduleContent(alarm: Alarm, ink: Color, clockInk: Color, detailInk: Color, onEdit: (Alarm, AlarmEditorScope) -> Unit) {
    val scheduleLabel = stringResource(R.string.home_edit_schedule)
    val interactions = remember { MutableInteractionSource() }
    Column(Modifier.fillMaxWidth().morningPress(interactions)
        .clickable(interactionSource = interactions, indication = LocalIndication.current) { onEdit(alarm, AlarmEditorScope.SCHEDULE) }
        .semantics { role = Role.Button; contentDescription = scheduleLabel }
        .padding(vertical = 3.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        if (alarm.label.isNotBlank()) Text(alarm.label, style = MaterialTheme.typography.titleSmall, color = ink, maxLines = 2, overflow = TextOverflow.Ellipsis)
        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(alarmTimeText(LocalContext.current, alarm),
                style = MaterialTheme.typography.displaySmall.copy(fontSize = 42.sp, fontWeight = FontWeight.Medium, fontFeatureSettings = "tnum"),
                color = clockInk, maxLines = 1)

        }
        if (alarm.enabled) {
            Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                Icon(if (alarm.weekdays.isEmpty()) Icons.Outlined.Event else Icons.Outlined.Repeat, null, tint = detailInk, modifier = Modifier.size(16.dp))
                Text(repeatSummary(alarm), style = MaterialTheme.typography.bodySmall, color = detailInk)
            }
        }
    }
}

@Composable
private fun ChallengeSummary(alarm: Alarm, ink: Color, onEdit: (Alarm, AlarmEditorScope) -> Unit, stacked: Boolean, onYellow: Boolean, modifier: Modifier = Modifier) {
    val editChallengeLabel = stringResource(R.string.home_edit_challenge)
    val interactions = remember { MutableInteractionSource() }
    val tint = MorningTheme.modeAccent(alarm.mode, onYellow)
    Column(modifier.widthIn(min = if (stacked) 0.dp else 100.dp).morningPress(interactions)
        .clickable(interactionSource = interactions, indication = LocalIndication.current) { onEdit(alarm, AlarmEditorScope.CHALLENGE) }
        .semantics { role = Role.Button; contentDescription = editChallengeLabel }
        .padding(2.dp), horizontalAlignment = if (stacked) Alignment.Start else Alignment.End,
        verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Box(Modifier.size(40.dp).background(tint.copy(alpha = .13f), CircleShape), contentAlignment = Alignment.Center) {
            MovementChallengeIcon(alarm.challenge, alarm.seated, tint = tint, size = 28.dp)
        }
        Text(stringResource(challengeText(alarm.challenge)), style = MaterialTheme.typography.titleSmall, color = ink, maxLines = 2,
            overflow = TextOverflow.Ellipsis, textAlign = if (stacked) TextAlign.Start else TextAlign.End)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
            Icon(modeIcon(alarm.mode), contentDescription = null, tint = tint, modifier = Modifier.size(17.dp))
            Text(stringResource(modeText(alarm.mode)), style = MaterialTheme.typography.labelMedium, color = tint)
        }
    }
}

@Composable
private fun RecentWinsCard(entries: List<MorningEntry>, onProgress: () -> Unit) {
    val days = completedDays(entries, 7)
    Column(Modifier.fillMaxWidth().morningSurface(MorningTheme.colors.soft, radius = 22.dp, tint = MorningTheme.colors.yellow, elevated = false).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(stringResource(R.string.home_recent_wins), style = MaterialTheme.typography.titleMedium, color = MorningTheme.colors.ink)
        Text(if (days == 0) stringResource(R.string.no_recent_challenges) else stringResource(R.string.home_recent_count, days), style = MaterialTheme.typography.bodyLarge, color = MorningTheme.colors.ink)
        Text(stringResource(R.string.home_recent_note), style = MaterialTheme.typography.bodySmall, color = MorningTheme.colors.muted)
        if (days == 0) Text(stringResource(R.string.home_first_win), style = MaterialTheme.typography.bodyMedium, color = MorningTheme.colors.ink)
        TextButton(onClick = onProgress) { Text(stringResource(R.string.home_progress)) }
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
internal fun nextOccurrence(instant: Instant): String {
    val date = instant.atZone(ZoneId.systemDefault()).toLocalDate()
    val today = java.time.LocalDate.now()
    val time = occurrenceTimeText(LocalContext.current, instant)
    return when (date) {
        today -> stringResource(R.string.alarm_rings_today, time)
        today.plusDays(1) -> stringResource(R.string.alarm_rings_tomorrow, time)
        else -> stringResource(R.string.home_rings_at, time, DateTimeFormatter.ofPattern("EEE, MMM d", homeLocale()).format(date))
    }
}

@Composable
private fun homeLocale(): Locale {
    val locales = LocalConfiguration.current.locales
    return if (locales.size() == 0) Locale.US else locales[0]
}

private fun sameLocalDay(a: Long, b: Long): Boolean {
    val zone = ZoneId.systemDefault()
    return Instant.ofEpochMilli(a).atZone(zone).toLocalDate() == Instant.ofEpochMilli(b).atZone(zone).toLocalDate()
}
private fun completedDays(entries: List<MorningEntry>, days: Int): Int {
    val zone = ZoneId.systemDefault()
    val now = java.time.LocalDate.now(zone)
    val start = now.minusDays((days - 1).toLong())
    return entries.asSequence().filter { it.completedChallenge }
        .map { Instant.ofEpochMilli(it.date).atZone(zone).toLocalDate() }
        .filter { it >= start && it <= now }.distinct().count().toInt()
}
