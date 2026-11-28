package com.himorning.android.ui

import android.text.format.DateFormat
import android.view.ContextThemeWrapper
import android.widget.TimePicker
import android.widget.NumberPicker
import android.view.View
import android.view.ViewGroup
import androidx.compose.foundation.*
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.window.DialogWindowProvider
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.Role
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
import com.himorning.android.core.PushUpVariant
import com.himorning.android.core.WakeMode
import com.himorning.android.core.availableChallenges
import com.himorning.android.platform.AlarmScheduler
import com.himorning.android.platform.movementTarget

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
    val displayTime = alarmTimeText(context, alarm)
    var nativeTimePicker by remember { mutableStateOf<TimePicker?>(null) }
    var soundOpen by remember { mutableStateOf(false) }
    var challengeInfo by remember(draft) { mutableStateOf<Alarm?>(null) }
    var filter by remember(draft) { mutableStateOf(alarm.mode) }
    var confirmDelete by remember { mutableStateOf(false) }
    var chooseChallenge by remember(draft) { mutableStateOf(true) }
    val lifecycle = androidx.lifecycle.compose.LocalLifecycleOwner.current.lifecycle
    androidx.compose.runtime.DisposableEffect(lifecycle, draft) {
        val observer = androidx.lifecycle.LifecycleEventObserver { _, event ->
            if (event == androidx.lifecycle.Lifecycle.Event.ON_RESUME &&
                draft.saveError == R.string.alarm_permission_save && AlarmScheduler(context).canScheduleExactAlarms()) {
                draft.saveError = null
            }
        }
        lifecycle.addObserver(observer)
        onDispose { lifecycle.removeObserver(observer) }
    }
    val available = filter.availableChallenges()
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
            Box(Modifier.fillMaxSize().morningBackdrop()) {
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
                    if (scope != AlarmEditorScope.CHALLENGE) TimeHero(draft, showMorning = false, onPickerCreated = { nativeTimePicker = it })
                    if (scope != AlarmEditorScope.CHALLENGE) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
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
                    if (scope == AlarmEditorScope.ALL) HorizontalDivider(color = colors.line)
                    if (scope != AlarmEditorScope.SCHEDULE) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f)) {
                                Text(stringResource(R.string.composer_your_morning), color = colors.muted, style = MaterialTheme.typography.labelLarge)
                                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    Icon(challengeIcon(alarm.challenge, alarm.seated), null, tint = MorningTheme.modeAccent(alarm.mode), modifier = Modifier.size(24.dp))
                                    Text(stringResource(challengeText(alarm.challenge)), color = colors.ink, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold,
                                        minLines = if (LocalConfiguration.current.fontScale < 1.3f) 2 else 1)
                                }
                            }
                            val canPractice = alarm.challenge != ChallengeKind.NONE
                            TextButton(onClick = {
                                nativeTimePicker?.clearFocus(); nativeTimePicker?.rootView?.findFocus()?.clearFocus()
                                onPractice(draft.alarm)
                            }, enabled = canPractice, modifier = if (canPractice) Modifier else Modifier.alpha(0f).clearAndSetSemantics {}) {
                                Text(stringResource(R.string.composer_try))
                            }
                        }
                    }
                    if (scope == AlarmEditorScope.ALL) {
                        TextButton(onClick = { chooseChallenge = !chooseChallenge }) {
                            Text(stringResource(if (chooseChallenge) R.string.collapse_challenges else R.string.composer_change_challenge))
                        }
                    }
                    if (scope != AlarmEditorScope.SCHEDULE && chooseChallenge) {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            Text(stringResource(R.string.composer_challenge_level), color = colors.ink, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                listOf(WakeMode.GENTLE, WakeMode.BALANCED, WakeMode.FOCUSED).forEach { mode ->
                                    val selected = filter == mode
                                    val modeTint = MorningTheme.modeAccent(mode)
                                    val shape = RoundedCornerShape(22.dp)
                                    val modeInteractions = remember(mode) { MutableInteractionSource() }
                                    Column(Modifier.weight(1f).heightIn(min = 58.dp)
                                        .morningPress(modeInteractions, enabled = !draft.saving)
                                        .clip(shape).background(colors.surface)
                                        .border(if (selected) 2.dp else 1.dp, if (selected) modeTint else colors.line, shape)
                                        .clickable(interactionSource = modeInteractions, indication = null, enabled = !draft.saving, role = Role.Button) {
                                            filter = mode
                                        }.semantics { this.selected = selected }.padding(horizontal = 4.dp, vertical = 10.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                                        Icon(composerModeIcon(mode), null, tint = if (selected) modeTint else colors.muted, modifier = Modifier.size(22.dp))
                                        Text(stringResource(modeText(mode)), color = if (selected) colors.ink else colors.muted, fontSize = 12.sp, maxLines = 2, textAlign = TextAlign.Center)
                                    }
                                }
                            }
                        }
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            Text(stringResource(R.string.composer_first_win), color = colors.ink, style = MaterialTheme.typography.titleMedium, fontFamily = quicksandFont, fontWeight = FontWeight.SemiBold)
                            val oneColumn = LocalConfiguration.current.fontScale >= 1.3f
                            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                available.chunked(if (oneColumn) 1 else 2).forEach { rowKinds ->
                                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                        rowKinds.forEach { kind ->
                                            key(kind) {
                                                ChallengeCard(draft, kind, filter, Modifier.weight(1f), wide = rowKinds.size == 1, locked = isProChallenge(kind) && !fullAccess) {
                                                    challengeInfo = if (kind == alarm.challenge) alarm.copy(mode = filter) else alarm.copy(
                                                        challenge = kind, mode = filter, repetitions = filter.repetitions.coerceIn(1, 50),
                                                    )
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            if (alarm.challenge !in available) {
                                ChallengeCard(draft, alarm.challenge, filter, Modifier.fillMaxWidth(), wide = true, locked = isProChallenge(alarm.challenge) && !fullAccess) { challengeInfo = alarm }
                            }
                            if (alarm.challenge == ChallengeKind.PUSH_UPS) PushUpSettings(draft, fullAccess)
                            if (alarm.challenge == ChallengeKind.GUIDED_RHYTHM) {
                                ChoiceRow(stringResource(R.string.seated), alarm.seated) { draft.alarm = alarm.copy(seated = it) }
                            }
                            RequirementList(alarm)
                        }
                    }
                    Spacer(Modifier.height(14.dp))
                }
                Column(Modifier.fillMaxWidth().navigationBarsPadding().background(colors.canvas).padding(horizontal = 20.dp, vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    draft.saveError?.let { error ->
                        Text(stringResource(error), Modifier.fillMaxWidth(), color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                        if (error == R.string.alarm_permission_save) {
                            TextButton(onClick = {
                                runCatching { context.startActivity(AlarmScheduler(context).exactAlarmSettingsIntent()) }
                            }) { Text(stringResource(R.string.exact_alarm)) }
                        }
                    }
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
    challengeInfo?.let { details ->
        val cameraRequired = usesCamera(details.challenge)
        val tint = MorningTheme.modeAccent(details.mode)
        AlertDialog(
            onDismissRequest = { challengeInfo = null },
            icon = if (!cameraRequired) {
                {
                    Box(Modifier.background(tint.copy(alpha = .12f), CircleShape).padding(8.dp)) {
                        MovementChallengeIcon(details.challenge, details.seated, tint = tint, size = 28.dp)
                    }
                }
            } else null,
            title = {
                Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(stringResource(challengeText(details.challenge)), fontFamily = quicksandFont, fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center)
                    Row(
                        Modifier.background(tint.copy(alpha = .12f), RoundedCornerShape(50)).padding(horizontal = 10.dp, vertical = 5.dp),
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(composerModeIcon(details.mode), null, tint = tint, modifier = Modifier.size(14.dp))
                        Text(stringResource(modeText(details.mode)), style = MaterialTheme.typography.labelMedium, color = tint)
                    }
                }
            },
            text = {
                Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    if (isProChallenge(details.challenge) && !fullAccess) {
                        Column(
                            Modifier.fillMaxWidth().background(colors.soft, RoundedCornerShape(14.dp))
                                .border(1.dp, colors.yellow.copy(alpha = .4f), RoundedCornerShape(14.dp)).padding(12.dp),
                            verticalArrangement = Arrangement.spacedBy(6.dp),
                        ) {
                            ProLockBadge()
                            Text(stringResource(R.string.challenge_info_requires_pro), style = MaterialTheme.typography.bodyMedium, color = colors.ink)
                        }
                    }
                    if (cameraRequired) {
                        MovementMotionStage(kind = details.challenge, seated = details.seated)
                        Row(
                            Modifier.fillMaxWidth().background(colors.soft, RoundedCornerShape(14.dp)).padding(12.dp),
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            Icon(Icons.Outlined.CameraAlt, null, tint = tint, modifier = Modifier.size(18.dp))
                            Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                                Text(stringResource(R.string.challenge_info_camera_required), style = MaterialTheme.typography.labelLarge, color = tint)
                                Text(stringResource(challengeCameraFraming(details)), style = MaterialTheme.typography.bodySmall, color = colors.muted)
                            }
                        }
                    }
                    Text(stringResource(challengeInfoInstruction(details)), style = MaterialTheme.typography.bodyLarge, color = colors.ink)
                    if (cameraRequired) {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Icon(Icons.Outlined.AutoAwesome, null, tint = colors.muted, modifier = Modifier.size(18.dp))
                            Text(
                                stringResource(R.string.challenge_info_ai_count, movementTarget(details.challenge, details.repetitions)),
                                style = MaterialTheme.typography.bodyMedium,
                                color = colors.muted,
                            )
                        }
                    }
                }
            },
            confirmButton = { TextButton(onClick = { challengeInfo = null }) { Text(stringResource(R.string.done)) } },
            containerColor = colors.surface,
            titleContentColor = colors.ink,
        )
    }
    if (confirmDelete) AlertDialog(onDismissRequest = { confirmDelete = false }, title = { Text(stringResource(R.string.delete_alarm)) }, text = { Text(alarm.label.ifBlank { displayTime }) }, confirmButton = { TextButton(onClick = { confirmDelete = false; onDelete?.invoke() }) { Text(stringResource(R.string.delete)) } }, dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text(stringResource(R.string.cancel)) } })
}

