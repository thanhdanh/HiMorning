import XCTest
import Vision
import AVFoundation
@testable import HiMorning

final class CameraTrackingTests:XCTestCase {
 @MainActor func testCameraPreviewRetainsTheLiveSessionAndCompleteCameraImage() {
  let session=AVCaptureSession()
  let view=CameraPreview.Preview(session:session)
  let layer=view.layer as? AVCaptureVideoPreviewLayer
  XCTAssertNotNil(layer)
  XCTAssertTrue(layer?.session === session)
  XCTAssertEqual(layer?.videoGravity,.resizeAspect)
  XCTAssertNil(layer?.mask,"The preview must retain the person and surrounding scene")
 }
 func testProjectionFitsPortraitVideoInsideWidePreviewAndFlipsOnlyVerticalOrigin() {
  let projection=TrackingProjection(imageSize:CGSize(width:480,height:640),bounds:CGRect(x:10,y:20,width:360,height:280))
  XCTAssertEqual(projection.videoRect,CGRect(x:85,y:20,width:210,height:280))
  XCTAssertEqual(projection.point(CGPoint(x:0,y:0)),CGPoint(x:85,y:300))
  XCTAssertEqual(projection.point(CGPoint(x:1,y:1)),CGPoint(x:295,y:20))
  XCTAssertEqual(projection.point(CGPoint(x:0.5,y:0.5)),CGPoint(x:190,y:160))
  let box=projection.box(CGRect(x:0.1,y:0.6,width:0.2,height:0.3))
  XCTAssertEqual(box.minX,106,accuracy:0.001);XCTAssertEqual(box.minY,48,accuracy:0.001)
  XCTAssertEqual(box.width,42,accuracy:0.001);XCTAssertEqual(box.height,84,accuracy:0.001)
 }
 func testMissingOrUncertainElbowDoesNotCreateAnInventedShoulderWristLine() {
  typealias Joint=VNHumanBodyPoseObservation.JointName
  var points:[Joint:TrackedJoint]=[
   .leftShoulder:.init(point:CGPoint(x:0.3,y:0.7),confidence:0.9),
   .leftElbow:.init(point:CGPoint(x:0.2,y:0.5),confidence:0.2),
   .leftWrist:.init(point:CGPoint(x:0.1,y:0.3),confidence:0.9)
  ]
  let size=CGSize(width:480,height:640)
  let uncertain=CameraTrackingSnapshot.body(points,imageSize:size,uptime:10)
  XCTAssertTrue(uncertain.segments.isEmpty);XCTAssertEqual(uncertain.joints.count,2)
  points[.leftElbow] = .init(point:CGPoint(x:0.2,y:0.5),confidence:0.9)
  XCTAssertEqual(CameraTrackingSnapshot.body(points,imageSize:size,uptime:10).segments.count,2)
  points[.leftElbow] = .init(point:CGPoint(x:0.0,y:0.5),confidence:0.99)
  XCTAssertTrue(CameraTrackingSnapshot.body(points,imageSize:size,uptime:10).segments.isEmpty)
 }
 func testHeadBoxRequiresMultipleConfidentFacialLandmarks() {
  typealias Joint=VNHumanBodyPoseObservation.JointName
  var points:[Joint:TrackedJoint]=[.nose:.init(point:CGPoint(x:0.5,y:0.8),confidence:0.9)]
  let size=CGSize(width:480,height:640)
  XCTAssertNil(CameraTrackingSnapshot.body(points,imageSize:size,uptime:10).headBox)
  points[.leftEye] = .init(point:CGPoint(x:0.46,y:0.85),confidence:0.9)
  points[.rightEye] = .init(point:CGPoint(x:0.54,y:0.85),confidence:0.9)
  let box=CameraTrackingSnapshot.body(points,imageSize:size,uptime:10).headBox
  XCTAssertNotNil(box);XCTAssertTrue(CGRect(x:0,y:0,width:1,height:1).contains(box!))
 }
 func testStaleOrFutureGeometryCannotRemainOnTheLivePreview() {
  let snapshot=CameraTrackingSnapshot(observedAt:10)
  XCTAssertTrue(snapshot.isFresh(at:10.49))
  XCTAssertFalse(snapshot.isFresh(at:10.51))
  XCTAssertFalse(snapshot.isFresh(at:9.99))
  XCTAssertFalse(TrackedJoint(point:CGPoint(x:Double.nan,y:0.5),confidence:1).visible)
  XCTAssertFalse(TrackedJoint(point:CGPoint(x:0.5,y:0.5),confidence:Float.nan).visible)
 }
 func testCameraDenialPublishesNoTrackingGeometryOrRepetitions() async {
  let ended=expectation(description:"Denied capture")
  let capture=CameraCapture(target:3) {update in
   XCTAssertTrue(update.ended);XCTAssertFalse(update.tracking.hasMarks);XCTAssertEqual(update.reps,0)
   ended.fulfill()
  }
  await capture.start(requestAccess:{false})
  await fulfillment(of:[ended],timeout:1)
  capture.stop()
 }
}
