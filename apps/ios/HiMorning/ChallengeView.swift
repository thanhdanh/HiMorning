import SwiftUI
import AVFoundation
import HiMorningCore
struct CameraPreview:UIViewRepresentable {
 let capture:CameraCapture
 final class Preview:UIView {override class var layerClass:AnyClass {AVCaptureVideoPreviewLayer.self}}
 func makeUIView(context:Context)->Preview {let view=Preview();let layer=view.layer as! AVCaptureVideoPreviewLayer;layer.session=capture.session;layer.videoGravity = .resizeAspectFill;return view}
 func updateUIView(_ uiView:Preview,context:Context) {}
}
struct ChallengeView:View {
 let alarm:SavedAlarm
 @State private var sessionMode:WakeMode?
 private var mode:WakeMode {sessionMode ?? model.access.effectiveMode(alarm.mode)}
 private var effectiveAlarm:SavedAlarm {
  var value=SavedAlarm(id:alarm.id,time:alarm.time,mode:mode,sound:alarm.sound)
  value.enabled=alarm.enabled;value.state=alarm.state;return value
 }
 @ObservedObject var model:PilotModel
 @Environment(\.dismiss) private var dismiss
 @Environment(\.scenePhase) private var scene
 @State private var coordinator:ChallengeCoordinator?
 @State private var camera:CameraCapture?
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
     CameraPreview(capture:camera).frame(height:280).clipShape(RoundedRectangle(cornerRadius:24))
      .overlay(alignment:.bottom) {Text("\(reps) / \(mode.policy.reps)").font(.largeTitle.bold()).padding(12).background(.regularMaterial,in:Capsule()).padding()}
    } else {
     MorningSun()
     Text(String(format:"%02d:%02d",alarm.time.hour,alarm.time.minute)).font(.system(.largeTitle,design:.rounded).weight(.regular)).monospacedDigit()
    }
    Text(mode.title).font(.subheadline.weight(.medium)).padding(.horizontal,14).padding(.vertical,8).background(MorningTheme.soft,in:Capsule())
    if mode != alarm.mode {Text(appText("Your preview has ended. This morning uses the basic challenge. Your saved choice stays the same.")).font(.footnote).foregroundStyle(MorningTheme.muted)}
    Text(result ?? message).font(.title3.weight(.medium)).multilineTextAlignment(.center).accessibilityIdentifier("challengeMessage")
   }.padding(24).frame(maxWidth:.infinity)
  }.background(MorningTheme.canvas.ignoresSafeArea()).foregroundStyle(MorningTheme.ink)
   .safeAreaInset(edge:.bottom) {
    VStack(spacing:12) {
     if mode.policy.reps>0 && camera == nil && !finished {
      Button(appText("Start AI challenge")) {consentDialog=true}.buttonStyle(MorningButtonStyle()).disabled(busy).accessibilityIdentifier("startChallenge")
     }
     if finished {Button(appText("Back to home")) {dismiss()}.buttonStyle(MorningButtonStyle())}
     else {
      Button(appText("I’m awake")) {finish(.selfConfirmed)}.buttonStyle(MorningButtonStyle(primary:mode.policy.reps==0))
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
    sessionMode=model.access.effectiveMode(alarm.mode)
    coordinator=ChallengeCoordinator(alarm:effectiveAlarm,cloud:model.cloud,scheduler:model.scheduler,rehearsal:model.rehearsal)
   }
   .onChange(of:scene) {_,value in if value != .active && !finished {consent=false;camera?.stop();camera=nil;message=appText("The challenge is paused. You can choose another way.");Task {await coordinator?.suspend()}}}
   .onDisappear {camera?.stop();if !finished {Task {await coordinator?.suspend()}}}
 }
 @MainActor private func startCamera() async {
  guard let coordinator else {return};busy=true
  defer {busy=false}
  do {
   try await coordinator.startCloud(consent:true)
   guard coordinator.session.outcome == nil else {return}
   consent=true
   let capture=CameraCapture(target:mode.policy.reps) {update in Task {@MainActor in
    guard consent,!finished else {return};reps=update.reps;message=update.message
    if update.ready {await submit(update.frames)}
   }}
   camera=capture;await capture.start()
  } catch {message=appText("AI is not available. You can confirm you are awake or stop.")}
 }
 @MainActor private func submit(_ frames:[EvidenceFrame]) async {
  guard let coordinator,!busy else {return};busy=true
  defer {busy=false}
  do {
   if try await coordinator.submit(frames) {finished=true;consent=false;camera?.stop();camera=nil;result=appText("Movement checked. Have a good morning!");model.recordMorning(id:historyID,outcome:.openaiVerified,rehearsal:model.rehearsal)}
   else if coordinator.session.outcome == nil {message=appText("The movement could not be fully checked. You can choose another way.")}
  } catch {message=appText("The movement could not be checked right now. You can still stop.")}
 }
 private func finish(_ outcome:WakeOutcome) {
  guard !finished,!stopping,let coordinator else {return}
  stopping=true
  consent=false;camera?.stop();camera=nil
  Task {@MainActor in
   defer {stopping=false}
   do {try await coordinator.finish(outcome);model.recordMorning(id:historyID,outcome:coordinator.session.outcome ?? outcome,rehearsal:model.rehearsal);finished=true;result=outcome == .selfConfirmed ? appText("You confirmed you are awake. Have a good morning!") : (model.rehearsal ? appText("Practice ended. Your alarms are unchanged.") : appText("Alarm stopped. Take care today."))}
   catch {message=appText("The alarm could not be stopped here. Please use the system Stop button.")}
  }
 }
}
