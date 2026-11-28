import AVFoundation
import CoreMotion
import Vision
import HiMorningCore

struct LocalMovementUpdate:Sendable {
 let reps:Int
 let ready:Bool
 let ended:Bool
 let message:String
 let hint:FramingHint
 var tracking:CameraTrackingSnapshot = .empty
 var scanError:VisionScanError? = nil
 var trackingHint:String? = nil
 var romProgress:Double? = nil
 var formCue:MovementFormCue = .aligned
 var isLowLight:Bool = false
}

private enum MovementCounter {
 case wave(WaveCounter),neck(NeckTurnCounter),body(MovementChallengeProgress),squat(SquatCounter)

 init(kind:ChallengeKind) {
  let target=kind.localMovementTarget ?? 3
  switch kind {
  case .waveHand:self = .wave(WaveCounter(target:target))
  case .neckRotation:self = .neck(NeckTurnCounter(target:target))
  case .squats:self = .squat(SquatCounter(target:target))
  default:self = .body(MovementChallengeProgress(kind:kind,target:target))
  }
 }

 var completed:Int {
  switch self {
  case .wave(let c):return c.completed
  case .neck(let c):return c.completed
  case .body(let c):return c.completed
  case .squat(let c):return c.completedReps
  }
 }

 var ready:Bool {
  switch self {
  case .wave(let c):return c.ready
  case .neck(let c):return c.ready
  case .body(let c):return c.ready
  case .squat(let c):return c.ready
  }
 }

 var romProgress:Double? {
  if case .squat(let c)=self {return c.romProgress}
  return nil
 }

 var formCue:MovementFormCue {
  if case .squat(let c)=self {return c.formCue}
  return .aligned
 }

 mutating func observeLoss(timestampMs:Int) {
  switch self {
  case .wave(var c):c.observeLoss(timestampMs:timestampMs);self = .wave(c)
  case .neck(var c):c.observeLoss(timestampMs:timestampMs);self = .neck(c)
  case .body(var c):_=c.observe(.unavailable,timestampMs:timestampMs);self = .body(c)
  case .squat(var c):_=c.observe(kneeAngle:0,visible:false,timestampMs:timestampMs);self = .squat(c)
  }
 }
}

final class MovementChallengeCapture:NSObject,AVCaptureVideoDataOutputSampleBufferDelegate,@unchecked Sendable {
 let session=AVCaptureSession()
 private let kind:ChallengeKind
 private let queue=DispatchQueue(label:"com.himorning.local-movement",qos:.userInitiated)
 private let motionManager=CMMotionManager()
 private let motionQueue:OperationQueue={
  let q=OperationQueue();q.name="com.himorning.local-movement.motion";q.maxConcurrentOperationCount=1;return q
 }()
 private let onUpdate:@Sendable(LocalMovementUpdate)->Void
 private var counter:MovementCounter
 private let handRequest=VNDetectHumanHandPoseRequest()
 private let faceRequest:VNDetectFaceRectanglesRequest={
  let request=VNDetectFaceRectanglesRequest();request.revision=VNDetectFaceRectanglesRequestRevision3;return request
 }()
 private let faceLandmarksRequest:VNDetectFaceLandmarksRequest={
  let request=VNDetectFaceLandmarksRequest();request.revision=VNDetectFaceLandmarksRequestRevision3
  return request
 }()
 private let bodyRequest=VNDetectHumanBodyPoseRequest()
 private var started=0.0
 private var tracking:CameraTrackingSnapshot = .empty
 private var active=false
 private var cancelled=false
 private var consecutiveVisionErrors=0
 private var frameCount=0
 private var lastLowLight=false
 private var rollDeg:Double=0
 private var squatSide:Int?
 private var observers:[NSObjectProtocol]=[]
 private let lifecycleLock=NSLock()

 init(kind:ChallengeKind,onUpdate:@escaping @Sendable(LocalMovementUpdate)->Void) {
  precondition(kind.usesLocalMovement)
  handRequest.maximumHandCount=1
  self.kind=kind;counter=MovementCounter(kind:kind);self.onUpdate=onUpdate;super.init()
  motionQueue.underlyingQueue=queue
  motionManager.deviceMotionUpdateInterval=0.25
 }

