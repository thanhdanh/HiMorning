import SwiftUI
import AVFoundation
import HiMorningCore
import Vision
import CoreML
import CoreMotion

struct CameraPreview: UIViewRepresentable {
 let session: AVCaptureSession
 final class Preview:UIView {
  override class var layerClass:AnyClass {AVCaptureVideoPreviewLayer.self}
  init(session:AVCaptureSession) {
   super.init(frame:.zero)
   let previewLayer=layer as! AVCaptureVideoPreviewLayer
   previewLayer.session=session
   previewLayer.videoGravity = .resizeAspect
  }
  required init?(coder:NSCoder) {super.init(coder:coder)}
  func configure() {
   guard let connection=(layer as? AVCaptureVideoPreviewLayer)?.connection else {return}
   if connection.isVideoRotationAngleSupported(90),connection.videoRotationAngle != 90 {connection.videoRotationAngle=90}
   if connection.isVideoMirroringSupported,connection.automaticallyAdjustsVideoMirroring || !connection.isVideoMirrored {connection.automaticallyAdjustsVideoMirroring=false;connection.isVideoMirrored=true}
  }
  override func layoutSubviews() {super.layoutSubviews();configure()}
 }
 func makeUIView(context: Context) -> Preview {
  Preview(session:session)
 }
 func updateUIView(_ uiView:Preview,context:Context) {uiView.configure()}
}

struct ChallengeView: View {
 let alarm: SavedAlarm
 @State private var sessionAlarm: SavedAlarm?
 private var effectiveAlarm: SavedAlarm { sessionAlarm ?? model.access.effectiveAlarm(alarm) }
 @State private var readAloudFallback = false
 private var challenge: ChallengeSelection { readAloudFallback ? .readAndChoose : effectiveAlarm.challenge }
 private var performedAlarm: SavedAlarm {
  guard readAloudFallback else { return effectiveAlarm }
  var fallback = SavedAlarm(id: effectiveAlarm.id, time: effectiveAlarm.time, mode: effectiveAlarm.mode, sound: effectiveAlarm.sound, challenge: .readAndChoose, label: effectiveAlarm.label, scheduledOccurrence: effectiveAlarm.scheduledOccurrence)
  fallback.enabled = effectiveAlarm.enabled; fallback.state = effectiveAlarm.state
  return fallback
 }
 @ObservedObject var model: PilotModel
 var rehearsal=false
 @Environment(\.dismiss) private var dismiss
 @Environment(\.scenePhase) private var scene
 @State private var coordinator: ChallengeCoordinator?
 @State private var camera: CameraCapture?
 @State private var movementCamera: MovementChallengeCapture?
 @State private var rhythmCamera: GuidedRhythmCapture?
 @State private var speech: SpeechChallengeCapture?
 @StateObject private var spokenExample = SpokenExample()
 @State private var preparingExample = false
 @State private var captureGeneration = UUID()
 @State private var rhythmCycles = 0
 @State private var voice: VoiceCoach?
 @State private var transcript = ""
 @State private var speechEnded = false
 @State private var speechFinishing = false
 @State private var speechListening = false
 @State private var awakeAvailableAt = Date().addingTimeInterval(WakeEnforcementPolicy.selfConfirmDelay)
 @Environment(\.accessibilityReduceMotion) private var reduceMotion
 @State private var readPrompt: ChallengePrompt?
 @State private var riddlePrompt: ChallengePrompt?
 @State private var readAloudItem: ChallengeContentItem?
 @State private var message = appText("Good morning. Choose what feels right today.")
 @State private var tracking:CameraTrackingSnapshot = .empty
 @State private var reps = 0
 @State private var consent = false
 @State private var busy = false
 @State private var consentDialog = false
 @State private var completion: WakeOutcome?
 @State private var retrying = false
 private var practicing: Bool { rehearsal || model.rehearsal || retrying }
 private var finished: Bool { completion != nil }
 private var celebrates: Bool { completion == .localCompleted || completion == .openaiVerified || completion == .aiVerified }
 @State private var historyID = UUID()
 @State private var stopping = false
 @State private var result: String?