@Composable private fun TimeHero(draft: AlarmEditorDraft, showMorning: Boolean, onPickerCreated: (TimePicker) -> Unit) {
    val colors = MorningTheme.colors
    val context = LocalContext.current
    val dark = isSystemInDarkTheme()
    Column(Modifier.fillMaxWidth().morningSurface(base = colors.surface.copy(alpha = .88f), radius = 32.dp, elevated = true).padding(18.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
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
                    MorningEmblem(draft.alarm.challenge, draft.alarm.seated, draft.alarm.mode)
                }
            }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable private fun ChallengeCard(draft: AlarmEditorDraft, kind: ChallengeKind, filter: WakeMode, modifier: Modifier, wide: Boolean, locked: Boolean, onInfo: () -> Unit) {
    val colors = MorningTheme.colors
    val selected = draft.alarm.challenge == kind
    val interactions = remember { MutableInteractionSource() }
    val legacy = kind == draft.alarm.challenge && kind !in filter.availableChallenges()
    val tint = MorningTheme.modeAccent(if (legacy) draft.alarm.mode else filter)
    val shape = RoundedCornerShape(24.dp)
    val title = stringResource(challengeText(kind))
    val cardTitle = if (legacy) stringResource(R.string.composer_saved_choice, title) else title
    val accessibleTitle = if (locked) stringResource(R.string.challenge_pro_accessibility, cardTitle) else cardTitle
    Box(modifier.fillMaxWidth().heightIn(min = if (wide) 70.dp else 124.dp)
        .morningPress(interactions)
        .clip(shape).background(colors.surface)
        .border(if (selected) 2.dp else 1.dp, when {
            selected -> tint
            locked -> colors.yellow.copy(alpha = .45f)
            else -> colors.line
        }, shape)) {
        Box(Modifier.matchParentSize()
            .clickable(interactionSource = interactions, indication = null, role = Role.Button) {
                if (locked) onInfo() else if (!selected) draft.alarm = draft.alarm.copy(
                    mode = filter, challenge = kind,
                    repetitions = if (kind == ChallengeKind.PUSH_UPS) filter.repetitions.coerceIn(1, 50) else draft.alarm.repetitions,
                )
            }.semantics {
                this.selected = selected
                contentDescription = accessibleTitle
            })
        val badge: @Composable () -> Unit = {
            Box(Modifier.size(40.dp).clip(RoundedCornerShape(13.dp)).background(tint.copy(alpha = .13f)), contentAlignment = Alignment.Center) {
                MovementChallengeIcon(kind, draft.alarm.seated, tint = tint, size = 26.dp, animated = false)
            }
        }
        val description: @Composable () -> Unit = {
            Column(verticalArrangement = Arrangement.spacedBy(if (wide) 4.dp else 8.dp)) {
            Text(cardTitle, color = colors.ink, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold,
                minLines = if (!wide && !legacy && LocalConfiguration.current.fontScale <= 1.15f) 2 else 1)
            val indicator = when {
                selected && !locked -> Icons.Outlined.CheckCircle to R.string.composer_challenge_selected
                kind == ChallengeKind.STRETCHING -> null to R.string.composer_free
                usesCamera(kind) -> Icons.Outlined.CameraAlt to R.string.composer_camera
                kind == ChallengeKind.READ_ALOUD -> Icons.Outlined.Mic to R.string.composer_microphone
                else -> null
            }
            Box(Modifier.heightIn(min = 16.dp)) {
                if (locked && wide) {
                    ProLockBadge(compact = true)
                } else if (indicator != null) Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                    indicator.first?.let { icon ->
                        Icon(icon, null, tint = if (selected) tint else colors.muted, modifier = Modifier.size(14.dp))
                    }
                    Text(stringResource(indicator.second), color = if (selected) tint else colors.muted, style = MaterialTheme.typography.labelSmall)
                }
            }
            }
        }
        val content = Modifier.fillMaxWidth().padding(start = 14.dp, end = if (wide) 52.dp else 14.dp, top = 12.dp, bottom = 12.dp)
            .clearAndSetSemantics {}
        if (wide) {
            Row(content.align(Alignment.CenterStart), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                badge()
                description()
            }
        } else {
            Column(content.align(Alignment.TopStart), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy(5.dp), verticalAlignment = Alignment.CenterVertically) {
                    badge()
                    if (locked) ProLockBadge(compact = true)
                }
                description()
            }
        }
        IconButton(onClick = onInfo, modifier = Modifier.align(if (wide) Alignment.CenterEnd else Alignment.TopEnd).padding(4.dp)) {
            Icon(Icons.Outlined.Info, stringResource(R.string.composer_challenge_info, stringResource(challengeText(kind))), tint = colors.muted, modifier = Modifier.size(17.dp))
        }
    }
}

