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
 @State private var message="Chào buổi sáng. Hãy chọn cách thức dậy vừa sức."
 @State private var reps=0
 @State private var consent=false
 @State private var busy=false
 @State private var consentDialog=false
 @State private var finished=false
 @State private var result:String?
 var body:some View {
  VStack(spacing:24) {
   Text(model.rehearsal ? "Thử nhiệm vụ" : "Chào buổi sáng ☀️").font(.title.bold())
   if let camera {CameraPreview(capture:camera).clipShape(RoundedRectangle(cornerRadius:28)).overlay(alignment:.bottom){Text("\(reps) / \(alarm.mode.policy.reps)").font(.largeTitle.bold()).padding().background(.regularMaterial,in:Capsule()).padding()}}
   else {Image(systemName:"sun.max.fill").font(.system(size:80)).foregroundStyle(.orange).frame(maxHeight:.infinity)}
   Text(result ?? message).multilineTextAlignment(.center).accessibilityIdentifier("challengeMessage")
   if alarm.mode.policy.reps>0 && camera == nil && !finished {
    Button("Bắt đầu nhiệm vụ AI") {consentDialog=true}.buttonStyle(.borderedProminent).tint(.yellow).foregroundStyle(.black).disabled(busy)
   }
   if finished {Button("Về trang chính") {dismiss()}.buttonStyle(.borderedProminent)}
   else {
    Button("Tôi đã thức dậy") {finish(.selfConfirmed)}.buttonStyle(.bordered)
    Button("Dừng báo thức",role:.destructive) {finish(.dismissed)}.accessibilityIdentifier("stopAlarm")
   }
  }.padding(24).background(Color(.systemGroupedBackground))
   .confirmationDialog("Một số khung hình động tác được gửi qua máy chủ của HiMorning đến OpenAI để xác minh. Không thu âm hay lưu video mặc định. Bạn có thể dừng bất cứ lúc nào.",isPresented:$consentDialog,titleVisibility:.visible) {
    Button("Đồng ý và mở camera") {Task {await startCamera()}}
    Button("Chọn cách khác",role:.cancel) {}
   }
   .task {coordinator=ChallengeCoordinator(alarm:alarm,cloud:model.cloud,scheduler:model.scheduler,rehearsal:model.rehearsal)}
   .onChange(of:scene) {_,value in if value != .active && !finished {consent=false;camera?.stop();camera=nil;message="Nhiệm vụ đã tạm dừng. Bạn có thể chọn cách khác.";Task {await coordinator?.suspend()}}}
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
  } catch {message="AI chưa sẵn sàng. Bạn có thể tự xác nhận hoặc dừng ngay."}
 }
 @MainActor private func submit(_ frames:[EvidenceFrame]) async {
  guard let coordinator,!busy else {return};busy=true
  defer {busy=false}
  do {
   if try await coordinator.submit(frames) {finished=true;consent=false;camera?.stop();camera=nil;result="Đã xác minh động tác. Chúc bạn một ngày nhiều năng lượng!"}
   else if coordinator.session.outcome == nil {message="Chưa xác minh được toàn bộ động tác. Bạn có thể chọn cách khác."}
  } catch {message="Không thể xác minh lúc này. Bạn vẫn có thể dừng."}
 }
 private func finish(_ outcome:WakeOutcome) {
  consent=false;camera?.stop();camera=nil
  Task {@MainActor in
   do {try await coordinator?.finish(outcome);finished=true;result=outcome == .selfConfirmed ? "Bạn đã tự xác nhận thức dậy. Chúc buổi sáng tốt lành!" : "Đã dừng. Hẹn bạn một buổi sáng khác."}
   catch {message="Chưa xác nhận được việc dừng. Hãy dùng nút Dừng của báo thức hệ thống."}
  }
 }
}
