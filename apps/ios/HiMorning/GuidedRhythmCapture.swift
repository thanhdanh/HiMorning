import AVFoundation
import Vision
import HiMorningCore

struct RhythmUpdate:Sendable {
 let cycles:Int
 let completed:Bool
 let ended:Bool
 let message:String
 let hint:FramingHint
}

/// Converts camera frames into local pose labels. It never creates image data or uploads frames.
final class GuidedRhythmCapture:NSObject,AVCaptureVideoDataOutputSampleBufferDelegate,@unchecked Sendable {
 let session=AVCaptureSession()
 private let variant:GuidedRhythmVariant
 private let targetCycles:Int
 private let onUpdate:@Sendable(RhythmUpdate)->Void
 private let queue=DispatchQueue(label:"com.himorning.guided-rhythm",qos:.userInitiated)
 private let lock=NSLock()
 private var rhythm:GuidedRhythmSession
 private var generation=0
 private var stopped=false
 private var active=false
 private var started:TimeInterval=0
 private let request=VNDetectHumanBodyPoseRequest()
 private var observers:[NSObjectProtocol]=[]

 init(variant:GuidedRhythmVariant,targetCycles:Int=3,onUpdate:@escaping @Sendable(RhythmUpdate)->Void) {
  self.variant=variant
  self.targetCycles=min(10,max(1,targetCycles))
  rhythm=GuidedRhythmSession(variant:variant)
  self.onUpdate=onUpdate
  super.init()
 }

 func start() async {
  guard let token=beginStartup() else {return}
  let granted=await AVCaptureDevice.requestAccess(for:.video)
  guard isCurrent(token) else {return}
  guard granted else {
   publish(completed:false,ended:true,message:appText("Camera access is needed for guided rhythm."))
   return
  }
  queue.async { [weak self] in self?.startCamera(token:token) }
 }

 func stop() {
  stopPermanently()
  queue.async { [self] in
   stopCamera()
  }
 }

 private func startCamera(token:Int) {
  guard isCurrent(token) else {return}
  do {
   if session.inputs.isEmpty {
    session.beginConfiguration();defer {session.commitConfiguration()}
    session.sessionPreset = .vga640x480
    guard let device=AVCaptureDevice.default(.builtInWideAngleCamera,for:.video,position:.front) else {throw RhythmCaptureError.cameraUnavailable}
    let input=try AVCaptureDeviceInput(device:device)
    guard session.canAddInput(input) else {throw RhythmCaptureError.cameraUnavailable}
    session.addInput(input)
    let output=AVCaptureVideoDataOutput()
    output.alwaysDiscardsLateVideoFrames=true
    output.setSampleBufferDelegate(self,queue:queue)
    guard session.canAddOutput(output) else {throw RhythmCaptureError.cameraUnavailable}
    session.addOutput(output)
   }
   guard isCurrent(token) else {return}
   rhythm=GuidedRhythmSession(variant:variant)
   started=ProcessInfo.processInfo.systemUptime
   active=true
   for name in [AVCaptureSession.wasInterruptedNotification,AVCaptureSession.runtimeErrorNotification] {
    observers.append(NotificationCenter.default.addObserver(forName:name,object:session,queue:nil) { [weak self] _ in
     self?.queue.async { [weak self] in
      guard let self,self.active else {return}
      self.stopCamera()
      self.publish(completed:false,ended:true,message:appText("The challenge is paused. Start it again, or tap I’m awake when it unlocks."))
     }
    })
   }
   session.startRunning()
   publish(completed:false,ended:false,message:instruction)
  } catch {
   stopCamera()
   publish(completed:false,ended:true,message:appText("The camera could not open. You can tap I’m awake when it unlocks."))
  }
 }

 func captureOutput(_ output:AVCaptureOutput,didOutput sampleBuffer:CMSampleBuffer,from connection:AVCaptureConnection) {
  let uptime=ProcessInfo.processInfo.systemUptime
  guard active,rhythm.completedCycles<targetCycles,let buffer=CMSampleBufferGetImageBuffer(sampleBuffer) else {return}
  let timestamp=Int((uptime-started)*1_000)
  do {
   try VNImageRequestHandler(cvPixelBuffer:buffer,orientation:.leftMirrored).perform([request])
   guard let body=request.results?.first else {handleOcclusion(timestamp:timestamp,hint:.noPerson);return}
   let points=try body.recognizedPoints(.all)
   let hint=BodyFraming.hint(PoseGeometry.jointSamples(points),needsFeet:variant == .standing)
   let orientedSize=CGSize(width:CVPixelBufferGetHeight(buffer),height:CVPixelBufferGetWidth(buffer))
   switch classify(points,imageSize:orientedSize) {
   case .occluded:
    handleOcclusion(timestamp:timestamp,hint:hint)
   case .transition:
    publish(completed:false,ended:false,message:appText("Move smoothly and follow the rhythm."),hint:hint)
   case .pose(let pose):
    let completedCycle=rhythm.observe(pose,timestampMs:timestamp,visible:true)
    let completed=rhythm.completedCycles>=targetCycles
    publish(completed:completed,ended:completed,message:completed ? appText("Rhythm complete. Good morning!") : instruction,hint:hint)
    if completedCycle && completed {
     stopCamera()
    }
   }
  } catch {
   stopCamera()
   publish(completed:false,ended:true,message:appText("The pose is unclear. Try again slowly."))
  }
 }