private fun isProChallenge(kind: ChallengeKind): Boolean =
    kind == ChallengeKind.PUSH_UPS || kind == ChallengeKind.SQUATS || kind == ChallengeKind.JUMPING_JACKS

private fun usesCamera(kind: ChallengeKind): Boolean = when (kind) {
    ChallengeKind.PUSH_UPS, ChallengeKind.SQUATS, ChallengeKind.GUIDED_RHYTHM, ChallengeKind.WAVE_HAND,
    ChallengeKind.NECK_ROTATION, ChallengeKind.JUMPING_JACKS, ChallengeKind.STRETCHING,
    ChallengeKind.MORNING_LIGHT -> true
    else -> false
}

private fun challengeCameraFraming(alarm: Alarm): Int = when (alarm.challenge) {
    ChallengeKind.PUSH_UPS, ChallengeKind.SQUATS -> R.string.challenge_info_side_whole_body
    ChallengeKind.WAVE_HAND -> R.string.challenge_info_front_hand
    ChallengeKind.NECK_ROTATION -> R.string.challenge_info_front_face
    ChallengeKind.STRETCHING -> R.string.challenge_info_front_upper_body
    ChallengeKind.MORNING_LIGHT -> R.string.explore_badge_window_light
    ChallengeKind.GUIDED_RHYTHM ->
        if (alarm.seated) R.string.challenge_info_front_upper_body else R.string.challenge_info_side_whole_body
    else -> R.string.challenge_info_front_whole_body
}