 func start() async {
  guard !isCancelled else {return}
  guard await AVCaptureDevice.requestAccess(for:.video) else {
   publish(ended:true,"Camera access is off. You can tap I’m awake when it unlocks.",scanError:.cameraPermissionDenied);return
  }
  guard !isCancelled else {return}
  queue.async { [self] in
   guard !isCancelled else {return}
   do {
    if session.inputs.isEmpty {
     session.beginConfiguration();defer {session.commitConfiguration()};session.sessionPreset = .vga640x480
     guard let device=AVCaptureDevice.default(.builtInWideAngleCamera,for:.video,position:.front) else {throw CameraSetupError.unavailable}
     let input=try AVCaptureDeviceInput(device:device)
     guard session.canAddInput(input) else {throw CameraSetupError.unavailable};session.addInput(input)
     let output=AVCaptureVideoDataOutput();output.alwaysDiscardsLateVideoFrames=true
     output.setSampleBufferDelegate(self,queue:queue)
     guard session.canAddOutput(output) else {throw CameraSetupError.unavailable};session.addOutput(output)
    }
    guard !isCancelled else {return}
    for name in [AVCaptureSession.wasInterruptedNotification,AVCaptureSession.runtimeErrorNotification] {
     observers.append(NotificationCenter.default.addObserver(forName:name,object:session,queue:nil) { [weak self] _ in
      self?.queue.async { [weak self] in
       guard let self,self.active else {return}
       self.stopCamera()
       self.publish(ended:true,"The challenge is paused. Start it again, or tap I’m awake when it unlocks.",scanError:.interrupted)
      }
     })
    }
    if motionManager.isDeviceMotionAvailable,!motionManager.isDeviceMotionActive {
     motionManager.startDeviceMotionUpdates(to:motionQueue) { [weak self] motion,_ in
      guard let self,let g=motion?.gravity else {return}
      self.rollDeg=CameraConditionMath.iosRollDegrees(gx:g.x,gy:g.y)
     }
    }
    consecutiveVisionErrors=0;frameCount=0;lastLowLight=false;squatSide=nil
    counter=MovementCounter(kind:kind);started=ProcessInfo.processInfo.systemUptime;active=true;session.startRunning()
    publish(kind.movementInstruction)
    queue.asyncAfter(deadline:.now()+90) { [weak self] in
     guard let self,active,!counter.ready else {return}
     self.stopCamera()
     self.publish(ended:true,"Movement capture timed out. Try again, or tap I’m awake when it unlocks.",scanError:.timedOut)
    }
   } catch {
    stopCamera()
    publish(ended:true,"The camera could not open. You can tap I’m awake when it unlocks.",scanError:.cameraUnavailable)
   }
  }
 }

 func stop() {
  lifecycleLock.lock();cancelled=true;lifecycleLock.unlock()
  queue.async { [self] in stopCamera() }
 }

 private func stopCamera() {
  active=false;counter=MovementCounter(kind:kind);session.stopRunning()
  if motionManager.isDeviceMotionActive {motionManager.stopDeviceMotionUpdates()}
  observers.forEach {NotificationCenter.default.removeObserver($0)};observers.removeAll()
 }

