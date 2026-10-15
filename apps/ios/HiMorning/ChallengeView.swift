import SwiftUI
import AVFoundation
import HiMorningCore
struct CameraPreview:UIViewRepresentable {
 let session:AVCaptureSession
 final class Preview:UIView {override class var layerClass:AnyClass {AVCaptureVideoPreviewLayer.self}}
 func makeUIView(context:Context)->Preview {let view=Preview();let layer=view.layer as! AVCaptureVideoPreviewLayer;layer.session=session;layer.videoGravity = .resizeAspectFill;return view}
 func updateUIView(_ uiView:Preview,context:Context) {}
}
struct ChallengeView:View {
 let alarm:SavedAlarm
 @State private var sessionAlarm:SavedAlarm?
 private var effectiveAlarm:SavedAlarm {sessionAlarm ?? model.access.effectiveAlarm(alarm)}
 private var challenge:ChallengeSelection {effectiveAlarm.challenge}
 @ObservedObject var model:PilotModel
 @Environment(\.dismiss) private var dismiss
 @Environment(\.scenePhase) private var scene
 @State private var coordinator:ChallengeCoordinator?
 @State private var camera:CameraCapture?
 @State private var rhythmCamera:GuidedRhythmCapture?
 @State private var speech:SpeechChallengeCapture?
 @StateObject private var spokenExample=SpokenExample()
 @State private var preparingExample=false
 @State private var captureGeneration=UUID()
 @State private var rhythmCycles=0
 @State private var transcript=""
 @State private var speechScore=0.0
 @State private var readPrompt=EnglishChallengeContent.readAndChoose[0]
 @State private var readAloudPrompt=EnglishChallengeContent.readAloud[0]
 @State private var message=appText("Good morning. Choose what feels right today.")
 @State private var reps=0
 @State private var consent=false
 @State private var busy=false
 @State private var consentDialog=false
 @State private var finished=false
 @State private var historyID=UUID()
 @State private var stopping=false
 @State private var result:String?
 var body:some View {
  ScrollView {
   VStack(spacing:24) {
    Text(model.rehearsal ? appText("Try a challenge") : appText("Good morning ☀️")).font(.headline)
    if model.rehearsal {Text(appText("Practice only. Your alarms stay as they are.")).font(.footnote).foregroundStyle(MorningTheme.muted)}
    if let camera {
     CameraPreview(session:camera.session).frame(height:280).clipShape(RoundedRectangle(cornerRadius:24))
      .overlay(alignment:.bottom) {Text("\(reps) / \(challenge.repetitions ?? 0)").font(.largeTitle.bold()).padding(12).background(.regularMaterial,in:Capsule()).padding()}
    } else if let rhythmCamera {
     CameraPreview(session:rhythmCamera.session).frame(height:280).clipShape(RoundedRectangle(cornerRadius:24))
      .overlay(alignment:.bottom) {Text("\(rhythmCycles) / 3").font(.largeTitle.bold()).padding(12).background(.regularMaterial,in:Capsule()).padding()}
    } else {
     MorningSun()
     Text(String(format:"%02d:%02d",alarm.time.hour,alarm.time.minute)).font(.system(.largeTitle,design:.rounded).weight(.regular)).monospacedDigit()
    }
    Text(challenge.displayTitle).font(.subheadline.weight(.medium)).padding(.horizontal,14).padding(.vertical,8).background(MorningTheme.soft,in:Capsule())
    if effectiveAlarm.mode != alarm.mode || challenge != alarm.challenge {Text(appText("Your preview has ended. This morning uses the basic challenge. Your saved choice stays the same.")).font(.footnote).foregroundStyle(MorningTheme.muted)}
    if challenge.kind == .readAndChoose && !finished {
     Text(appText(readPrompt.sentence)).font(.title2.weight(.semibold)).multilineTextAlignment(.center)
     ForEach(Array(readPrompt.choices.enumerated()),id:\.offset) {index,key in
      Button(appText(key)) {chooseMeaning(index)}.buttonStyle(MorningButtonStyle(primary:false)).accessibilityIdentifier("readChoice-\(index)")
     }
    }
    if challenge.kind == .readAloud && !finished {
     Text(appText(readAloudPrompt.text)).font(.title2.weight(.semibold)).multilineTextAlignment(.center)
     Button {Task {await playExample()}} label: {
      Label(appText(spokenExample.isSpeaking ? "Stop example" : "Hear sentence"),systemImage:spokenExample.isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
     }.buttonStyle(MorningButtonStyle(primary:false)).disabled(busy || stopping || preparingExample).accessibilityIdentifier("hearSentence")
     if !transcript.isEmpty {Text(transcript).foregroundStyle(MorningTheme.muted).accessibilityIdentifier("speechTranscript")}
     if speechScore>0 {ProgressView(value:speechScore,total:1).accessibilityLabel(appText("Recognized-word match"))}
    }
    Text(result ?? message).font(.title3.weight(.medium)).multilineTextAlignment(.center).accessibilityIdentifier("challengeMessage")
   }.padding(24).frame(maxWidth:.infinity)
  }.background(MorningTheme.canvas.ignoresSafeArea()).foregroundStyle(MorningTheme.ink)
   .safeAreaInset(edge:.bottom) {
    VStack(spacing:12) {
     if challenge.kind == .pushUps && camera == nil && !finished {
      Button(appText("Start AI challenge")) {consentDialog=true}.buttonStyle(MorningButtonStyle()).disabled(busy || stopping).accessibilityIdentifier("startChallenge")
     }
     if challenge.kind == .guidedRhythm && rhythmCamera == nil && !finished {
      Button(appText("Start guided rhythm")) {Task {await startRhythm()}}.buttonStyle(MorningButtonStyle()).disabled(busy || stopping).accessibilityIdentifier("startGuidedRhythm")
     }
     if challenge.kind == .readAloud && speech == nil && !finished {
      Button(appText("Start reading")) {Task {await startSpeech()}}.buttonStyle(MorningButtonStyle()).disabled(busy || stopping || preparingExample || spokenExample.isSpeaking).accessibilityIdentifier("startReadAloud")
     }
     if finished {Button(appText("Back to home")) {dismiss()}.buttonStyle(MorningButtonStyle())}
     else {
      Button(appText("I’m awake")) {finish(.selfConfirmed)}.buttonStyle(MorningButtonStyle(primary:challenge.kind == .none))
      Button(model.rehearsal ? appText("End practice") : appText("Stop alarm"),role:.destructive) {finish(.dismissed)}
       .buttonStyle(.plain).font(.subheadline).underline().foregroundStyle(MorningTheme.muted).frame(maxWidth:.infinity,minHeight:44).accessibilityIdentifier("stopAlarm")
     }
    }.padding(.horizontal,24).padding(.vertical,12).background(MorningTheme.canvas)
   }.tint(MorningTheme.accent)
   .confirmationDialog(appText("Movement photos go through HiMorning to OpenAI for checking. No audio is recorded. HiMorning does not save these photos; OpenAI data policies apply. You can stop at any time."),isPresented:$consentDialog,titleVisibility:.visible) {
    Button(appText("Agree and open camera")) {Task {await startCamera()}}
    Button(appText("Choose another way")) {consentDialog=false}
   }
   .task {
    guard coordinator == nil else {return}
    model.preview.refresh()
    // Keep one target throughout an active challenge, including at preview expiry.
    sessionAlarm=model.access.effectiveAlarm(alarm)
    coordinator=ChallengeCoordinator(alarm:effectiveAlarm,cloud:model.cloud,scheduler:model.scheduler,rehearsal:model.rehearsal)
    preparePrompt()
   }
   .onChange(of:scene) {_,value in if value == .background && !finished {pauseResources();message=appText("The challenge is paused. You can choose another way.");Task {await coordinator?.suspend()}}}
   .onChange(of:scene) {_,value in if value != .active {spokenExample.stop()}}
   .onReceive(NotificationCenter.default.publisher(for:AVAudioSession.interruptionNotification).receive(on:RunLoop.main)) {notification in
    if let raw=notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,AVAudioSession.InterruptionType(rawValue:raw) == .began {spokenExample.stop()}
   }
   .onReceive(NotificationCenter.default.publisher(for:AVAudioSession.routeChangeNotification).receive(on:RunLoop.main)) {notification in
    if let raw=notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,AVAudioSession.RouteChangeReason(rawValue:raw) == .oldDeviceUnavailable {spokenExample.stop()}
   }
   .onDisappear {pauseResources();if !finished {Task {await coordinator?.suspend()}}}
 }
 @MainActor private func startCamera() async {
  guard !busy,!finished,!stopping,scene == .active,let coordinator,let target=challenge.repetitions else {return};busy=true
  let generation=UUID();captureGeneration=generation
  defer {busy=false}
  do {
   try await coordinator.startCloud(consent:true)
   guard coordinator.session.outcome == nil,captureGeneration == generation,scene == .active,!stopping else {return}
   consent=true
   let capture=CameraCapture(target:target) {update in Task {@MainActor in
    guard captureGeneration == generation,consent,!finished,!stopping else {return};reps=update.reps;message=update.message
    if update.ready {await submit(update.frames)}
   }}
   camera=capture;await capture.start()
  } catch {message=appText("AI is not available. You can confirm you are awake or stop.")}
 }
 @MainActor private func submit(_ frames:[EvidenceFrame]) async {
  guard let coordinator,!busy else {return};busy=true
  defer {busy=false}
  do {
   if try await coordinator.submit(frames) {finished=true;pauseResources();result=appText("Movement checked. Have a good morning!");model.recordMorning(id:historyID,outcome:.openaiVerified,rehearsal:model.rehearsal)}
   else if coordinator.session.outcome == nil {message=appText("The movement could not be fully checked. You can choose another way.")}
  } catch {message=appText("The movement could not be checked right now. You can still stop.")}
 }
 private func finish(_ outcome:WakeOutcome,success:String?=nil) {
  guard !finished,!stopping,let coordinator else {return}
  stopping=true
  pauseResources()
  Task {@MainActor in
   defer {stopping=false}
   do {try await coordinator.finish(outcome);pauseResources();model.recordMorning(id:historyID,outcome:coordinator.session.outcome ?? outcome,rehearsal:model.rehearsal);finished=true
    switch outcome {
    case .localCompleted:result=success ?? appText("Local challenge completed. Have a good morning!")
    case .selfConfirmed:result=appText("You confirmed you are awake. Have a good morning!")
    case .dismissed:result=model.rehearsal ? appText("Practice ended. Your alarms are unchanged.") : appText("Alarm stopped. Take care today.")
    case .openaiVerified:break
    }
   }
   catch {message=appText("The alarm could not be stopped here. Please use the system Stop button.")}
  }
 }
 private func preparePrompt() {
  let index=Int(alarm.id.uuid.0)
  readPrompt=EnglishChallengeContent.readAndChoose[index % EnglishChallengeContent.readAndChoose.count]
  readAloudPrompt=EnglishChallengeContent.readAloud[index % EnglishChallengeContent.readAloud.count]
  switch challenge.kind {
  case .none:message=appText("Confirm you are awake when you are ready.")
  case .pushUps:message=appText("Complete the selected push-ups in view of the camera.")
  case .readAndChoose:message=appText("Choose the closest meaning.")
  case .guidedRhythm:message=challenge.rhythmVariant == .seated ? appText("Stay seated. Lower your arms, raise them, then lower them. Complete 3 cycles. Video stays on this device.") : appText("Stand, bend your knees gently, then stand again. Complete 3 cycles. Video stays on this device.")
  case .readAloud:message=appText("Speech is recognized on this device. This checks words, not accent quality.")
  }
 }
 private func chooseMeaning(_ index:Int) {
  if readPrompt.isCorrect(choiceIndex:index) {finish(.localCompleted,success:appText("Correct. Challenge completed!"))}
  else {message=appText("Not quite. Read the sentence and try again.")}
 }
 @MainActor private func startRhythm() async {
  guard rhythmCamera == nil,!busy,!finished,!stopping,scene == .active else {return};busy=true
  let generation=UUID();captureGeneration=generation
  let capture=GuidedRhythmCapture(variant:challenge.rhythmVariant ?? .standing,targetCycles:3) {update in Task {@MainActor in
   guard captureGeneration == generation,!finished,!stopping else {return}
   rhythmCycles=update.cycles;message=update.message
   if update.completed {finish(.localCompleted,success:appText("Guided rhythm completed. Have a good morning!"))}
   else if update.ended {rhythmCamera?.stop();rhythmCamera=nil}
  }}
  rhythmCamera=capture;await capture.start();busy=false
 }
 @MainActor private func startSpeech() async {
  guard speech == nil,!busy,!finished,!stopping,!preparingExample,!spokenExample.isSpeaking,scene == .active else {return};busy=true
  transcript="";speechScore=0
  let generation=UUID();captureGeneration=generation
  let capture=SpeechChallengeCapture(target:appText(readAloudPrompt.text)) {update in Task {@MainActor in
   guard captureGeneration == generation,!finished,!stopping else {return}
   transcript=update.transcript;speechScore=update.score;message=update.message
   if update.completed {finish(.localCompleted,success:appText("Read aloud completed. Have a good morning!"))}
   else if update.ended {speech?.stop();speech=nil}
  }}
  speech=capture;await capture.start();busy=false
 }
 @MainActor private func playExample() async {
  guard !busy,!finished,!stopping,!preparingExample,scene == .active else {return}
  if spokenExample.isSpeaking {spokenExample.stop();return}
  preparingExample=true
  defer {preparingExample=false}
  let generation=UUID();captureGeneration=generation
  let previous=speech;speech=nil
  await previous?.stopAndWait()
  guard captureGeneration == generation,!finished,!stopping,scene == .active else {return}
  transcript="";speechScore=0
  message=spokenExample.play(appText(readAloudPrompt.text)) ? appText("Listen to the example, then tap Start reading.") : appText("The English voice is not available. You can still read the sentence.")
 }
 private func pauseResources() {
  captureGeneration=UUID();consent=false
  camera?.stop();camera=nil
  rhythmCamera?.stop();rhythmCamera=nil
  speech?.stop();speech=nil
  spokenExample.stop()
 }
}