private fun challengeInfoInstruction(alarm: Alarm): Int = when (alarm.challenge) {
    ChallengeKind.NONE -> R.string.requirement_none
    ChallengeKind.PUSH_UPS -> R.string.challenge_info_pushups
    ChallengeKind.SQUATS -> R.string.challenge_info_squats
    ChallengeKind.WAVE_HAND -> R.string.challenge_info_wave
    ChallengeKind.NECK_ROTATION -> R.string.challenge_info_neck
    ChallengeKind.JUMPING_JACKS -> R.string.challenge_info_jacks
    ChallengeKind.STRETCHING -> R.string.challenge_info_reach
    ChallengeKind.MORNING_LIGHT -> R.string.guide_morning_light
    ChallengeKind.GUIDED_RHYTHM -> if (alarm.seated) R.string.challenge_info_seated else R.string.challenge_info_standing
    ChallengeKind.READ_ALOUD -> R.string.challenge_info_read_aloud
    ChallengeKind.READ_AND_CHOOSE -> R.string.challenge_info_read_choose
    ChallengeKind.RIDDLE -> R.string.challenge_info_riddle
}

@Composable private fun PushUpSettings(draft: AlarmEditorDraft, fullAccess: Boolean) {
    val colors = MorningTheme.colors
    val alarm = draft.alarm
    val max = if (fullAccess) 50 else 5
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(stringResource(R.string.repetitions, alarm.repetitions), color = colors.ink, fontWeight = FontWeight.SemiBold)
                Text(stringResource(R.string.composer_pushup_preview), color = colors.muted, style = MaterialTheme.typography.bodySmall)
            }
            IconButton(onClick = { draft.alarm = alarm.copy(repetitions = (alarm.repetitions - 1).coerceAtLeast(1)) }, enabled = alarm.repetitions > 1) { Text("−", color = colors.ink, fontSize = 22.sp) }
            Text(alarm.repetitions.toString(), color = colors.ink, modifier = Modifier.widthIn(min = 24.dp), style = MaterialTheme.typography.titleMedium)
            IconButton(onClick = { draft.alarm = alarm.copy(repetitions = (alarm.repetitions + 1).coerceAtMost(max)) }, enabled = alarm.repetitions < max) { Text("+", color = colors.ink, fontSize = 22.sp) }
        }
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(stringResource(R.string.pushup_variant_label), color = colors.muted, style = MaterialTheme.typography.labelMedium)
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(
                    PushUpVariant.STANDARD to R.string.pushup_variant_standard,
                    PushUpVariant.INCLINE_OR_KNEE to R.string.pushup_variant_incline,
                ).forEach { (variant, labelRes) ->
                    val selected = alarm.pushUpVariant == variant
                    val chipShape = RoundedCornerShape(14.dp)
                    Box(
                        Modifier
                            .weight(1f)
                            .clip(chipShape)
                            .background(if (selected) colors.yellow.copy(alpha = 0.22f) else colors.surface)
                            .border(if (selected) 1.5.dp else 1.dp, if (selected) colors.accent else colors.line, chipShape)
                            .clickable(role = Role.Button) { draft.alarm = alarm.copy(pushUpVariant = variant) }
                            .padding(horizontal = 10.dp, vertical = 10.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            stringResource(labelRes),
                            color = if (selected) colors.ink else colors.muted,
                            style = MaterialTheme.typography.labelLarge,
                            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium,
                            textAlign = TextAlign.Center,
                        )
                    }
                }
            }
        }
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

