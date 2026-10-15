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
 @State private var movementCamera:MovementChallengeCapture?
 @State private var rhythmCamera:GuidedRhythmCapture?
 @State private var speech:SpeechChallengeCapture?
 @StateObject private var spokenExample=SpokenExample()
 @State private var preparingExample=false
 @State private var captureGeneration=UUID()
 @State private var rhythmCycles=0
 @State private var transcript=""
 @State private var speechEnded=false
 @State private var speechFinishing=false
 @State private var speechListening=false
 @State private var awakeAvailableAt=Date().addingTimeInterval(120)
 @Environment(\.accessibilityReduceMotion) private var reduceMotion
 @State private var readPrompt=ChallengePrompts.readAndChoose()!
 @State private var riddlePrompt=ChallengePrompts.riddle()!
 @State private var lastReadPromptID:String?
 @State private var lastRiddlePromptID:String?
 @State private var readAloudPrompt=EnglishChallengeContent.readAloud[0]
 @State private var message=appText("Good morning. Choose what feels right today.")
 @State private var reps=0
 @State private var consent=false
 @State private var busy=false
 @State private var consentDialog=false
 @State private var completion:WakeOutcome?
 @State private var retrying=false
 private var practicing:Bool {model.rehearsal || retrying}
 private var finished:Bool {completion != nil}
 private var celebrates:Bool {completion == .localCompleted || completion == .openaiVerified || completion == .aiVerified}
 @State private var historyID=UUID()
 @State private var stopping=false
 @State private var result:String?
 var body:some View {
  ScrollViewReader {scroll in
  ScrollView {
   VStack(spacing:20) {
    if celebrates {
     ChallengeCelebrationView()
    } else {
    Text(practicing ? appText("Try a challenge") : appText("Good morning ☀️")).font(.headline)
    if practicing {Text(appText("Practice only. Your alarms stay as they are.")).font(.footnote).foregroundStyle(MorningTheme.muted)}
    if let camera {
     CameraPreview(session:camera.session).frame(height:280).clipShape(RoundedRectangle(cornerRadius:24))
      .overlay(alignment:.bottom) {Text("\(reps) / \(challenge.repetitions ?? 0)").font(.largeTitle.bold()).padding(12).background(.regularMaterial,in:Capsule()).padding()}
    } else if let movementCamera {
     CameraPreview(session:movementCamera.session).frame(height:280).clipShape(RoundedRectangle(cornerRadius:24))
      .overlay(alignment:.bottom) {Text("\(reps) / \(challenge.kind.localMovementTarget ?? 0)").font(.largeTitle.bold()).padding(12).background(.regularMaterial,in:Capsule()).padding()}
    } else if let rhythmCamera {
     CameraPreview(session:rhythmCamera.session).frame(height:280).clipShape(RoundedRectangle(cornerRadius:24))
      .overlay(alignment:.bottom) {Text("\(rhythmCycles) / 3").font(.largeTitle.bold()).padding(12).background(.regularMaterial,in:Capsule()).padding()}
    } else {
     HStack(spacing:16) {
      MorningSun(size:64)
      Text(String(format:"%02d:%02d",alarm.time.hour,alarm.time.minute)).font(.system(.largeTitle,design:.rounded).weight(.regular)).monospacedDigit()
     }
    }
    }
    Text(challenge.displayTitle).font(.subheadline.weight(.medium)).padding(.horizontal,14).padding(.vertical,8).background(MorningTheme.soft,in:Capsule())
    if effectiveAlarm.mode != alarm.mode || challenge != alarm.challenge {Text(appText("Your preview has ended. This morning uses the basic challenge. Your saved choice stays the same.")).font(.footnote).foregroundStyle(MorningTheme.muted)}
    Text(result ?? message).font(.title3.weight(.medium)).multilineTextAlignment(.center).accessibilityIdentifier("challengeMessage")
    if !finished && (busy || stopping || speechFinishing || preparingExample) {ProgressView().accessibilityLabel(message)}
    if (challenge.kind == .readAndChoose || challenge.kind == .riddle) && !finished {
     let prompt=challenge.kind == .riddle ? riddlePrompt : readPrompt
     Text(appText(prompt.text)).font(.title2.weight(.semibold)).multilineTextAlignment(.center)
     ForEach(Array(prompt.choices.enumerated()),id:\.offset) {index,key in
      Button(appText(key)) {chooseMeaning(index,prompt:prompt)}.buttonStyle(MorningButtonStyle(primary:false)).accessibilityIdentifier("readChoice-\(index)")
     }
    }
    if challenge.kind == .readAloud {
     if speechListening {
      Label(appText("Listening…"),systemImage:"mic.fill").font(.headline)
       .symbolEffect(.pulse,isActive:!reduceMotion).accessibilityIdentifier("listeningIndicator")
     }
     ReadingFeedbackView(target:appText(readAloudPrompt.text),transcript:transcript,ended:speechEnded)
     if !finished {
      Text(String(format:appText("You have about %d seconds. Read at your own pace."),Int(ReadAloudAttempt(target:readAloudPrompt.text).listeningDuration))).font(.footnote).foregroundStyle(MorningTheme.muted)
      Button {Task {await playExample()}} label: {
       Label(appText(spokenExample.isSpeaking ? "Stop example" : "Hear sentence"),systemImage:spokenExample.isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
      }.buttonStyle(MorningButtonStyle(primary:false)).disabled(busy || stopping || preparingExample || speech != nil).accessibilityIdentifier("hearSentence")
     }
    }
    if challenge.kind == .pushUps && camera == nil && !finished {
     Button {consentDialog=true} label: {ChallengeStartLabel(title:"Start challenge")}.buttonStyle(MorningButtonStyle()).disabled(busy || stopping).accessibilityIdentifier("startChallenge")
     Text(appText("The camera counts push-ups on this iPhone. Video is not saved or uploaded.")).font(.footnote).foregroundStyle(MorningTheme.muted)
    }
    if challenge.kind == .guidedRhythm && rhythmCamera == nil && !finished {
     Button {Task {await startRhythm()}} label: {ChallengeStartLabel(title:"Start guided rhythm")}.buttonStyle(MorningButtonStyle()).disabled(busy || stopping).accessibilityIdentifier("startGuidedRhythm")
    }
    if challenge.kind.usesLocalMovement && movementCamera == nil && !finished {
     Button {Task {await startMovement()}} label: {ChallengeStartLabel(title:"Start on-device challenge")}.buttonStyle(MorningButtonStyle()).disabled(busy || stopping).accessibilityIdentifier("startLocalMovement")
     Text(appText("Camera video stays on this device.")).font(.footnote).foregroundStyle(MorningTheme.muted)
    }
   }.padding(24).frame(maxWidth:.infinity).id("challengeTop")
  }.background(MorningTheme.canvas.ignoresSafeArea()).foregroundStyle(MorningTheme.ink)
   .onChange(of:finished) {_,_ in scroll.scrollTo("challengeTop",anchor:.top)}
   .sensoryFeedback(.success,trigger:celebrates) {_,value in value}
   .safeAreaInset(edge:.bottom) {
    VStack(spacing:12) {
     if finished {
      if celebrates {
       Button(appText("Try again")) {retryChallenge()}.buttonStyle(MorningButtonStyle(primary:false))
        .disabled(busy || stopping || preparingExample).accessibilityIdentifier("retryChallenge")
      }
      Button(appText("Back to home")) {dismiss()}.buttonStyle(MorningButtonStyle()).accessibilityIdentifier("backToHome")
     }
     else {
      if challenge.kind == .readAloud {
       if let speech {
        Button(appText("Finish reading")) {speech.finishReading()}.buttonStyle(MorningButtonStyle()).disabled(busy || stopping || speechFinishing).accessibilityIdentifier("finishReadAloud")
       } else {
        Button {Task {await startSpeech()}} label: {ChallengeStartLabel(title:"Start reading",symbol:"mic.fill")}.buttonStyle(MorningButtonStyle()).disabled(busy || stopping || preparingExample || spokenExample.isSpeaking).accessibilityIdentifier("startReadAloud")
       }
      }
      TimelineView(.periodic(from:.now,by:1)) {context in
       let remaining=max(0,Int(ceil(awakeAvailableAt.timeIntervalSince(context.date))))
       Button {finish(.selfConfirmed)} label: {
        VStack(spacing:4) {
         Text(appText("I’m awake"))
         if remaining>0 {Text(String(format:appText("Available in %d:%02d"),remaining/60,remaining%60)).font(.footnote).monospacedDigit()}
        }
       }.buttonStyle(MorningButtonStyle(primary:challenge.kind == .none)).disabled(remaining>0 || stopping).accessibilityIdentifier("confirmAwake")
      }
      if practicing {
       Button(appText("Back to home")) {dismiss()}
        .buttonStyle(.plain).font(.subheadline).underline().foregroundStyle(MorningTheme.muted).frame(maxWidth:.infinity,minHeight:44).accessibilityIdentifier("backToHome")
      } else {
       Button(appText("Stop alarm"),role:.destructive) {finish(.dismissed)}
        .buttonStyle(.plain).font(.subheadline).underline().foregroundStyle(MorningTheme.muted).frame(maxWidth:.infinity,minHeight:44).accessibilityIdentifier("stopAlarm")
      }
     }
    }.padding(.horizontal,24).padding(.vertical,12).background(MorningTheme.canvas)
   }.tint(MorningTheme.accent)
   .confirmationDialog(appText("Allow the camera to check your push-ups on this iPhone. Video and sound are not saved or uploaded. You can stop at any time."),isPresented:$consentDialog,titleVisibility:.visible) {
    Button(appText("Open camera")) {Task {await startCamera()}}
    Button(appText("Choose another way")) {consentDialog=false}
   }
   .task {
    guard coordinator == nil else {return}
    model.preview.refresh()
    // Keep one target throughout an active challenge, including at preview expiry.
    sessionAlarm=model.access.effectiveAlarm(alarm)
    coordinator=ChallengeCoordinator(alarm:effectiveAlarm,cloud:model.cloud,scheduler:model.scheduler,rehearsal:practicing)
    preparePrompt(newReadingPrompt:true,newReadAloudPrompt:true)
    #if DEBUG
    let arguments=ProcessInfo.processInfo.arguments
    if arguments.contains("--ui-testing"),arguments.contains("--ui-reading-correct-first") {
     let prompt=readPrompt
     let correct=prompt.choices[prompt.correctChoiceIndex]
     let choices=[correct]+prompt.choices.enumerated().filter {$0.offset != prompt.correctChoiceIndex}.map(\.element)
     readPrompt=ChallengePrompt(id:prompt.id,text:prompt.text,choices:choices,correctChoiceIndex:0)
    }
    if arguments.contains("--ui-testing") {
     if arguments.contains("--ui-awake-ready") {awakeAvailableAt = .distantPast}
     else if arguments.contains("--ui-awake-countdown-near-end") {awakeAvailableAt=Date().addingTimeInterval(5)}
    }
    if arguments.contains("--ui-testing"),let index=arguments.firstIndex(of:"--ui-reading-transcript"),arguments.indices.contains(index+1) {
     readAloudPrompt=ReadAloudPrompt(id:"ui-reading",text:"Small steps create steady progress.")
     transcript=arguments[index+1];speechEnded=arguments.contains("--ui-reading-finished")
    }
    if arguments.contains("--ui-testing"),model.rehearsal,arguments.contains("--ui-reading-listening") {
     speechListening=true;message=appText("Listening… Read the sentence aloud.")
    }
    if arguments.contains("--ui-testing"),model.rehearsal,arguments.contains("--ui-complete-challenge") {
     switch challenge.kind {
     case .pushUps:complete(.localCompleted,success:appText("Push-ups complete. Have a good morning!"))
     case .guidedRhythm:complete(.localCompleted,success:appText("Guided rhythm completed. Have a good morning!"))
     case .readAloud:
      if transcript.isEmpty {transcript=appText(readAloudPrompt.text)}
      speechEnded=true
      complete(.localCompleted,success:appText("Great reading. Have a good morning!"))
     case .readAndChoose,.riddle:complete(.localCompleted,success:appText("Correct. Challenge completed!"))
     case .waveHand,.neckRotation,.jumpingJacks,.stretching:complete(.localCompleted,success:appText("Local challenge completed. Have a good morning!"))
     case .none:break
     }
    }
    #endif
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
  .overlay {
   if practicing,celebrates,!reduceMotion {ChallengeConfetti().ignoresSafeArea()}
  }
 }
 @MainActor private func startCamera() async {
  guard !busy,!finished,!stopping,scene == .active,let coordinator,let target=challenge.repetitions else {return}
  busy=true;reps=0;message=appText("Getting the camera ready…")
  let generation=UUID();captureGeneration=generation;consent=true
  defer {busy=false}
  let capture=CameraCapture(target:target) {update in Task {@MainActor in
   guard captureGeneration == generation,consent,!finished,!stopping else {return}
   reps=update.reps;message=update.message
   if update.ready {await completePushUps(update.counter)}
   else if update.ended {camera?.stop();camera=nil;consent=false;await coordinator.suspend()}
  }}
  camera=capture;await capture.start()
 }
 @MainActor private func completePushUps(_ counter:PushUpCounter) async {
  guard let coordinator,!busy,!stopping,!finished,consent,scene == .active else {return}
  busy=true;let generation=captureGeneration
  defer {busy=false}
  do {
   let applied=try await coordinator.completePushUps(counter)
   guard captureGeneration == generation,!stopping,scene == .active else {return}
   if applied {complete(.localCompleted,success:appText("Push-ups complete. Have a good morning!"))}
  } catch {message=appText("The alarm could not be stopped here. Please use the system Stop button.")}
 }
 private func finish(_ outcome:WakeOutcome,success:String?=nil) {
  guard !finished,!stopping,let coordinator else {return}
  guard outcome != .selfConfirmed || Date()>=awakeAvailableAt else {return}
  stopping=true;message=appText("Finishing your challenge…")
  pauseResources()
  Task {@MainActor in
   defer {stopping=false}
   do {try await coordinator.finish(outcome);complete(coordinator.session.outcome ?? outcome,success:success)}
   catch {message=appText("The alarm could not be stopped here. Please use the system Stop button.")}
  }
 }
 private func complete(_ outcome:WakeOutcome,success:String?=nil) {
  guard !finished else {return}
  pauseResources();completion=outcome
  model.recordMorning(id:historyID,alarm:effectiveAlarm,outcome:outcome,rehearsal:practicing)
  if !practicing,celebrates {model.celebrationID=reduceMotion ? nil : UUID();dismiss();return}
  switch outcome {
  case .localCompleted:result=success ?? appText("Local challenge completed. Have a good morning!")
  case .openaiVerified,.aiVerified:result=appText("Movement checked. Have a good morning!")
  case .selfConfirmed:result=appText("You confirmed you are awake. Have a good morning!")
  case .dismissed:result=appText("Alarm stopped. Take care today.")
  }
 }
 private func retryChallenge() {
  guard celebrates,!busy,!stopping,!preparingExample,scene == .active else {return}
  pauseResources()
  // A passed alarm stays completed; further attempts are practice only.
  retrying=true
  coordinator=ChallengeCoordinator(alarm:effectiveAlarm,cloud:model.cloud,scheduler:model.scheduler,rehearsal:true)
  transcript="";speechEnded=false;reps=0;rhythmCycles=0;consentDialog=false
  preparePrompt(newReadingPrompt:true)
  result=nil;completion=nil;message=challengeInstructions
 }
 private func preparePrompt(newReadingPrompt:Bool=false,newReadAloudPrompt:Bool=false) {
  if newReadingPrompt {
   readPrompt=ChallengePrompts.readAndChoose(previousID:lastReadPromptID) ?? readPrompt
   lastReadPromptID=readPrompt.id
   riddlePrompt=ChallengePrompts.riddle(previousID:lastRiddlePromptID) ?? riddlePrompt
   lastRiddlePromptID=riddlePrompt.id
  }
  if newReadAloudPrompt {readAloudPrompt=EnglishChallengeContent.readAloud.randomElement() ?? readAloudPrompt}
  message=challengeInstructions
 }
 private var challengeInstructions:String {
  switch challenge.kind {
  case .none:return appText("You can confirm you’re awake when the countdown ends.")
  case .pushUps:return appText("Place your phone to the side so your whole body is visible. Start the camera, then do your push-ups. Each full down-and-up movement counts once.")
  case .readAndChoose:return appText("Read the sentence, then choose the closest meaning. You can try again.")
  case .riddle:return appText("Solve the riddle, then choose your answer. You can try again.")
  case .waveHand:return appText("Place your hand in view and wave it side to side. Video stays on this device.")
  case .neckRotation:return appText("Keep your face visible and turn your head left and right. Video stays on this device.")
  case .jumpingJacks:return appText("Keep your whole body visible and complete 10 gentle jumping jacks. Video stays on this device.")
  case .stretching:return appText("Raise both hands above your shoulders, then lower them. Video stays on this device.")
  case .guidedRhythm:return challenge.rhythmVariant == .seated ? appText("Stay seated. Lower your arms, raise them, then lower them. Complete 3 cycles. Video stays on this device.") : appText("Stand, bend your knees gently, then stand again. Complete 3 cycles. Video stays on this device.")
  case .readAloud:return appText("Tap Start reading, then read the English sentence aloud. Match at least 80% of the words.")
  }
 }
 private func chooseMeaning(_ index:Int,prompt:ChallengePrompt) {
  if prompt.isCorrect(choiceIndex:index) {finish(.localCompleted,success:appText("Correct. Challenge completed!"))}
  else {message=appText(challenge.kind == .riddle ? "Not quite. Think it over and try again." : "Not quite. Read the sentence and try again.")}
 }
 @MainActor private func startRhythm() async {
  guard rhythmCamera == nil,!busy,!finished,!stopping,scene == .active else {return};busy=true;message=appText("Getting the camera ready…")
  let generation=UUID();captureGeneration=generation
  let capture=GuidedRhythmCapture(variant:challenge.rhythmVariant ?? .standing,targetCycles:3) {update in Task {@MainActor in
   guard captureGeneration == generation,!finished,!stopping else {return}
   rhythmCycles=update.cycles;message=update.message
   if update.completed {finish(.localCompleted,success:appText("Guided rhythm completed. Have a good morning!"))}
   else if update.ended {rhythmCamera?.stop();rhythmCamera=nil}
  }}
  rhythmCamera=capture;await capture.start();busy=false
 }
 @MainActor private func startMovement() async {
  guard movementCamera == nil,!busy,!finished,!stopping,scene == .active,challenge.kind.usesLocalMovement else {return}
  busy=true;message=appText("Getting the camera ready…")
  let generation=UUID();captureGeneration=generation
  let capture=MovementChallengeCapture(kind:challenge.kind) {update in Task {@MainActor in
   guard captureGeneration == generation,!finished,!stopping else {return}
   reps=update.reps;message=update.message
   if update.ready {finish(.localCompleted,success:appText("Local challenge completed. Have a good morning!"))}
   else if update.ended {movementCamera?.stop();movementCamera=nil}
  }}
  movementCamera=capture;await capture.start();busy=false
 }
 @MainActor private func startSpeech() async {
  guard speech == nil,!busy,!finished,!stopping,!preparingExample,!spokenExample.isSpeaking,scene == .active else {return};busy=true
  transcript="";speechEnded=false;speechFinishing=false;speechListening=false
  let generation=UUID();captureGeneration=generation
  let capture=SpeechChallengeCapture(target:appText(readAloudPrompt.text)) {update in Task {@MainActor in
   guard captureGeneration == generation,!finished,!stopping else {return}
   transcript=update.transcript;speechEnded=update.ended;speechFinishing=update.finishing && !update.ended;speechListening=update.listening;message=update.message
   if update.completed {finish(.localCompleted,success:appText("Great reading. Have a good morning!"))}
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
  transcript="";speechEnded=false;speechFinishing=false
  message=spokenExample.play(appText(readAloudPrompt.text)) ? appText("Listen to the example, then tap Start reading.") : appText("The English voice is not available. You can still read the sentence.")
 }
 private func pauseResources() {
  captureGeneration=UUID();consent=false;speechListening=false;speechFinishing=false
  camera?.stop();camera=nil
  movementCamera?.stop();movementCamera=nil
  rhythmCamera?.stop();rhythmCamera=nil
  speech?.stop();speech=nil
  spokenExample.stop()
 }
}

private struct ChallengeStartLabel:View {
 let title:String
 var symbol="play.circle.fill"
 @Environment(\.accessibilityReduceMotion) private var reduceMotion
 @Environment(\.isEnabled) private var enabled
 @State private var animate=false
 var body:some View {
  Label(appText(title),systemImage:symbol)
   .symbolEffect(.bounce,options:.repeat(3).speed(0.8),value:animate)
   .symbolEffectsRemoved(reduceMotion || !enabled)
   .onAppear {if !reduceMotion {animate=true}}
 }
}

struct ReadingFeedbackView:View {
 let target:String
 let transcript:String
 let ended:Bool
 private var feedback:RecognizedWordMatch.Feedback {RecognizedWordMatch.feedback(target:target,recognized:transcript,finished:ended)}
 var body:some View {
  let feedback=feedback
  VStack(spacing:12) {
   Text(highlightedPrompt(feedback)).font(.title2.weight(.semibold)).multilineTextAlignment(.center)
    .accessibilityIdentifier("readingPrompt").accessibilityLabel(target).accessibilityValue(wordSummary(feedback))
   Text(String(format:appText("Word match: %d/100"),Int((feedback.score*100).rounded())))
    .font(.headline).accessibilityIdentifier("readingScore")
   ProgressView(value:feedback.score,total:1).accessibilityLabel(appText("Word match score"))
   Text(appText("Matched words are green. Underlined words need practice. Gray words have not been read yet."))
    .font(.footnote).foregroundStyle(MorningTheme.muted)
   let incorrect=feedback.words.filter {$0.status == .incorrect}.map(\.text)
   if !incorrect.isEmpty {
    Text(String(format:appText("Needs practice: %@"),incorrect.joined(separator:", ")))
     .font(.footnote).frame(maxWidth:.infinity,alignment:.leading).accessibilityIdentifier("readingIncorrectWords")
   }
   if !feedback.extraWords.isEmpty {
    Text(String(format:appText("Extra words: %@"),feedback.extraWords.joined(separator:", ")))
     .font(.footnote).frame(maxWidth:.infinity,alignment:.leading).accessibilityIdentifier("readingExtraWords")
   }
   if !transcript.isEmpty {
    Text(String(format:appText("Heard: %@"),transcript)).foregroundStyle(MorningTheme.muted).accessibilityIdentifier("speechTranscript")
   }
   Text(appText("The score compares recognized words with the sentence; it does not measure accent or pronunciation quality."))
    .font(.footnote).foregroundStyle(MorningTheme.muted)
  }
 }
 private func wordSummary(_ feedback:RecognizedWordMatch.Feedback)->String {
  [RecognizedWordMatch.WordStatus.correct,.incorrect,.pending].map {status in
   let words=feedback.words.filter {$0.status == status}.map(\.text).joined(separator:", ")
   return String(format:appText(status == .correct ? "Correct: %@" : status == .incorrect ? "Needs practice: %@" : "Not read yet: %@"),words)
  }.joined(separator:"; ")
 }
 private func highlightedPrompt(_ feedback:RecognizedWordMatch.Feedback)->AttributedString {
  var result=AttributedString(),index=0
  for (position,part) in target.split(whereSeparator:\.isWhitespace).enumerated() {
   if position>0 {result+=AttributedString(" ")}
   var word=AttributedString(String(part))
   let count=RecognizedWordMatch.tokens(in:String(part)).count
   let statuses=feedback.words.dropFirst(index).prefix(count).map(\.status)
   if statuses.contains(.incorrect) {word.foregroundColor = .red;word.underlineStyle = .single}
   else if !statuses.isEmpty,statuses.allSatisfy({$0 == .correct}) {word.foregroundColor=MorningTheme.correctWord;word.inlinePresentationIntent = .stronglyEmphasized}
   else {word.foregroundColor=MorningTheme.muted}
   result+=word;index+=count
  }
  return result
 }
}
