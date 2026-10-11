import AVFoundation
import Vision
import CoreImage
import ImageIO
import HiMorningCore
struct CaptureUpdate:Sendable {let reps:Int;let frames:[EvidenceFrame];let ready:Bool;let message:String}
final class CameraCapture:NSObject,AVCaptureVideoDataOutputSampleBufferDelegate,@unchecked Sendable {
 let session=AVCaptureSession()
 private let queue=DispatchQueue(label:"com.himorning.camera",qos:.userInitiated)
 private let context=CIContext(options:[.cacheIntermediates:false])
 private var capture:CycleCapture
 private var started:TimeInterval=0
 private var lastSample:TimeInterval=0
 private var active=false
 private let onUpdate:@Sendable(CaptureUpdate)->Void
 init(target:Int,onUpdate:@escaping @Sendable(CaptureUpdate)->Void) {capture=CycleCapture(target:target);self.onUpdate=onUpdate;super.init()}
 func start() async {
  guard await AVCaptureDevice.requestAccess(for:.video) else {onUpdate(.init(reps:0,frames:[],ready:false,message:"Chưa có quyền camera. Bạn vẫn có thể dừng."));return}
  queue.async { [self] in
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
    started=ProcessInfo.processInfo.systemUptime;lastSample=0;active=true;session.startRunning()
   } catch {onUpdate(.init(reps:0,frames:[],ready:false,message:"Không mở được camera. Hãy chọn cách khác."))}
  }
 }
 func stop() {queue.async { [self] in active=false;session.stopRunning();capture.clear()}}
 func captureOutput(_ output:AVCaptureOutput,didOutput sampleBuffer:CMSampleBuffer,from connection:AVCaptureConnection) {
  guard active,!capture.ready,ProcessInfo.processInfo.systemUptime-lastSample>=0.2,let buffer=CMSampleBufferGetImageBuffer(sampleBuffer) else {return}
  lastSample=ProcessInfo.processInfo.systemUptime
  let timestamp=Int((ProcessInfo.processInfo.systemUptime-started)*1000)
  do {
   let request=VNDetectHumanBodyPoseRequest()
   try VNImageRequestHandler(cvPixelBuffer:buffer,orientation:.leftMirrored).perform([request])
   guard let body=request.results?.first else {capture.interrupt();publish("Đặt điện thoại để thấy toàn thân.");return}
   let points=try body.recognizedPoints(.all)
   let sides:[[VNHumanBodyPoseObservation.JointName]] = [[.leftShoulder,.leftElbow,.leftWrist,.leftHip,.leftAnkle],[.rightShoulder,.rightElbow,.rightWrist,.rightHip,.rightAnkle]]
   guard let side=sides.first(where:{names in names.allSatisfy {name in guard let point=points[name] else {return false};return point.confidence>=0.6 && point.location.x>0.02 && point.location.x<0.98 && point.location.y>0.02 && point.location.y<0.98}}) else {capture.interrupt();publish("Chưa nhìn rõ. Bạn có thể đổi góc máy.");return}
   let image=CIImage(cvPixelBuffer:buffer).oriented(.leftMirrored)
   let scale=min(1,512/max(image.extent.width,image.extent.height))
   let reduced=image.transformed(by:CGAffineTransform(scaleX:scale,y:scale))
   guard let jpeg=context.jpegRepresentation(of:reduced,colorSpace:CGColorSpaceCreateDeviceRGB(),options:[kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption:0.45]),jpeg.count<=50000 else {capture.interrupt();return}
   let a=points[side[0]]!.location,b=points[side[1]]!.location,c=points[side[2]]!.location
   let ax=(a.x-b.x)*image.extent.width,ay=(a.y-b.y)*image.extent.height,bx=(c.x-b.x)*image.extent.width,by=(c.y-b.y)*image.extent.height
   let denominator=sqrt((ax*ax+ay*ay)*(bx*bx+by*by))
   guard denominator>0 else {capture.interrupt();return}
   let angle=acos(max(-1,min(1,(ax*bx+ay*by)/denominator)))*180 / .pi
   capture.observe(angle:angle,visible:true,jpeg:jpeg,timestampMs:timestamp)
   publish(capture.ready ? "Đã ghi đủ chuyển động. Đang xác minh…" : "Lên và xuống chậm, trong vùng camera.")
   if capture.ready {active=false;queue.async {self.session.stopRunning()}}
  } catch {capture.interrupt();publish("Chưa nhìn rõ động tác. Hãy thử đổi góc máy.")}
 }
 private func publish(_ message:String) {onUpdate(.init(reps:capture.completedReps,frames:capture.ready ? capture.frames : [],ready:capture.ready,message:message))}
}