@Composable
internal fun ChallengeCheckingGuide(alarm: Alarm) {
    val colors = MorningTheme.colors
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(stringResource(challengeCheckingGuide(alarm)), style = MaterialTheme.typography.bodyMedium, color = colors.ink)
        when {
            alarm.challenge == ChallengeKind.READ_ALOUD ->
                Text(stringResource(R.string.composer_microphone), color = colors.muted, style = MaterialTheme.typography.labelMedium)
            usesCamera(alarm.challenge) ->
                Text(stringResource(R.string.challenge_guide_camera), color = colors.muted, style = MaterialTheme.typography.labelMedium)
        }
    }
}

private fun challengeCheckingGuide(alarm: Alarm): Int = when (alarm.challenge) {
    ChallengeKind.PUSH_UPS -> R.string.challenge_guide_pushups
    ChallengeKind.SQUATS -> R.string.challenge_guide_squats
    ChallengeKind.WAVE_HAND -> R.string.challenge_guide_wave
    ChallengeKind.NECK_ROTATION -> R.string.challenge_guide_neck
    ChallengeKind.JUMPING_JACKS -> R.string.challenge_guide_jacks
    ChallengeKind.STRETCHING -> R.string.challenge_guide_reach
    ChallengeKind.MORNING_LIGHT -> R.string.challenge_guide_morning_light
    ChallengeKind.GUIDED_RHYTHM -> if (alarm.seated) R.string.challenge_guide_seated else R.string.challenge_guide_standing
    ChallengeKind.READ_ALOUD -> R.string.challenge_guide_words
    ChallengeKind.READ_AND_CHOOSE, ChallengeKind.RIDDLE -> R.string.challenge_guide_answer
    ChallengeKind.NONE -> R.string.requirement_none
}

