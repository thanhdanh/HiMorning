import AVFoundation
import Vision
import HiMorningCore

struct CaptureUpdate:Sendable {
 let counter:PushUpCounter
 let ended:Bool
 let message:String
 var reps:Int {counter.completedReps}
 var ready:Bool {counter.ready}
}
final class CameraCapture:NSObject,AVCaptureVideoDataOutputSampleBufferDelegate,@unchecked Sendable {
 let session=AVCaptureSession()
 private let queue=DispatchQueue(label:"com.himorning.camera",qos:.userInitiated)
 private var counter:PushUpCounter
 private var started:TimeInterval=0
 private var lastSample:TimeInterval=0
 private var side:Int?
 private var active=false
 private let lifecycleLock=NSLock()
 private var cancelled=false
 private var observers:[NSObjectProtocol]=[]
 private let onUpdate:@Sendable(CaptureUpdate)->Void
 init(target:Int,onUpdate:@escaping @Sendable(CaptureUpdate)->Void) {counter=PushUpCounter(target:target);self.onUpdate=onUpdate;super.init()}
 func start(requestAccess:@Sendable () async ->Bool = {await AVCaptureDevice.requestAccess(for:.video)}) async {
  guard !isCancelled else {return}
  guard await requestAccess() else {
   publish(ended:true,message:appText("Camera access is off. You can still stop."));return
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
    for name in [AVCaptureSession.wasInterruptedNotification,AVCaptureSession.runtimeErrorNotification] {
     observers.append(NotificationCenter.default.addObserver(forName:name,object:session,queue:nil) { [weak self] _ in
      self?.queue.async { [weak self] in
       guard let self,self.active else {return}
       self.stopCamera();self.publish(ended:true,message:appText("The challenge is paused. You can choose another way."))
      }
     })
    }
    started=ProcessInfo.processInfo.systemUptime;lastSample=0;active=true;session.startRunning()
    publish(ended:false,message:appText("Move slowly up and down, within the camera view."))
   } catch {stopCamera();publish(ended:true,message:appText("The camera could not open. Please choose another way."))}
  }
 }
 private var isCancelled:Bool {lifecycleLock.lock();defer {lifecycleLock.unlock()};return cancelled}
 func stop() {lifecycleLock.lock();cancelled=true;lifecycleLock.unlock();queue.async { [self] in stopCamera()}}
 private func stopCamera() {
  active=false;session.stopRunning();counter.interrupt()
  observers.forEach {NotificationCenter.default.removeObserver($0)};observers.removeAll()
 }
 func captureOutput(_ output:AVCaptureOutput,didOutput sampleBuffer:CMSampleBuffer,from connection:AVCaptureConnection) {
  let now=ProcessInfo.processInfo.systemUptime
  guard active,!isCancelled,!counter.ready,now-lastSample>=0.12,let buffer=CMSampleBufferGetImageBuffer(sampleBuffer) else {return}
  lastSample=now
  let timestamp=Int((now-started)*1000)
  guard timestamp<=EvidenceBuffer.maximumDurationMs else {
   stopCamera();publish(ended:true,message:appText("Movement capture timed out. Try again or choose another challenge."));return
  }
  do {
   let request=VNDetectHumanBodyPoseRequest()
   try VNImageRequestHandler(cvPixelBuffer:buffer,orientation:.leftMirrored).perform([request])
   guard let body=request.results?.first else {counter.interrupt();publish(ended:false,message:appText("Place your phone so your whole body is visible."));return}
   let points=try body.recognizedPoints(.all)
   let sides:[[VNHumanBodyPoseObservation.JointName]] = [[.leftShoulder,.leftElbow,.leftWrist,.leftHip,.leftAnkle],[.rightShoulder,.rightElbow,.rightWrist,.rightHip,.rightAnkle]]
   guard let selected=sides.firstIndex(where:{names in names.allSatisfy {name in PoseGeometry.isVisible(points[name], minConfidence: 0.6)}}) else {counter.interrupt();publish(ended:false,message:appText("The view is unclear. Try moving your phone."));return}
   if let side,side != selected {counter.interrupt()};side=selected
   let joints=sides[selected].map {points[$0]!.location}
   let size=CGSize(width:CVPixelBufferGetHeight(buffer),height:CVPixelBufferGetWidth(buffer))
   let elbow=PoseGeometry.jointAngle(joints[0],joints[1],joints[2],imageSize:size)
   let bodyAngle=PoseGeometry.jointAngle(joints[0],joints[3],joints[4],imageSize:size)
   let dx=abs(joints[0].x-joints[4].x)*size.width,dy=abs(joints[0].y-joints[4].y)*size.height
   let incline=atan2(dy,dx)*180 / .pi
   let supported=joints[0].y>=joints[2].y-0.02 && abs(joints[2].y-joints[4].y)*size.height<=max(20,hypot(dx,dy)*0.2)
   counter.observe(elbowAngle:elbow,bodyAngle:bodyAngle,incline:incline,visible:supported,timestampMs:timestamp)
   let aligned=supported && bodyAngle>=150 && incline<=35
   publish(ended:counter.ready,message:appText(counter.ready ? "Push-ups complete. Have a good morning!" : aligned ? "Move slowly up and down, within the camera view." : "Keep your body straight in a push-up position, with your whole body in view."))
   if counter.ready {stopCamera()}
  } catch {counter.interrupt();publish(ended:false,message:appText("The movement is unclear. Try moving your phone."))}
 }
 private func publish(ended:Bool,message:String) {
  guard !isCancelled else {return}
  onUpdate(.init(counter:counter,ended:ended,message:message))
 }
}
