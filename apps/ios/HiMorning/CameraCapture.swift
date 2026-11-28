import AVFoundation
import CoreMotion
import Vision
import HiMorningCore

enum CameraSetupError: Error {case unavailable}

/// Samples mean brightness [0..1] from a 16x16 luma grid on CVPixelBuffer (ported from go-tall).
enum PixelBufferLuma {
 static func sampleMeanLuma(_ pixelBuffer:CVPixelBuffer)->Double {
  CVPixelBufferLockBaseAddress(pixelBuffer,.readOnly)
  defer {CVPixelBufferUnlockBaseAddress(pixelBuffer,.readOnly)}
  let isPlanar=CVPixelBufferIsPlanar(pixelBuffer)
  let width=isPlanar ? CVPixelBufferGetWidthOfPlane(pixelBuffer,0) : CVPixelBufferGetWidth(pixelBuffer)
  let height=isPlanar ? CVPixelBufferGetHeightOfPlane(pixelBuffer,0) : CVPixelBufferGetHeight(pixelBuffer)
  let bytesPerRow=isPlanar ? CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer,0) : CVPixelBufferGetBytesPerRow(pixelBuffer)
  let base=isPlanar ? CVPixelBufferGetBaseAddressOfPlane(pixelBuffer,0) : CVPixelBufferGetBaseAddress(pixelBuffer)
  guard let base,width>0,height>0,bytesPerRow>0 else {return 0.5}
  let ptr=base.assumingMemoryBound(to:UInt8.self)
  let grid=16
  var sum=0,samples=0
  for r in 0..<grid {
   let y=(r*height)/grid
   let row=y*bytesPerRow
   for c in 0..<grid {
    let x=(c*width)/grid
    sum+=Int(ptr[row+x]);samples+=1
   }
  }
  guard samples>0 else {return 0.5}
  return Double(sum)/(Double(samples)*255.0)
 }
}

struct CaptureUpdate:Sendable {
 let counter:PushUpCounter
 let ended:Bool
 let message:String
 var tracking:CameraTrackingSnapshot = .empty
 var scanError:VisionScanError? = nil
 var trackingHint:String? = nil
 var romProgress:Double = 0
 var formCue:MovementFormCue = .aligned
 var isLowLight:Bool = false
 var reps:Int {counter.completedReps}
 var ready:Bool {counter.ready}
}

final class CameraCapture:NSObject,AVCaptureVideoDataOutputSampleBufferDelegate,@unchecked Sendable {
 let session=AVCaptureSession()
 private let queue=DispatchQueue(label:"com.himorning.camera",qos:.userInitiated)
 private let motionManager=CMMotionManager()
 private let motionQueue:OperationQueue={
  let q=OperationQueue();q.name="com.himorning.camera.motion";q.maxConcurrentOperationCount=1;return q
 }()
 private var counter:PushUpCounter
 private let variant:PushUpVariant
 private var started:TimeInterval=0
 private let request=VNDetectHumanBodyPoseRequest()
 private var side:Int?
 private var tracking:CameraTrackingSnapshot = .empty
 private var active=false
 private var consecutiveVisionErrors=0
 private var frameCount=0
 private var lastLowLight=false
 private var rollDeg:Double=0
 private let lifecycleLock=NSLock()
 private var cancelled=false
 private var observers:[NSObjectProtocol]=[]
 private let onUpdate:@Sendable(CaptureUpdate)->Void

 init(target:Int,variant:PushUpVariant = .standard,onUpdate:@escaping @Sendable(CaptureUpdate)->Void) {
  self.variant=variant
  counter=PushUpCounter(target:target,variant:variant)
  self.onUpdate=onUpdate
  super.init()
  motionQueue.underlyingQueue=queue
  motionManager.deviceMotionUpdateInterval=0.25
 }