@Composable private fun RequirementList(alarm: Alarm) {
    val colors = MorningTheme.colors
    val requirements = when (alarm.challenge) {
        ChallengeKind.NONE -> listOf(R.string.requirement_none)
        ChallengeKind.PUSH_UPS -> listOf(R.string.requirement_pushup_place, R.string.requirement_pushup_count)
        ChallengeKind.SQUATS -> listOf(R.string.requirement_body_view, R.string.requirement_squats_count)
        ChallengeKind.READ_AND_CHOOSE -> listOf(R.string.requirement_read_clues, R.string.requirement_choose_answer)
        ChallengeKind.RIDDLE -> listOf(R.string.requirement_solve_riddle, R.string.requirement_choose_answer)
        ChallengeKind.READ_ALOUD -> listOf(R.string.requirement_read_aloud, R.string.requirement_word_match)
        ChallengeKind.WAVE_HAND -> listOf(R.string.requirement_wave_view, R.string.requirement_wave_count)
        ChallengeKind.NECK_ROTATION -> listOf(R.string.requirement_face_view, R.string.requirement_neck_count)
        ChallengeKind.JUMPING_JACKS -> listOf(R.string.requirement_body_view, R.string.requirement_jacks_count)
        ChallengeKind.STRETCHING -> listOf(R.string.requirement_shoulders_view, R.string.requirement_stretch_count)
        ChallengeKind.MORNING_LIGHT -> listOf(R.string.guide_morning_light, R.string.requirement_morning_light_hold)
        ChallengeKind.GUIDED_RHYTHM -> if (alarm.seated) listOf(R.string.requirement_seated, R.string.requirement_seated_cycles) else listOf(R.string.requirement_standing, R.string.requirement_standing_cycles)
    }
    Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
        requirements.forEach { id ->
            val text = when (id) {
                R.string.requirement_pushup_count -> stringResource(id, alarm.repetitions)
                R.string.requirement_wave_count, R.string.requirement_neck_count, R.string.requirement_stretch_count -> stringResource(id, 3)
                R.string.requirement_jacks_count, R.string.requirement_squats_count -> stringResource(id, 10)
                else -> stringResource(id)
            }
            Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                Icon(Icons.Outlined.CheckCircle, null, tint = colors.accent, modifier = Modifier.size(16.dp))
                Text(text, color = colors.ink, style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}

@Composable private fun MorningEmblem(kind: ChallengeKind, seated: Boolean, mode: WakeMode) {
    val tint = MorningTheme.modeAccent(mode)
    Box(Modifier.size(92.dp), contentAlignment = Alignment.Center) {
        Box(Modifier.size(88.dp).border(1.dp, tint.copy(alpha = .22f), CircleShape))
        Box(Modifier.size(72.dp).border(1.dp, tint.copy(alpha = .3f), CircleShape).background(tint.copy(alpha = .1f), CircleShape))
        Box(Modifier.size(54.dp).background(tint.copy(alpha = .14f), CircleShape), contentAlignment = Alignment.Center) {
            MovementChallengeIcon(kind, seated, tint = tint, size = 34.dp)
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
