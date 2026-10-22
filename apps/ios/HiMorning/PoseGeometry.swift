import CoreGraphics
import Vision
import HiMorningCore

/// Reusable joint-geometry helpers shared by the camera capture pipelines,
/// so visibility bounds and angle math live in one place and do not drift
/// between challenges.
enum PoseGeometry {
 /// Ignore joints this close to the image edge, where Vision is unreliable.
 static let edgeMargin: CGFloat = 0.02

 /// A joint counts as visible when it is present, in-frame, away from the
 /// edges, and at or above the caller's confidence bar.
 static func isVisible(_ point: VNRecognizedPoint?, minConfidence: Float) -> Bool {
  guard let point, point.confidence >= minConfidence else { return false }
  let p = point.location
  return p.x > edgeMargin && p.x < 1 - edgeMargin && p.y > edgeMargin && p.y < 1 - edgeMargin
 }

 /// Angle ABC in degrees (B is the vertex), corrected for a non-square image.
 static func jointAngle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, imageSize: CGSize) -> Double {
  let first = CGVector(dx: (a.x - b.x) * imageSize.width, dy: (a.y - b.y) * imageSize.height)
  let second = CGVector(dx: (c.x - b.x) * imageSize.width, dy: (c.y - b.y) * imageSize.height)
  let denominator = sqrt((first.dx * first.dx + first.dy * first.dy) * (second.dx * second.dx + second.dy * second.dy))
  guard denominator > 0 else { return 0 }
  let cosine = Double(max(-1, min(1, (first.dx * second.dx + first.dy * second.dy) / denominator)))
  return acos(cosine) * 180 / Double.pi
 }
}

extension PoseGeometry {
 private static let bodyJoints:[VNHumanBodyPoseObservation.JointName:BodyJoint]=[
  .nose:.nose,.leftShoulder:.leftShoulder,.rightShoulder:.rightShoulder,.leftElbow:.leftElbow,.rightElbow:.rightElbow,
  .leftWrist:.leftWrist,.rightWrist:.rightWrist,.leftHip:.leftHip,.rightHip:.rightHip,.leftKnee:.leftKnee,.rightKnee:.rightKnee,
  .leftAnkle:.leftAnkle,.rightAnkle:.rightAnkle
 ]

 static func jointSamples(_ points:[VNHumanBodyPoseObservation.JointName:VNRecognizedPoint])->[BodyJoint:JointSample] {
  var samples:[BodyJoint:JointSample]=[:]
  for (name,joint) in bodyJoints {
   guard let point=points[name] else {continue}
   samples[joint]=JointSample(x:Double(point.location.x),y:Double(point.location.y),confidence:Double(point.confidence))
  }
  return samples
 }
}

extension FramingHint {
 var message:String? {
  switch self {
  case .ok:return nil
  case .stepBack:return appText("Step back so your whole body fits.")
  case .showFeet:return appText("Show your feet in the camera.")
  case .comeCloser:return appText("Come a little closer.")
  case .noPerson:return appText("Stand where the camera can see you.")
  }
 }
}
