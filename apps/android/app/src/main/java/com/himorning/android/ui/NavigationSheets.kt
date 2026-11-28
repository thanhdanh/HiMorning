package com.himorning.android.ui

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.Alignment
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.DialogWindowProvider
import androidx.core.view.WindowCompat
import com.himorning.android.R
import com.himorning.android.core.*
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter

@Composable internal fun MorningSystemBars() {
    val dark = isSystemInDarkTheme()
    val view = LocalView.current
    val activity = LocalContext.current.activity()
    val window = (view.parent as? DialogWindowProvider)?.window ?: activity?.window
    SideEffect {
        window?.let {
            WindowCompat.getInsetsController(it, view).apply {
                isAppearanceLightStatusBars = !dark
                isAppearanceLightNavigationBars = !dark
            }
            it.isStatusBarContrastEnforced = false
            it.isNavigationBarContrastEnforced = false
        }
    }
}
private tailrec fun Context.activity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.activity()
    else -> null
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable internal fun MorningSheet(
    title: String,
    onDismiss: () -> Unit,
    titleStyle: TextStyle = MaterialTheme.typography.titleLarge,
    content: @Composable ColumnScope.() -> Unit,
) {
    val colors = MorningTheme.colors
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = colors.canvas, contentColor = colors.ink, shape = RoundedCornerShape(topStart = 30.dp, topEnd = 30.dp),
        dragHandle = { BottomSheetDefaults.DragHandle(color = colors.muted.copy(alpha = .45f)) }) {
        MorningSystemBars()
        Row(Modifier.fillMaxWidth().padding(start = 20.dp, end = 12.dp, bottom = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(title, style = titleStyle, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
            MorningIconButton(Icons.Outlined.Close, stringResource(R.string.close), onDismiss)
        }
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(16.dp), content = content)
    }
}

@Composable internal fun PracticePicker(onChoose: (ChallengeKind) -> Unit) {
    val colors = MorningTheme.colors
    Text(stringResource(R.string.explore_subtitle), color = colors.muted, style = MaterialTheme.typography.bodyMedium)
    val categories = listOf(
        R.string.explore_category_camera_free to listOf(
            ChallengeKind.READ_AND_CHOOSE, ChallengeKind.RIDDLE, ChallengeKind.READ_ALOUD, ChallengeKind.NONE,
        ),
        R.string.explore_category_gentle_camera to listOf(
            ChallengeKind.MORNING_LIGHT, ChallengeKind.WAVE_HAND, ChallengeKind.NECK_ROTATION, ChallengeKind.GUIDED_RHYTHM,
        ),
        R.string.explore_category_active_movement to listOf(
            ChallengeKind.PUSH_UPS, ChallengeKind.SQUATS, ChallengeKind.JUMPING_JACKS, ChallengeKind.STRETCHING,
        ),
    )
    categories.forEach { (titleRes, kinds) ->
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(stringResource(titleRes), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold, color = colors.ink)
            kinds.forEach { kind ->
                val tint = MorningTheme.modeAccent(preferredMode(kind))
                val interactions = remember(kind) { MutableInteractionSource() }
                Surface(
                    onClick = { onChoose(kind) },
                    interactionSource = interactions,
                    color = Color.Transparent,
                    contentColor = colors.ink,
                    shape = RoundedCornerShape(MorningTheme.Radius.card),
                    modifier = Modifier
                        .fillMaxWidth()
                        .morningPress(interactions)
                        .morningSurface(colors.surface, radius = MorningTheme.Radius.card, elevated = false, borderColor = colors.line),
                ) {
                    Row(
                        Modifier.padding(14.dp),
                        verticalAlignment = Alignment.Top,
                        horizontalArrangement = Arrangement.spacedBy(14.dp),
                    ) {
                        Box(
                            Modifier
                                .size(42.dp)
                                .clip(RoundedCornerShape(12.dp))
                                .background(tint.copy(alpha = 0.12f)),
                            contentAlignment = Alignment.Center,
                        ) {
                            MovementChallengeIcon(kind, tint = tint, size = 24.dp, animated = true)
                        }
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Row(
                                Modifier.fillMaxWidth(),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                Text(
                                    stringResource(challengeText(kind)),
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.SemiBold,
                                    color = colors.ink,
                                    modifier = Modifier.weight(1f),
                                )
                                Text(
                                    stringResource(practiceMethod(kind)),
                                    style = MaterialTheme.typography.labelSmall,
                                    fontWeight = FontWeight.SemiBold,
                                    color = colors.muted,
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(50))
                                        .background(colors.soft)
                                        .padding(horizontal = 8.dp, vertical = 4.dp),
                                )
                            }
                            Text(
                                stringResource(exploreSummary(kind)),
                                style = MaterialTheme.typography.bodySmall,
                                color = colors.muted,
                            )
                        }
                    }
                }
            }
        }
    }
}

