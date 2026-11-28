import Foundation

public enum MovementFormCue:String,Equatable,Sendable {
 case aligned
 case goLower
 case extendFully
 case keepBodyStraight
 case tooFast
}

public struct RepFeedback:Equatable,Sendable {
 public let completedReps:Int
 public let romProgress:Double
 public let cue:MovementFormCue
 public init(completedReps:Int,romProgress:Double,cue:MovementFormCue) {
  self.completedReps=completedReps
  self.romProgress=romProgress
  self.cue=cue
 }
}

public struct PushUpCounter:Sendable {
 public let target:Int
 public let variant:PushUpVariant
 public private(set) var completedReps=0
 public private(set) var romProgress:Double=0
 public private(set) var formCue:MovementFormCue = .aligned
 public var ready:Bool {completedReps == target}
 public var feedback:RepFeedback {RepFeedback(completedReps:completedReps,romProgress:romProgress,cue:formCue)}

 private static let occlusionGraceMs=600
 private static let formGraceMs=450
 private var elbowFilter=OneEuroFilter(minCutoff:2.2,beta:0.18,derivativeCutoff:1.0)
 private var bodyFilter=OneEuroFilter(minCutoff:2.0,beta:0.15,derivativeCutoff:1.0)
 private var phase=0
 private var began:Int?
 private var loweredAt:Int?
 private var lastObservation:Int?
 private var lostSince:Int?
 private var formLostSince:Int?

 private var downThresholdDeg:Double {variant == .inclineOrKnee ? 108.0 : 98.0}
 private var upThresholdDeg:Double {variant == .inclineOrKnee ? 146.0 : 150.0}
 private var bodyMinDeg:Double {variant == .inclineOrKnee ? 138.0 : 150.0}
 private var inclineMaxDeg:Double {variant == .inclineOrKnee ? 68.0 : 42.0}

 // ChallengeCoordinator.completePushUps requires target == the saved repetitions, so this must accept every saved value.
 public init(target:Int,variant:PushUpVariant = .standard) {
  self.target=min(ChallengeSelection.maximumPushUps,max(1,target))
  self.variant=variant
 }

 public mutating func interrupt() {
  phase=0;began=nil;loweredAt=nil;lastObservation=nil;lostSince=nil;formLostSince=nil
  romProgress=0;formCue = .aligned
  elbowFilter.reset();bodyFilter.reset()
 }

 public mutating func observe(elbowAngle:Double,bodyAngle:Double,incline:Double,visible:Bool,timestampMs:Int) {
  guard !ready else {return}
  // Same limit as CameraCapture, so a long target never keeps the camera open after counting has stopped.
  guard (0...EvidenceBuffer.maximumDurationMs).contains(timestampMs) else {interrupt();return}
  if let lastObservation {
   guard timestampMs>lastObservation else {interrupt();return}
   if timestampMs-lastObservation>1500 {interrupt()}
  }
  guard visible else {
   let since=lostSince ?? timestampMs
   if timestampMs-since>Self.occlusionGraceMs {interrupt()} else {lostSince=since;lastObservation=timestampMs}
   return
  }
  if let lostSince,timestampMs-lostSince>Self.occlusionGraceMs {interrupt();return}
  lostSince=nil
  guard elbowAngle.isFinite,bodyAngle.isFinite,incline.isFinite,(0...180).contains(elbowAngle) else {interrupt();return}

  let smoothedElbow=elbowFilter.filter(elbowAngle,timestampMs:timestampMs)
  let smoothedBody=bodyFilter.filter(bodyAngle,timestampMs:timestampMs)
  guard smoothedElbow.isFinite,smoothedBody.isFinite else {interrupt();return}

  guard (bodyMinDeg...180).contains(smoothedBody),(0...inclineMaxDeg).contains(incline) else {
   formCue = .keepBodyStraight
   let since=formLostSince ?? timestampMs
   if timestampMs-since>Self.formGraceMs {interrupt()} else {formLostSince=since;lastObservation=timestampMs}
   return
  }
  if let formLostSince,timestampMs-formLostSince>Self.formGraceMs {interrupt();return}
  formLostSince=nil
  lastObservation=timestampMs
  if let began,timestampMs-began>15000 {interrupt();lastObservation=timestampMs}

  // Normalized Range-of-Motion gauge (0.0 at extended arms -> 1.0 at target bottom depth)
  let span=max(10.0,upThresholdDeg-downThresholdDeg)
  romProgress=min(1.0,max(0.0,(upThresholdDeg-smoothedElbow)/span))

  if phase == 1 && smoothedElbow > downThresholdDeg && smoothedElbow <= downThresholdDeg + 27 {
   formCue = .goLower
  } else if phase == 2 && smoothedElbow < upThresholdDeg && smoothedElbow >= downThresholdDeg + 15 {
   formCue = .extendFully
  } else {
   formCue = .aligned
  }

  let matches:Bool
  switch phase {
  case 1:matches=smoothedElbow<=downThresholdDeg
  default:matches=smoothedElbow>=upThresholdDeg
  }
  guard matches else {return}
  if phase == 0 {began=timestampMs}
  if phase == 1 {
   guard let began,timestampMs-began>=150 else {formCue = .tooFast;interrupt();return}
   loweredAt=timestampMs
  }
  if phase == 2 {
   // A one-frame elbow dip must not become a completed rep after holding the plank.
   guard let loweredAt,timestampMs-loweredAt>=150 else {formCue = .tooFast;interrupt();return}
   if let began,timestampMs-began>=750 {
    completedReps+=1
    formCue = .aligned
   } else {
    formCue = .tooFast
   }
   interrupt()
  } else {phase+=1}
 }
}
