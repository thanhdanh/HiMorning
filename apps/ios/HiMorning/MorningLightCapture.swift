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
 private var captureDevice: AVCaptureDevice?
 private var observers: [NSObjectProtocol] = []
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
   self.registerObservers()
   session.startRunning()
  }
  return true
 }

 func stop() {
  stopped = true
  let session = self.session
  queue.async { [weak self] in
   self?.clearObservers()
   if session.isRunning { session.stopRunning() }
  }
 }

 private func registerObservers() {
  clearObservers()
  for name in [AVCaptureSession.wasInterruptedNotification, AVCaptureSession.runtimeErrorNotification] {
   observers.append(NotificationCenter.default.addObserver(forName: name, object: session, queue: nil) { [weak self] _ in
    self?.queue.async { [weak self] in
     guard let self, !self.stopped else { return }
     self.stopped = true
     self.clearObservers()
     if self.session.isRunning { self.session.stopRunning() }
     self.onInterruption()
    }
   })
  }
 }

 private func clearObservers() {
  observers.forEach { NotificationCenter.default.removeObserver($0) }
  observers.removeAll()
 }

 private func configureSession() -> Bool {
  guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
   ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
   ?? AVCaptureDevice.default(for: .video),
   let input = try? AVCaptureDeviceInput(device: device) else {
   return false
  }
  captureDevice = device
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
  let pixelLuminance = Double(sum) / (Double(count) * 255.0)
  let evBrightness: Double
  if let device = captureDevice {
   evBrightness = MorningLightEvaluator.exposureBrightness(
    aperture: Double(device.lensAperture),
    exposureDuration: device.exposureDuration.seconds,
    iso: Double(device.iso)
   )
  } else {
   evBrightness = 0
  }
  let luminance = max(pixelLuminance, evBrightness)
  let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
  let state = evaluator.process(luminance: luminance, timestamp: timestamp)
  onUpdate(luminance, state)
 }

 func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
  _ = output
 }
}
