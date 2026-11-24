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
 private var trialOccurrence:Date? {
  guard !practicing,let wake=model.activeWake,wake.alarmID == alarm.id else {return nil}
  return wake.occurrence
 }
 private var effectiveAlarm: SavedAlarm { sessionAlarm ?? model.access.effectiveAlarm(alarm,occurrence:trialOccurrence,rehearsal:practicing) }
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
 @State private var answerSound=SoundPreview()
 @Environment(\.scenePhase) private var scene
 @State private var coordinator: ChallengeCoordinator?
 @State private var camera: CameraCapture?
 @State private var movementCamera: MovementChallengeCapture?
 @State private var rhythmCamera: GuidedRhythmCapture?
 @State private var lightCamera: MorningLightCapture?
 @State private var lightProgress: Double = 0
 @State private var lightConsentDialog = false
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
 @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
 private var isContentChallenge:Bool {[ChallengeKind.readAndChoose,.riddle,.readAloud].contains(challenge.kind)}
 private var scrollCompletionActions:Bool {isContentChallenge}
 private var celebrates: Bool { completion == .localCompleted || completion == .openaiVerified || completion == .aiVerified }
 @State private var historyID = UUID()
 @State private var stopping = false
 @State private var result: String?

 var body: some View {
  ZStack {
   MorningTheme.canvas.ignoresSafeArea()
   if practicing, celebrates, !reduceMotion {
    ChallengeConfetti().ignoresSafeArea().opacity(0.6)
   }
   ScrollViewReader { scroll in
    ScrollView {
    VStack(spacing: isContentChallenge ? 14 : 20) {
     if celebrates {
      ChallengeCelebrationView(isQuestion:challenge.kind == .readAndChoose || challenge.kind == .riddle)
     } else {
      Text(practicing ? appText("Try a challenge") : appText("Good morning ☀️")).font(.headline)
      if practicing { Text(appText("Practice only. Your alarms stay as they are, and this does not count toward progress.")).font(.footnote).foregroundStyle(MorningTheme.muted) }
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
      } else if let lightCamera {
       VStack(spacing: 12) {
        CameraPreview(session: lightCamera.session)
         .aspectRatio(3.0 / 4.0, contentMode: .fit)
         .frame(maxWidth: 260)
         .clipShape(RoundedRectangle(cornerRadius: 20))
        ProgressView(value: lightProgress, total: 1.0)
         .tint(MorningTheme.yellow)
         .frame(maxWidth: 240)
       }
      } else if challenge.kind.hasMovementIllustration {
       MovementGuide(selection:challenge,mode:effectiveAlarm.mode)
      } else if !practicing || !isContentChallenge {
       HStack(spacing: 16) {
        MorningSun(size: isContentChallenge ? 32 : 64)
        Text(alarmTimeText(alarm.time)).font(.system(isContentChallenge ? .title3 : .largeTitle, design: .rounded).weight(.regular)).monospacedDigit()
       }
      }
     }
     Label {
      Text(challenge.displayTitle)
     } icon: {
      ChallengeIcon(kind:challenge.kind,seated:challenge.rhythmVariant == .seated,size:19)
       .foregroundStyle(MorningTheme.modeAccent(effectiveAlarm.mode))
     }.font(.subheadline.weight(.semibold)).padding(.horizontal,14).padding(.vertical,8).background(MorningTheme.soft,in:Capsule())
     if let theme = contentTheme {
      Text(ChallengePrompts.themeTitle(theme)).font(.caption.weight(.semibold)).foregroundStyle(MorningTheme.muted)
       .accessibilityIdentifier("contentTheme")
     }
     if celebrates,let explanation = contentExplanation {
      VStack(alignment:.leading,spacing:8) {
       if let prompt=challenge.kind == .riddle ? riddlePrompt : readPrompt {
        Text(prompt.text).font(.subheadline).foregroundStyle(MorningTheme.muted)
       }
       Text(appText("Why it’s right")).font(.headline)
       Text(explanation).font(.body).fixedSize(horizontal:false,vertical:true).accessibilityIdentifier("contentExplanation")
      }.padding(16).frame(maxWidth:.infinity,alignment:.leading).background(MorningTheme.soft,in:RoundedRectangle(cornerRadius:18))
     }
     if !practicing,trialOccurrence == nil || trialOccurrence != alarm.challengeTrial?.occurrence, effectiveAlarm.challenge != alarm.challenge {
      Text(appText("This alarm is using a free challenge.")).font(.footnote).foregroundStyle(MorningTheme.muted)
     }
     if !finished,challenge.kind.hasMovementIllustration,camera != nil || movementCamera != nil || rhythmCamera != nil {
      MovementGuide(selection:challenge,mode:effectiveAlarm.mode,compact:true)
     }
     if celebrates && practicing {
      Text(appText("Practice complete. A real morning win counts when you complete a challenge after your alarm."))
       .font(.footnote).foregroundStyle(MorningTheme.muted).multilineTextAlignment(.center)
       .accessibilityIdentifier("practiceCompleteExplanation")
     } else if !finished && message == challengeInstructions {
      ChallengeRequirementsView(selection:challenge)
     } else if !celebrates {
     Text(result ?? message)
      .font(distanceLayout ? .system(size: 34, weight: .semibold) : .title3.weight(.medium))
      .minimumScaleFactor(distanceLayout ? 0.6 : 1)
      .multilineTextAlignment(.center)
      .contentTransition(.opacity)
      .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: result ?? message)
      .accessibilityIdentifier("challengeMessage")
     }
     if !finished,challenge.kind != .none,camera == nil,movementCamera == nil,rhythmCamera == nil,!speechListening {
      DisclosureGroup(appText("challenge_guide_scoring_title")) {
       ChallengeCheckingGuide(selection:challenge).padding(.top,8)
      }.font(.footnote.weight(.semibold)).frame(maxWidth:.infinity,alignment:.leading)
       .padding(12).background(MorningTheme.soft,in:RoundedRectangle(cornerRadius:14))
       .accessibilityIdentifier("showChallengeCheckingGuide")
     }
     if !finished && (busy || stopping || speechFinishing || preparingExample) {
      ProgressView().accessibilityLabel(message)
     }
     if (challenge.kind == .readAndChoose || challenge.kind == .riddle) && !finished {
      if let prompt = challenge.kind == .riddle ? riddlePrompt : readPrompt {
       Text(prompt.text)
        .font(.title3.weight(.semibold))
        .lineSpacing(4)
        .frame(maxWidth:.infinity,alignment:.leading)
        .padding(18)
        .background(MorningTheme.surface,in:RoundedRectangle(cornerRadius:MorningTheme.Radius.card))
        .overlay {RoundedRectangle(cornerRadius:MorningTheme.Radius.card).strokeBorder(MorningTheme.line)}
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
       ForEach(Array(prompt.choices.enumerated()), id: \.offset) { index, choice in
        Button(choice) { chooseMeaning(index, prompt: prompt) }
         .buttonStyle(MorningButtonStyle(primary: false))
         .accessibilityIdentifier("readChoice-\(index)")
       }
      } else {
       Text(appText("Try again"))
        .font(.subheadline).foregroundStyle(MorningTheme.muted)
        .frame(maxWidth:.infinity,alignment:.center).padding(18)
        .background(MorningTheme.surface,in:RoundedRectangle(cornerRadius:MorningTheme.Radius.card))
        .overlay {RoundedRectangle(cornerRadius:MorningTheme.Radius.card).strokeBorder(MorningTheme.line)}
      }
     }
     if challenge.kind == .readAloud, let item = readAloudItem {
      if speechListening {
       Label(appText("Listening…"), systemImage: "mic.fill").font(.headline)
        .symbolEffect(.pulse, isActive: !reduceMotion).accessibilityIdentifier("listeningIndicator")
      }
      ReadingFeedbackView(target: item.text, language: item.language, transcript: transcript, ended: speechEnded)
       .id(item.id)
      if !finished {
       Text(String(format: appText("You have about %d seconds. Read at your own pace."), Int(ReadAloudAttempt(target: item.text, language: item.language).listeningDuration))).font(.footnote).foregroundStyle(MorningTheme.muted)
       Button { Task { await playExample() } } label: {
        Label(appText(spokenExample.isSpeaking ? "Stop example" : "Hear an example"), systemImage: spokenExample.isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
       }.buttonStyle(MorningButtonStyle(primary: false)).disabled(busy || stopping || preparingExample || speech != nil).accessibilityIdentifier("hearSentence")
      }
     }
     if finished && scrollCompletionActions { completionActions }
    }.padding(.horizontal, isContentChallenge ? 20 : 24).padding(.top, isContentChallenge ? 20 : 24).padding(.bottom, 32).frame(maxWidth: .infinity).id("challengeTop")
   }
   .foregroundStyle(MorningTheme.ink)
   .onChange(of: finished) { _, _ in scroll.scrollTo("challengeTop", anchor: .top) }
   .sensoryFeedback(.success, trigger: celebrates) { _, value in value }
   .sensoryFeedback(.increase, trigger: reps)
   .sensoryFeedback(.increase, trigger: rhythmCycles)
   .safeAreaInset(edge: .bottom) {
    VStack(spacing: 12) {
     if finished {
      if !scrollCompletionActions { completionActions }
      Button(appText(rehearsal ? "Back to alarm" : "Back to home")) { dismiss() }
       .buttonStyle(.plain).font(.subheadline.weight(.semibold)).foregroundStyle(MorningTheme.ink)
       .frame(maxWidth:.infinity,minHeight:44)
       .background(MorningTheme.soft,in:RoundedRectangle(cornerRadius:MorningTheme.Radius.control))
       .accessibilityIdentifier("backToHome")
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
      if challenge.kind == .morningLight && lightCamera == nil {
       Button { lightConsentDialog = true } label: { ChallengeStartLabel(title: "Start challenge") }.buttonStyle(MorningButtonStyle()).disabled(busy || stopping).accessibilityIdentifier("startMorningLight")
      }
      if challenge.kind == .readAloud {
       if let speech {
        Button(appText("Finish reading")) { speech.finishReading() }.buttonStyle(MorningButtonStyle()).disabled(busy || stopping || speechFinishing).accessibilityIdentifier("finishReadAloud")
       } else {
        Button { Task { await startSpeech() } } label: { ChallengeStartLabel(title: "Start reading", symbol: "mic.fill") }.buttonStyle(MorningButtonStyle()).disabled(busy || stopping || preparingExample || spokenExample.isSpeaking).accessibilityIdentifier("startReadAloud")
       }
      }
      if !rehearsal && (!practicing || challenge.kind == .none) {
      TimelineView(.periodic(from: .now, by: 1)) { context in
       let remaining = challenge.kind == .none ? 0 : max(0, Int(ceil(awakeAvailableAt.timeIntervalSince(context.date))))
       Button { finish(.selfConfirmed) } label: {
        VStack(spacing: 4) {
         Text(appText(challenge.kind == .none ? "Stop alarm" : "I’m awake"))
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
   .confirmationDialog(appText("Allow the camera to check morning light on this iPhone. Video and images are not saved or uploaded."), isPresented: $lightConsentDialog, titleVisibility: .visible) {
    Button(appText("Open camera")) { Task { await startMorningLight() } }
    Button(appText("Not now")) { lightConsentDialog = false }
   }
   .task {
    guard coordinator == nil else { return }
    model.preview.refresh()
    sessionAlarm = model.access.effectiveAlarm(alarm,occurrence:trialOccurrence,rehearsal:practicing)
    if let wake = model.activeWake, wake.alarmID == alarm.id, !model.rehearsal { awakeAvailableAt = wake.selfConfirmAvailableAt }
    coordinator = ChallengeCoordinator(alarm: effectiveAlarm, cloud: model.cloud, scheduler: model.scheduler, rehearsal: practicing)
    preparePrompt()
    #if DEBUG
    let arguments = ProcessInfo.processInfo.arguments
    if arguments.contains("--ui-testing"), arguments.contains("--ui-reading-correct-first"), let prompt = readPrompt {
     let correct = prompt.choices[prompt.correctChoiceIndex]
     let choices = [correct] + prompt.choices.enumerated().filter { $0.offset != prompt.correctChoiceIndex }.map(\.element)
     readPrompt = ChallengePrompt(id: prompt.id, text: prompt.text, choices: choices, correctChoiceIndex: 0, theme: prompt.theme, explanation: prompt.explanation)
    }
    if arguments.contains("--ui-testing") {
     if arguments.contains("--ui-awake-ready") { awakeAvailableAt = .distantPast }
     else if arguments.contains("--ui-awake-countdown-near-end") { awakeAvailableAt = Date().addingTimeInterval(5) }
    }
    if arguments.contains("--ui-testing"), let index = arguments.firstIndex(of: "--ui-reading-transcript"), arguments.indices.contains(index + 1) {
     readAloudItem = ChallengeContentItem(id: "ui-reading", kind: .readAloud, language: "en", text: "Small steps create steady progress.", choices: nil, answerIndex: nil, source: "ui-test", license: "original", attribution: nil)
     transcript = arguments[index + 1]; speechEnded = arguments.contains("--ui-reading-finished")
    }
    if arguments.contains("--ui-testing"), practicing, arguments.contains("--ui-reading-listening") {
     speechListening = true; message = appText("Listening… Read the English passage aloud.")
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
     case .waveHand, .neckRotation, .jumpingJacks, .stretching, .morningLight: complete(.localCompleted, success: appText("Challenge completed"))
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
  case .morningLight:return appText("Point your camera toward a bright window or lamp.")
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
  guard outcome != .selfConfirmed || challenge.kind == .none || Date() >= awakeAvailableAt else { return }
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
  if practicing,outcome == .localCompleted,
     challenge.kind == .readAndChoose || challenge.kind == .riddle,
     let chime=Bundle.main.url(forResource:"answerChime",withExtension:"wav") {
   answerSound.play(url:chime,volume:0.25)
  }
  model.recordMorning(id: historyID, alarm: performedAlarm, outcome: outcome, rehearsal: practicing)
  if !practicing, celebrates, contentExplanation == nil { model.celebrationID = reduceMotion ? nil : UUID(); dismiss(); return }
  switch outcome {
  case .localCompleted: result = success ?? appText("Challenge completed")
  case .openaiVerified, .aiVerified: result = appText("Movement checked.")
  case .selfConfirmed: result = appText("You confirmed you are awake.")
  case .dismissed: break
  }
  if let result { voice?.speak(result) }
 }

 @ViewBuilder private var completionActions:some View {
      if celebrates && practicing && !rehearsal {
       Button(appText("Set an alarm with this challenge")) {model.challengeAfterPractice=performedAlarm.challenge;dismiss()}
        .buttonStyle(MorningButtonStyle()).accessibilityIdentifier("setFirstAlarmAfterPractice")
      }
      if celebrates {
       MorningWinShareButton(
        challengeTitle: challenge.displayTitle,
        completedAt: Date(),
        journeyStep: practicing ? nil : model.journey.journey?.completedCount,
        journeyTotal: 7
       )
      }
      if celebrates && practicing {
       Button(appText("Try again")) { retryChallenge() }.buttonStyle(MorningButtonStyle(primary: false))
        .disabled(busy || stopping || preparingExample).accessibilityIdentifier("retryChallenge")
      }
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
  case .readAndChoose: readPrompt = model.nextPrompt(.readAndChoose).flatMap(ChallengePrompts.fromItem) ?? readPrompt
  case .riddle: riddlePrompt = model.nextPrompt(.riddle).flatMap(ChallengePrompts.fromItem) ?? riddlePrompt
  case .readAloud: if repickReadAloud || readAloudItem == nil { readAloudItem = model.nextPrompt(.readAloud) ?? readAloudItem }
  default: break
  }
  message = challengeInstructions
 }

 private var contentTheme:String? {
  switch challenge.kind {
  case .readAndChoose:return readPrompt?.theme
  case .riddle:return riddlePrompt?.theme
  case .readAloud:return readAloudItem?.theme
  default:return nil
  }
 }
 private var contentExplanation:String? {
  switch challenge.kind {
  case .readAndChoose:return readPrompt?.explanation
  case .riddle:return riddlePrompt?.explanation
  default:return nil
  }
 }

 private var challengeInstructions: String {
  ChallengeRequirements.forSelection(challenge).joined(separator:"\n")
 }

 private func chooseMeaning(_ index: Int, prompt: ChallengePrompt) {
  if prompt.isCorrect(choiceIndex: index) { finish(.localCompleted, success: appText("Correct. Challenge completed!")) }
  else { message = appText(challenge.kind == .riddle ? "Not quite. Think it over and try again." : "Not quite. Read the clues and try again.") }
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

 @MainActor private func startMorningLight() async {
  guard lightCamera == nil, !busy, !finished, !stopping, scene == .active else { return }
  busy = true; lightProgress = 0; message = appText("Getting the camera ready…")
  let availability = await MorningLightCapture.requestAccessIfNeeded()
  guard !finished, !stopping, scene == .active else { busy = false; return }
  guard availability == .ready else {
   busy = false
   message = appText("Morning light isn’t available on this device without a camera.")
   return
  }
  let generation = UUID(); captureGeneration = generation
  let capture = MorningLightCapture(
   onUpdate: { _, state in
    Task { @MainActor in
     guard captureGeneration == generation, !finished, !stopping else { return }
     switch state {
     case .seekingLight:
      lightProgress = 0
      message = appText("Point toward a bright window or lamp")
     case .holding(let progress):
      lightProgress = progress
      message = appText("Hold steady in the light…")
     case .completed:
      lightProgress = 1.0
      finish(.localCompleted, success: appText("Morning light checked."))
     }
    }
   },
   onInterruption: {
    Task { @MainActor in
     lightCamera?.stop(); lightCamera = nil
    }
   }
  )
  if capture.start() {
   lightCamera = capture
   message = appText("Point toward a bright window or lamp")
  } else {
   message = appText("Morning light isn’t available on this device without a camera.")
  }
  busy = false
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
  message = spokenExample.play(item.text, language: item.language) ? appText("Listen to the example, then tap Start reading.") : appText("The sample voice is unavailable. You can still read the passage.")
 }

 private func pauseResources() {
  captureGeneration = UUID(); consent = false; speechListening = false; speechFinishing = false; tracking = .empty
  voice?.stop()
  camera?.stop(); camera = nil
  movementCamera?.stop(); movementCamera = nil
  rhythmCamera?.stop(); rhythmCamera = nil
  lightCamera?.stop(); lightCamera = nil; lightProgress = 0
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
   answerSound.stop()
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
 @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
   ReadingWordLayout {
    ForEach(Array(displayWords(feedback).enumerated()), id: \.offset) { _, word in
     ReadingPromptWord(text: word.text, status: word.status, attemptCleared: transcript.isEmpty)
    }
   }
   .font(.title2.weight(.semibold))
   .padding(.top, 5)
   .accessibilityElement(children: .ignore)
   .accessibilityAddTraits(.isStaticText)
   .accessibilityIdentifier("readingPrompt").accessibilityLabel(target).accessibilityValue(wordSummary(feedback))
   Text(String(format: appText("Word match: %d/100"), Int((feedback.score * 100).rounded())))
    .font(.headline)
    .contentTransition(.numericText())
    .animation(.smooth(duration: 0.2), value: Int((feedback.score * 100).rounded()))
    .accessibilityIdentifier("readingScore")
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
   Text(appText("Your score reflects how closely the words the app hears match the passage."))
    .font(.footnote).foregroundStyle(MorningTheme.muted)
  }
 }

 private func wordSummary(_ feedback: RecognizedWordMatch.Feedback) -> String {
  [RecognizedWordMatch.WordStatus.correct, .incorrect, .pending].map { status in
   let words = feedback.words.filter { $0.status == status }.map(\.text).joined(separator: ", ")
   return String(format: appText(status == .correct ? "Correct: %@" : status == .incorrect ? "Needs practice: %@" : "Not read yet: %@"), words)
  }.joined(separator: "; ")
 }

 private func displayWords(_ feedback: RecognizedWordMatch.Feedback) -> [(text: String, status: RecognizedWordMatch.WordStatus)] {
  var index = 0
  return target.split(whereSeparator: \.isWhitespace).map { part in
   let text = String(part)
   let count = RecognizedWordMatch.tokens(in: text, language: language).count
   let statuses = feedback.words.dropFirst(index).prefix(count).map(\.status)
   index += count
   let status: RecognizedWordMatch.WordStatus
   if statuses.contains(.incorrect) { status = .incorrect }
   else if !statuses.isEmpty, statuses.allSatisfy({ $0 == .correct }) { status = .correct }
   else { status = .pending }
   return (text, status)
  }
 }
}

private struct ReadingPromptWord: View {
 let text: String
 let status: RecognizedWordMatch.WordStatus
 let attemptCleared: Bool
 @Environment(\.accessibilityReduceMotion) private var reduceMotion
 @State private var bounced = false
 @State private var bounceCount = 0

 private var color: Color {
  switch status {
  case .correct: MorningTheme.correctWord
  case .incorrect: .red
  case .pending: MorningTheme.muted
  }
 }

 var body: some View {
  let showMotion = !reduceMotion && !attemptCleared
  Text(text)
   .underline(status == .incorrect)
   .foregroundStyle(color)
   .keyframeAnimator(initialValue: CGFloat.zero, trigger: bounceCount) { content, offset in
    content.offset(y: showMotion ? offset : 0)
   } keyframes: { _ in
    CubicKeyframe(-4, duration: 0.09)
    CubicKeyframe(0, duration: 0.17)
   }
   .onChange(of: attemptCleared) { _, cleared in
    if cleared { bounced = false }
   }
   .onChange(of: status, initial: true) { _, newStatus in
    guard newStatus == .correct, !reduceMotion, !bounced else { return }
    bounced = true
    bounceCount += 1
   }
 }
}

private struct ReadingWordLayout: Layout {
 @ScaledMetric(relativeTo: .title2) private var wordSpacing = 5
 @ScaledMetric(relativeTo: .title2) private var lineSpacing = 6

 private struct Line {
  var indices: [Int] = []
  var width: CGFloat = 0
  var height: CGFloat = 0
 }

 func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
  let width = proposal.width ?? .infinity
  let lines = lines(for: sizes(of: subviews, within: width), width: width)
  let height = lines.reduce(0) { $0 + $1.height } + CGFloat(max(0, lines.count - 1)) * lineSpacing
  return CGSize(width: proposal.width ?? lines.map(\.width).max() ?? 0, height: height)
 }

 func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
  let sizes = sizes(of: subviews, within: bounds.width)
  var y = bounds.minY
  for line in lines(for: sizes, width: bounds.width) {
   var x = bounds.midX - line.width / 2
   for index in line.indices {
    let size = sizes[index]
    subviews[index].place(at: CGPoint(x: x, y: y + (line.height - size.height) / 2),
                          anchor: .topLeading, proposal: ProposedViewSize(size))
    x += size.width + wordSpacing
   }
   y += line.height + lineSpacing
  }
 }

 private func sizes(of subviews: Subviews, within width: CGFloat) -> [CGSize] {
  subviews.map { view in
   let ideal = view.sizeThatFits(.unspecified)
   return ideal.width <= width ? ideal : view.sizeThatFits(ProposedViewSize(width: width, height: nil))
  }
 }

 private func lines(for sizes: [CGSize], width: CGFloat) -> [Line] {
  var lines: [Line] = []
  var line = Line()
  for (index, size) in sizes.enumerated() {
   if !line.indices.isEmpty, line.width + wordSpacing + size.width > width {
    lines.append(line)
    line = Line()
   }
   line.width += (line.indices.isEmpty ? 0 : wordSpacing) + size.width
   line.height = max(line.height, size.height)
   line.indices.append(index)
  }
  if !line.indices.isEmpty { lines.append(line) }
  return lines
 }
}
