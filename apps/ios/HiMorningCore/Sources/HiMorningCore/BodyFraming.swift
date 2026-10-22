import Foundation

public enum BodyJoint:String,CaseIterable,Sendable {
 case nose,leftShoulder,rightShoulder,leftElbow,rightElbow,leftWrist,rightWrist,leftHip,rightHip,leftKnee,rightKnee,leftAnkle,rightAnkle
}

public struct JointSample:Equatable,Sendable {
 public let x:Double
 public let y:Double
 public let confidence:Double
 public init(x:Double,y:Double,confidence:Double) {self.x=x;self.y=y;self.confidence=confidence}
}

public enum FramingHint:Equatable,Sendable {
 case ok,stepBack,showFeet,comeCloser,noPerson,showArms
}

public enum BodyFraming {
 private static let minConfidence=0.3
 private static let edgeMargin=0.02
 private static let minExtent=1.0/3.0

 // Close upper-body poses can have lower elbow confidence and touch the image edge.
 // Keep these bounds specific to reach up; other challenges retain their stricter checks.
 public static let upperBodyMinConfidence=0.4
 public static let upperBodyEdgeMargin=0.005

 /// Reach-up uses shoulders and elbows, not wrists, hips or feet.
 public static func upperBodyHint(_ joints:[BodyJoint:JointSample])->FramingHint {
  let required:[BodyJoint]=[.leftShoulder,.rightShoulder,.leftElbow,.rightElbow]
  let range=upperBodyEdgeMargin...(1-upperBodyEdgeMargin)
  guard required.allSatisfy({name in
   guard let point=joints[name] else {return false}
   return point.confidence.isFinite && point.confidence>=upperBodyMinConfidence && point.x.isFinite && point.y.isFinite &&
    point.x>range.lowerBound && point.x<range.upperBound && point.y>range.lowerBound && point.y<range.upperBound
  }) else {return .showArms}
  return .ok
 }

 public static func hint(_ joints:[BodyJoint:JointSample],needsFeet:Bool)->FramingHint {
  let detected=joints.filter {$0.value.confidence>=minConfidence}
  guard detected.count>=3 else {return .noPerson}
  let range=edgeMargin...(1-edgeMargin)
  if detected.values.contains(where:{!range.contains($0.x) || !range.contains($0.y)}) {return .stepBack}
  if needsFeet,detected[.leftAnkle]==nil,detected[.rightAnkle]==nil {return .showFeet}
  let ys=detected.values.map(\.y)
  if let top=ys.max(),let bottom=ys.min(),top-bottom<minExtent {return .comeCloser}
  return .ok
 }
}
