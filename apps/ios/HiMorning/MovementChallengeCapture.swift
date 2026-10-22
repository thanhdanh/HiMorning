import AVFoundation
import Vision
import HiMorningCore

struct LocalMovementUpdate:Sendable {let reps:Int;let ready:Bool;let ended:Bool;let message:String;let hint:FramingHint;var tracking:CameraTrackingSnapshot = .empty}

private enum MovementCounter {
 case wave(WaveCounter),neck(NeckTurnCounter),body(MovementChallengeProgress)

 init(kind:ChallengeKind) {
  let target=kind.localMovementTarget ?? 3
  switch kind {
  case .waveHand:self = .wave(WaveCounter(target:target))
  case .neckRotation:self = .neck(NeckTurnCounter(target:target))
  default:self = .body(MovementChallengeProgress(kind:kind,target:target))
  }
 }

 var completed:Int {
  switch self {
  case .wave(let c):return c.completed
  case .neck(let c):return c.completed
  case .body(let c):return c.completed
  }
 }

 var ready:Bool {
  switch self {
  case .wave(let c):return c.ready
  case .neck(let c):return c.ready
  case .body(let c):return c.ready
  }
 }

 mutating func observeLoss(timestampMs:Int) {
  switch self {
  case .wave(var c):c.observeLoss(timestampMs:timestampMs);self = .wave(c)
  case .neck(var c):c.observeLoss(timestampMs:timestampMs);self = .neck(c)
  case .body(var c):_=c.observe(.unavailable,timestampMs:timestampMs);self = .body(c)
  }
 }
}

final class MovementChallengeCapture:NSObject,AVCaptureVideoDataOutputSampleBufferDelegate,@unchecked Sendable {
 let session=AVCaptureSession()
 private let kind:ChallengeKind
 private let queue=DispatchQueue(label:"com.himorning.local-movement",qos:.userInitiated)
 private let onUpdate:@Sendable(LocalMovementUpdate)->Void
 private var counter:MovementCounter
 private let handRequest=VNDetectHumanHandPoseRequest()
 private let faceRequest:VNDetectFaceRectanglesRequest={
  let request=VNDetectFaceRectanglesRequest();request.revision=VNDetectFaceRectanglesRequestRevision3;return request
 }()
 private let bodyRequest=VNDetectHumanBodyPoseRequest()
 private var started=0.0
 private var tracking:CameraTrackingSnapshot = .empty
 private var active=false
 private var cancelled=false
 private let lifecycleLock=NSLock()

 init(kind:ChallengeKind,onUpdate:@escaping @Sendable(LocalMovementUpdate)->Void) {
  precondition(kind.usesLocalMovement)
  handRequest.maximumHandCount=1
  self.kind=kind;counter=MovementCounter(kind:kind);self.onUpdate=onUpdate;super.init()
 }

 func start() async {
  guard !isCancelled else {return}
  guard await AVCaptureDevice.requestAccess(for:.video) else {
   publish(ended:true,"Camera access is off. You can tap I’m awake when it unlocks.");return
  }
  guard !isCancelled else {return}
  queue.async { [self] in
   guard !isCancelled else {return}
   do {
    if session.inputs.isEmpty {
     session.beginConfiguration();defer {session.commitConfiguration()};session.sessionPreset = .vga640x480
     guard let device=AVCaptureDevice.default(.builtInWideAngleCamera,for:.video,position:.front) else {throw NativeAlarmError.denied}
     let input=try AVCaptureDeviceInput(device:device)
     guard session.canAddInput(input) else {throw NativeAlarmError.denied};session.addInput(input)
     let output=AVCaptureVideoDataOutput();output.alwaysDiscardsLateVideoFrames=true
     output.setSampleBufferDelegate(self,queue:queue)
     guard session.canAddOutput(output) else {throw NativeAlarmError.denied};session.addOutput(output)
    }
    guard !isCancelled else {return}
    counter=MovementCounter(kind:kind);started=ProcessInfo.processInfo.systemUptime;active=true;session.startRunning()
    queue.asyncAfter(deadline:.now()+90) { [weak self] in
     guard let self,active,!counter.ready else {return}
     active=false;session.stopRunning()
     publish(ended:true,"Movement capture timed out. Try again, or tap I’m awake when it unlocks.")
    }
   } catch {publish(ended:true,"The camera could not open. You can tap I’m awake when it unlocks.")}
  }
 }