 var body: some View {
  ScrollViewReader { scroll in
   ScrollView {
    VStack(spacing: 20) {
     if celebrates {
      ChallengeCelebrationView()
     } else {
      Text(practicing ? appText("Try a challenge") : appText("Good morning ☀️")).font(.headline)
      if practicing { Text(appText("Practice only. Your alarms stay as they are.")).font(.footnote).foregroundStyle(MorningTheme.muted) }
      if testingTrackingOverlay {
       #if DEBUG
       CameraTrackingFixturePreview()
       #endif
      } else if let camera {
       cameraBlock(camera.session, counter: "\(reps) / \(challenge.repetitions ?? 0)")
      } else if let movementCamera {
       cameraBlock(movementCamera.session, counter: "\(reps) / \(challenge.kind.localMovementTarget ?? 0)")
      } else if let rhythmCamera {
       cameraBlock(rhythmCamera.session, counter: "\(rhythmCycles) / 3")
      } else if challenge.kind.hasMovementIllustration {
       MovementGuide(selection:challenge)
      } else {
       HStack(spacing: 16) {
        MorningSun(size: 64)
        Text(String(format: "%02d:%02d", alarm.time.hour, alarm.time.minute)).font(.system(.largeTitle, design: .rounded).weight(.regular)).monospacedDigit()
       }
      }
     }
     Text(challenge.displayTitle).font(.subheadline.weight(.medium)).padding(.horizontal, 14).padding(.vertical, 8).background(MorningTheme.soft, in: Capsule())
     if effectiveAlarm.mode != alarm.mode || effectiveAlarm.challenge != alarm.challenge {
      Text(appText("Your preview has ended. This morning uses the basic challenge. Your saved choice stays the same.")).font(.footnote).foregroundStyle(MorningTheme.muted)
     }
     if !finished,challenge.kind.hasMovementIllustration,camera != nil || movementCamera != nil || rhythmCamera != nil {
      MovementGuide(selection:challenge,compact:true)
     }
     Text(result ?? message)
      .font(distanceLayout ? .system(size: 34, weight: .semibold) : .title3.weight(.medium))
      .minimumScaleFactor(distanceLayout ? 0.6 : 1)
      .multilineTextAlignment(.center).accessibilityIdentifier("challengeMessage")
     if !finished && (busy || stopping || speechFinishing || preparingExample) {
      ProgressView().accessibilityLabel(message)
     }
     if (challenge.kind == .readAndChoose || challenge.kind == .riddle) && !finished, let prompt = challenge.kind == .riddle ? riddlePrompt : readPrompt {
      Text(prompt.text).font(.title2.weight(.semibold)).multilineTextAlignment(.center)
      ForEach(Array(prompt.choices.enumerated()), id: \.offset) { index, choice in
       Button(choice) { chooseMeaning(index, prompt: prompt) }.buttonStyle(MorningButtonStyle(primary: false)).accessibilityIdentifier("readChoice-\(index)")
      }
     }
     if challenge.kind == .readAloud, let item = readAloudItem {
      if speechListening {
       Label(appText("Listening…"), systemImage: "mic.fill").font(.headline)
        .symbolEffect(.pulse, isActive: !reduceMotion).accessibilityIdentifier("listeningIndicator")
      }
      ReadingFeedbackView(target: item.text, language: item.language, transcript: transcript, ended: speechEnded)
      if !finished {
       Text(String(format: appText("You have about %d seconds. Read at your own pace."), Int(ReadAloudAttempt(target: item.text, language: item.language).listeningDuration))).font(.footnote).foregroundStyle(MorningTheme.muted)
       Button { Task { await playExample() } } label: {
        Label(appText(spokenExample.isSpeaking ? "Stop example" : "Hear sentence"), systemImage: spokenExample.isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
       }.buttonStyle(MorningButtonStyle(primary: false)).disabled(busy || stopping || preparingExample || speech != nil).accessibilityIdentifier("hearSentence")
      }
     }
     if challenge.kind == .pushUps && camera == nil && !finished {
      Text(appText("The camera counts push-ups on this iPhone. Video is not saved or uploaded.")).font(.footnote).foregroundStyle(MorningTheme.muted)
     }
     if challenge.kind.usesLocalMovement && movementCamera == nil && !finished {
      Text(appText("Camera video stays on this device.")).font(.footnote).foregroundStyle(MorningTheme.muted)
     }
    }.padding(24).frame(maxWidth: .infinity).id("challengeTop")
   }
   .background(MorningTheme.canvas.ignoresSafeArea()).foregroundStyle(MorningTheme.ink)
   .onChange(of: finished) { _, _ in scroll.scrollTo("challengeTop", anchor: .top) }
   .sensoryFeedback(.success, trigger: celebrates) { _, value in value }
   .sensoryFeedback(.increase, trigger: reps)
   .sensoryFeedback(.increase, trigger: rhythmCycles)
   .safeAreaInset(edge: .bottom) {
    VStack(spacing: 12) {
     if finished {
      if celebrates {
       Button(appText("Try again")) { retryChallenge() }.buttonStyle(MorningButtonStyle(primary: false))
        .disabled(busy || stopping || preparingExample).accessibilityIdentifier("retryChallenge")
      }
      Button(appText(rehearsal ? "Back to alarm" : "Back to home")) { dismiss() }.buttonStyle(MorningButtonStyle()).accessibilityIdentifier("backToHome")
     } else {
      if challenge.kind == .pushUps && camera == nil {
       Button { consentDialog = true } label: { ChallengeStartLabel(title: "Start challenge") }.buttonStyle(MorningButtonStyle()).disabled(busy || stopping).accessibilityIdentifier("startChallenge")
      }
      if challenge.kind == .guidedRhythm && rhythmCamera == nil {
       Button { Task { await startRhythm() } } label: { ChallengeStartLabel(title: "Start guided rhythm") }.buttonStyle(MorningButtonStyle()).disabled(busy || stopping).accessibilityIdentifier("startGuidedRhythm")
      }
      if challenge.kind.usesLocalMovement && movementCamera == nil {
       Button { Task { await startMovement() } } label: { ChallengeStartLabel(title: "Start challenge") }.buttonStyle(MorningButtonStyle()).disabled(busy || stopping).accessibilityIdentifier("startLocalMovement")
      }
      if challenge.kind == .readAloud {
       if let speech {
        Button(appText("Finish reading")) { speech.finishReading() }.buttonStyle(MorningButtonStyle()).disabled(busy || stopping || speechFinishing).accessibilityIdentifier("finishReadAloud")
       } else {
        Button { Task { await startSpeech() } } label: { ChallengeStartLabel(title: "Start reading", symbol: "mic.fill") }.buttonStyle(MorningButtonStyle()).disabled(busy || stopping || preparingExample || spokenExample.isSpeaking).accessibilityIdentifier("startReadAloud")
       }
      }
      if !rehearsal {
      TimelineView(.periodic(from: .now, by: 1)) { context in
       let remaining = max(0, Int(ceil(awakeAvailableAt.timeIntervalSince(context.date))))
       Button { finish(.selfConfirmed) } label: {
        VStack(spacing: 4) {
         Text(appText("I’m awake"))
         if remaining > 0 { Text(String(format: appText("Available in %d:%02d"), remaining / 60, remaining % 60)).font(.footnote).monospacedDigit() }
        }
       }.buttonStyle(MorningButtonStyle(primary: challenge.kind == .none)).disabled(remaining > 0 || stopping).accessibilityIdentifier("confirmAwake")
      }
      }
      if practicing {
       Button(appText(rehearsal ? "Back to alarm" : "Back to home")) { dismiss() }
        .buttonStyle(.plain).font(.subheadline).underline().foregroundStyle(MorningTheme.muted).frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("backToHome")
      }
     }
    }.padding(.horizontal, 24).padding(.vertical, 12).background(MorningTheme.canvas)
   }
   .tint(MorningTheme.accent)
   .confirmationDialog(appText("Allow the camera to check your push-ups on this iPhone. Video and sound are not saved or uploaded. You can stop at any time."), isPresented: $consentDialog, titleVisibility: .visible) {
    Button(appText("Open camera")) { Task { await startCamera() } }
    Button(appText("Not now")) { consentDialog = false }
   }
   .task {
    guard coordinator == nil else { return }
    model.preview.refresh()
    sessionAlarm = model.access.effectiveAlarm(alarm)
    if let wake = model.activeWake, wake.alarmID == alarm.id, !model.rehearsal { awakeAvailableAt = wake.selfConfirmAvailableAt }
    coordinator = ChallengeCoordinator(alarm: effectiveAlarm, cloud: model.cloud, scheduler: model.scheduler, rehearsal: practicing)
    preparePrompt()
    #if DEBUG
    let arguments = ProcessInfo.processInfo.arguments
    if arguments.contains("--ui-testing"), arguments.contains("--ui-reading-correct-first"), let prompt = readPrompt {
     let correct = prompt.choices[prompt.correctChoiceIndex]
     let choices = [correct] + prompt.choices.enumerated().filter { $0.offset != prompt.correctChoiceIndex }.map(\.element)
     readPrompt = ChallengePrompt(id: prompt.id, text: prompt.text, choices: choices, correctChoiceIndex: 0)
    }
    if arguments.contains("--ui-testing") {
     if arguments.contains("--ui-awake-ready") { awakeAvailableAt = .distantPast }
     else if arguments.contains("--ui-awake-countdown-near-end") { awakeAvailableAt = Date().addingTimeInterval(5) }
    }
    if arguments.contains("--ui-testing"), let index = arguments.firstIndex(of: "--ui-reading-transcript"), arguments.indices.contains(index + 1) {
     readAloudItem = ChallengeContentItem(id: "ui-reading", kind: .readAloud, language: appLocale().identifier, text: appText("Small steps create steady progress."), choices: nil, answerIndex: nil, source: "ui-test", license: "original", attribution: nil)
     transcript = arguments[index + 1]; speechEnded = arguments.contains("--ui-reading-finished")
    }
    if arguments.contains("--ui-testing"), practicing, arguments.contains("--ui-reading-listening") {
     speechListening = true; message = appText("Listening… Read the sentence aloud.")
    }
    if arguments.contains("--ui-testing"), practicing, arguments.contains("--ui-complete-challenge") {
     switch challenge.kind {
     case .pushUps: complete(.localCompleted, success: appText("Push-ups complete."))
     case .guidedRhythm: complete(.localCompleted, success: appText("Guided rhythm completed."))
     case .readAloud:
      if transcript.isEmpty, let item = readAloudItem { transcript = item.text }
      speechEnded = true
      complete(.localCompleted, success: appText("Great reading."))
     case .readAndChoose, .riddle: complete(.localCompleted, success: appText("Correct. Challenge completed!"))
     case .waveHand, .neckRotation, .jumpingJacks, .stretching: complete(.localCompleted, success: appText("Challenge completed"))
     case .none: break
     }
    }
    #endif
   }
    .onChange(of: scene) { _, phase in handleSceneChange(phase) }
    .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification).receive(on: RunLoop.main), perform: handleAudioInterruption)
    .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification).receive(on: RunLoop.main), perform: handleAudioRouteChange)
    .onDisappear(perform: handleDisappear)
  }
  .overlay {
   if practicing, celebrates, !reduceMotion { ChallengeConfetti().ignoresSafeArea() }
  }
  .interactiveDismissDisabled(!practicing)
 }

 private var distanceLayout: Bool {
  guard movementCamera != nil || rhythmCamera != nil else { return false }
  return challenge.kind == .jumpingJacks || (challenge.kind == .guidedRhythm && (challenge.rhythmVariant ?? .standing) == .standing)
 }

 private var testingTrackingOverlay:Bool {
  #if DEBUG
  ProcessInfo.processInfo.arguments.contains("--ui-testing") && ProcessInfo.processInfo.arguments.contains("--ui-tracking-overlay")
  #else
  false
  #endif
 }
 @ViewBuilder private func cameraBlock(_ session:AVCaptureSession,counter:String)->some View {
  let preview=TrackedCameraPreview(session:session,tracking:tracking,counter:counter,largeCounter:distanceLayout)
  // Keep the complete portrait camera frame, including the person and the room.
  preview.aspectRatio(3.0/4.0,contentMode:.fit).frame(maxWidth:300)
   .frame(maxWidth:.infinity)
 }

 private func beginCoaching() {
  voice?.stop()
  let coach = VoiceCoach()
  voice = coach
  coach.speak(spokenMovementCue)
 }
 private var spokenMovementCue:String {
  switch challenge.kind {
  case .pushUps:return appText("Lower yourself, then push up.")
  case .waveHand:return appText("Wave your hand side to side.")
  case .neckRotation:return appText("Turn your head to each side, then back to the middle.")
  case .jumpingJacks:return appText("Open your arms and legs, then bring them together.")
  case .stretching:return appText("Raise both arms to count one.")
  case .guidedRhythm:return challenge.rhythmVariant == .seated ? appText("Arms down, up, then down.") : appText("Bend your knees, then stand up.")
  default:return challengeInstructions
  }
 }

 @MainActor private func startCamera() async {
  guard !busy, !finished, !stopping, scene == .active, let coordinator, let target = challenge.repetitions else { return }
  busy = true; reps = 0; message = appText("Getting the camera ready…")
  let generation = UUID(); captureGeneration = generation; consent = true; tracking = .empty
  defer { busy = false }
  let capture = CameraCapture(target: target) { update in Task { @MainActor in
   guard captureGeneration == generation, consent, !finished, !stopping else { return }
   if update.reps > reps { voice?.rep(update.reps, spoken: !update.ready) }
   voice?.hint(update.message)
   tracking=update.tracking
   reps = update.reps; message = update.message
   if update.ready { await completePushUps(update.counter) }
   else if update.ended { camera?.stop(); camera = nil; consent = false; await coordinator.suspend() }
  }}
  beginCoaching(); camera = capture; await capture.start()
 }

 @MainActor private func completePushUps(_ counter: PushUpCounter) async {
  guard let coordinator, !busy, !stopping, !finished, consent, scene == .active else { return }
  busy = true; let generation = captureGeneration
  defer { busy = false }
  do {
   let applied = try await coordinator.completePushUps(counter)
   guard captureGeneration == generation, !stopping, scene == .active else { return }
   if applied { complete(.localCompleted, success: appText("Push-ups complete.")) }
  } catch { message = appText("The alarm could not be stopped just now. Please try again.") }
 }

 private func finish(_ outcome: WakeOutcome, success: String? = nil) {
  guard !finished, !stopping, let coordinator else { return }
  guard outcome != .selfConfirmed || Date() >= awakeAvailableAt else { return }
  stopping = true; message = appText("Finishing your challenge…")
  pauseResources()
  Task { @MainActor in
   defer { stopping = false }
   do { try await coordinator.finish(outcome); complete(coordinator.session.outcome ?? outcome, success: success) }
   catch { message = appText("The alarm could not be stopped just now. Please try again.") }
  }
 }

 private func complete(_ outcome: WakeOutcome, success: String? = nil) {
  guard !finished else { return }
  pauseResources(); completion = outcome
  model.recordMorning(id: historyID, alarm: performedAlarm, outcome: outcome, rehearsal: practicing)
  if !practicing, celebrates { model.celebrationID = reduceMotion ? nil : UUID(); dismiss(); return }
  switch outcome {
  case .localCompleted: result = success ?? appText("Challenge completed")
  case .openaiVerified, .aiVerified: result = appText("Movement checked.")
  case .selfConfirmed: result = appText("You confirmed you are awake.")
  case .dismissed: break
  }
  if let result { voice?.speak(result) }
 }

 private func retryChallenge() {
  guard celebrates, !busy, !stopping, !preparingExample, scene == .active else { return }
  pauseResources()
  retrying = true
  coordinator = ChallengeCoordinator(alarm: effectiveAlarm, cloud: model.cloud, scheduler: model.scheduler, rehearsal: true)
  transcript = ""; speechEnded = false; reps = 0; rhythmCycles = 0; consentDialog = false
  preparePrompt(repickReadAloud: false)
  result = nil; completion = nil; message = challengeInstructions
 }

 private func preparePrompt(repickReadAloud: Bool = true) {
  switch challenge.kind {
  case .readAndChoose: readPrompt = model.nextPrompt(.readAndChoose).flatMap(\.readAndChoosePrompt).map(ChallengePrompts.readAndChoose) ?? readPrompt
  case .riddle: riddlePrompt = model.nextPrompt(.riddle).flatMap(\.readAndChoosePrompt).map(ChallengePrompts.readAndChoose) ?? riddlePrompt
  case .readAloud: if repickReadAloud || readAloudItem == nil { readAloudItem = model.nextPrompt(.readAloud) ?? readAloudItem }
  default: break
  }
  message = challengeInstructions
 }

 private var challengeInstructions: String {
  switch challenge.kind {
  case .none: return appText("You can confirm you’re awake when the countdown ends.")
  case .pushUps: return appText("Place your phone to the side so your whole body is visible. Start the camera, then do your push-ups. Each full down-and-up movement counts once.")
  case .readAndChoose: return appText("Read the sentence, then choose the closest meaning. You can try again.")
  case .riddle: return appText("Solve the riddle, then choose your answer. You can try again.")
  case .waveHand: return appText("Place your hand in view and wave it side to side. Video stays on this device.")
  case .neckRotation: return appText("Keep your face visible and turn your head left and right. Video stays on this device.")
  case .jumpingJacks: return appText("Keep your whole body visible and complete 10 gentle jumping jacks. Video stays on this device.")
  case .stretching: return appText("Keep both shoulders and elbows in view. Raise both arms to count one. Lower them before raising them again.")
  case .guidedRhythm: return challenge.rhythmVariant == .seated ? appText("Stay seated. Lower your arms, raise them, then lower them. Complete 3 cycles. Video stays on this device.") : appText("Stand sideways in view, bend your knees gently, then stand again.")
  case .readAloud: return appText("Tap Start reading, then read the sentence aloud. Match at least 80% of the words.")
  }
 }

 private func chooseMeaning(_ index: Int, prompt: ChallengePrompt) {
  if prompt.isCorrect(choiceIndex: index) { finish(.localCompleted, success: appText("Correct. Challenge completed!")) }
  else { message = appText(challenge.kind == .riddle ? "Not quite. Think it over and try again." : "Not quite. Read the sentence and try again.") }
 }

 @MainActor private func startRhythm() async {
  guard rhythmCamera == nil, !busy, !finished, !stopping, scene == .active else { return }; busy = true; message = appText("Getting the camera ready…")
  let generation = UUID(); captureGeneration = generation
  tracking = .empty
  let capture = GuidedRhythmCapture(variant: challenge.rhythmVariant ?? .standing, targetCycles: 3) { update in Task { @MainActor in
   guard captureGeneration == generation, !finished, !stopping else { return }
   if update.cycles > rhythmCycles { voice?.rep(update.cycles, spoken: !update.completed) }
   voice?.hint(update.message)
   tracking=update.tracking
   rhythmCycles = update.cycles; message = update.message
   if update.completed { finish(.localCompleted, success: appText("Guided rhythm completed.")) }
   else if update.ended { rhythmCamera?.stop(); rhythmCamera = nil }
  }}
  beginCoaching(); rhythmCamera = capture; await capture.start(); busy = false
 }

 @MainActor private func startMovement() async {
  guard movementCamera == nil, !busy, !finished, !stopping, scene == .active, challenge.kind.usesLocalMovement else { return }
  busy = true; message = appText("Getting the camera ready…")
  let generation = UUID(); captureGeneration = generation
  tracking = .empty
  let capture = MovementChallengeCapture(kind: challenge.kind) { update in Task { @MainActor in
   guard captureGeneration == generation, !finished, !stopping else { return }
   if update.reps > reps { voice?.rep(update.reps, spoken: !update.ready) }
   voice?.hint(update.message)
   tracking=update.tracking
   reps = update.reps; message = update.message
   if update.ready { finish(.localCompleted, success: appText("Challenge completed")) }
   else if update.ended { movementCamera?.stop(); movementCamera = nil }
  }}
  beginCoaching(); movementCamera = capture; await capture.start(); busy = false
 }

 @MainActor private func startSpeech() async {
  guard speech == nil, !busy, !finished, !stopping, !preparingExample, !spokenExample.isSpeaking, scene == .active, let item = readAloudItem else { return }; busy = true
  transcript = ""; speechEnded = false; speechFinishing = false; speechListening = false
  let generation = UUID(); captureGeneration = generation
  let capture = SpeechChallengeCapture(target: item.text, language: item.language) { update in Task { @MainActor in
   guard captureGeneration == generation, !finished, !stopping else { return }
   if update.unsupported, !practicing { fallBackToReading(); return }
   transcript = update.transcript; speechEnded = update.ended; speechFinishing = update.finishing && !update.ended; speechListening = update.listening; message = update.message
   if update.completed { finish(.localCompleted, success: appText("Great reading.")) }
   else if update.ended { speech?.stop(); speech = nil }
  }}
  speech = capture; await capture.start(); busy = false
 }

 private func fallBackToReading() {
  pauseResources()
  readAloudFallback = true; readAloudItem = nil
  transcript = ""; speechEnded = false
  preparePrompt()
  message = ["en", "vi"].map { appText("Reading aloud isn't available on this iPhone, so here is a reading question instead.", language: $0) }.joined(separator: "\n")
 }

 @MainActor private func playExample() async {
  guard !busy, !finished, !stopping, !preparingExample, scene == .active else { return }
  if spokenExample.isSpeaking { spokenExample.stop(); return }
  preparingExample = true
  defer { preparingExample = false }
  let generation = UUID(); captureGeneration = generation
  let previous = speech; speech = nil
  await previous?.stopAndWait()
  guard captureGeneration == generation, !finished, !stopping, scene == .active else { return }
  transcript = ""; speechEnded = false; speechFinishing = false
  guard let item = readAloudItem else { return }
  message = spokenExample.play(item.text, language: item.language) ? appText("Listen to the example, then tap Start reading.") : appText("This voice is not available. You can still read the sentence.")
 }

 private func pauseResources() {
  captureGeneration = UUID(); consent = false; speechListening = false; speechFinishing = false; tracking = .empty
  voice?.stop()
  camera?.stop(); camera = nil
  movementCamera?.stop(); movementCamera = nil
  rhythmCamera?.stop(); rhythmCamera = nil
  speech?.stop(); speech = nil
  spokenExample.stop()
 }

  // MARK: - Lifecycle
  @MainActor private func handleSceneChange(_ phase: ScenePhase) {
   if phase != .active { spokenExample.stop() }
   guard phase == .background, !finished else { return }
   pauseResources()
   message = appText("The challenge is paused. Start it again, or tap I’m awake when it unlocks.")
   Task { @MainActor in await coordinator?.suspend() }
  }

  @MainActor private func handleDisappear() {
   pauseResources()
   guard !finished else { return }
   Task { @MainActor in await coordinator?.suspend() }
  }

  @MainActor private func handleAudioInterruption(_ notification: Notification) {
   guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt else { return }
   if AVAudioSession.InterruptionType(rawValue: raw) == .began { spokenExample.stop() }
  }

  @MainActor private func handleAudioRouteChange(_ notification: Notification) {
   guard let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt else { return }
   if AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable { spokenExample.stop() }
  }
}

