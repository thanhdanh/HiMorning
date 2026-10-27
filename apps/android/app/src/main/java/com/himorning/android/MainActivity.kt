package com.himorning.android

import android.Manifest
import android.app.NotificationManager
import android.app.TimePickerDialog
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.speech.tts.TextToSpeech
import androidx.activity.ComponentActivity
import androidx.activity.enableEdgeToEdge
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.contentDescription
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.himorning.android.core.*
import com.himorning.android.platform.*
import com.himorning.android.ui.*
import java.text.DateFormatSymbols
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import java.util.UUID
import kotlin.math.roundToInt

class MainActivity : ComponentActivity() {
    override fun attachBaseContext(base: Context) {
        val language = runCatching { AppRepository(base).state.language }.getOrDefault(AppLanguage.SYSTEM)
        val locale = when (language) { AppLanguage.ENGLISH -> Locale.ENGLISH; AppLanguage.VIETNAMESE -> Locale.forLanguageTag("vi"); AppLanguage.SYSTEM -> android.content.res.Resources.getSystem().configuration.locales[0] }
        val config = Configuration(base.resources.configuration).apply { setLocale(locale) }
        super.attachBaseContext(base.createConfigurationContext(config))
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            HiMorningTheme {
                MorningSystemBars()
                Surface(Modifier.fillMaxSize(), color = MorningTheme.colors.canvas) { HiMorning() }
            }
        }
    }
}

@Composable private fun HiMorning() {
    val base = LocalContext.current
    var attempt by remember { mutableIntStateOf(0) }
    val result = remember(attempt) { runCatching { AppRepository(base) } }
    val repo = result.getOrNull()
    if (repo == null) {
        Column(Modifier.safeDrawingPadding().padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Text(stringResource(R.string.data_error))
            MorningButton(stringResource(R.string.retry), { attempt++ })
        }
        return
    }
    var state by remember { mutableStateOf(repo.state) }
    var error by remember { mutableStateOf(false) }
    var previewDays by remember { mutableIntStateOf(30) }
    val refresh = {
        runCatching { previewDays = repo.remainingPreviewDays(); state = repo.state }.onFailure { error = true }
        Unit
    }
    AppContent(repo, state, previewDays, error, { error = false }, refresh, { error = true })
    LaunchedEffect(Unit) { refresh() }
    LaunchedEffect(state.previewStartedAt) {
        state.previewStartedAt?.let { started ->
            val remaining = (started + 30L * 86_400_000 - maxOf(System.currentTimeMillis(), state.previewLastSeenAt ?: started)).coerceAtLeast(0)
            kotlinx.coroutines.delay(remaining + 1)
            refresh()
        }
    }
}

private enum class HomeSheet { PROGRESS, PRO, LANGUAGE, PURPOSE, EXPLORE, PLAN }