 func stop() {
  lifecycleLock.lock();cancelled=true;lifecycleLock.unlock()
  queue.async { [self] in active=false;counter=MovementCounter(kind:kind);session.stopRunning() }
 }

 func captureOutput(_ output:AVCaptureOutput,didOutput sampleBuffer:CMSampleBuffer,from connection:AVCaptureConnection) {
  let now=ProcessInfo.processInfo.systemUptime
  guard active,let buffer=CMSampleBufferGetImageBuffer(sampleBuffer) else {return}
  tracking = .empty
  let timestamp=Int((now-started)*1000)
  guard timestamp<=90_000 else {
   active=false;session.stopRunning()
   publish(ended:true,"Movement capture timed out. Try again, or tap I’m awake when it unlocks.");return
  }
  let size=CGSize(width:CVPixelBufferGetHeight(buffer),height:CVPixelBufferGetWidth(buffer))
  do {
   switch kind {
   case .waveHand:try observeWave(buffer,size:size,timestamp:timestamp)
   case .neckRotation:try observeNeck(buffer,size:size,timestamp:timestamp)
   case .jumpingJacks,.stretching:try observeBody(buffer,size:size,timestamp:timestamp)
   default:return
   }
  } catch {
   counter.observeLoss(timestampMs:timestamp)
   publish("The view is unclear. Try moving your phone.")
  }
 }

 private func observeWave(_ buffer:CVPixelBuffer,size:CGSize,timestamp:Int) throws {
  try VNImageRequestHandler(cvPixelBuffer:buffer,orientation:.leftMirrored).perform([handRequest])
  if let hand=handRequest.results?.first,let points=try? hand.recognizedPoints(.all) {tracking = .hand(points,imageSize:size)}
  let names:[VNHumanHandPoseObservation.JointName]=[.wrist,.indexMCP,.middleMCP,.ringMCP,.littleMCP]
  guard let hand=handRequest.results?.first,
        let points=try? names.map({try hand.recognizedPoint($0)}),
        points.allSatisfy({PoseGeometry.isVisible($0,minConfidence:0.6)}) else {
   counter.observeLoss(timestampMs:timestamp);publish(kind.movementInstruction);return
  }
  let centerX=points.map {Double($0.location.x)}.reduce(0,+)/Double(points.count)*Double(size.width)
  let centerY=points.map {Double($0.location.y)}.reduce(0,+)/Double(points.count)*Double(size.height)
  let handWidth=hypot(Double(points[0].location.x-points[2].location.x)*Double(size.width),Double(points[0].location.y-points[2].location.y)*Double(size.height))
  guard handWidth>=min(Double(size.width),Double(size.height))*0.025 else {
   counter.observeLoss(timestampMs:timestamp);publish("The view is unclear. Try moving your phone.");return
  }
  guard case .wave(var wave)=counter else {return}
  wave.observe(centerX:centerX,centerY:centerY,handWidth:handWidth,timestampMs:timestamp)
  counter = .wave(wave)
  finishFrame()
 }

 private func observeNeck(_ buffer:CVPixelBuffer,size:CGSize,timestamp:Int) throws {
  try VNImageRequestHandler(cvPixelBuffer:buffer,orientation:.leftMirrored).perform([faceRequest])
  tracking = .face(faceRequest.results?.first,imageSize:size)
  guard let face=faceRequest.results?.first,face.confidence>=0.6,let yaw=face.yaw?.doubleValue,case .neck(var neck)=counter else {
   counter.observeLoss(timestampMs:timestamp);publish(kind.movementInstruction);return
  }
  neck.observe(yawDegrees:yaw*180/Double.pi,timestampMs:timestamp)
  counter = .neck(neck)
  finishFrame()
 }

