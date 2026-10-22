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
 case ok,stepBack,showFeet,comeCloser,noPerson
}

public enum BodyFraming {
 private static let minConfidence=0.3
 private static let edgeMargin=0.02
 private static let minExtent=1.0/3.0

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
