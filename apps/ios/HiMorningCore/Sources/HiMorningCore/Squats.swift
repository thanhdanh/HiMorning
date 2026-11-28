import Foundation

/// On-device squat counter sharing thresholds from shared/contracts/v1/movement-rules.json.
/// Smooths knee angles with OneEuroFilter, tracks ROM progress (0...1), and emits specific form cues.
public struct SquatCounter:Sendable {
 public let target:Int
 public private(set) var completedReps=0
 public private(set) var romProgress:Double=0
 public private(set) var formCue:MovementFormCue = .aligned
 public var ready:Bool {completedReps >= target}
 public var feedback:RepFeedback {RepFeedback(completedReps:completedReps,romProgress:romProgress,cue:formCue)}

 private static let standingMinDeg=155.0
 private static let bottomMaxDeg=115.0
 private static let minPhaseMs=140
 private static let minRepMs=650
 private static let maxRepMs=15_000
 private static let occlusionGraceMs=600
 private static let maxGapMs=1_500

 private var kneeFilter=OneEuroFilter(minCutoff:2.2,beta:0.18,derivativeCutoff:1.0)
 private var phase=0 // 0: waiting for standing, 1: descending to bottom, 2: rising back to standing
 private var began:Int?
 private var bottomAt:Int?
 private var lastObservation:Int?
 private var lostSince:Int?

 public init(target:Int=10) {
  self.target=min(ChallengeSelection.maximumPushUps,max(1,target))
 }

 public mutating func interrupt() {
  phase=0;began=nil;bottomAt=nil;lastObservation=nil;lostSince=nil
  romProgress=0;formCue = .aligned
  kneeFilter.reset()
 }

 @discardableResult public mutating func observe(kneeAngle:Double,visible:Bool,timestampMs:Int)->Int {
  guard !ready else {return completedReps}
  guard (0...90_000).contains(timestampMs) else {interrupt();return completedReps}
  if let lastObservation {
   guard timestampMs>lastObservation else {interrupt();return completedReps}
   if timestampMs-lastObservation>Self.maxGapMs {interrupt()}
  }
  guard visible else {
   let since=lostSince ?? timestampMs
   if timestampMs-since>Self.occlusionGraceMs {interrupt()} else {lostSince=since;lastObservation=timestampMs}
   return completedReps
  }
  if let lostSince,timestampMs-lostSince>Self.occlusionGraceMs {interrupt();return completedReps}
  lostSince=nil
  guard kneeAngle.isFinite,(0...180).contains(kneeAngle) else {interrupt();return completedReps}

  let smoothed=kneeFilter.filter(kneeAngle,timestampMs:timestampMs)
  guard smoothed.isFinite else {interrupt();return completedReps}
  lastObservation=timestampMs
  if let began,timestampMs-began>Self.maxRepMs {interrupt();lastObservation=timestampMs}

  let span=Self.standingMinDeg-Self.bottomMaxDeg
  romProgress=min(1.0,max(0.0,(Self.standingMinDeg-smoothed)/span))

  if phase == 1 && smoothed > Self.bottomMaxDeg && smoothed <= Self.bottomMaxDeg + 25 {
   formCue = .goLower
  } else if phase == 2 && smoothed < Self.standingMinDeg && smoothed >= Self.bottomMaxDeg + 15 {
   formCue = .extendFully
  } else {
   formCue = .aligned
  }

  let matches:Bool
  switch phase {
  case 1:matches=smoothed<=Self.bottomMaxDeg
  default:matches=smoothed>=Self.standingMinDeg
  }
  guard matches else {return completedReps}
  if phase == 0 {began=timestampMs;phase=1}
  else if phase == 1 {
   guard let began,timestampMs-began>=Self.minPhaseMs else {formCue = .tooFast;interrupt();return completedReps}
   bottomAt=timestampMs;phase=2
  } else {
   guard let bottomAt,timestampMs-bottomAt>=Self.minPhaseMs else {formCue = .tooFast;interrupt();return completedReps}
   if let began,timestampMs-began>=Self.minRepMs {
    completedReps+=1
    formCue = .aligned
   } else {
    formCue = .tooFast
   }
   // Rearm immediately in standing position so consecutive squats flow naturally.
   phase=1;began=timestampMs;self.bottomAt=nil;romProgress=0
  }
  return completedReps
 }
}