 private func observeBody(_ buffer:CVPixelBuffer,size:CGSize,timestamp:Int) throws {
  try VNImageRequestHandler(cvPixelBuffer:buffer,orientation:.leftMirrored).perform([bodyRequest])
  guard let body=bodyRequest.results?.first else {
   counter.observeLoss(timestampMs:timestamp);publish(kind.movementInstruction,hint:.noPerson);return
  }
  let allPoints=try body.recognizedPoints(.all)
  tracking = .body(allPoints,imageSize:size)
  let hint=BodyFraming.hint(PoseGeometry.jointSamples(allPoints),needsFeet:kind == .jumpingJacks)
  func point(_ name:VNHumanBodyPoseObservation.JointName)->CGPoint? {
   guard let p=allPoints[name],PoseGeometry.isVisible(p,minConfidence:0.6) else {return nil}
   return p.location
  }
  guard let leftShoulder=point(.leftShoulder),let rightShoulder=point(.rightShoulder),let leftWrist=point(.leftWrist),let rightWrist=point(.rightWrist) else {
   counter.observeLoss(timestampMs:timestamp);publish(hint == .ok ? "The view is unclear. Try moving your phone.":kind.movementInstruction,hint:hint);return
  }
  let observation:MovementObservation
  if kind == .stretching {
   let raised=leftWrist.y>leftShoulder.y+0.08 && rightWrist.y>rightShoulder.y+0.08
   let lowered=leftWrist.y<leftShoulder.y-0.05 && rightWrist.y<rightShoulder.y-0.05
   observation = raised ? .stretch(overhead:true):lowered ? .stretch(overhead:false):.transition
  } else {
   guard let leftAnkle=point(.leftAnkle),let rightAnkle=point(.rightAnkle) else {
    counter.observeLoss(timestampMs:timestamp);publish(kind.movementInstruction,hint:hint);return
   }
   let shoulderWidth=abs(leftShoulder.x-rightShoulder.x),ankleWidth=abs(leftAnkle.x-rightAnkle.x)
   let armsRaised=leftWrist.y>leftShoulder.y+0.06 && rightWrist.y>rightShoulder.y+0.06
   let armsLowered=leftWrist.y<leftShoulder.y-0.05 && rightWrist.y<rightShoulder.y-0.05
   let legsApart=ankleWidth>shoulderWidth*1.25
   let legsTogether=ankleWidth<=shoulderWidth*1.15
   observation = armsRaised && legsApart ? .jumpingJack(open:true) : armsLowered && legsTogether ? .jumpingJack(open:false) : .transition
  }
  guard case .body(var progress)=counter else {return}
  _=progress.observe(observation,timestampMs:timestamp)
  counter = .body(progress)
  finishFrame(hint:hint)
 }

 private func finishFrame(hint:FramingHint = .ok) {
  if counter.ready {
   active=false;session.stopRunning();publish(ended:true,"Movement detected.")
  } else {
   publish(kind.movementInstruction,hint:hint)
  }
 }

 private func publish(ended:Bool=false,_ message:String,hint:FramingHint = .ok) {
  guard !isCancelled else {return}
  onUpdate(.init(reps:counter.completed,ready:ended && counter.ready,ended:ended,message:hint.message ?? appText(message),hint:hint,tracking:ended ? .empty : tracking))
 }
 private var isCancelled:Bool {lifecycleLock.lock();defer {lifecycleLock.unlock()};return cancelled}
}

private extension ChallengeKind {
 var movementInstruction:String {
  switch self {
  case .waveHand:return "Place your hand in view and wave it side to side."
  case .neckRotation:return "Turn your head to each side, then back to the middle."
  case .stretching:return "Raise both hands above your shoulders, then lower them."
  default:return "Keep your whole body visible and move through the jumping jack."
  }
 }
}