private struct ChallengeStartLabel: View {
 let title: String
 var symbol = "play.circle.fill"
 @Environment(\.accessibilityReduceMotion) private var reduceMotion
 @Environment(\.isEnabled) private var enabled
 @State private var animate = false
 var body: some View {
  Label(appText(title), systemImage: symbol)
   .symbolEffect(.bounce, options: .repeat(3).speed(0.8), value: animate)
   .symbolEffectsRemoved(reduceMotion || !enabled)
   .onAppear { if !reduceMotion { animate = true } }
 }
}

struct ReadingFeedbackView: View {
 let target: String
 var language = "en"
 let transcript: String
 let ended: Bool
 private var feedback: RecognizedWordMatch.Feedback { RecognizedWordMatch.feedback(target: target, recognized: transcript, finished: ended, language: language) }
 var body: some View {
  let feedback = feedback
  VStack(spacing: 12) {
   Text(highlightedPrompt(feedback)).font(.title2.weight(.semibold)).multilineTextAlignment(.center)
    .accessibilityIdentifier("readingPrompt").accessibilityLabel(target).accessibilityValue(wordSummary(feedback))
   Text(String(format: appText("Word match: %d/100"), Int((feedback.score * 100).rounded())))
    .font(.headline).accessibilityIdentifier("readingScore")
   ProgressView(value: feedback.score, total: 1).accessibilityLabel(appText("Word match score"))
   Text(appText("Matched words are green. Underlined words need practice. Gray words have not been read yet."))
    .font(.footnote).foregroundStyle(MorningTheme.muted)
   let incorrect = feedback.words.filter { $0.status == .incorrect }.map(\.text)
   if !incorrect.isEmpty {
    Text(String(format: appText("Needs practice: %@"), incorrect.joined(separator: ", ")))
     .font(.footnote).frame(maxWidth: .infinity, alignment: .leading).accessibilityIdentifier("readingIncorrectWords")
   }
   if !feedback.extraWords.isEmpty {
    Text(String(format: appText("Extra words: %@"), feedback.extraWords.joined(separator: ", ")))
     .font(.footnote).frame(maxWidth: .infinity, alignment: .leading).accessibilityIdentifier("readingExtraWords")
   }
   if !transcript.isEmpty {
    Text(String(format: appText("Heard: %@"), transcript)).foregroundStyle(MorningTheme.muted).accessibilityIdentifier("speechTranscript")
   }
   Text(appText("The score compares recognized words with the sentence; it does not measure accent or pronunciation quality."))
    .font(.footnote).foregroundStyle(MorningTheme.muted)
  }
 }

