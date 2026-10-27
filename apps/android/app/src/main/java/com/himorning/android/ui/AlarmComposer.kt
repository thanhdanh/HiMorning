package com.himorning.android.ui

import android.text.format.DateFormat
import android.view.ContextThemeWrapper
import android.widget.TimePicker
import android.widget.NumberPicker
import android.view.View
import android.view.ViewGroup
import java.util.Calendar
import androidx.compose.foundation.*
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.compositeOver
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.window.DialogWindowProvider
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.himorning.android.R
import com.himorning.android.core.Alarm
import com.himorning.android.core.ChallengeKind
import com.himorning.android.core.WakeMode
import com.himorning.android.core.availableChallenges

enum class AlarmEditorScope { ALL, SCHEDULE, CHALLENGE }

/** Kept by the caller while the composer is temporarily hidden for practice. */
class AlarmEditorDraft(original: Alarm, scope: AlarmEditorScope = AlarmEditorScope.ALL) {
    val original = original
    var alarm by mutableStateOf(original)
    var scope by mutableStateOf(scope)
    var saving by mutableStateOf(false)
    var saveError by mutableStateOf<Int?>(null)
}

@Composable
fun AlarmComposer(
    draft: AlarmEditorDraft,
    existing: Boolean,
    fullAccess: Boolean,
    onDismiss: () -> Unit,
    onSave: (Alarm) -> Unit,
    onDelete: (() -> Unit)?,
    onPractice: (Alarm) -> Unit,
) {
    val colors = MorningTheme.colors
    val context = LocalContext.current
    val alarm = draft.alarm
    val displayTime = remember(alarm.hour, alarm.minute, context) {
        Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, alarm.hour)
            set(Calendar.MINUTE, alarm.minute)
            set(Calendar.SECOND, 0)
        }.let { DateFormat.getTimeFormat(context).format(it.time) }
    }
    var nativeTimePicker by remember { mutableStateOf<TimePicker?>(null) }
    var soundOpen by remember { mutableStateOf(false) }
    var confirmPractice by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }
    val available = alarm.mode.availableChallenges(draft.original.challenge.takeIf { existing && draft.original.mode == alarm.mode })
    val scope = draft.scope
    val dayLabels = listOf(R.string.day_mon, R.string.day_tue, R.string.day_wed, R.string.day_thu, R.string.day_fri, R.string.day_sat, R.string.day_sun)
    val systemDay = listOf(2, 3, 4, 5, 6, 7, 1)
    val title = when (scope) {
        AlarmEditorScope.SCHEDULE -> R.string.composer_edit_time
        AlarmEditorScope.CHALLENGE -> R.string.composer_change_challenge
        AlarmEditorScope.ALL -> if (existing) R.string.edit_alarm else R.string.composer_new_alarm
    }

    Dialog(onDismissRequest = { if (!draft.saving) onDismiss() }, properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)) {
        val dialogView = LocalView.current
        val dialogWindow = (dialogView.parent as? DialogWindowProvider)?.window
        SideEffect { dialogWindow?.setDimAmount(.18f) }
        Surface(Modifier.fillMaxSize().statusBarsPadding().padding(top = 16.dp), shape = RoundedCornerShape(topStart = 34.dp, topEnd = 34.dp), color = Color.Transparent) {
            MorningSystemBars()
            Box(Modifier.fillMaxSize().morningBackdrop(challengeColor(alarm.challenge))) {
            Column(Modifier.fillMaxSize().imePadding()) {
                Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).padding(horizontal = 18.dp), verticalAlignment = Alignment.CenterVertically) {
                    val cancelInteractions = remember { MutableInteractionSource() }
                    Row(Modifier.heightIn(min = 48.dp).morningPress(cancelInteractions, enabled = !draft.saving)
                        .morningSurface(colors.surface, radius = 50.dp, tint = colors.accent.copy(alpha = .08f), elevated = true)
                        .clickable(interactionSource = cancelInteractions, indication = null, enabled = !draft.saving, role = Role.Button, onClick = onDismiss)
                        .padding(horizontal = 20.dp, vertical = 12.dp)) {
                        Text(stringResource(R.string.cancel), style = MaterialTheme.typography.labelLarge, color = colors.accent)
                    }
                    Text(stringResource(title), Modifier.weight(1f), style = MaterialTheme.typography.titleMedium, color = colors.ink, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center)
                    Spacer(Modifier.width(68.dp))
                }
                Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 20.dp), verticalArrangement = Arrangement.spacedBy(22.dp)) {
                    if (scope != AlarmEditorScope.CHALLENGE) TimeHero(draft, showMorning = scope != AlarmEditorScope.SCHEDULE, onPickerCreated = { nativeTimePicker = it })
                    if (scope == AlarmEditorScope.ALL) HorizontalDivider(color = colors.line)
                    if (scope == AlarmEditorScope.CHALLENGE) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f)) {
                                Text(stringResource(R.string.composer_your_morning), color = colors.muted, style = MaterialTheme.typography.labelLarge)
                                Text(stringResource(challengeText(alarm.challenge)), color = colors.ink, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                                RequirementList(alarm)
                            }
                            MorningEmblem(alarm.challenge)
                        }
                    }
                    if (scope != AlarmEditorScope.SCHEDULE) {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            Text(stringResource(R.string.composer_challenge_level), color = colors.ink, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                listOf(WakeMode.GENTLE, WakeMode.BALANCED, WakeMode.FOCUSED).forEach { mode ->
                                    val selected = alarm.mode == mode
                                    val allowed = fullAccess || mode != WakeMode.FOCUSED
                                    val modeSurface by animateColorAsState(
                                        targetValue = if (selected) colors.yellow.copy(alpha = .30f) else colors.surface.copy(alpha = .82f),
                                        animationSpec = tween(170), label = "modeSurface",
                                    )
                                    val modeTint by animateColorAsState(if (selected) colors.yellow else colors.soft, tween(170), label = "modeTint")
                                    val modeInteractions = remember(mode) { MutableInteractionSource() }
                                    Column(Modifier.weight(1f).heightIn(min = 70.dp)
                                        .morningPress(modeInteractions, enabled = allowed && !draft.saving)
                                        .morningSurface(base = modeSurface, radius = 22.dp, tint = modeTint, elevated = true)
                                        .clickable(interactionSource = modeInteractions, indication = null, enabled = allowed && !draft.saving, role = Role.Button) {
                                            draft.alarm = alarm.copy(mode = mode, challenge = when (mode) {
                                                WakeMode.GENTLE -> ChallengeKind.NONE
                                                WakeMode.BALANCED -> ChallengeKind.READ_AND_CHOOSE
                                                WakeMode.FOCUSED -> ChallengeKind.PUSH_UPS
                                            }, repetitions = mode.repetitions.coerceIn(1, 50))
                                        }.semantics { this.selected = selected }.padding(horizontal = 4.dp, vertical = 10.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                                        Icon(composerModeIcon(mode), null, tint = if (selected) colors.accent else colors.muted, modifier = Modifier.size(22.dp))
                                        Text(stringResource(modeText(mode)), color = if (selected) colors.ink else colors.muted, fontSize = 12.sp, maxLines = 2, textAlign = TextAlign.Center)
                                    }
                                }
                            }
                            if (!fullAccess && alarm.mode == WakeMode.FOCUSED) Text(stringResource(R.string.preview_locked), color = colors.muted, style = MaterialTheme.typography.bodySmall)
                        }
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(stringResource(R.string.composer_first_win), Modifier.weight(1f), color = colors.ink, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                                Icon(Icons.Outlined.AutoAwesome, null, tint = colors.accent)
                            }
                            val oneColumn = LocalConfiguration.current.fontScale >= 1.3f
                            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                available.chunked(if (oneColumn) 1 else 2).forEach { rowKinds ->
                                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                        rowKinds.forEach { kind -> ChallengeCard(draft, kind, Modifier.weight(1f)) { confirmPractice = true } }
                                        if (!oneColumn && rowKinds.size == 1) Spacer(Modifier.weight(1f))
                                    }
                                }
                            }
                        if (alarm.challenge == ChallengeKind.PUSH_UPS) PushUpSettings(draft, fullAccess)
                            if (alarm.challenge == ChallengeKind.GUIDED_RHYTHM) {
                                ChoiceRow(stringResource(R.string.seated), alarm.seated) { draft.alarm = alarm.copy(seated = it) }
                            }
                        }
                    }
                    if (scope != AlarmEditorScope.CHALLENGE) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            Text(stringResource(R.string.composer_details), color = colors.ink, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                            Column(Modifier.fillMaxWidth().morningSurface(base = colors.surface.copy(alpha = .82f), radius = 22.dp, tint = colors.soft, elevated = true)) {
                                    if (scope == AlarmEditorScope.ALL) {
                                        val soundInteractions = remember { MutableInteractionSource() }
                                        Row(Modifier.fillMaxWidth().morningPress(soundInteractions).clickable(interactionSource = soundInteractions, indication = null) { soundOpen = true }.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                                            Icon(Icons.Outlined.MusicNote, null, tint = colors.accent)
                                            Text(stringResource(R.string.sound), Modifier.weight(1f).padding(start = 12.dp), color = colors.ink)
                                            Text(stringResource(soundText(alarm.sound)), color = colors.muted)
                                        }
                                        HorizontalDivider(color = colors.line.copy(alpha = .48f))
                                    }
                                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            Text(stringResource(R.string.repeat), Modifier.weight(1f), color = colors.ink)
                                            val daySummary = systemDay.filter { it in alarm.weekdays }.joinToString(", ") { context.getString(dayLabels[systemDay.indexOf(it)]) }
                                            Text(if (alarm.weekdays.isEmpty()) stringResource(R.string.composer_once) else if (alarm.weekdays.size == 7) stringResource(R.string.composer_every_day) else daySummary, color = colors.muted, style = MaterialTheme.typography.bodySmall)
                                        }
                                        BoxWithConstraints(Modifier.fillMaxWidth()) {
                                            val columns = if (maxWidth < 336.dp || LocalConfiguration.current.fontScale >= 1.3f) 4 else 7
                                            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                                dayLabels.indices.toList().chunked(columns).forEach { row ->
                                                    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                                        row.forEach { i ->
                                                            val label = dayLabels[i]
                                                            val day = systemDay[i]; val selected = day in alarm.weekdays
                                                            val dayInteractions = remember(day) { MutableInteractionSource() }
                                                            Box(Modifier.weight(1f).heightIn(min = 48.dp).morningPress(dayInteractions)
                                                                .clickable(interactionSource = dayInteractions, indication = null) { draft.alarm = alarm.copy(weekdays = if (selected) alarm.weekdays - day else alarm.weekdays + day) }
                                                                .semantics { contentDescription = context.getString(label); role = androidx.compose.ui.semantics.Role.Checkbox; this.selected = selected }, contentAlignment = Alignment.Center) {
                                                                Box(Modifier.size(34.dp).morningSurface(base = if (selected) colors.yellow.copy(alpha = .82f) else colors.soft, radius = 50.dp, tint = if (selected) colors.yellow else colors.line, elevated = false), contentAlignment = Alignment.Center) {
                                                                    Text(stringResource(label), color = if (selected) colors.onYellow else colors.muted, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold)
                                                                }
                                                            }
                                                        }
                                                        if (row.size < columns) repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    HorizontalDivider(color = colors.line.copy(alpha = .48f))
                                    Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                                        Text(stringResource(R.string.label), color = colors.ink)
                                        BasicTextField(value = alarm.label, onValueChange = { draft.alarm = alarm.copy(label = it.take(80)) }, modifier = Modifier.weight(1f).padding(start = 12.dp), textStyle = MaterialTheme.typography.bodyLarge.copy(color = colors.ink, textAlign = TextAlign.End), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Text), decorationBox = { inner -> if (alarm.label.isEmpty()) Text(stringResource(R.string.composer_optional_label), color = colors.muted); inner() })
                                    }
                            }
                            Text(stringResource(if (alarm.weekdays.isEmpty()) R.string.composer_rings_once else R.string.composer_local_time), color = colors.muted, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(horizontal = 4.dp))
                            if (existing && onDelete != null) TextButton(onClick = { confirmDelete = true }, enabled = !draft.saving) { Icon(Icons.Outlined.DeleteOutline, null); Text(stringResource(R.string.delete)) }
                        }
                    }
                    Spacer(Modifier.height(14.dp))
                }
                Column(Modifier.fillMaxWidth().navigationBarsPadding().background(Brush.verticalGradient(listOf(Color.Transparent, colors.canvas.copy(alpha = .72f), colors.canvas.copy(alpha = .91f)))).padding(horizontal = 20.dp, vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    draft.saveError?.let { Text(stringResource(it), Modifier.fillMaxWidth(), color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall) }
                    val saveInteractions = remember { MutableInteractionSource() }
                    Row(Modifier.fillMaxWidth().heightIn(min = 64.dp)
                        .morningPress(saveInteractions, enabled = !draft.saving)
                        .morningSurface(base = colors.yellow, radius = 50.dp, tint = colors.yellow, elevated = true)
                        .clickable(interactionSource = saveInteractions, indication = null, enabled = !draft.saving, role = Role.Button) {
                            nativeTimePicker?.clearFocus()
                            dialogView.rootView.findFocus()?.clearFocus()
                            draft.saveError = null
                            onSave(draft.alarm)
                        }.padding(horizontal = 20.dp, vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Outlined.Check, null, tint = colors.onYellow)
                            Text(stringResource(R.string.save), Modifier.padding(start = 10.dp), color = colors.onYellow, style = MaterialTheme.typography.titleMedium)
                            Spacer(Modifier.weight(1f))
                            if (scope != AlarmEditorScope.CHALLENGE) Text(displayTime, color = colors.onYellow, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                    }
                }
            }
            }
        }
    }
    if (soundOpen) AlarmSoundPicker(alarm.sound, fullAccess, onDismiss = { soundOpen = false }) { chosen -> draft.alarm = alarm.copy(sound = chosen); soundOpen = false }
    if (confirmPractice) AlertDialog(onDismissRequest = { confirmPractice = false }, title = { Text(stringResource(R.string.composer_try_challenge)) }, text = { Text(stringResource(challengeText(alarm.challenge))) }, confirmButton = { TextButton(onClick = { nativeTimePicker?.clearFocus(); nativeTimePicker?.rootView?.findFocus()?.clearFocus(); confirmPractice = false; onPractice(draft.alarm) }) { Text(stringResource(R.string.composer_try)) } }, dismissButton = { TextButton(onClick = { confirmPractice = false }) { Text(stringResource(R.string.cancel)) } })
    if (confirmDelete) AlertDialog(onDismissRequest = { confirmDelete = false }, title = { Text(stringResource(R.string.delete_alarm)) }, text = { Text(alarm.label.ifBlank { "%02d:%02d".format(alarm.hour, alarm.minute) }) }, confirmButton = { TextButton(onClick = { confirmDelete = false; onDelete?.invoke() }) { Text(stringResource(R.string.delete)) } }, dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text(stringResource(R.string.cancel)) } })
}

