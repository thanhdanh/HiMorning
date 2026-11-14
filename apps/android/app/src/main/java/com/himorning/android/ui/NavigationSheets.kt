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
import androidx.compose.ui.Alignment
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
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
import kotlin.math.roundToInt

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
@Composable internal fun MorningSheet(title: String, onDismiss: () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    val colors = MorningTheme.colors
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = colors.canvas, contentColor = colors.ink, shape = RoundedCornerShape(topStart = 30.dp, topEnd = 30.dp),
        dragHandle = { BottomSheetDefaults.DragHandle(color = colors.muted.copy(alpha = .45f)) }) {
        MorningSystemBars()
        Row(Modifier.fillMaxWidth().padding(start = 20.dp, end = 12.dp, bottom = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
            MorningIconButton(Icons.Outlined.Close, stringResource(R.string.close), onDismiss)
        }
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(16.dp), content = content)
    }
}

@Composable internal fun PracticePicker(onChoose: (ChallengeKind) -> Unit) {
    val colors = MorningTheme.colors
    Text(stringResource(R.string.practice_note), color = colors.muted, style = MaterialTheme.typography.bodyMedium)
    ChallengeKind.entries.filter { it != ChallengeKind.NONE }.forEach { kind ->
        val interactions = remember(kind) { MutableInteractionSource() }
        Surface(onClick = { onChoose(kind) }, interactionSource = interactions, color = Color.Transparent, contentColor = colors.ink,
            shape = RoundedCornerShape(20.dp), modifier = Modifier.fillMaxWidth()
                .morningPress(interactions).morningSurface(colors.surface, radius = 20.dp, tint = challengeColor(kind), elevated = false)) {
            Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                Icon(challengeIcon(kind), null, tint = challengeColor(kind), modifier = Modifier.size(28.dp))
                Text(stringResource(challengeText(kind)), style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                Icon(Icons.Outlined.PlayCircleOutline, null, tint = colors.accent)
            }
        }
    }
}