private fun exploreSummary(kind: ChallengeKind): Int = when (kind) {
    ChallengeKind.NONE -> R.string.explore_summary_none
    ChallengeKind.PUSH_UPS -> R.string.explore_summary_push_ups
    ChallengeKind.SQUATS -> R.string.explore_summary_squats
    ChallengeKind.READ_AND_CHOOSE -> R.string.explore_summary_read_and_choose
    ChallengeKind.GUIDED_RHYTHM -> R.string.explore_summary_guided_rhythm
    ChallengeKind.READ_ALOUD -> R.string.explore_summary_read_aloud
    ChallengeKind.WAVE_HAND -> R.string.explore_summary_wave_hand
    ChallengeKind.NECK_ROTATION -> R.string.explore_summary_neck_rotation
    ChallengeKind.RIDDLE -> R.string.explore_summary_riddle
    ChallengeKind.JUMPING_JACKS -> R.string.explore_summary_jumping_jacks
    ChallengeKind.STRETCHING -> R.string.explore_summary_stretching
    ChallengeKind.MORNING_LIGHT -> R.string.explore_summary_morning_light
}

@Composable internal fun PurposePicker(current: MorningFocus, onChoose: (MorningFocus) -> Unit) {
    val colors = MorningTheme.colors
    Text(stringResource(R.string.nav_purpose_question), style = MaterialTheme.typography.headlineSmall, fontFamily = quicksandFont, fontWeight = FontWeight.SemiBold)
    Text(stringResource(R.string.nav_purpose_note), color = colors.muted)
    MorningFocus.entries.forEach { focus ->
        val selected = current == focus
        val interactions = remember(focus) { MutableInteractionSource() }
        Surface(onClick = { onChoose(focus) },
            interactionSource = interactions, color = Color.Transparent, contentColor = colors.ink,
            shape = RoundedCornerShape(22.dp), border = androidx.compose.foundation.BorderStroke(1.dp, if (selected) colors.accent else colors.line),
            modifier = Modifier.morningPress(interactions).morningSurface(if (selected) colors.yellow.copy(alpha = .22f) else colors.surface,
                radius = 22.dp, tint = if (selected) colors.yellow else Color.Transparent, elevated = false)) {
            Row(Modifier.fillMaxWidth().padding(18.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Icon(when (focus) { MorningFocus.CLEAR_START -> Icons.Outlined.Lightbulb; MorningFocus.GENTLE_MOVEMENT -> Icons.Outlined.WavingHand; MorningFocus.FIND_YOUR_VOICE -> Icons.Outlined.ChatBubbleOutline; MorningFocus.ENERGIZE -> Icons.Outlined.FitnessCenter }, null, tint = colors.accent)
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(stringResource(focusText(focus)), style = MaterialTheme.typography.titleMedium)
                    Text(stringResource(when (focus) { MorningFocus.CLEAR_START -> R.string.nav_focus_clear; MorningFocus.GENTLE_MOVEMENT -> R.string.nav_focus_gentle; MorningFocus.FIND_YOUR_VOICE -> R.string.nav_focus_voice; MorningFocus.ENERGIZE -> R.string.nav_focus_energy }), style = MaterialTheme.typography.bodySmall, color = colors.muted)
                }
                Icon(if (selected) Icons.Outlined.CheckCircle else Icons.Outlined.RadioButtonUnchecked, null, tint = colors.accent)
            }
        }
    }
}

