import Foundation

public struct PushUpCounter:Sendable {
 public let target:Int
 public private(set) var completedReps=0
 public var ready:Bool {completedReps == target}
 private static let occlusionGraceMs=600
 private var phase=0
 private var began:Int?
 private var loweredAt:Int?
 private var lastObservation:Int?
 private var lostSince:Int?
 // ChallengeCoordinator.completePushUps requires target == the saved repetitions, so this must accept every saved value.
 public init(target:Int) {self.target=min(ChallengeSelection.maximumPushUps,max(1,target))}
 public mutating func interrupt() {phase=0;began=nil;loweredAt=nil;lastObservation=nil;lostSince=nil}
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
  guard elbowAngle.isFinite,bodyAngle.isFinite,incline.isFinite,
        (0...180).contains(elbowAngle),(150...180).contains(bodyAngle),(0...35).contains(incline) else {interrupt();return}
  lastObservation=timestampMs
  if let began,timestampMs-began>15000 {interrupt();lastObservation=timestampMs}
  let matches:Bool
  switch phase {
  case 1:matches=elbowAngle<=90
  default:matches=elbowAngle>=160
  }
  guard matches else {return}
  if phase == 0 {began=timestampMs}
  if phase == 1 {
   guard let began,timestampMs-began>=150 else {interrupt();return}
   loweredAt=timestampMs
  }
  if phase == 2 {
   // A one-frame elbow dip must not become a completed rep after holding the plank.
   guard let loweredAt,timestampMs-loweredAt>=150 else {interrupt();return}
   if let began,timestampMs-began>=800 {completedReps+=1}
   interrupt()
  } else {phase+=1}
 }
}