@Composable private fun TimeHero(draft: AlarmEditorDraft, showMorning: Boolean, onPickerCreated: (TimePicker) -> Unit) {
    val colors = MorningTheme.colors
    val context = LocalContext.current
    val dark = isSystemInDarkTheme()
    val tint = challengeColor(draft.alarm.challenge)
    Column(Modifier.fillMaxWidth().morningSurface(base = colors.surface.copy(alpha = .88f), radius = 32.dp, tint = tint, elevated = true).padding(18.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                MorningSunrise(size = 20.dp)
                Text(stringResource(R.string.composer_wakeup_time), Modifier.weight(1f).padding(start = 8.dp), color = colors.ink, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                Text(if (draft.alarm.weekdays.isEmpty()) stringResource(R.string.composer_once) else stringResource(R.string.composer_repeat), color = colors.muted, style = MaterialTheme.typography.labelSmall)
            }
            val textSizePx = with(LocalDensity.current) { 22.sp.toPx() }
            val wheelHeight = if (LocalConfiguration.current.fontScale >= 1.5f) 216.dp else 180.dp
            Box(Modifier.fillMaxWidth().height(wheelHeight), contentAlignment = Alignment.Center) {
                Box(Modifier.fillMaxWidth().height(if (LocalConfiguration.current.fontScale >= 1.5f) 48.dp else 36.dp)
                    .background(colors.ink.copy(alpha = .075f), RoundedCornerShape(50)))
                AndroidView(factory = { base ->
                    TimePicker(ContextThemeWrapper(base, if (dark) R.style.HiMorningSpinnerTimePickerDark else R.style.HiMorningSpinnerTimePicker)).apply {
                        setIs24HourView(DateFormat.is24HourFormat(context))
                        hour = draft.alarm.hour; minute = draft.alarm.minute
                        styleTimeWheel(this, textSizePx, colors.ink.toArgb())
                        setOnTimeChangedListener { _, h, m -> draft.alarm = draft.alarm.copy(hour = h, minute = m) }
                        onPickerCreated(this)
                    }
                }, update = { picker ->
                    if (picker.hour != draft.alarm.hour) picker.hour = draft.alarm.hour
                    if (picker.minute != draft.alarm.minute) picker.minute = draft.alarm.minute
                    styleTimeWheel(picker, textSizePx, colors.ink.toArgb())
                }, modifier = Modifier.fillMaxWidth().height(wheelHeight))
            }
            if (showMorning) {
                HorizontalDivider(color = colors.line.copy(alpha = .48f))
                Row(Modifier.padding(top = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(stringResource(R.string.composer_your_morning), color = colors.muted, style = MaterialTheme.typography.labelMedium)
                        Text(stringResource(if (draft.alarm.challenge == ChallengeKind.NONE) R.string.composer_gentle_start else challengeText(draft.alarm.challenge)), color = colors.ink, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                        RequirementList(draft.alarm)
                    }
                    MorningEmblem(draft.alarm.challenge)
                }
            }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable private fun ChallengeCard(draft: AlarmEditorDraft, kind: ChallengeKind, modifier: Modifier, practice: () -> Unit) {
    val colors = MorningTheme.colors
    val context = LocalContext.current
    val selected = draft.alarm.challenge == kind
    val interactions = remember { MutableInteractionSource() }
    val tint = challengeColor(kind)
    val cardTint by animateColorAsState(if (selected) tint else colors.soft, tween(170), label = "challengeTint")
    val cardBase by animateColorAsState(if (selected) tint.copy(alpha = .12f).compositeOver(colors.surface) else colors.surface.copy(alpha = .8f), tween(170), label = "challengeBase")
    val legacy = kind == draft.original.challenge && kind !in draft.alarm.mode.availableChallenges()
    Column(modifier.fillMaxWidth().heightIn(min = 142.dp)
        .morningPress(interactions)
        .morningSurface(base = cardBase, radius = 24.dp, tint = cardTint, elevated = true)
        .combinedClickable(interactionSource = interactions, indication = null, role = Role.Button, onClick = {
            draft.alarm = draft.alarm.copy(challenge = kind)
        }, onDoubleClick = { if (kind != ChallengeKind.NONE) { draft.alarm = draft.alarm.copy(challenge = kind); practice() } }).semantics {
            this.selected = selected
            if (kind != ChallengeKind.NONE) customActions = listOf(CustomAccessibilityAction(context.getString(R.string.composer_try_challenge)) {
                draft.alarm = draft.alarm.copy(challenge = kind); practice(); true
            })
        }.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(50.dp).clip(RoundedCornerShape(17.dp)).background(tint.copy(alpha = .13f)), contentAlignment = Alignment.Center) { Icon(challengeIcon(kind), null, tint = tint, modifier = Modifier.size(26.dp)) }
                Spacer(Modifier.weight(1f))
                if (selected) Icon(Icons.Outlined.CheckCircle, null, tint = tint, modifier = Modifier.size(24.dp))
            }
            Text(if (legacy) stringResource(R.string.composer_saved_choice, stringResource(challengeText(kind))) else stringResource(challengeText(kind)), color = colors.ink, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold, maxLines = 3)
            if (kind in setOf(ChallengeKind.PUSH_UPS, ChallengeKind.GUIDED_RHYTHM, ChallengeKind.WAVE_HAND, ChallengeKind.NECK_ROTATION, ChallengeKind.JUMPING_JACKS, ChallengeKind.STRETCHING)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                    Icon(Icons.Outlined.CameraAlt, null, tint = colors.muted, modifier = Modifier.size(14.dp))
                    Text(stringResource(R.string.composer_camera), color = colors.muted, style = MaterialTheme.typography.labelSmall)
                }
            }
        }
}

@Composable private fun PushUpSettings(draft: AlarmEditorDraft, fullAccess: Boolean) {
    val colors = MorningTheme.colors
    val alarm = draft.alarm
    val max = if (fullAccess) 50 else 5
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(stringResource(R.string.repetitions, alarm.repetitions), color = colors.ink, fontWeight = FontWeight.SemiBold)
            Text(stringResource(R.string.composer_pushup_preview), color = colors.muted, style = MaterialTheme.typography.bodySmall)
        }
        IconButton(onClick = { draft.alarm = alarm.copy(repetitions = (alarm.repetitions - 1).coerceAtLeast(1)) }, enabled = alarm.repetitions > 1) { Text("−", color = colors.ink, fontSize = 22.sp) }
        Text(alarm.repetitions.toString(), color = colors.ink, modifier = Modifier.widthIn(min = 24.dp), style = MaterialTheme.typography.titleMedium)
        IconButton(onClick = { draft.alarm = alarm.copy(repetitions = (alarm.repetitions + 1).coerceAtMost(max)) }, enabled = alarm.repetitions < max) { Text("+", color = colors.ink, fontSize = 22.sp) }
    }
}