@Composable private fun AppContent(repo: AppRepository, state: AppState, previewDays: Int, error: Boolean, clearError: () -> Unit, refresh: () -> Unit, showError: () -> Unit) {
    val context = LocalContext.current
    val scheduler = remember { AlarmScheduler(context) }
    val catalog = remember { ContentCatalog(context) }
    val uiPreferences = remember(context) { context.getSharedPreferences("morning-ui", Context.MODE_PRIVATE) }
    var purposeChosen by remember { mutableStateOf(uiPreferences.getBoolean("purpose_chosen", false)) }
    val hasPurpose = purposeChosen || state.entries.isNotEmpty() || state.journey.focus != MorningFocus.CLEAR_START || state.journey.completions.isNotEmpty() || state.journey.completedJourneys > 0
    var sheet by remember { mutableStateOf<HomeSheet?>(null) }
    var editor by remember { mutableStateOf<AlarmEditorDraft?>(null) }
    var selected by remember { mutableStateOf<Alarm?>(null) }
    var practice by remember { mutableStateOf(true) }
    var deleting by remember { mutableStateOf<Alarm?>(null) }
    var restarting by remember { mutableStateOf(false) }
    val homeState = androidx.compose.runtime.saveable.rememberSaveableStateHolder()
    val activeId by RingingService.activeAlarmId.collectAsState()
    val owner = LocalLifecycleOwner.current
    DisposableEffect(owner) {
        val observer = LifecycleEventObserver { _, event -> if (event == Lifecycle.Event.ON_RESUME) { RingingService.restoreState(context); refresh() } }
        owner.lifecycle.addObserver(observer)
        onDispose { owner.lifecycle.removeObserver(observer) }
    }
    LaunchedEffect(Unit) {
        if (!scheduler.canScheduleExactAlarms()) {
            runCatching { repo.state.alarms.filter { it.enabled }.forEach { repo.updateAlarmState(it.id, ScheduleState.NEEDS_REVIEW) } }.onFailure { showError() }
        }
        RingingService.restoreState(context)
        refresh()
    }
    LaunchedEffect(activeId) {
        refresh()
        activeId?.let { id -> repo.state.alarms.firstOrNull { it.id == id }?.let {
            editor = null; sheet = null; selected = it; practice = false
        } }
    }
    val full = previewDays > 0
    val operation: (() -> Unit) -> Unit = { action -> runCatching(action).onFailure { showError() }; refresh() }
    val mission = missionAlarm(state.journey, full)
    fun beginNew(missionSelection: Alarm? = null) {
        val now = java.time.LocalTime.now()
        val alarm = Alarm(hour = now.hour, minute = now.minute).let { base ->
            missionSelection?.let { base.copy(mode = it.mode, challenge = it.challenge, repetitions = it.repetitions, seated = it.seated) } ?: base
        }
        editor = AlarmEditorDraft(alarm)
        sheet = null
    }
    MorningSystemBars()
    if (selected != null) {
        ChallengeScreen(selected!!, practice, full, state.language, catalog,
            onClose = { selected = null; refresh() }, onChanged = refresh, onError = showError)
        return
    }
    Box(Modifier.fillMaxSize().safeDrawingPadding()) {
        homeState.SaveableStateProvider("home") {
            MorningHomeScreen(state = state, previewDays = previewDays, purposeChosen = hasPurpose, suggestedMission = mission,
                onAdd = { beginNew() }, onEdit = { alarm, scope -> editor = AlarmEditorDraft(alarm, scope) },
                onToggle = { alarm, enabled -> operation {
                    repo.setAlarmEnabled(alarm.id, enabled)
                    if (enabled) scheduler.schedule(repo.state.alarms.first { it.id == alarm.id }) else {
                        scheduler.cancel(alarm.id); repo.updateAlarmState(alarm.id, ScheduleState.OFF)
                    }
                } }, onDelete = { deleting = it }, onPractice = { selected = it; practice = true },
                onExplore = { sheet = HomeSheet.EXPLORE }, onProgress = { sheet = HomeSheet.PROGRESS },
                onPro = { sheet = HomeSheet.PRO }, onLanguage = { sheet = HomeSheet.LANGUAGE }, onPurpose = { sheet = HomeSheet.PURPOSE },
                onMissionPractice = { selected = mission; practice = true }, onMissionPlan = {
                    if (state.alarms.any { it.enabled && it.state == ScheduleState.CONFIRMED && (it.scheduledAt ?: Long.MIN_VALUE) > System.currentTimeMillis() }) sheet = HomeSheet.PLAN
                    else beginNew(mission)
                }, onRestartJourney = { restarting = true },
                readiness = {
                    PermissionPanel()
                    if (WakeRecovery.limited(context)) Text(stringResource(R.string.recovery_limited), color = MaterialTheme.colorScheme.error)
                }, errorContent = {
                    if (error) Surface(shape = androidx.compose.foundation.shape.RoundedCornerShape(20.dp), color = MorningTheme.colors.soft) {
                        Column(Modifier.padding(16.dp)) {
                            Text(stringResource(R.string.save_error), color = MorningTheme.colors.ink)
                            TextButton(onClick = clearError) { Text(stringResource(R.string.close)) }
                        }
                    }
                })
        }
    }
    sheet?.let { current ->
        val title = when (current) {
            HomeSheet.PROGRESS -> R.string.nav_your_progress
            HomeSheet.PRO -> R.string.nav_pro_title
            HomeSheet.LANGUAGE -> R.string.language
            HomeSheet.PURPOSE -> R.string.nav_morning_purpose
            HomeSheet.EXPLORE -> R.string.nav_explore_challenges
            HomeSheet.PLAN -> R.string.nav_select_alarm
        }
        MorningSheet(stringResource(title), { sheet = null }) {
            when (current) {
                HomeSheet.PROGRESS -> MorningProgress(state, full, { goal -> operation { repo.setGoal(goal) } }, { sheet = HomeSheet.PRO })
                HomeSheet.PRO -> ProPreview(previewDays, state.previewStartedAt != null)
                HomeSheet.LANGUAGE -> LanguagePicker(state.language) { language ->
                    runCatching { repo.setLanguage(language) }.onSuccess { (context as? android.app.Activity)?.recreate() }.onFailure { showError() }
                }
                HomeSheet.PURPOSE -> PurposePicker(state.journey.focus, full, { focus ->
                    runCatching {
                        repo.setFocus(focus)
                        check(uiPreferences.edit().putBoolean("purpose_chosen", true).commit()) { "Could not save the purpose presentation state" }
                        purposeChosen = true
                        sheet = null
                    }.onFailure { showError() }
                    refresh()
                }, { sheet = HomeSheet.PRO })
                HomeSheet.EXPLORE -> PracticePicker { kind ->
                    selected = Alarm(hour = 7, minute = 0, challenge = kind, mode = preferredMode(kind)); practice = true; sheet = null
                }
                HomeSheet.PLAN -> {
                    state.alarms.filter { it.enabled && it.state == ScheduleState.CONFIRMED && (it.scheduledAt ?: Long.MIN_VALUE) > System.currentTimeMillis() }.forEach { alarm ->
                        MorningButton("%02d:%02d".format(alarm.hour, alarm.minute) + if (alarm.label.isBlank()) "" else " · ${alarm.label}", {
                            editor = AlarmEditorDraft(alarm, AlarmEditorScope.CHALLENGE).also { it.alarm = alarm.copy(mode = mission.mode, challenge = mission.challenge, repetitions = mission.repetitions, seated = mission.seated) }
                            sheet = null
                        }, primary = false)
                    }
                    MorningButton(stringResource(R.string.nav_new_alarm), { beginNew(mission) })
                }
            }
        }
    }
    editor?.let { draft ->
        AlarmComposer(draft, state.alarms.any { it.id == draft.alarm.id }, full,
            onDismiss = { editor = null }, onDelete = {
                runCatching { scheduler.cancel(draft.alarm.id); repo.removeAlarm(draft.alarm.id) }
                    .onSuccess { editor = null }.onFailure { draft.saveError = R.string.save_error; showError() }
                refresh()
            }, onPractice = { selected = it; practice = true },
            onSave = { edited ->
                if (!draft.saving) {
                    draft.saving = true; draft.saveError = null
                    var previous: Alarm? = null
                    var writeStarted = false
                    var nativeAttempted = false
                    val id = edited.id
                    try {
                        val updated = mergeAlarmEdits(draft.original, edited, draft.scope)
                        previous = repo.state.alarms.firstOrNull { it.id == updated.id }
                        val old = previous
                        val needsSchedule = old == null || old.hour != updated.hour || old.minute != updated.minute || old.weekdays != updated.weekdays || old.sound != updated.sound || old.state != ScheduleState.CONFIRMED
                        val willSchedule = (old?.enabled ?: true) && needsSchedule
                        check(!willSchedule || scheduler.canScheduleExactAlarms()) { "Exact alarm access is required" }
                        writeStarted = true
                        if (old == null) repo.saveAlarm(updated) else repo.updateAlarm(updated)
                        if (willSchedule) {
                            nativeAttempted = true
                            scheduler.schedule(repo.state.alarms.first { it.id == updated.id })
                        }
                        editor = null
                    } catch (_: Exception) {
                        var uncertain = false
                        if (writeStarted) {
                            var restore = previous
                            if (nativeAttempted) {
                                val old = previous
                                if (old?.enabled == true && old.state == ScheduleState.CONFIRMED) {
                                    try {
                                        scheduler.schedule(old)
                                        val occurrence = repo.state.alarms.first { it.id == id }.scheduledAt
                                        restore = old.copy(state = ScheduleState.CONFIRMED, scheduledAt = occurrence)
                                    } catch (_: Exception) { uncertain = true }
                                } else {
                                    try { scheduler.cancel(id) } catch (_: Exception) { uncertain = true }
                                }
                            }
                            runCatching { repo.rollbackAlarmSave(id, restore, uncertain) }.onFailure { uncertain = true }
                        }
                        draft.saveError = if (uncertain) R.string.nav_alarm_save_uncertain else R.string.save_error
                        showError()
                    } finally { draft.saving = false; refresh() }
                }
            })
    }
    deleting?.let { alarm ->
        AlertDialog(onDismissRequest = { deleting = null }, title = { Text(stringResource(R.string.delete_alarm)) },
            text = { Text(alarm.label.ifBlank { "%02d:%02d".format(alarm.hour, alarm.minute) }) },
            confirmButton = { TextButton(onClick = {
                operation { scheduler.cancel(alarm.id); repo.removeAlarm(alarm.id) }
                deleting = null; if (editor?.alarm?.id == alarm.id) editor = null
            }) { Text(stringResource(R.string.delete)) } },
            dismissButton = { TextButton(onClick = { deleting = null }) { Text(stringResource(R.string.cancel)) } })
    }
    if (restarting) AlertDialog(onDismissRequest = { restarting = false }, title = { Text(stringResource(R.string.restart_journey)) },
        text = { Text(stringResource(R.string.nav_purpose_note)) }, confirmButton = { TextButton(onClick = { operation { repo.restartJourney() }; restarting = false }) { Text(stringResource(R.string.start)) } },
        dismissButton = { TextButton(onClick = { restarting = false }) { Text(stringResource(R.string.cancel)) } })
}