 private func wordSummary(_ feedback: RecognizedWordMatch.Feedback) -> String {
  [RecognizedWordMatch.WordStatus.correct, .incorrect, .pending].map { status in
   let words = feedback.words.filter { $0.status == status }.map(\.text).joined(separator: ", ")
   return String(format: appText(status == .correct ? "Correct: %@" : status == .incorrect ? "Needs practice: %@" : "Not read yet: %@"), words)
  }.joined(separator: "; ")
 }

 private func highlightedPrompt(_ feedback: RecognizedWordMatch.Feedback) -> AttributedString {
  var result = AttributedString(), index = 0
  for (position, part) in target.split(whereSeparator: \.isWhitespace).enumerated() {
   if position > 0 { result += AttributedString(" ") }
   var word = AttributedString(String(part))
   let count = RecognizedWordMatch.tokens(in: String(part), language: language).count
   let statuses = feedback.words.dropFirst(index).prefix(count).map(\.status)
   if statuses.contains(.incorrect) { word.foregroundColor = .red; word.underlineStyle = .single }
   else if !statuses.isEmpty, statuses.allSatisfy({ $0 == .correct }) { word.foregroundColor = MorningTheme.correctWord; word.inlinePresentationIntent = .stronglyEmphasized }
   else { word.foregroundColor = MorningTheme.muted }
   result += word; index += count
  }
  return result
 }
}
