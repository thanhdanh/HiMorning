import AVFoundation
import CoreVideo
import Foundation
import HiMorningCore

final class MorningLightCapture: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
 enum Availability {
  case ready
  case needsPermission
  case unavailable
 }

 let session = AVCaptureSession()
 private let queue = DispatchQueue(label: "com.himorning.morninglight", qos: .userInitiated)
 private var evaluator = MorningLightEvaluator()
 private var configured = false
 private var stopped = false
 private let onUpdate: @Sendable (Double, MorningLightEvaluator.State) -> Void
 private let onInterruption: @Sendable () -> Void

 init(
  onUpdate: @escaping @Sendable (Double, MorningLightEvaluator.State) -> Void,
  onInterruption: @escaping @Sendable () -> Void
 ) {
  self.onUpdate = onUpdate
  self.onInterruption = onInterruption
  super.init()
 }

 static func requestAccessIfNeeded() async -> Availability {
  switch AVCaptureDevice.authorizationStatus(for: .video) {
  case .authorized:
   return .ready
  case .notDetermined:
   let granted = await AVCaptureDevice.requestAccess(for: .video)
   return granted ? .ready : .needsPermission
  case .denied, .restricted:
   return .needsPermission
  @unknown default:
   return .unavailable
  }
 }

 func start() -> Bool {
  if !configured {
   guard configureSession() else { return false }
   configured = true
  }
  stopped = false
  let session = self.session
  queue.async { [weak self] in
   guard let self, !self.stopped, !session.isRunning else { return }
   session.startRunning()
  }
  return true
 }

 func stop() {
  stopped = true
  let session = self.session
  queue.async {
   if session.isRunning { session.stopRunning() }
  }
 }

 private func configureSession() -> Bool {
  guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
   ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
   ?? AVCaptureDevice.default(for: .video),
   let input = try? AVCaptureDeviceInput(device: device) else {
   return false
  }
  session.beginConfiguration()
  session.sessionPreset = .low
  guard session.canAddInput(input) else {
   session.commitConfiguration()
   return false
  }
  session.addInput(input)

  let output = AVCaptureVideoDataOutput()
  output.videoSettings = [
   kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
  ]
  output.alwaysDiscardsLateVideoFrames = true
  output.setSampleBufferDelegate(self, queue: queue)
  guard session.canAddOutput(output) else {
   session.commitConfiguration()
   return false
  }
  session.addOutput(output)
  session.commitConfiguration()
  return true
 }

 func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
  guard !stopped, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
  CVPixelBufferLockBaseAddress(buffer, .readOnly)
  defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

  guard let baseAddress = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) else { return }
  let width = CVPixelBufferGetWidthOfPlane(buffer, 0)
  let height = CVPixelBufferGetHeightOfPlane(buffer, 0)
  let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
  let ptr = baseAddress.assumingMemoryBound(to: UInt8.self)

  var sum: UInt64 = 0
  var count: UInt64 = 0
  let step = 4
  for y in stride(from: 0, to: height, by: step) {
   let row = ptr + y * bytesPerRow
   for x in stride(from: 0, to: width, by: step) {
    sum += UInt64(row[x])
    count += 1
   }
  }
  guard count > 0 else { return }
  let luminance = Double(sum) / (Double(count) * 255.0)
  let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
  let state = evaluator.process(luminance: luminance, timestamp: timestamp)
  onUpdate(luminance, state)
 }

 func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
  _ = output
 }
}