 func captureOutput(_ output:AVCaptureOutput,didOutput sampleBuffer:CMSampleBuffer,from connection:AVCaptureConnection) {
  let now=ProcessInfo.processInfo.systemUptime
  guard active,let buffer=CMSampleBufferGetImageBuffer(sampleBuffer) else {return}
  tracking = .empty
  frameCount+=1
  if frameCount == 1 || frameCount % 8 == 0 {
   lastLowLight = CameraConditionMath.classifyLuma(PixelBufferLuma.sampleMeanLuma(buffer)) == .lowLight
  }
  let timestamp=Int((now-started)*1000)
  guard timestamp<=90_000 else {
   stopCamera()
   publish(ended:true,"Movement capture timed out. Try again, or tap I’m awake when it unlocks.",scanError:.timedOut);return
  }
  let size=CGSize(width:CVPixelBufferGetHeight(buffer),height:CVPixelBufferGetWidth(buffer))
  do {
   switch kind {
   case .waveHand:try observeWave(buffer,size:size,timestamp:timestamp)
   case .neckRotation:try observeNeck(buffer,size:size,timestamp:timestamp)
   case .squats:try observeSquat(buffer,size:size,timestamp:timestamp)
   case .jumpingJacks,.stretching:try observeBody(buffer,size:size,timestamp:timestamp)
   default:return
   }
   consecutiveVisionErrors=0
  } catch {
   consecutiveVisionErrors+=1
   counter.observeLoss(timestampMs:timestamp)
   if consecutiveVisionErrors >= 10 {
    stopCamera()
    publish(ended:true,"AI couldn’t read the camera frames. Check lighting and try again.",scanError:.aiScannerFailed)
   } else {
    publish("AI couldn’t read this frame — check lighting and hold steady.",trackingHint:appText("Low light or unclear view"))
   }
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
  let handler=VNImageRequestHandler(cvPixelBuffer:buffer,orientation:.leftMirrored)
  try handler.perform([faceRequest])
  tracking = .face(faceRequest.results?.first,imageSize:size)
  guard let face=faceRequest.results?.first,face.confidence>=0.6,let yaw=face.yaw?.doubleValue,case .neck(var neck)=counter else {
   counter.observeLoss(timestampMs:timestamp);publish(kind.movementInstruction);return
  }
  faceLandmarksRequest.inputFaceObservations=[face]
  do {
   try handler.perform([faceLandmarksRequest])
   if let markedFace=faceLandmarksRequest.results?.first {tracking = .face(markedFace,imageSize:size)}
  } catch {}
  neck.observe(yawDegrees:yaw*180/Double.pi,timestampMs:timestamp)
  counter = .neck(neck)
  finishFrame()
 }

 private func observeSquat(_ buffer:CVPixelBuffer,size:CGSize,timestamp:Int) throws {
  try VNImageRequestHandler(cvPixelBuffer:buffer,orientation:.leftMirrored).perform([bodyRequest])
  guard let body=bodyRequest.results?.first else {
   counter.observeLoss(timestampMs:timestamp);publish(kind.movementInstruction,hint:.noPerson);return
  }
  let allPoints=try body.recognizedPoints(.all)
  tracking = .body(allPoints,imageSize:size,minConfidence:0.55)
  let samples=PoseGeometry.jointSamples(allPoints)
  let hint=BodyFraming.hint(samples,needsFeet:true)
  let legSides:[[VNHumanBodyPoseObservation.JointName]]=[
   [.leftHip,.leftKnee,.leftAnkle],
   [.rightHip,.rightKnee,.rightAnkle]
  ]
  let preferred=squatSide ?? 0
  let order=[preferred,1-preferred]
  guard let chosen=order.first(where:{idx in legSides[idx].allSatisfy {PoseGeometry.isVisible(allPoints[$0],minConfidence:0.55)}}) else {
   counter.observeLoss(timestampMs:timestamp);publish(kind.movementInstruction,hint:hint);return
  }
  if let prev=squatSide,prev != chosen,case .squat(var s)=counter {s.interrupt();counter = .squat(s)}
  squatSide=chosen
  let aspect=size.height > 0 ? Double(size.width)/Double(size.height) : 0.75
  let pts=legSides[chosen].map {name -> CGPoint in
   let raw=allPoints[name]!.location
   let d=CameraConditionMath.derotateNormalizedPoint(x:Double(raw.x),y:Double(raw.y),rollDeg:rollDeg,aspectRatio:aspect)
   return CGPoint(x:d.x,y:d.y)
  }
  let kneeAngle=PoseGeometry.jointAngle(pts[0],pts[1],pts[2],imageSize:size)
  guard case .squat(var squat)=counter else {return}
  _=squat.observe(kneeAngle:kneeAngle,visible:true,timestampMs:timestamp)
  counter = .squat(squat)
  let formHint:String?
  switch squat.formCue {
  case .goLower:formHint=appText("Bend knees a little deeper")
  case .extendFully:formHint=appText("Stand all the way back up")
  case .tooFast:formHint=appText("Move smoothly")
  default:formHint=lastLowLight ? appText("Low light — tap Fill Light") : nil
  }
  if squat.ready {
   active=false;session.stopRunning();publish(ended:true,"Squats complete.")
  } else {
   publish(kind.movementInstruction,hint:hint,trackingHint:formHint)
  }
 }

 private func observeBody(_ buffer:CVPixelBuffer,size:CGSize,timestamp:Int) throws {
  try VNImageRequestHandler(cvPixelBuffer:buffer,orientation:.leftMirrored).perform([bodyRequest])
  guard let body=bodyRequest.results?.first else {
   counter.observeLoss(timestampMs:timestamp);publish(kind.movementInstruction,hint:.noPerson);return
  }
  let allPoints=try body.recognizedPoints(.all)
  tracking = .body(allPoints,imageSize:size,
   minConfidence:kind == .stretching ? Float(BodyFraming.upperBodyMinConfidence):0.55,
   edgeMargin:kind == .stretching ? CGFloat(BodyFraming.upperBodyEdgeMargin):0.02)
  let samples=PoseGeometry.jointSamples(allPoints)
  if kind == .stretching {
   let assessment=ReachUpGeometry.assess(samples,imageWidth:Double(size.width),imageHeight:Double(size.height))
   tracking.requiredJointsVisible=assessment.pose != .unclear
   guard case .body(var progress)=counter else {return}
   _=progress.observe(assessment.pose.observation,timestampMs:timestamp)
   counter = .body(progress)
   if assessment.pose == .unclear {
    publish("Keep both shoulders and elbows in view.",hint:assessment.hint)
   } else {finishFrame()}
   return
  }
  let hint=BodyFraming.hint(samples,needsFeet:true)
  func point(_ name:VNHumanBodyPoseObservation.JointName)->CGPoint? {
   guard let p=allPoints[name],PoseGeometry.isVisible(p,minConfidence:0.55) else {return nil}
   return p.location
  }
  guard let leftShoulder=point(.leftShoulder),let rightShoulder=point(.rightShoulder) else {
   counter.observeLoss(timestampMs:timestamp);publish(hint == .ok ? "The view is unclear. Try moving your phone.":kind.movementInstruction,hint:hint);return
  }
  let leftWrist=point(.leftWrist),rightWrist=point(.rightWrist)
  let leftElbow=point(.leftElbow),rightElbow=point(.rightElbow)
  guard (leftWrist != nil || leftElbow != nil),(rightWrist != nil || rightElbow != nil) else {
   counter.observeLoss(timestampMs:timestamp);publish(hint == .ok ? "The view is unclear. Try moving your phone.":kind.movementInstruction,hint:hint);return
  }
  guard let leftAnkle=point(.leftAnkle),let rightAnkle=point(.rightAnkle) else {
   counter.observeLoss(timestampMs:timestamp);publish(kind.movementInstruction,hint:hint);return
  }
  let shoulderWidth=abs(leftShoulder.x-rightShoulder.x),ankleWidth=abs(leftAnkle.x-rightAnkle.x)
  guard shoulderWidth>=0.06 else {
   counter.observeLoss(timestampMs:timestamp);publish(kind.movementInstruction,hint:.comeCloser);return
  }
  let leftArmUp=leftWrist.map {$0.y>leftShoulder.y+0.06} ?? (leftElbow.map {$0.y>leftShoulder.y-0.02} ?? false)
  let rightArmUp=rightWrist.map {$0.y>rightShoulder.y+0.06} ?? (rightElbow.map {$0.y>rightShoulder.y-0.02} ?? false)
  let leftArmDown=leftWrist.map {$0.y<leftShoulder.y-0.05} ?? (leftElbow.map {$0.y<leftShoulder.y-0.08} ?? false)
  let rightArmDown=rightWrist.map {$0.y<rightShoulder.y-0.05} ?? (rightElbow.map {$0.y<rightShoulder.y-0.08} ?? false)
  let armsRaised=leftArmUp && rightArmUp
  let armsLowered=leftArmDown && rightArmDown
  let legsApart=ankleWidth>shoulderWidth*1.25
  let legsTogether=ankleWidth<=shoulderWidth*1.15
  let observation:MovementObservation=armsRaised && legsApart ? .jumpingJack(open:true) : armsLowered && legsTogether ? .jumpingJack(open:false) : .transition
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

 private func publish(ended:Bool=false,_ message:String,hint:FramingHint = .ok,scanError:VisionScanError?=nil,trackingHint:String?=nil) {
  guard !isCancelled else {return}
  let resolvedHint=trackingHint ?? hint.message ?? (lastLowLight ? appText("Low light — tap Fill Light") : nil)
  onUpdate(.init(
   reps:counter.completed,
   ready:ended && counter.ready,
   ended:ended,
   message:hint.message ?? appText(message),
   hint:hint,
   tracking:ended ? .empty : tracking,
   scanError:scanError,
   trackingHint:resolvedHint,
   romProgress:counter.romProgress,
   formCue:counter.formCue,
   isLowLight:lastLowLight
  ))
 }
 private var isCancelled:Bool {lifecycleLock.lock();defer {lifecycleLock.unlock()};return cancelled}
}

private extension ChallengeKind {
 var movementInstruction:String {
  switch self {
  case .waveHand:return "Place your hand in view and wave it side to side."
  case .neckRotation:return "Turn your head to each side, then back to the middle."
  case .stretching:return "Raise both arms to count one. Lower them before raising them again."
  case .squats:return "Stand in view, bend your knees smoothly, then stand tall."
  default:return "Keep your whole body visible and move through the jumping jack."
  }
 }
}