@Composable private fun ChoiceRow(label: String, selected: Boolean, onClick: (Boolean) -> Unit) {
    val colors = MorningTheme.colors
    Row(Modifier.fillMaxWidth().clickable { onClick(!selected) }.padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(label, Modifier.weight(1f), color = colors.ink)
        Switch(selected, onCheckedChange = onClick)
    }
}

private fun composerModeIcon(mode: WakeMode): ImageVector = when (mode) {
    WakeMode.GENTLE -> Icons.Outlined.Eco
    WakeMode.BALANCED -> Icons.Outlined.WbSunny
    WakeMode.FOCUSED -> Icons.Outlined.Bolt
}

@Composable private fun RequirementList(alarm: Alarm) {
    val colors = MorningTheme.colors
    val requirements = when (alarm.challenge) {
        ChallengeKind.NONE -> listOf(R.string.requirement_none)
        ChallengeKind.PUSH_UPS -> listOf(R.string.requirement_pushup_place, R.string.requirement_pushup_count)
        ChallengeKind.READ_AND_CHOOSE -> listOf(R.string.requirement_read_clues, R.string.requirement_choose_answer)
        ChallengeKind.RIDDLE -> listOf(R.string.requirement_solve_riddle, R.string.requirement_choose_answer)
        ChallengeKind.READ_ALOUD -> listOf(R.string.requirement_read_aloud, R.string.requirement_word_match)
        ChallengeKind.WAVE_HAND -> listOf(R.string.requirement_wave_view, R.string.requirement_wave_count)
        ChallengeKind.NECK_ROTATION -> listOf(R.string.requirement_face_view, R.string.requirement_neck_count)
        ChallengeKind.JUMPING_JACKS -> listOf(R.string.requirement_body_view, R.string.requirement_jacks_count)
        ChallengeKind.STRETCHING -> listOf(R.string.requirement_shoulders_view, R.string.requirement_stretch_count)
        ChallengeKind.GUIDED_RHYTHM -> if (alarm.seated) listOf(R.string.requirement_seated, R.string.requirement_seated_cycles) else listOf(R.string.requirement_standing, R.string.requirement_standing_cycles)
    }
    Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
        requirements.forEach { id ->
            val text = when (id) {
                R.string.requirement_pushup_count -> stringResource(id, alarm.repetitions)
                R.string.requirement_wave_count, R.string.requirement_neck_count, R.string.requirement_stretch_count -> stringResource(id, 3)
                R.string.requirement_jacks_count -> stringResource(id, 10)
                else -> stringResource(id)
            }
            Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                Icon(Icons.Outlined.CheckCircle, null, tint = colors.accent, modifier = Modifier.size(16.dp))
                Text(text, color = colors.ink, style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}

@Composable private fun MorningEmblem(kind: ChallengeKind) {
    val tint = challengeColor(kind)
    Box(Modifier.size(92.dp), contentAlignment = Alignment.Center) {
        Box(Modifier.size(88.dp).border(1.dp, tint.copy(alpha = .22f), CircleShape))
        Box(Modifier.size(72.dp).border(1.dp, tint.copy(alpha = .3f), CircleShape).background(tint.copy(alpha = .1f), CircleShape))
        Box(Modifier.size(54.dp).background(tint.copy(alpha = .14f), CircleShape), contentAlignment = Alignment.Center) {
            Icon(challengeIcon(kind), null, tint = tint, modifier = Modifier.size(32.dp))
        }
        Icon(Icons.Outlined.AutoAwesome, null, tint = tint, modifier = Modifier.size(17.dp).align(Alignment.TopEnd))
        Icon(Icons.Outlined.AutoAwesome, null, tint = tint.copy(alpha = .6f), modifier = Modifier.size(10.dp).align(Alignment.BottomStart))
    }
}

private fun styleTimeWheel(view: View, textSizePx: Float, textColor: Int) {
    if (view is NumberPicker) {
        if (view.textSize != textSizePx) view.textSize = textSizePx
        if (view.textColor != textColor) view.textColor = textColor
        view.selectionDividerHeight = 0
    }
    if (view is ViewGroup) for (index in 0 until view.childCount) styleTimeWheel(view.getChildAt(index), textSizePx, textColor)
}
