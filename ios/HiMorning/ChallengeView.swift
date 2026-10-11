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
 @State private var result:String?
 var body:some View {
  VStack(spacing:24) {
   Text(model.rehearsal ? appText("Try a challenge") : appText("Good morning ☀️")).font(.title.bold())
   if let camera {CameraPreview(capture:camera).clipShape(RoundedRectangle(cornerRadius:28)).overlay(alignment:.bottom){Text("\(reps) / \(alarm.mode.policy.reps)").font(.largeTitle.bold()).padding().background(.regularMaterial,in:Capsule()).padding()}}
   else {Image(systemName:"sun.max.fill").font(.system(size:80)).foregroundStyle(.orange).frame(maxHeight:.infinity)}
   Text(result ?? message).multilineTextAlignment(.center).accessibilityIdentifier("challengeMessage")
   if alarm.mode.policy.reps>0 && camera == nil && !finished {
    Button(appText("Start AI challenge")) {consentDialog=true}.buttonStyle(.borderedProminent).tint(.yellow).foregroundStyle(.black).disabled(busy)
   }
   if finished {Button(appText("Back to home")) {dismiss()}.buttonStyle(.borderedProminent)}
   else {
    Button(appText("I’m awake")) {finish(.selfConfirmed)}.buttonStyle(.bordered)
    Button(appText("Stop alarm"),role:.destructive) {finish(.dismissed)}.accessibilityIdentifier("stopAlarm")
   }
  }.padding(24).background(Color(.systemGroupedBackground))
   .confirmationDialog(appText("Movement photos go through HiMorning to OpenAI for checking. No audio is recorded. HiMorning does not save these photos; OpenAI data policies apply. You can stop at any time."),isPresented:$consentDialog,titleVisibility:.visible) {
    Button(appText("Agree and open camera")) {Task {await startCamera()}}
    Button(appText("Choose another way"),role:.cancel) {}
   }
   .task {coordinator=ChallengeCoordinator(alarm:alarm,cloud:model.cloud,scheduler:model.scheduler,rehearsal:model.rehearsal)}
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
   let capture=CameraCapture(target:alarm.mode.policy.reps) {update in Task {@MainActor in
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
   if try await coordinator.submit(frames) {finished=true;consent=false;camera?.stop();camera=nil;result=appText("Movement checked. Have a good morning!")}
   else if coordinator.session.outcome == nil {message=appText("The movement could not be fully checked. You can choose another way.")}
  } catch {message=appText("The movement could not be checked right now. You can still stop.")}
 }
 private func finish(_ outcome:WakeOutcome) {
  consent=false;camera?.stop();camera=nil
  Task {@MainActor in
   do {try await coordinator?.finish(outcome);finished=true;result=outcome == .selfConfirmed ? appText("You confirmed you are awake. Have a good morning!") : appText("Alarm stopped. Take care today.")}
   catch {message=appText("The alarm could not be stopped here. Please use the system Stop button.")}
  }
 }
}
