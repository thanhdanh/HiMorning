import AVFoundation
import Vision
import CoreImage
import ImageIO
import HiMorningCore

struct CaptureUpdate:Sendable {let reps:Int;let frames:[EvidenceFrame];let ready:Bool;let ended:Bool;let message:String}

final class CameraCapture:NSObject,AVCaptureVideoDataOutputSampleBufferDelegate,@unchecked Sendable {
 let session=AVCaptureSession()
 private let queue=DispatchQueue(label:"com.himorning.camera",qos:.userInitiated)
 private let context=CIContext(options:[.cacheIntermediates:false])
 private var capture:CycleCapture
 private var started:TimeInterval=0
 private var lastSample:TimeInterval=0
 private var active=false
 private let lifecycleLock=NSLock()
 private var cancelled=false
 private let onUpdate:@Sendable(CaptureUpdate)->Void
 init(target:Int,onUpdate:@escaping @Sendable(CaptureUpdate)->Void) {capture=CycleCapture(target:target);self.onUpdate=onUpdate;super.init()}
 
 func start(requestAccess:@Sendable () async ->Bool = {await AVCaptureDevice.requestAccess(for:.video)}) async {
  guard !isCancelled else {return}
  guard await requestAccess() else {
   guard !isCancelled else {return}
   onUpdate(.init(reps:0,frames:[],ready:false,ended:true,message:appText("Camera access is off. You can still stop.")));return
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
    started=ProcessInfo.processInfo.systemUptime;lastSample=0;active=true;session.startRunning()
   } catch {onUpdate(.init(reps:0,frames:[],ready:false,ended:true,message:appText("The camera could not open. Please choose another way.")))}
  }
 }
 
 private var isCancelled:Bool {lifecycleLock.lock();defer {lifecycleLock.unlock()};return cancelled}
 func stop() {lifecycleLock.lock();cancelled=true;lifecycleLock.unlock();queue.async { [self] in active=false;session.stopRunning();capture.clear()}}
 
 func captureOutput(_ output:AVCaptureOutput,didOutput sampleBuffer:CMSampleBuffer,from connection:AVCaptureConnection) {
  guard active,!capture.ready,ProcessInfo.processInfo.systemUptime-lastSample>=0.2,let buffer=CMSampleBufferGetImageBuffer(sampleBuffer) else {return}
  lastSample=ProcessInfo.processInfo.systemUptime
  let timestamp=Int((ProcessInfo.processInfo.systemUptime-started)*1000)
  
  // Use Apple's Vision framework for local push-up detection without network calls
  processFrameWithVision(buffer, timestamp:timestamp)
 }

 private func processFrameWithVision(_ buffer: CVPixelBuffer, timestamp: Int) {
  do {
   // Create a VNImageRequestHandler that runs entirely on device (no network call)
   let request = VNDetectHumanBodyPoseRequest { [weak self] request, error in
    guard let self = self else { return }
    
    if let error = error {
     print("Vision processing error: \(error)")
     // Fallback to basic counting or do nothing for now 
     DispatchQueue.main.async {
      let update = self.capture.currentUpdate()
      self.onUpdate(update)
     }
     return
    }
    
    guard let observations = request.results as? [VNHumanBodyPoseObservation],
          let pose = observations.first else {
     // Fallback if no body detected
     DispatchQueue.main.async {
      let update = self.capture.currentUpdate()
      self.onUpdate(update)
     }
     return
    }
    
    // Process the human body pose data using only local vision processing
    processBodyPose(pose, timestamp: timestamp)
   }
   
   // Configure for on-device processing (local only - no network calls)
   request.imageCropAndScaleOption = .centerCrop
   request.minimumConfidence = 0.7
   
   try VNImageRequestHandler(cvPixelBuffer:buffer,options:[:]).perform([request])
   
  } catch {
   // Handle any error gracefully without remote service dependencies  
   print("Vision handler setup error: \(error)")
   DispatchQueue.main.async {
    let update = capture.currentUpdate()
    self.onUpdate(update)
   }
  }
 }

 private func processBodyPose(_ pose: VNHumanBodyPoseObservation, timestamp: Int) {
  // Use Apple's Vision Framework for local body analysis
  guard let joints = pose.joints else { return }
  
  // Extract key joint positions from the human body pose (local processing)
  let leftShoulder = joints[.leftShoulder]
  let rightShoulder = joints[.rightShoulder] 
  let leftElbow = joints[.leftElbow]
  let rightElbow = joints[.rightElbow]
  let leftWrist = joints[.leftWrist]
  let rightWrist = joints[.rightWrist]
  
  // Calculate arm positions for push-up detection using only local processing
  if let leftShoulder, let leftElbow, let leftWrist,
     let rightShoulder, let rightElbow, let rightWrist {
    
    let leftArmBent = calculateArmAngle(leftShoulder, leftElbow, leftWrist)
    let rightArmBent = calculateArmAngle(rightShoulder, rightElbow, rightWrist)
    
    // Use Vision's local processing to decide if this is a push-up rep
    let update = capture.update(isPushUpRep: leftArmBent < 100.0 && rightArmBent < 100.0,
                               timestamp: timestamp)
    onUpdate(update)
   } else {
    // If we can't get all required joints, just update with current state
    let update = capture.currentUpdate()
    DispatchQueue.main.async {onUpdate(update)}
   }
 }

 private func calculateArmAngle(_ shoulder: VNPoint, _ elbow: VNPoint, _ wrist: VNPoint) -> Float {
  // Calculate angle using only local math - completely client-side calculation
  let dx1 = wrist.x - elbow.x
  let dy1 = wrist.y - elbow.y
  
  let dx2 = shoulder.x - elbow.x
  let dy2 = shoulder.y - elbow.y
  
  let dotProduct = dx1 * dx2 + dy1 * dy2
  let magnitude1 = sqrt(dx1 * dx1 + dy1 * dy1)
  let magnitude2 = sqrt(dx2 * dx2 + dy2 * dy2)
  
  // Convert to degrees using only local math
  return acos(max(-1, min(1, dotProduct / (magnitude1 * magnitude2)))) * 180 / .pi
 }

 private func processError(_ error: Error) {
  print("Camera capture processing error (using local AI): \(error)")
  // Continue with existing logic without remote service calls
  let update = capture.currentUpdate()
  DispatchQueue.main.async {onUpdate(update)}
 }
}

// MARK: - Push-up detection helper class

final class CycleCapture {
 private var reps = 0
 private var target: Int
 private let lock = NSLock()
 
 init(target: Int) {
  self.target = target
 }
 
 func update(isPushUpRep: Bool, timestamp: Int) -> CaptureUpdate {
  // Using Vision's local processing to determine if this is a push-up
  if isPushUpRep {
   lock.lock()
   reps += 1
   lock.unlock()
   
   return CaptureUpdate(
     reps: reps,
     frames: [],
     ready: reps >= target,
     ended: false,
     message: appText("Push-ups detected. \(target - reps) to go.")
   )
  }
  
  return currentUpdate()
 }

 func currentUpdate() -> CaptureUpdate {
  return CaptureUpdate(
    reps: reps,
    frames: [],
    ready: reps >= target,
    ended: false,
    message: appText("Ready for push-ups. \(target - reps) to go.")
  )
 }
 
 func clear() {
  lock.lock()
  reps = 0
  lock.unlock()
 }

 var ready: Bool { reps >= target }
}