@Composable private fun PermissionPanel() {
    val context = LocalContext.current
    var revision by remember { mutableIntStateOf(0) }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { revision++ }
    val lifecycle = LocalLifecycleOwner.current
    DisposableEffect(lifecycle) {
        val observer = LifecycleEventObserver { _, event -> if (event == Lifecycle.Event.ON_RESUME) revision++ }
        lifecycle.lifecycle.addObserver(observer); onDispose { lifecycle.lifecycle.removeObserver(observer) }
    }
    val exact = remember(revision) { AlarmScheduler(context).canScheduleExactAlarms() }
    val notifications = remember(revision) { Build.VERSION.SDK_INT < 33 || ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == android.content.pm.PackageManager.PERMISSION_GRANTED }
    val fullScreen = remember(revision) { Build.VERSION.SDK_INT < 34 || context.getSystemService(NotificationManager::class.java).canUseFullScreenIntent() }
    if (exact && notifications && fullScreen) return
    Card {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(stringResource(R.string.permission_title), style = MaterialTheme.typography.titleMedium)
            Text(stringResource(R.string.permission_note))
            if (!exact) TextButton(onClick = { context.startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:${context.packageName}"))) }) { Text(stringResource(R.string.exact_alarm)) }
            if (!notifications) TextButton(onClick = { if (Build.VERSION.SDK_INT >= 33) launcher.launch(Manifest.permission.POST_NOTIFICATIONS) }) { Text(stringResource(R.string.notifications)) }
            if (!fullScreen && Build.VERSION.SDK_INT >= 34) TextButton(onClick = { context.startActivity(Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:${context.packageName}"))) }) { Text(stringResource(R.string.full_screen)) }
        }
    }
}

@Composable private fun ChallengeScreen(saved: Alarm, practice: Boolean, full: Boolean, language: AppLanguage, catalog: ContentCatalog, onClose: () -> Unit, onChanged: () -> Unit, onError: () -> Unit) {
    val context = LocalContext.current
    val actualLanguage = if (language == AppLanguage.VIETNAMESE || (language == AppLanguage.SYSTEM && LocalConfiguration.current.locales[0].language == "vi")) AppLanguage.VIETNAMESE else AppLanguage.ENGLISH
    val effective = remember(saved, full) { if (full) saved else saved.copy(mode = if (saved.mode == WakeMode.FOCUSED) WakeMode.BALANCED else saved.mode, sound = AlarmSound.SYSTEM, repetitions = if (saved.challenge == ChallengeKind.PUSH_UPS) minOf(5, saved.repetitions) else saved.repetitions) }
    var kind by remember(saved.id) { mutableStateOf(effective.challenge) }
    var prompt by remember(saved.id, actualLanguage) { mutableStateOf(catalog.prompt(kind, actualLanguage)) }
    var completed by remember(saved.id) { mutableStateOf(false) }
    var completion by remember(saved.id) { mutableStateOf<WakeOutcome?>(null) }
    val serviceStarted by RingingService.activeStartedAt.collectAsState()
    val snoozesUsed by RingingService.activeSnoozesUsed.collectAsState()
    val audioFailed by RingingService.audioFailed.collectAsState()
    val wakeSession = remember(saved.id) { RingingService.activeSessionId.value }
    var message by remember { mutableStateOf<Int?>(null) }
    var transcript by remember { mutableStateOf("") }
    var listening by remember { mutableStateOf(false) }
    var capturing by remember { mutableStateOf(false) }
    var progress by remember { mutableIntStateOf(0) }
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    val startedAt = remember(saved.id) { System.currentTimeMillis() }
    val speech = remember { SpeechCapture(context) }
    var tts by remember { mutableStateOf<TextToSpeech?>(null) }
    var ttsReady by remember { mutableStateOf(false) }
    val voiceLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted -> message = if (granted) null else R.string.microphone_permission }
    val cameraLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted -> if (granted) capturing = true else message = R.string.camera_permission }
    val permission = { name: String -> ContextCompat.checkSelfPermission(context, name) == android.content.pm.PackageManager.PERMISSION_GRANTED }
    DisposableEffect(Unit) {
        val engine = TextToSpeech(context) { status -> ttsReady = status == TextToSpeech.SUCCESS }
        tts = engine
        onDispose { speech.destroy(); engine.stop(); engine.shutdown() }
    }
    val lifecycle = LocalLifecycleOwner.current
    DisposableEffect(lifecycle) {
        val observer = LifecycleEventObserver { _, event -> if (event == Lifecycle.Event.ON_STOP) { speech.stop(); tts?.stop(); listening = false; capturing = false } }
        lifecycle.lifecycle.addObserver(observer); onDispose { lifecycle.lifecycle.removeObserver(observer) }
    }
    LaunchedEffect(Unit) { while (true) { kotlinx.coroutines.delay(1000); now = System.currentTimeMillis() } }
    val finish: (WakeOutcome) -> Unit = { outcome ->
        if (!completed) {
            speech.stop(); tts?.stop(); listening = false; capturing = false
            if (!practice) runCatching {
                when (outcome) {
                    WakeOutcome.LOCAL_COMPLETED -> RingingService.complete(context, saved.id, wakeSession)
                    WakeOutcome.SELF_CONFIRMED -> RingingService.selfConfirm(context, saved.id, wakeSession)
                    else -> RingingService.stop(context, saved.id, wakeSession)
                }
            }.onFailure { onError() }
            completion = outcome; completed = true; onChanged()
        }
    }
    val close: () -> Unit = {
        val stopped = practice || completed || runCatching { RingingService.stop(context, saved.id, wakeSession) }
            .onFailure { message = R.string.save_error; onError() }.isSuccess
        if (stopped) onClose()
    }
    BackHandler { close() }
    Column(Modifier.fillMaxSize().safeDrawingPadding().verticalScroll(rememberScrollState()).padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text(stringResource(if (practice) R.string.explore else R.string.good_morning), style = MaterialTheme.typography.headlineMedium)
        if (practice) Text(stringResource(R.string.practice_note))
        if (!practice && audioFailed) Text(stringResource(R.string.audio_error), color = MaterialTheme.colorScheme.error)
        Text(stringResource(challengeText(kind)), style = MaterialTheme.typography.titleLarge)
        if (completed) {
            Text(stringResource(if (practice) R.string.practice_completed else if (completion == WakeOutcome.SELF_CONFIRMED) R.string.self_confirmed else R.string.completed), style = MaterialTheme.typography.headlineSmall, color = MaterialTheme.colorScheme.primary)
            prompt?.explanation?.let { Text(it) }
            MorningButton(stringResource(R.string.close), close)
            return@Column
        }
        if (kind in listOf(ChallengeKind.READ_AND_CHOOSE, ChallengeKind.RIDDLE, ChallengeKind.READ_ALOUD)) {
            val current = prompt
            if (current == null) Text(stringResource(R.string.data_error)) else {
                Text(current.text, style = MaterialTheme.typography.headlineSmall)
                if (kind == ChallengeKind.READ_ALOUD) {
                    MorningButton(text = stringResource(R.string.listen_example), primary = false, enabled = ttsReady && !listening, onClick = {
                        tts?.language = Locale.forLanguageTag(if (actualLanguage == AppLanguage.VIETNAMESE) "vi-VN" else "en-US")
                        tts?.speak(current.text, TextToSpeech.QUEUE_FLUSH, null, current.id)
                    })
                    if (transcript.isNotBlank()) {
                        Text(transcript)
                        val feedback = RecognizedWordMatch.feedback(current.text, transcript, actualLanguage, !listening)
                        Text(stringResource(R.string.reading_score, (feedback.score * 100).roundToInt()))
                        val statuses = mapOf(RecognizedWordMatch.WordStatus.CORRECT to stringResource(R.string.word_correct), RecognizedWordMatch.WordStatus.INCORRECT to stringResource(R.string.word_incorrect), RecognizedWordMatch.WordStatus.PENDING to stringResource(R.string.word_pending))
                        val description = feedback.words.joinToString(", ") { "${it.text}: ${statuses[it.status]}" }
                        val colors = MaterialTheme.colorScheme
                        val wordColors = MorningTheme.colors
                        Text(buildAnnotatedString {
                            feedback.words.forEach { word ->
                                val color = when (word.status) { RecognizedWordMatch.WordStatus.CORRECT -> wordColors.correctWord; RecognizedWordMatch.WordStatus.INCORRECT -> colors.error; RecognizedWordMatch.WordStatus.PENDING -> colors.onSurfaceVariant }
                                withStyle(SpanStyle(color = color)) { append(word.text); append(" ") }
                            }
                        }, modifier = Modifier.semantics { contentDescription = description })
                    }
                    MorningButton(text = stringResource(if (listening) R.string.listening else R.string.start_listening), enabled = !listening, onClick = {
                        if (!permission(Manifest.permission.RECORD_AUDIO)) voiceLauncher.launch(Manifest.permission.RECORD_AUDIO)
                        else {
                            tts?.stop(); if (!practice) RingingService.stop(context, saved.id, wakeSession); message = null; transcript = ""; listening = true
                            speech.start(if (actualLanguage == AppLanguage.VIETNAMESE) "vi-VN" else "en-US", onTranscript = { transcript = it }, onFinal = { text ->
                                transcript = text; listening = false
                                if (RecognizedWordMatch.score(current.text, text, actualLanguage) >= RecognizedWordMatch.PASSING_SCORE) finish(WakeOutcome.LOCAL_COMPLETED) else message = R.string.speech_error
                            }, onError = { listening = false; message = R.string.speech_unavailable })
                        }
                    })
                } else {
                    current.choices.forEachIndexed { index, choice ->
                        MorningButton(choice, {
                            if (index == current.correctIndex) finish(WakeOutcome.LOCAL_COMPLETED) else message = R.string.wrong_answer
                        }, primary = false)
                    }
                }
                TextButton(onClick = { speech.stop(); tts?.stop(); listening = false; transcript = ""; message = null; prompt = catalog.prompt(kind, actualLanguage) }) { Text(stringResource(R.string.next_prompt)) }
            }
        } else if (kind != ChallengeKind.NONE) {
            Text(stringResource(guideText(kind)))
            Text(stringResource(R.string.cloud_local), style = MaterialTheme.typography.bodySmall)
            val target = when (kind) { ChallengeKind.PUSH_UPS -> effective.repetitions; ChallengeKind.JUMPING_JACKS -> 10; else -> 3 }
            Text(stringResource(R.string.movement_progress, progress, target), style = MaterialTheme.typography.headlineMedium)
            if (capturing) {
                MovementCapture(kind = kind, repetitions = effective.repetitions, seated = effective.seated,
                    modifier = Modifier.fillMaxWidth().aspectRatio(3f / 4f),
                    onProgress = { progress = it }, onComplete = { finish(WakeOutcome.LOCAL_COMPLETED) }, onError = { failure ->
                        capturing = false
                        message = when (failure) { CaptureError.TRACKING_LOST -> R.string.tracking_lost; CaptureError.TIMEOUT -> R.string.capture_timeout; else -> R.string.capture_error }
                    })
            } else MorningButton(text = stringResource(R.string.start), onClick = {
                if (permission(Manifest.permission.CAMERA)) { if (!practice) RingingService.stop(context, saved.id, wakeSession); progress = 0; capturing = true; message = null } else cameraLauncher.launch(Manifest.permission.CAMERA)
            })
        }
        message?.let { Text(stringResource(it), color = MaterialTheme.colorScheme.error) }
        if (kind != ChallengeKind.READ_AND_CHOOSE) TextButton(onClick = {
            speech.stop(); capturing = false; listening = false; kind = ChallengeKind.READ_AND_CHOOSE; prompt = catalog.prompt(kind, actualLanguage); message = null
        }) { Text(stringResource(R.string.try_reading)) }
        if (!practice) {
            HorizontalDivider()
            Text(stringResource(R.string.recovery_note), style = MaterialTheme.typography.bodySmall)
            val remaining = (((serviceStarted ?: startedAt) + 300_000 - now).coerceAtLeast(0) / 1000).toInt()
            if (remaining > 0) Text(stringResource(R.string.awake_wait, remaining / 60, remaining % 60))
            MorningButton(stringResource(R.string.awake), { finish(WakeOutcome.SELF_CONFIRMED) }, enabled = remaining == 0)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                MorningButton(stringResource(R.string.stop), close, modifier = Modifier.weight(1f), primary = false)
                if (snoozesUsed < effective.mode.snoozes) MorningButton(stringResource(R.string.snooze), { RingingService.snooze(context, saved.id, wakeSession); onClose() }, modifier = Modifier.weight(1f), primary = false)
            }
        }
        TextButton(onClick = close) { Text(stringResource(R.string.close)) }
    }
}

private fun missionAlarm(journey: Journey, full: Boolean): Alarm {
    val focus = if (!full && journey.focus == MorningFocus.ENERGIZE) MorningFocus.GENTLE_MOVEMENT else journey.focus
    val kind = focus.mission(journey.missionIndex(), full)
    return Alarm(hour = 7, minute = 0, challenge = kind, mode = preferredMode(kind), seated = focus == MorningFocus.GENTLE_MOVEMENT)

}

@Composable private fun daySummary(days: Set<Int>): String {
    val names = DateFormatSymbols.getInstance(LocalConfiguration.current.locales[0]).shortWeekdays
    return if (days.isEmpty()) stringResource(R.string.once) else days.sorted().joinToString(" · ") { names[it] }
}