 private func classify(_ points:[VNHumanBodyPoseObservation.JointName:VNRecognizedPoint],imageSize:CGSize) -> PoseClassification {
  switch variant {
  case .standing:return classifyStanding(points,imageSize:imageSize)
  case .seated:return classifySeatedArms(points)
  }
 }

 private func classifyStanding(_ points:[VNHumanBodyPoseObservation.JointName:VNRecognizedPoint],imageSize:CGSize) -> PoseClassification {
  let sides:[[VNHumanBodyPoseObservation.JointName]]=[
   [.leftHip,.leftKnee,.leftAnkle],
   [.rightHip,.rightKnee,.rightAnkle]
  ]
  guard let joints=sides.first(where:{names in names.allSatisfy {PoseGeometry.isVisible(points[$0], minConfidence: 0.55)}}) else {return .occluded}
  guard let hip=points[joints[0]],let knee=points[joints[1]],let ankle=points[joints[2]] else {return .occluded}
  let angle=PoseGeometry.jointAngle(hip.location,knee.location,ankle.location,imageSize:imageSize)
  if angle>=155 {return .pose(.standing)}
  if angle<=125 {return .pose(.lowered)}
  return .transition
 }

 private func classifySeatedArms(_ points:[VNHumanBodyPoseObservation.JointName:VNRecognizedPoint]) -> PoseClassification {
  let names:[VNHumanBodyPoseObservation.JointName]=[.leftShoulder,.leftWrist,.rightShoulder,.rightWrist]
  guard names.allSatisfy({PoseGeometry.isVisible(points[$0], minConfidence: 0.55)}),
        let leftShoulder=points[.leftShoulder],let leftWrist=points[.leftWrist],
        let rightShoulder=points[.rightShoulder],let rightWrist=points[.rightWrist] else {return .occluded}
  let margin=0.08
  if leftWrist.location.y>leftShoulder.location.y+margin && rightWrist.location.y>rightShoulder.location.y+margin {return .pose(.armsUp)}
  if leftWrist.location.y<leftShoulder.location.y-margin && rightWrist.location.y<rightShoulder.location.y-margin {return .pose(.armsDown)}
  return .transition
 }

 private func handleOcclusion(timestamp:Int,hint:FramingHint) {
  let placeholder:GuidedRhythmPose=variant == .standing ? .standing : .armsDown
  _=rhythm.observe(placeholder,timestampMs:timestamp,visible:false)
  publish(completed:false,ended:false,message:appText(variant == .standing ? "Keep your whole body in view." : "Keep your upper body and both wrists in view."),hint:hint)
 }

 private var instruction:String {
  appText(variant == .standing ? "Stand sideways in view, bend your knees gently, then stand again." : "Stay seated and move both arms down, up, then down.")
 }

 private func stopCamera() {
  active=false
  session.stopRunning()
  rhythm.interrupt()
  observers.forEach {NotificationCenter.default.removeObserver($0)}
  observers.removeAll()
 }

 private func publish(completed:Bool,ended:Bool,message:String,hint framing:FramingHint = .ok) {
  let hint:FramingHint=completed || ended ? .ok : framing
  onUpdate(.init(cycles:rhythm.completedCycles,completed:completed,ended:ended,message:hint.message ?? message,hint:hint))
 }

 private func beginStartup() -> Int? {
  lock.lock();defer {lock.unlock()}
  guard !stopped else {return nil}
  generation+=1
  return generation
 }

 private func stopPermanently() {
  lock.lock();stopped=true;generation+=1;lock.unlock()
 }

 private func isCurrent(_ token:Int) -> Bool {
  lock.lock();defer {lock.unlock()}
  return token == generation
 }
}

private enum PoseClassification {
 case pose(GuidedRhythmPose)
 case transition
 case occluded
}

private enum RhythmCaptureError:Error {case cameraUnavailable}