@Composable internal fun PurposePicker(current: MorningFocus, full: Boolean, onChoose: (MorningFocus) -> Unit, onPro: () -> Unit) {
    val colors = MorningTheme.colors
    Text(stringResource(R.string.nav_purpose_question), style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.SemiBold)
    Text(stringResource(R.string.nav_purpose_note), color = colors.muted)
    MorningFocus.entries.forEach { focus ->
        val selected = current == focus
        val interactions = remember(focus) { MutableInteractionSource() }
        Surface(onClick = { if (focus == MorningFocus.ENERGIZE && !full) onPro() else onChoose(focus) },
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
                Icon(if (selected) Icons.Outlined.CheckCircle else if (focus == MorningFocus.ENERGIZE && !full) Icons.Outlined.Lock else Icons.Outlined.RadioButtonUnchecked, null, tint = colors.accent)
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

@Composable internal fun ProPreview(previewDays: Int, started: Boolean) {
    val colors = MorningTheme.colors
    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) { MorningSun(size = 120.dp) }
    Text(stringResource(R.string.nav_pro_title), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
    Text(if (!started) stringResource(R.string.preview_not_started) else if (previewDays > 0) stringResource(R.string.preview, previewDays) else stringResource(R.string.basic_access), color = colors.muted)
    Surface(color = Color.Transparent, contentColor = colors.ink, shape = RoundedCornerShape(24.dp),
        modifier = Modifier.fillMaxWidth().morningSurface(colors.soft, radius = 24.dp, tint = colors.yellow, elevated = false)) {
        Column(Modifier.fillMaxWidth().padding(20.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
            listOf(R.string.nav_pro_challenges, R.string.nav_pro_sounds, R.string.nav_pro_history).forEach { text ->
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Outlined.CheckCircle, null, tint = colors.accent)
                    Text(stringResource(text), modifier = Modifier.weight(1f))
                }
            }
        }
    }
    Text(stringResource(R.string.billing_unavailable), style = MaterialTheme.typography.bodySmall, color = colors.muted)
}

@Composable internal fun MorningProgress(state: AppState, full: Boolean, onGoal: (Int) -> Unit, onPro: () -> Unit) {
    val colors = MorningTheme.colors
    val context = LocalContext.current
    val locale = LocalConfiguration.current.locales[0]
    val zone = ZoneId.systemDefault()
    val today = LocalDate.now(zone)
    val successful = setOf(WakeOutcome.LOCAL_COMPLETED, WakeOutcome.AI_VERIFIED)
    val week = (6 downTo 0).map { today.minusDays(it.toLong()) }
    val byDay = state.entries.groupBy { Instant.ofEpochMilli(it.date).atZone(zone).toLocalDate() }
    val days = week.count { day -> byDay[day].orEmpty().any { it.outcome in successful } }
    val month = state.entries.filter { Instant.ofEpochMilli(it.date).atZone(zone).toLocalDate().withDayOfMonth(1) == today.withDayOfMonth(1) }
    val monthlyScore = if (month.isEmpty()) null else (100.0 * month.count { it.outcome in successful } / month.size).roundToInt()
    var selectedDay by remember { mutableStateOf(today) }
    if (!full) {
        Surface(color = Color.Transparent, shape = RoundedCornerShape(24.dp),
            modifier = Modifier.fillMaxWidth().morningSurface(colors.surface, radius = 24.dp, tint = colors.yellow, elevated = false)) {
            Column(Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Text(stringResource(R.string.basic_access), color = colors.ink)
                MorningButton(stringResource(R.string.nav_explore_pro), onPro)
            }
        }
        return
    }
    Surface(color = Color.Transparent, contentColor = colors.ink, shape = RoundedCornerShape(24.dp), border = androidx.compose.foundation.BorderStroke(1.dp, colors.line),
        modifier = Modifier.fillMaxWidth().morningSurface(colors.surface, radius = 24.dp, tint = colors.yellow, elevated = false)) {
        Column(Modifier.fillMaxWidth().padding(20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(stringResource(R.string.nav_this_month), style = MaterialTheme.typography.titleMedium)
                Text(today.format(DateTimeFormatter.ofPattern("MMMM yyyy", locale)), style = MaterialTheme.typography.bodySmall, color = colors.muted)
            }
            Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(monthlyScore?.toString() ?: "—", style = MaterialTheme.typography.displayMedium, fontWeight = FontWeight.Bold)
                Text(stringResource(R.string.nav_points), color = colors.muted, modifier = Modifier.padding(bottom = 10.dp))
            }
            LinearProgressIndicator(progress = { (monthlyScore ?: 0) / 100f }, color = colors.success, trackColor = colors.soft, modifier = Modifier.fillMaxWidth())
            Text(if (month.isEmpty()) stringResource(R.string.no_history) else stringResource(R.string.nav_month_completed, month.count { it.outcome in successful }, month.size), style = MaterialTheme.typography.bodyMedium)
        }
    }
    Surface(color = Color.Transparent, contentColor = colors.ink, shape = RoundedCornerShape(24.dp), border = androidx.compose.foundation.BorderStroke(1.dp, colors.line),
        modifier = Modifier.fillMaxWidth().morningSurface(colors.surface, radius = 24.dp, tint = colors.yellow, elevated = false)) {
        Column(Modifier.fillMaxWidth().padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Text(stringResource(R.string.nav_past_week), style = MaterialTheme.typography.titleMedium)
            if (LocalConfiguration.current.fontScale >= 1.3f) {
                week.forEach { date ->
                    val entries = byDay[date].orEmpty()
                    val score = if (entries.isEmpty()) null else (100.0 * entries.count { it.outcome in successful } / entries.size).roundToInt()
                    TextButton(onClick = { selectedDay = date }, modifier = Modifier.fillMaxWidth()) {
                        Text(date.format(DateTimeFormatter.ofPattern("EEE d MMM", locale)), modifier = Modifier.weight(1f))
                        Text(score?.let { "$it/100" } ?: "—")
                    }
                }
            } else Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                week.forEach { date ->
                    val entries = byDay[date].orEmpty()
                    val score = if (entries.isEmpty()) null else (100.0 * entries.count { it.outcome in successful } / entries.size).roundToInt()
                    TextButton(onClick = { selectedDay = date }, contentPadding = PaddingValues(0.dp), modifier = Modifier.weight(1f)) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(7.dp)) {
                            Text(score?.toString() ?: "—", style = MaterialTheme.typography.labelSmall)
                            Box(Modifier.height(56.dp).width(12.dp).background(colors.line, RoundedCornerShape(6.dp)), contentAlignment = Alignment.BottomCenter) {
                                if (score != null) Box(Modifier.height(maxOf(4f, score * .56f).dp).fillMaxWidth().background(if (score == 100) colors.success else colors.accent, RoundedCornerShape(6.dp)))
                            }
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
    Surface(color = Color.Transparent, contentColor = colors.ink, shape = RoundedCornerShape(24.dp),
        modifier = Modifier.fillMaxWidth().morningSurface(colors.soft, radius = 24.dp, tint = colors.yellow, elevated = false)) {
        Column(Modifier.fillMaxWidth().padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(stringResource(R.string.weekly_goal, state.weeklyGoal), style = MaterialTheme.typography.titleMedium)
            Text(stringResource(R.string.home_recent_count, days), color = colors.muted)
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
                MorningIconButton(Icons.Outlined.Remove, stringResource(R.string.nav_decrease_goal), { onGoal(state.weeklyGoal - 1) }, Modifier, enabled = state.weeklyGoal > 1)
                Text(state.weeklyGoal.toString(), style = MaterialTheme.typography.headlineMedium)
                MorningIconButton(Icons.Outlined.Add, stringResource(R.string.nav_increase_goal), { onGoal(state.weeklyGoal + 1) }, Modifier, enabled = state.weeklyGoal < 7)
            }
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
            entry.challenge?.let { Icon(challengeIcon(it), null, tint = challengeColor(it), modifier = Modifier.size(20.dp)); Text(stringResource(challengeText(it)), modifier = Modifier.weight(1f)) }
            Text(Instant.ofEpochMilli(entry.date).atZone(ZoneId.systemDefault()).format(DateTimeFormatter.ofPattern("HH:mm")), style = MaterialTheme.typography.labelMedium, color = colors.muted)
        }
        Text(stringResource(when (entry.outcome) { WakeOutcome.LOCAL_COMPLETED -> R.string.local_completed; WakeOutcome.AI_VERIFIED -> R.string.ai_verified; WakeOutcome.SELF_CONFIRMED -> R.string.self_confirmed; WakeOutcome.DISMISSED -> R.string.dismissed }), style = MaterialTheme.typography.bodySmall, color = colors.muted)
    }
}
