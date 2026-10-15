import AVFoundation
import Vision
import HiMorningCore

final class MovementChallengeCapture:NSObject,AVCaptureVideoDataOutputSampleBufferDelegate,@unchecked Sendable {
 let session=AVCaptureSession()
 private let kind:ChallengeKind
 private let queue=DispatchQueue(label:"com.himorning.local-movement",qos:.userInitiated)
 private let onUpdate:@Sendable(CaptureUpdate)->Void
 private var waveMotion=WaveHandMotion()
 private var progress:MovementChallengeProgress
 private var started=0.0
 private var lastSample=0.0
 private var active=false
 private var cancelled=false
 private let lifecycleLock=NSLock()

 init(kind:ChallengeKind,onUpdate:@escaping @Sendable(CaptureUpdate)->Void) {
  precondition(kind.usesLocalMovement)
  self.kind=kind;progress=MovementChallengeProgress(kind:kind);self.onUpdate=onUpdate;super.init()
 }

 func start() async {
  guard !isCancelled else {return}
  guard await AVCaptureDevice.requestAccess(for:.video) else {
   publish(0,ended:true,"Camera access is off. You can still stop.");return
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
    queue.asyncAfter(deadline:.now()+90) { [weak self] in
     guard let self,active,!progress.ready else {return}
     active=false;progress.interrupt();waveMotion.reset();session.stopRunning()
     publish(progress.completed,ended:true,"Movement capture timed out. Try again or choose another challenge.")
    }
   } catch {publish(0,ended:true,"The camera could not open. Please choose another way.")}
  }
 }

 func stop() {
  lifecycleLock.lock();cancelled=true;lifecycleLock.unlock()
  queue.async { [self] in active=false;progress.interrupt();waveMotion.reset();session.stopRunning() }
 }

 func captureOutput(_ output:AVCaptureOutput,didOutput sampleBuffer:CMSampleBuffer,from connection:AVCaptureConnection) {
  let now=ProcessInfo.processInfo.systemUptime
  guard active,now-lastSample>=0.25,let buffer=CMSampleBufferGetImageBuffer(sampleBuffer) else {return}
  lastSample=now
  let timestamp=Int((now-started)*1000)
  guard timestamp<=90_000 else {
   active=false;progress.interrupt();waveMotion.reset();session.stopRunning()
   publish(progress.completed,ended:true,"Movement capture timed out. Try again or choose another challenge.");return
  }
  do {
   let observation:MovementObservation
   switch kind {
   case .waveHand:
    let request=VNDetectHumanHandPoseRequest();request.maximumHandCount=1
    try VNImageRequestHandler(cvPixelBuffer:buffer,orientation:.leftMirrored).perform([request])
    guard let hand=request.results?.first,let tip=try? hand.recognizedPoint(.indexTip),let wrist=try? hand.recognizedPoint(.wrist),tip.confidence>=0.6,wrist.confidence>=0.6 else {waveMotion.reset();observe(.unavailable,timestamp);publish(progress.completed,"Place your hand in view and wave it side to side.");return}
    observation=waveMotion.observe(x:Double(tip.location.x))
   case .neckRotation:
    let request=VNDetectFaceLandmarksRequest()
    try VNImageRequestHandler(cvPixelBuffer:buffer,orientation:.leftMirrored).perform([request])
    guard let face=request.results?.first,face.confidence>=0.6,let yaw=face.yaw?.doubleValue else {observe(.unavailable,timestamp);publish(progress.completed,"Keep your face visible and turn your head left and right.");return}
    observation = abs(yaw)>0.15 && abs(yaw)<0.30 ? .transition:.headYaw(yaw)
   case .jumpingJacks,.stretching:
    let request=VNDetectHumanBodyPoseRequest()
    try VNImageRequestHandler(cvPixelBuffer:buffer,orientation:.leftMirrored).perform([request])
    guard let body=request.results?.first else {observe(.unavailable,timestamp);publish(progress.completed,kind == .stretching ? "Raise both hands above your shoulders, then lower them.":"Keep your whole body visible and move through the jumping jack.");return}
    let points=try body.recognizedPoints(.all)
    func point(_ name:VNHumanBodyPoseObservation.JointName)->CGPoint? {
     guard let p=points[name],p.confidence>=0.6,p.location.x>0.02,p.location.x<0.98,p.location.y>0.02,p.location.y<0.98 else {return nil}
     return p.location
    }
    guard let leftShoulder=point(.leftShoulder),let rightShoulder=point(.rightShoulder),let leftWrist=point(.leftWrist),let rightWrist=point(.rightWrist) else {observe(.unavailable,timestamp);publish(progress.completed,"The view is unclear. Try moving your phone.");return}
    if kind == .stretching {
     let raised=leftWrist.y>leftShoulder.y+0.08 && rightWrist.y>rightShoulder.y+0.08
     let lowered=leftWrist.y<leftShoulder.y-0.05 && rightWrist.y<rightShoulder.y-0.05
     observation = raised ? .stretch(overhead:true):lowered ? .stretch(overhead:false):.transition
    } else {
     guard let leftAnkle=point(.leftAnkle),let rightAnkle=point(.rightAnkle) else {observe(.unavailable,timestamp);publish(progress.completed,"Keep your whole body visible and move through the jumping jack.");return}
     let shoulderWidth=abs(leftShoulder.x-rightShoulder.x),ankleWidth=abs(leftAnkle.x-rightAnkle.x)
     let armsRaised=leftWrist.y>leftShoulder.y+0.06 && rightWrist.y>rightShoulder.y+0.06
     let armsLowered=leftWrist.y<leftShoulder.y-0.05 && rightWrist.y<rightShoulder.y-0.05
     let legsApart=ankleWidth>shoulderWidth*1.25
     let legsTogether=ankleWidth<=shoulderWidth*1.15
     observation = armsRaised && legsApart ? .jumpingJack(open:true) : armsLowered && legsTogether ? .jumpingJack(open:false) : .transition
    }
   default:return
   }
   observe(observation,timestamp)
   if progress.ready {
    active=false;session.stopRunning();publish(progress.completed,ended:true,"Movement captured.")
   } else {
    let message=kind == .waveHand ? "Place your hand in view and wave it side to side." : kind == .neckRotation ? "Keep your face visible and turn your head left and right." : kind == .stretching ? "Raise both hands above your shoulders, then lower them.":"Keep your whole body visible and move through the jumping jack."
    publish(progress.completed,message)
   }
  } catch {waveMotion.reset();observe(.unavailable,timestamp);publish(progress.completed,"The view is unclear. Try moving your phone.")}
 }

 private func observe(_ value:MovementObservation,_ timestamp:Int) { _ = progress.observe(value,timestampMs:timestamp) }
 private func publish(_ reps:Int,ended:Bool=false,_ message:String) {
  onUpdate(.init(reps:reps,frames:[],ready:ended && progress.ready,ended:ended,message:appText(message)))
 }
 private var isCancelled:Bool {lifecycleLock.lock();defer {lifecycleLock.unlock()};return cancelled}
}
