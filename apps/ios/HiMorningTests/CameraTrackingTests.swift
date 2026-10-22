import XCTest
import Vision
import AVFoundation
import HiMorningCore
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
 private let faceBox=CGRect(x:0.25,y:0.22,width:0.5,height:0.6)
 private let faceContour=[CGPoint(x:0.1,y:0.6),CGPoint(x:0.2,y:0.3),CGPoint(x:0.5,y:0.08),CGPoint(x:0.8,y:0.3),CGPoint(x:0.9,y:0.6)]
 private func faceGuide(turn:CGFloat=0,confidence:Float=0.95,landmarkConfidence:Float=0.95)->CameraTrackingSnapshot {
  .face(box:faceBox,confidence:confidence,landmarkConfidence:landmarkConfidence,
   medianLine:[CGPoint(x:0.5,y:0.82),CGPoint(x:0.5+turn*0.7,y:0.64),CGPoint(x:0.5+turn,y:0.47),CGPoint(x:0.5+turn*0.4,y:0.28)],
   contour:faceContour,imageSize:CGSize(width:480,height:640),uptime:10)
 }
 func testFaceCurveFollowsMeasuredMidlineLeftAndRightThroughTheChin() {
  let front=faceGuide()
  XCTAssertTrue(front.faceMidline.allSatisfy {abs($0.x-0.5)<0.001})
  XCTAssertEqual(front.faceMidline.last,CGPoint(x:0.5,y:0.268))
  XCTAssertGreaterThan(front.faceMidline.first!.y,faceBox.minY+0.82*faceBox.height)
  for turn:CGFloat in [-0.2,0.2] {
   let snapshot=faceGuide(turn:turn)
   XCTAssertEqual(snapshot.faceMidline.count,6)
   XCTAssertEqual(snapshot.faceMidline.last,front.faceMidline.last)
   XCTAssertTrue(snapshot.faceMidline.contains {(($0.x-0.5)*turn)>0.015})
   XCTAssertTrue(snapshot.faceMidline.allSatisfy {faceBox.contains($0)})
   let projection=TrackingProjection(imageSize:snapshot.imageSize,bounds:CGRect(x:0,y:0,width:300,height:400))
   let curve=projection.facePath(snapshot.faceMidline)
   XCTAssertFalse(curve.isEmpty)
   XCTAssertTrue(projection.box(faceBox).contains(curve.boundingRect))
   XCTAssertTrue(snapshot.isFresh(at:10.49));XCTAssertFalse(snapshot.isFresh(at:10.51))
  }
 }
 func testFaceCurveFollowsARolledFaceInsteadOfSortingByScreenHeight() {
  func roll(_ point:CGPoint)->CGPoint {CGPoint(x:1-point.y,y:point.x)}
  let median=[CGPoint(x:0.5,y:0.82),CGPoint(x:0.6,y:0.64),CGPoint(x:0.7,y:0.47),CGPoint(x:0.55,y:0.28)]
  let snapshot=CameraTrackingSnapshot.face(box:faceBox,confidence:0.95,landmarkConfidence:0.95,
   medianLine:median.map(roll),contour:faceContour.map(roll),imageSize:CGSize(width:480,height:640),uptime:10)
  XCTAssertEqual(snapshot.faceMidline.count,6)
  XCTAssertLessThan(snapshot.faceMidline.first!.x,faceBox.minX+0.18*faceBox.width)
  XCTAssertEqual(snapshot.faceMidline.last!.x,faceBox.minX+0.92*faceBox.width,accuracy:0.0001)
 }
 func testFaceRectangleCannotInventACurveWithoutReliableLandmarks() {
  XCTAssertTrue(faceGuide(landmarkConfidence:0.2).faceMidline.isEmpty)
  XCTAssertTrue(faceGuide(confidence:0.2).faceMidline.isEmpty)
  XCTAssertFalse(faceGuide(confidence:.nan).hasMarks)
  for median in [[],[CGPoint(x:0.5,y:0.8)],[CGPoint(x:0.5,y:0.8),CGPoint(x:.nan,y:0.5),CGPoint(x:0.5,y:0.3)]] {
   let snapshot=CameraTrackingSnapshot.face(box:faceBox,confidence:0.95,landmarkConfidence:0.95,
    medianLine:median,contour:faceContour,imageSize:CGSize(width:480,height:640),uptime:10)
   XCTAssertNotNil(snapshot.headBox);XCTAssertTrue(snapshot.faceMidline.isEmpty)
  }
  XCTAssertFalse(CameraTrackingSnapshot.face(nil,imageSize:CGSize(width:480,height:640)).hasMarks)
 }
 func testBodySpineAndLimbLinesUseOnlyVisibleDetectedJoints() {
  typealias Joint=VNHumanBodyPoseObservation.JointName
  let positions:[Joint:CGPoint]=[
   .neck:CGPoint(x:0.5,y:0.78),.root:CGPoint(x:0.5,y:0.44),
   .leftShoulder:CGPoint(x:0.35,y:0.72),.rightShoulder:CGPoint(x:0.65,y:0.72),
   .leftElbow:CGPoint(x:0.25,y:0.58),.rightElbow:CGPoint(x:0.75,y:0.58),
   .leftWrist:CGPoint(x:0.18,y:0.4),.rightWrist:CGPoint(x:0.82,y:0.4),
   .leftHip:CGPoint(x:0.4,y:0.44),.rightHip:CGPoint(x:0.6,y:0.44),
   .leftKnee:CGPoint(x:0.4,y:0.26),.rightKnee:CGPoint(x:0.6,y:0.26),
   .leftAnkle:CGPoint(x:0.4,y:0.06),.rightAnkle:CGPoint(x:0.6,y:0.06)
  ]
  var points=positions.mapValues {TrackedJoint(point:$0,confidence:0.95)}
  let full=CameraTrackingSnapshot.body(points,imageSize:CGSize(width:480,height:640),uptime:10)
  XCTAssertEqual(full.segments.count,13)
  XCTAssertTrue(full.segments.contains {$0.start==positions[.neck] && $0.end==positions[.root]})
  points[.root] = .init(point:positions[.root]!,confidence:0.2)
  points[.leftKnee]=nil
  let partial=CameraTrackingSnapshot.body(points,imageSize:CGSize(width:480,height:640),uptime:10)
  XCTAssertFalse(partial.segments.contains {$0.start==positions[.neck] && $0.end==positions[.root]})
  XCTAssertFalse(partial.segments.contains {$0.start==positions[.leftHip] && $0.end==positions[.leftAnkle]})
  XCTAssertTrue(partial.segments.contains {$0.start==positions[.rightKnee] && $0.end==positions[.rightAnkle]})
 }
 func testReachUpDrawsBothCompleteArmChainsWithoutAHeadOrLowerBody() {
  typealias Joint=VNHumanBodyPoseObservation.JointName
  let positions:[Joint:CGPoint]=[
   .leftShoulder:CGPoint(x:0.35,y:0.5),.rightShoulder:CGPoint(x:0.65,y:0.5),
   .leftElbow:CGPoint(x:0.25,y:0.65),.rightElbow:CGPoint(x:0.75,y:0.65),
   .leftWrist:CGPoint(x:0.2,y:0.8),.rightWrist:CGPoint(x:0.8,y:0.8)
  ]
  let points=positions.mapValues {TrackedJoint(point:$0,confidence:0.95)}
  var snapshot=CameraTrackingSnapshot.body(points,imageSize:CGSize(width:480,height:640),uptime:10)
  XCTAssertNil(snapshot.headBox);XCTAssertEqual(snapshot.segments.count,5)
  XCTAssertTrue(snapshot.segments.contains {$0.start==positions[.leftShoulder] && $0.end==positions[.leftElbow]})
  XCTAssertTrue(snapshot.segments.contains {$0.start==positions[.rightElbow] && $0.end==positions[.rightWrist]})
  XCTAssertTrue(snapshot.hasRequiredMarks)
  snapshot.requiredJointsVisible=false
  XCTAssertTrue(snapshot.hasMarks);XCTAssertFalse(snapshot.hasRequiredMarks,"Partial geometry must not claim that all required arms are visible")
 }
 func testReachUpKeepsShoulderElbowLinesWithWristsOutsideTheFrame() {
  typealias Joint=VNHumanBodyPoseObservation.JointName
  let positions:[Joint:CGPoint]=[
   .leftShoulder:CGPoint(x:0.35,y:0.5),.rightShoulder:CGPoint(x:0.65,y:0.5),
   .leftElbow:CGPoint(x:0.2,y:0.5),.rightElbow:CGPoint(x:0.8,y:0.5),
   .leftWrist:CGPoint(x:-0.2,y:0.8),.rightWrist:CGPoint(x:1.2,y:0.8)
  ]
  let snapshot=CameraTrackingSnapshot.body(positions.mapValues {TrackedJoint(point:$0,confidence:0.95)},imageSize:CGSize(width:480,height:640),uptime:10)
  XCTAssertEqual(snapshot.segments.count,3)
  XCTAssertTrue(snapshot.segments.contains {$0.start==positions[.leftShoulder] && $0.end==positions[.leftElbow]})
  XCTAssertTrue(snapshot.segments.contains {$0.start==positions[.rightShoulder] && $0.end==positions[.rightElbow]})
  XCTAssertFalse(snapshot.joints.contains(positions[.leftWrist]!))
  XCTAssertFalse(snapshot.joints.contains(positions[.rightWrist]!))
 }
 func testCloseReachOverlayUsesTheSameConfidenceAndEdgeBoundsAsCounting() {
  typealias Joint=VNHumanBodyPoseObservation.JointName
  let points:[Joint:TrackedJoint]=[
   .leftShoulder:.init(point:CGPoint(x:0.15,y:0.55),confidence:0.5),
   .rightShoulder:.init(point:CGPoint(x:0.85,y:0.55),confidence:0.5),
   .leftElbow:.init(point:CGPoint(x:0.008,y:0.58),confidence:0.45),
   .rightElbow:.init(point:CGPoint(x:0.992,y:0.58),confidence:0.45)
  ]
  let size=CGSize(width:480,height:640)
  let normal=CameraTrackingSnapshot.body(points,imageSize:size,uptime:10)
  XCTAssertTrue(normal.segments.isEmpty)
  let close=CameraTrackingSnapshot.body(points,imageSize:size,uptime:10,minConfidence:Float(BodyFraming.upperBodyMinConfidence),edgeMargin:CGFloat(BodyFraming.upperBodyEdgeMargin))
  XCTAssertEqual(close.segments.count,3);XCTAssertEqual(close.joints.count,4)
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
