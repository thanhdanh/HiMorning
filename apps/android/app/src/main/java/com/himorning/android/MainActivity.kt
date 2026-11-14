package com.himorning.android

import android.Manifest
import android.app.NotificationManager
import android.app.TimePickerDialog
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.ToneGenerator
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import com.himorning.android.core.*
import com.himorning.android.platform.*
import com.himorning.android.ui.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.withContext
import java.text.DateFormatSymbols
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import java.util.UUID

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
    val refresh = {
        runCatching { state = repo.state }.onFailure { error = true }
        Unit
    }
    AppContent(repo, state, error, { error = false }, refresh, { error = true })
    LaunchedEffect(Unit) { refresh() }
}

private enum class HomeSheet { PROGRESS, LANGUAGE, PURPOSE, EXPLORE, PLAN }

@Composable private fun AppContent(repo: AppRepository, state: AppState, error: Boolean, clearError: () -> Unit, refresh: () -> Unit, showError: () -> Unit) {
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
    var scheduleNotice by remember { mutableStateOf<Long?>(null) }
    var restarting by remember { mutableStateOf(false) }
    val homeState = androidx.compose.runtime.saveable.rememberSaveableStateHolder()
    val activeId by RingingService.activeAlarmId.collectAsState()
    val owner = LocalLifecycleOwner.current
    DisposableEffect(owner) {
        val observer = LifecycleEventObserver { _, event -> if (event == Lifecycle.Event.ON_RESUME) {
            if (!scheduler.canScheduleExactAlarms()) {
                runCatching { repo.state.alarms.filter { it.enabled }.forEach { repo.updateAlarmState(it.id, ScheduleState.NEEDS_REVIEW) } }.onFailure { showError() }
            }
            RingingService.restoreState(context); refresh()
        } }
        owner.lifecycle.addObserver(observer)
        onDispose { owner.lifecycle.removeObserver(observer) }
    }
    LaunchedEffect(owner, catalog) {
        owner.lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
            withContext(Dispatchers.IO) { catalog.refreshIfDue() }
            awaitCancellation()
        }
    }
    LaunchedEffect(activeId) {
        refresh()
        activeId?.let { id -> repo.state.alarms.firstOrNull { it.id == id }?.let {
            editor = null; sheet = null; selected = it; practice = false
        } }
    }
    val full = true
    val operation: (() -> Unit) -> Unit = { action -> runCatching(action).onFailure { showError() }; refresh() }
    val planThreshold = if (state.journey.completedToday())
        java.time.LocalDate.now().plusDays(1).atStartOfDay(java.time.ZoneId.systemDefault()).toInstant().toEpochMilli()
        else System.currentTimeMillis()
    val upcomingAlarms = state.alarms.filter {
        it.enabled && it.state == ScheduleState.CONFIRMED && (it.scheduledAt ?: Long.MIN_VALUE) >= planThreshold
    }
    val mission = missionAlarm(state.journey, full)
    fun beginNew(missionSelection: Alarm? = null) {
        val alarm = Alarm(hour = 7, minute = 0).let { base ->
            missionSelection?.let { base.copy(mode = it.mode, challenge = it.challenge, repetitions = it.repetitions, seated = it.seated) } ?: base
        }
        editor = AlarmEditorDraft(alarm)
        sheet = null
    }
    MorningSystemBars()
    if (selected != null) {
        ChallengeScreen(selected!!, practice, full, state.language, catalog,
            onClose = { selected = null; refresh() }, onChanged = refresh, onError = showError,
            onUseChallenge = if (practice && editor == null) { { chosen -> selected = null; beginNew(chosen) } } else null)
        return
    }
    val snackbar = remember { SnackbarHostState() }
    val notice = scheduleNotice?.let { nextOccurrence(Instant.ofEpochMilli(it)) }
    LaunchedEffect(notice) {
        if (notice != null) {
            snackbar.showSnackbar(notice, duration = SnackbarDuration.Short)
            scheduleNotice = null
        }
    }
    Box(Modifier.fillMaxSize().safeDrawingPadding()) {
        homeState.SaveableStateProvider("home") {
            MorningHomeScreen(state = state, purposeChosen = hasPurpose, suggestedMission = mission,
                onAdd = { beginNew() }, onEdit = { alarm, scope -> editor = AlarmEditorDraft(alarm, scope) },
                onToggle = { alarm, enabled -> operation {
                    if (enabled && !scheduler.canScheduleExactAlarms()) {
                        context.startActivity(scheduler.exactAlarmSettingsIntent())
                    } else {
                        repo.setAlarmEnabled(alarm.id, enabled)
                        try {
                            if (enabled) scheduler.schedule(repo.state.alarms.first { it.id == alarm.id })
                            else scheduler.cancel(alarm.id)
                        } catch (failure: Exception) {
                            repo.updateAlarmState(alarm.id, ScheduleState.NEEDS_REVIEW)
                            throw failure
                        }
                    }
                } }, onDelete = { deleting = it }, onPractice = { selected = it; practice = true },
                onExplore = { sheet = HomeSheet.EXPLORE }, onProgress = { sheet = HomeSheet.PROGRESS },
                onLanguage = { sheet = HomeSheet.LANGUAGE }, onPurpose = { sheet = HomeSheet.PURPOSE },
                onQuickPractice = { selected = Alarm(hour = 7, minute = 0, challenge = ChallengeKind.READ_AND_CHOOSE, mode = WakeMode.BALANCED); practice = true },
                onMissionPractice = { selected = mission; practice = true }, onMissionPlan = {
                    if (upcomingAlarms.isEmpty()) beginNew(mission) else sheet = HomeSheet.PLAN
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
        SnackbarHost(snackbar, Modifier.align(androidx.compose.ui.Alignment.BottomCenter))
    }
    sheet?.let { current ->
        val title = when (current) {
            HomeSheet.PROGRESS -> R.string.nav_your_progress
            HomeSheet.LANGUAGE -> R.string.language
            HomeSheet.PURPOSE -> R.string.nav_morning_purpose
            HomeSheet.EXPLORE -> R.string.nav_explore_challenges
            HomeSheet.PLAN -> R.string.nav_select_alarm
        }
        val titleStyle = MaterialTheme.typography.titleLarge.let {
            if (current == HomeSheet.PROGRESS) it.copy(fontFamily = quicksandFont) else it
        }
        MorningSheet(stringResource(title), { sheet = null }, titleStyle) {
            when (current) {
                HomeSheet.PROGRESS -> MorningProgress(state) { goal -> operation { repo.setGoal(goal) } }
                HomeSheet.LANGUAGE -> LanguagePicker(state.language) { language ->
                    runCatching { repo.setLanguage(language) }.onSuccess { (context as? android.app.Activity)?.recreate() }.onFailure { showError() }
                }
                HomeSheet.PURPOSE -> PurposePicker(state.journey.focus) { focus ->
                    runCatching {
                        repo.setFocus(focus)
                        check(uiPreferences.edit().putBoolean("purpose_chosen", true).commit()) { "Could not save the purpose presentation state" }
                        purposeChosen = true
                        sheet = null
                    }.onFailure { showError() }
                    refresh()
                }
                HomeSheet.EXPLORE -> PracticePicker { kind ->
                    selected = Alarm(hour = 7, minute = 0, challenge = kind, mode = preferredMode(kind)); practice = true; sheet = null
                }
                HomeSheet.PLAN -> {
                    upcomingAlarms.forEach { alarm ->
                        MorningButton(alarmTimeText(context, alarm) + if (alarm.label.isBlank()) "" else " · ${alarm.label}", {
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
                        if (willSchedule && !scheduler.canScheduleExactAlarms()) {
                            draft.saveError = R.string.alarm_permission_save
                            return@AlarmComposer
                        }
                        writeStarted = true
                        if (old == null) repo.saveAlarm(updated) else repo.updateAlarm(updated)
                        if (willSchedule) {
                            nativeAttempted = true
                            scheduler.schedule(repo.state.alarms.first { it.id == updated.id })
                            scheduleNotice = repo.state.alarms.first { it.id == updated.id }.scheduledAt
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
            text = { Text(alarm.label.ifBlank { alarmTimeText(context, alarm) }) },
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

@Composable private fun ChallengeScreen(saved: Alarm, practice: Boolean, full: Boolean, language: AppLanguage, catalog: ContentCatalog, onClose: () -> Unit, onChanged: () -> Unit, onError: () -> Unit, onUseChallenge: ((Alarm) -> Unit)?) {
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
    val startCamera = {
        val ready = practice || runCatching { RingingService.silence(context, saved.id, wakeSession) }
            .onFailure { message = R.string.save_error; onError() }.isSuccess
        if (ready) {
            progress = 0
            message = null
            capturing = true
        }
    }
    val cameraLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) startCamera() else message = R.string.camera_permission
    }
    val permission = { name: String -> ContextCompat.checkSelfPermission(context, name) == android.content.pm.PackageManager.PERMISSION_GRANTED }
    DisposableEffect(Unit) {
        val engine = TextToSpeech(context) { status -> ttsReady = status == TextToSpeech.SUCCESS }
        tts = engine
        onDispose { speech.destroy(); engine.stop(); engine.shutdown() }
    }
    val instruction = stringResource(guideText(kind, effective.seated))
    val voice = tts
    LaunchedEffect(capturing, voice, ttsReady) {
        if (capturing && ttsReady && voice != null) {
            val locale = if (actualLanguage == AppLanguage.VIETNAMESE) Locale.forLanguageTag("vi-VN") else Locale.US
            if (voice.setLanguage(locale) >= TextToSpeech.LANG_AVAILABLE) {
                voice.speak(instruction, TextToSpeech.QUEUE_FLUSH, null, "movement-guide")
            }
        }
    }
    var repTone by remember { mutableStateOf<ToneGenerator?>(null) }
    DisposableEffect(capturing) {
        val tone = if (capturing) runCatching { ToneGenerator(AudioManager.STREAM_MUSIC, 40) }.getOrNull() else null
        repTone = tone
        onDispose {
            tone?.release()
            if (capturing) voice?.stop()
        }
    }
    val lifecycle = LocalLifecycleOwner.current
    DisposableEffect(lifecycle) {
        val observer = LifecycleEventObserver { _, event -> if (event == Lifecycle.Event.ON_STOP) { speech.stop(); tts?.stop(); listening = false; capturing = false } }
        lifecycle.lifecycle.addObserver(observer); onDispose { lifecycle.lifecycle.removeObserver(observer) }
    }
    LaunchedEffect(Unit) { while (true) { kotlinx.coroutines.delay(1000); now = System.currentTimeMillis() } }
    var answerChime by remember { mutableStateOf<MediaPlayer?>(null) }
    DisposableEffect(Unit) { onDispose { answerChime?.release() } }
    val finish: (WakeOutcome) -> Unit = finish@{ outcome ->
        if (!completed) {
            speech.stop(); tts?.stop(); listening = false; capturing = false
            if (!practice && runCatching {
                when (outcome) {
                    WakeOutcome.LOCAL_COMPLETED -> RingingService.complete(context, saved.id, wakeSession)
                    WakeOutcome.SELF_CONFIRMED -> RingingService.selfConfirm(context, saved.id, wakeSession)
                    else -> RingingService.stop(context, saved.id, wakeSession)
                }
            }.onFailure { onError(); message = R.string.save_error }.isFailure) return@finish
            if (practice && outcome == WakeOutcome.LOCAL_COMPLETED &&
                (kind == ChallengeKind.READ_AND_CHOOSE || kind == ChallengeKind.RIDDLE)) {
                runCatching {
                    answerChime?.release()
                    answerChime = MediaPlayer.create(context, R.raw.answer_chime)?.apply {
                        setVolume(.25f, .25f)
                        start()
                    }
                }
            }
            completion = outcome; completed = true; onChanged()
        }
    }
    val close: () -> Unit = {
        val stopped = practice || completed || runCatching { RingingService.stop(context, saved.id, wakeSession) }
            .onFailure { message = R.string.save_error; onError() }.isSuccess
        if (stopped) onClose()
    }
    BackHandler { close() }
    val scroll = rememberScrollState()
    LaunchedEffect(capturing) { if (capturing) scroll.scrollTo(0) }
    Column(Modifier.fillMaxSize().safeDrawingPadding().verticalScroll(scroll).padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        if (!capturing) {
            Text(stringResource(if (practice) R.string.explore else R.string.good_morning), style = MaterialTheme.typography.headlineMedium)
            if (practice) Text(stringResource(R.string.practice_note))
            if (!practice) {
                val occurrence = serviceStarted?.let(Instant::ofEpochMilli)
                Text(if (occurrence == null) alarmTimeText(context, saved) else occurrenceTimeText(context, occurrence),
                    style = MaterialTheme.typography.titleLarge)
            }
            if (!practice && audioFailed) Text(stringResource(R.string.audio_error), color = MaterialTheme.colorScheme.error)
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            MovementChallengeIcon(kind, effective.seated, tint = MorningTheme.modeAccent(effective.mode), size = 28.dp, animated = !capturing && !completed)
            Text(stringResource(challengeText(kind)), style = MaterialTheme.typography.titleLarge, fontFamily = quicksandFont)
        }
        if (!completed && kind != ChallengeKind.NONE && !capturing && !listening) {
            var showCheckingGuide by remember(kind) { mutableStateOf(false) }
            TextButton(onClick = { showCheckingGuide = !showCheckingGuide }) {
                Text(stringResource(R.string.challenge_guide_scoring_title))
                Text(if (showCheckingGuide) " −" else " +")
            }
            if (showCheckingGuide) ChallengeCheckingGuide(effective)
        }
        if (kind == ChallengeKind.READ_ALOUD && (!completed || completion == WakeOutcome.LOCAL_COMPLETED)) {
            prompt?.let { current ->
                key(current.id) { ReadingPassage(current.text, transcript, finished = !listening) }
            }
        }
        if (completed) {
            val answered = prompt != null && (kind == ChallengeKind.READ_AND_CHOOSE || kind == ChallengeKind.RIDDLE)
            val resultText = when {
                completion == WakeOutcome.SELF_CONFIRMED -> R.string.self_confirmed
                answered -> R.string.answer_correct
                practice -> R.string.practice_completed
                else -> R.string.completed
            }
            Text(stringResource(resultText), style = MaterialTheme.typography.headlineSmall, color = MaterialTheme.colorScheme.primary)
            prompt?.explanation?.let {
                Text(stringResource(R.string.why_answer_right), style = MaterialTheme.typography.titleSmall)
                Text(it)
            }
            if (practice) onUseChallenge?.let { use ->
                MorningButton(stringResource(R.string.set_alarm_with_challenge), { use(effective.copy(challenge = kind, mode = preferredMode(kind))) })
            }
            if (practice) MorningButton(stringResource(R.string.retry_challenge), {
                progress = 0
                message = null
                transcript = ""
                if (kind != ChallengeKind.READ_ALOUD) prompt = catalog.prompt(kind, actualLanguage)
                completion = null
                completed = false
            }, primary = false)
            TextButton(onClick = close) { Text(stringResource(if (practice && onUseChallenge == null) R.string.back_to_alarm else R.string.back_to_home)) }
            return@Column
        }
        if (kind in listOf(ChallengeKind.READ_AND_CHOOSE, ChallengeKind.RIDDLE, ChallengeKind.READ_ALOUD)) {
            val current = prompt
            if (current == null) Text(stringResource(R.string.data_error)) else {
                if (kind == ChallengeKind.READ_ALOUD) {
                    MorningButton(text = stringResource(R.string.listen_example), primary = false, enabled = ttsReady && !listening, onClick = {
                        tts?.language = Locale.US
                        tts?.speak(current.text, TextToSpeech.QUEUE_FLUSH, null, current.id)
                    })
                    MorningButton(text = stringResource(if (listening) R.string.listening else R.string.start_listening), enabled = !listening, onClick = {
                        if (!permission(Manifest.permission.RECORD_AUDIO)) voiceLauncher.launch(Manifest.permission.RECORD_AUDIO)
                        else {
                            tts?.stop(); if (!practice) RingingService.silence(context, saved.id, wakeSession); message = null; transcript = ""; listening = true
                            speech.start("en-US", onTranscript = { transcript = it }, onFinal = { text ->
                                transcript = text; listening = false
                                if (RecognizedWordMatch.score(current.text, text, AppLanguage.ENGLISH) >= RecognizedWordMatch.PASSING_SCORE) finish(WakeOutcome.LOCAL_COMPLETED) else message = R.string.speech_error
                            }, onError = { listening = false; message = R.string.speech_unavailable })
                        }
                    })
                } else {
                    Text(current.text, style = MaterialTheme.typography.headlineSmall)
                    current.choices.forEachIndexed { index, choice ->
                        MorningButton(choice, {
                            if (index == current.correctIndex) finish(WakeOutcome.LOCAL_COMPLETED) else message = R.string.wrong_answer
                        }, primary = false)
                    }
                }
                TextButton(onClick = { speech.stop(); tts?.stop(); listening = false; transcript = ""; message = null; prompt = catalog.prompt(kind, actualLanguage) }) { Text(stringResource(R.string.next_prompt)) }
            }
        } else if (kind != ChallengeKind.NONE) {
            if (capturing) {
                MovementCapture(kind = kind, repetitions = effective.repetitions, seated = effective.seated, progress = progress,
                    modifier = Modifier.fillMaxWidth().aspectRatio(3f / 4f),
                    onProgress = {
                        progress = it
                        repTone?.startTone(ToneGenerator.TONE_PROP_BEEP, 90)
                    },
                    onComplete = { finish(WakeOutcome.LOCAL_COMPLETED) }, onError = { failure ->
                        capturing = false
                        message = when (failure) { CaptureError.TRACKING_LOST -> R.string.tracking_lost; CaptureError.TIMEOUT -> R.string.capture_timeout; else -> R.string.capture_error }
                    })
                Text(instruction)
            } else {
                Text(instruction)
                MorningButton(text = stringResource(R.string.start), onClick = {
                    if (permission(Manifest.permission.CAMERA)) startCamera() else cameraLauncher.launch(Manifest.permission.CAMERA)
                })
            }
        }
        message?.let { Text(stringResource(it), color = MaterialTheme.colorScheme.error) }
        if (kind != ChallengeKind.NONE && kind != ChallengeKind.READ_AND_CHOOSE) TextButton(onClick = {
            speech.stop(); tts?.stop(); capturing = false; listening = false; kind = ChallengeKind.READ_AND_CHOOSE; prompt = catalog.prompt(kind, actualLanguage); message = null
        }) { Text(stringResource(R.string.try_reading)) }
        if (!practice && kind == ChallengeKind.NONE) {
            MorningButton(stringResource(R.string.stop), close)
            if (snoozesUsed < effective.mode.snoozes) MorningButton(stringResource(R.string.snooze_five_minutes), {
                runCatching { RingingService.snooze(context, saved.id, wakeSession) }
                    .onSuccess { onClose() }.onFailure { message = R.string.save_error; onError() }
            }, primary = false)
        } else if (!practice) {
            HorizontalDivider()
            Text(stringResource(R.string.recovery_note), style = MaterialTheme.typography.bodySmall)
            val remaining = (((serviceStarted ?: startedAt) + 300_000 - now).coerceAtLeast(0) + 999).div(1000).toInt()
            if (remaining > 0) Text(stringResource(R.string.awake_wait, remaining / 60, remaining % 60))
            MorningButton(stringResource(R.string.awake), { finish(WakeOutcome.SELF_CONFIRMED) }, enabled = remaining == 0)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                MorningButton(stringResource(R.string.stop), close, modifier = Modifier.weight(1f), primary = false)
                if (snoozesUsed < effective.mode.snoozes) MorningButton(stringResource(R.string.snooze), { RingingService.snooze(context, saved.id, wakeSession); onClose() }, modifier = Modifier.weight(1f), primary = false)
            }
        }
        if (practice) TextButton(onClick = close) { Text(stringResource(R.string.back_to_home)) }
    }
}

private fun missionAlarm(journey: Journey, full: Boolean): Alarm {
    val focus = if (!full && journey.focus == MorningFocus.ENERGIZE) MorningFocus.GENTLE_MOVEMENT else journey.focus
    val kind = focus.mission(if (journey.completedToday()) journey.completions.size else journey.missionIndex(), full)
    return Alarm(hour = 7, minute = 0, challenge = kind, mode = preferredMode(kind), seated = focus == MorningFocus.GENTLE_MOVEMENT)

}

@Composable private fun daySummary(days: Set<Int>): String {
    val names = DateFormatSymbols.getInstance(LocalConfiguration.current.locales[0]).shortWeekdays
    return if (days.isEmpty()) stringResource(R.string.once) else days.sorted().joinToString(" · ") { names[it] }
}