@Composable internal fun LanguagePicker(current: AppLanguage, onChoose: (AppLanguage) -> Unit) {
    val colors = MorningTheme.colors
    AppLanguage.entries.forEach { language ->
        val interactions = remember(language) { MutableInteractionSource() }
        Surface(onClick = { onChoose(language) }, interactionSource = interactions, color = Color.Transparent, contentColor = colors.ink,
            shape = RoundedCornerShape(18.dp), modifier = Modifier.fillMaxWidth()
                .morningPress(interactions).morningSurface(colors.surface, radius = 18.dp, tint = colors.yellow, elevated = false)) {
            Row(Modifier.fillMaxWidth().padding(18.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(when (language) { AppLanguage.SYSTEM -> R.string.language_system; AppLanguage.ENGLISH -> R.string.language_en; AppLanguage.VIETNAMESE -> R.string.language_vi }), modifier = Modifier.weight(1f))
                if (current == language) Icon(Icons.Outlined.Check, null, tint = colors.accent)
            }
        }
    }
}

@Composable internal fun MorningProgress(state: AppState, onGoal: (Int) -> Unit) {
    val colors = MorningTheme.colors
    val context = LocalContext.current
    val locale = LocalConfiguration.current.locales[0]
    val zone = ZoneId.systemDefault()
    val today = LocalDate.now(zone)
    val week = (6 downTo 0).map { today.minusDays(it.toLong()) }
    val byDay = state.entries.groupBy { Instant.ofEpochMilli(it.date).atZone(zone).toLocalDate() }
    val days = week.count { day -> byDay[day].orEmpty().any { it.completedChallenge } }
    val weekStart = today.with(java.time.temporal.TemporalAdjusters.previousOrSame(java.time.temporal.WeekFields.of(locale).firstDayOfWeek))
    val daysThisWeek = week.count { day -> day >= weekStart && byDay[day].orEmpty().any { it.completedChallenge } }
    var selectedDay by remember { mutableStateOf(today) }
    Surface(color = Color.Transparent, contentColor = colors.ink, shape = RoundedCornerShape(24.dp),
        modifier = Modifier.fillMaxWidth().morningSurface(colors.soft, radius = 24.dp, tint = colors.yellow, elevated = false)) {
        Column(Modifier.fillMaxWidth().padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(stringResource(R.string.home_week_goal, daysThisWeek, state.weeklyGoal), style = MaterialTheme.typography.titleMedium)
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
                MorningIconButton(Icons.Outlined.Remove, stringResource(R.string.nav_decrease_goal), { onGoal(state.weeklyGoal - 1) }, Modifier, enabled = state.weeklyGoal > 1)
                Text(state.weeklyGoal.toString(), style = MaterialTheme.typography.headlineMedium)
                MorningIconButton(Icons.Outlined.Add, stringResource(R.string.nav_increase_goal), { onGoal(state.weeklyGoal + 1) }, Modifier, enabled = state.weeklyGoal < 7)
            }
        }
    }
    Surface(color = Color.Transparent, contentColor = colors.ink, shape = RoundedCornerShape(24.dp), border = androidx.compose.foundation.BorderStroke(1.dp, colors.line),
        modifier = Modifier.fillMaxWidth().morningSurface(colors.surface, radius = 24.dp, tint = colors.yellow, elevated = false)) {
        Column(Modifier.fillMaxWidth().padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Text(stringResource(R.string.nav_past_week), style = MaterialTheme.typography.titleMedium)
            val largeText = LocalConfiguration.current.fontScale >= 1.3f
            if (largeText) {
                week.forEach { date ->
                    val done = byDay[date].orEmpty().any { it.completedChallenge }
                    TextButton(onClick = { selectedDay = date }, modifier = Modifier.fillMaxWidth()) {
                        Text(date.format(DateTimeFormatter.ofPattern("EEE d MMM", locale)), modifier = Modifier.weight(1f))
                        if (done) Icon(Icons.Outlined.CheckCircle, stringResource(R.string.completed), tint = colors.success)
                    }
                }
            } else Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                week.forEach { date ->
                    val done = byDay[date].orEmpty().any { it.completedChallenge }
                    TextButton(onClick = { selectedDay = date }, contentPadding = PaddingValues(0.dp), modifier = Modifier.weight(1f)) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(7.dp)) {
                            if (done) Icon(Icons.Outlined.CheckCircle, stringResource(R.string.completed), tint = colors.success, modifier = Modifier.size(18.dp))
                            else Box(Modifier.size(18.dp), contentAlignment = Alignment.Center) { Text("–", color = colors.muted) }
                            Text(date.format(DateTimeFormatter.ofPattern("EEE", locale)), style = MaterialTheme.typography.labelSmall)
                        }
                    }
                }
            }
            HorizontalDivider(color = colors.line)
            Text(selectedDay.format(DateTimeFormatter.ofPattern("EEEE, d MMM", locale)), style = MaterialTheme.typography.titleMedium)
            if (byDay[selectedDay].isNullOrEmpty()) Text(stringResource(R.string.no_history), color = colors.muted, style = MaterialTheme.typography.bodyMedium)
            else byDay[selectedDay].orEmpty().forEach { entry -> ProgressEntry(entry) }
        }
    }
    var expanded by remember { mutableStateOf(false) }
    Surface(color = Color.Transparent, contentColor = colors.ink, shape = RoundedCornerShape(24.dp),
        modifier = Modifier.fillMaxWidth().morningSurface(colors.surface, radius = 24.dp, tint = colors.yellow, elevated = false)) {
        Column(Modifier.fillMaxWidth().padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            TextButton(onClick = { expanded = !expanded }) {
                Text(stringResource(R.string.nav_past_month), style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                Icon(if (expanded) Icons.Outlined.ExpandLess else Icons.Outlined.ExpandMore, null)
            }
            if (expanded) if (state.entries.isEmpty()) Text(stringResource(R.string.no_history), color = colors.muted)
            else state.entries.sortedByDescending { it.date }.forEach { ProgressEntry(it) }
        }
    }
    MorningButton(stringResource(R.string.nav_share_progress), {
        val text = context.getString(R.string.home_recent_count, days)
        context.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply { type = "text/plain"; putExtra(Intent.EXTRA_TEXT, text) }, null))
    }, primary = false, leadingIcon = Icons.Outlined.Share)
}

@Composable private fun ProgressEntry(entry: MorningEntry) {
    val colors = MorningTheme.colors
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            entry.challenge?.let {
                Icon(challengeIcon(it), null, tint = MorningTheme.modeAccent(entry.mode ?: preferredMode(it)), modifier = Modifier.size(20.dp))
                Text(stringResource(challengeText(it)), modifier = Modifier.weight(1f))
            }
            Text(occurrenceTimeText(LocalContext.current, Instant.ofEpochMilli(entry.date)), style = MaterialTheme.typography.labelMedium, color = colors.muted)
        }
        Text(stringResource(when (entry.outcome) { WakeOutcome.LOCAL_COMPLETED -> R.string.local_completed; WakeOutcome.AI_VERIFIED -> R.string.ai_verified; WakeOutcome.SELF_CONFIRMED -> R.string.self_confirmed; WakeOutcome.DISMISSED -> R.string.dismissed }), style = MaterialTheme.typography.bodySmall, color = colors.muted)
    }
}