 func start(requestAccess:@Sendable () async ->Bool = {await AVCaptureDevice.requestAccess(for:.video)}) async {
  guard !isCancelled else {return}
  guard await requestAccess() else {
   publish(ended:true,message:appText("Camera access is off. You can tap I’m awake when it unlocks."),scanError:.cameraPermissionDenied);return
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
       self.stopCamera();self.publish(ended:true,message:appText("The challenge is paused. Start it again, or tap I’m awake when it unlocks."),scanError:.interrupted)
      }
     })
    }
    if motionManager.isDeviceMotionAvailable,!motionManager.isDeviceMotionActive {
     motionManager.startDeviceMotionUpdates(to:motionQueue) { [weak self] motion,_ in
      guard let self,let g=motion?.gravity else {return}
      self.rollDeg=CameraConditionMath.iosRollDegrees(gx:g.x,gy:g.y)
     }
    }
    consecutiveVisionErrors=0;frameCount=0;lastLowLight=false;started=ProcessInfo.processInfo.systemUptime;active=true;session.startRunning()
    publish(ended:false,message:appText("Move slowly up and down, within the camera view."))
   } catch {stopCamera();publish(ended:true,message:appText("The camera could not open. You can tap I’m awake when it unlocks."),scanError:.cameraUnavailable)}
  }
 }

 private var isCancelled:Bool {lifecycleLock.lock();defer {lifecycleLock.unlock()};return cancelled}
 func stop() {lifecycleLock.lock();cancelled=true;lifecycleLock.unlock();queue.async { [self] in stopCamera()}}
 private func stopCamera() {
  active=false;session.stopRunning();counter.interrupt()
  if motionManager.isDeviceMotionActive {motionManager.stopDeviceMotionUpdates()}
  observers.forEach {NotificationCenter.default.removeObserver($0)};observers.removeAll()
 }

 func captureOutput(_ output:AVCaptureOutput,didOutput sampleBuffer:CMSampleBuffer,from connection:AVCaptureConnection) {
  let now=ProcessInfo.processInfo.systemUptime
  guard active,!isCancelled,!counter.ready,let buffer=CMSampleBufferGetImageBuffer(sampleBuffer) else {return}
  tracking = .empty
  frameCount+=1
  if frameCount == 1 || frameCount % 8 == 0 {
   lastLowLight = CameraConditionMath.classifyLuma(PixelBufferLuma.sampleMeanLuma(buffer)) == .lowLight
  }
  let size=CGSize(width:CVPixelBufferGetHeight(buffer),height:CVPixelBufferGetWidth(buffer))
  let aspect=size.height > 0 ? Double(size.width)/Double(size.height) : 0.75
  let timestamp=Int((now-started)*1000)
  guard timestamp<=EvidenceBuffer.maximumDurationMs else {
   stopCamera();publish(ended:true,message:appText("Movement capture timed out. Try again, or tap I’m awake when it unlocks."),scanError:.timedOut);return
  }
  do {
   try VNImageRequestHandler(cvPixelBuffer:buffer,orientation:.leftMirrored).perform([request])
   consecutiveVisionErrors=0
   guard let body=request.results?.first else {
    counter.observe(elbowAngle:0,bodyAngle:0,incline:0,visible:false,timestampMs:timestamp)
    publish(ended:false,message:appText("Place your phone so your whole body is visible."),trackingHint:lastLowLight ? appText("Low light — tap Fill Light") : appText("AI can’t see your body"))
    return
   }
   let points=try body.recognizedPoints(.all)
   tracking = .body(points,imageSize:size,minConfidence:0.55)

   // Standard push-up requires ankle; incline/knee variant accepts knee when ankle is resting or hidden.
   let fullSides:[[VNHumanBodyPoseObservation.JointName]]=[[.leftShoulder,.leftElbow,.leftWrist,.leftHip,.leftAnkle],[.rightShoulder,.rightElbow,.rightWrist,.rightHip,.rightAnkle]]
   let kneeSides:[[VNHumanBodyPoseObservation.JointName]]=[[.leftShoulder,.leftElbow,.leftWrist,.leftHip,.leftKnee],[.rightShoulder,.rightElbow,.rightWrist,.rightHip,.rightKnee]]
   var selectedSide:Int?
   var selectedJoints:[CGPoint]?
   if let idx=fullSides.firstIndex(where:{names in names.allSatisfy {PoseGeometry.isVisible(points[$0],minConfidence:0.55)}}) {
    selectedSide=idx
    selectedJoints=fullSides[idx].map {points[$0]!.location}
   } else if variant == .inclineOrKnee,
             let idx=kneeSides.firstIndex(where:{names in names.allSatisfy {PoseGeometry.isVisible(points[$0],minConfidence:0.55)}}) {
    selectedSide=idx
    selectedJoints=kneeSides[idx].map {points[$0]!.location}
   }

   guard let selected=selectedSide,let rawJoints=selectedJoints else {
    counter.observe(elbowAngle:0,bodyAngle:0,incline:0,visible:false,timestampMs:timestamp)
    publish(ended:false,message:appText("The view is unclear. Try moving your phone."),trackingHint:lastLowLight ? appText("Low light — tap Fill Light") : appText("Step back — show full body"))
    return
   }
   if let side,side != selected {counter.interrupt()};side=selected

   // Apply CoreMotion roll compensation so a phone propped slightly crooked still reads incline accurately.
   let joints=rawJoints.map {pt -> CGPoint in
    let d=CameraConditionMath.derotateNormalizedPoint(x:Double(pt.x),y:Double(pt.y),rollDeg:rollDeg,aspectRatio:aspect)
    return CGPoint(x:d.x,y:d.y)
   }
   let elbow=PoseGeometry.jointAngle(joints[0],joints[1],joints[2],imageSize:size)
   let bodyAngle=PoseGeometry.jointAngle(joints[0],joints[3],joints[4],imageSize:size)
   let dx=abs(joints[0].x-joints[4].x)*size.width,dy=abs(joints[0].y-joints[4].y)*size.height
   let incline=atan2(dy,dx)*180 / .pi
   let supported:Bool
   if variant == .inclineOrKnee {
    supported=joints[0].y>=joints[2].y-0.05
   } else {
    supported=joints[0].y>=joints[2].y-0.02 && abs(joints[2].y-joints[4].y)*size.height<=max(24,hypot(dx,dy)*0.28)
   }
   counter.observe(elbowAngle:elbow,bodyAngle:bodyAngle,incline:incline,visible:supported,timestampMs:timestamp)

   let bodyMin=variant == .inclineOrKnee ? 138.0 : 150.0
   let inclineMax=variant == .inclineOrKnee ? 68.0 : 42.0
   let aligned=supported && bodyAngle>=bodyMin && incline<=inclineMax
   let cueMessage:String
   let cueHint:String?
   if counter.ready {
    cueMessage=appText("Push-ups complete.");cueHint=nil
   } else if !aligned {
    cueMessage=appText("Keep your body straight in a push-up position, with your whole body in view.")
    cueHint=appText("Straighten into push-up form")
   } else {
    switch counter.formCue {
    case .goLower:
     cueMessage=appText("Lower a little more to count the rep.");cueHint=appText("Lower a bit more")
    case .extendFully:
     cueMessage=appText("Push all the way back up to finish the rep.");cueHint=appText("Push all the way up")
    case .tooFast:
     cueMessage=appText("Move smoothly up and down.");cueHint=appText("Slow down slightly")
    case .keepBodyStraight:
     cueMessage=appText("Keep your body straight.");cueHint=appText("Keep hips level")
    case .aligned:
     cueMessage=appText("Move slowly up and down, within the camera view.");cueHint=lastLowLight ? appText("Low light — tap Fill Light") : nil
    }
   }
   publish(ended:counter.ready,message:cueMessage,trackingHint:cueHint)
   if counter.ready {stopCamera()}
  } catch {
   consecutiveVisionErrors+=1
   counter.observe(elbowAngle:0,bodyAngle:0,incline:0,visible:false,timestampMs:timestamp)
   if consecutiveVisionErrors >= 10 {
    stopCamera();publish(ended:true,message:appText("AI couldn’t read the camera frames. Check lighting and try again."),scanError:.aiScannerFailed)
   } else {
    publish(ended:false,message:appText("AI couldn’t read this frame — check lighting and hold steady."),trackingHint:appText("Low light or unclear view"))
   }
  }
 }

 private func publish(ended:Bool,message:String,scanError:VisionScanError?=nil,trackingHint:String?=nil) {
  guard !isCancelled else {return}
  onUpdate(.init(
   counter:counter,
   ended:ended,
   message:message,
   tracking:ended ? .empty : tracking,
   scanError:scanError,
   trackingHint:trackingHint,
   romProgress:counter.romProgress,
   formCue:counter.formCue,
   isLowLight:lastLowLight
  ))
 }
}
