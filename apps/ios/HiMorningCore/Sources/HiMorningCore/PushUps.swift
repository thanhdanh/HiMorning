import Foundation

public struct PushUpCounter:Sendable {
 public let target:Int
 public private(set) var completedReps=0
 public var ready:Bool {completedReps == target}
 private var phase=0
 private var began:Int?
 private var lastPhase:Int?
 private var lastObservation:Int?
 public init(target:Int) {self.target=min(5,max(1,target))}
 public mutating func interrupt() {phase=0;began=nil;lastPhase=nil;lastObservation=nil}
 public mutating func observe(elbowAngle:Double,bodyAngle:Double,incline:Double,visible:Bool,timestampMs:Int) {
  guard !ready else {return}
  guard visible,elbowAngle.isFinite,bodyAngle.isFinite,incline.isFinite,
        (0...180).contains(elbowAngle),(150...180).contains(bodyAngle),(0...35).contains(incline),
        (0...120000).contains(timestampMs) else {interrupt();return}
  if let lastObservation {
   guard timestampMs>lastObservation else {interrupt();return}
   if timestampMs-lastObservation>1500 {interrupt()}
  }
  lastObservation=timestampMs
  if let began,timestampMs-began>15000 {interrupt();lastObservation=timestampMs}
  if let lastPhase,timestampMs-lastPhase<120 {return}
  let matches:Bool
  switch phase {
  case 0,4:matches=elbowAngle>=160
  case 1,3:matches=(100...150).contains(elbowAngle)
  default:matches=elbowAngle<=90
  }
  guard matches else {return}
  if phase == 0 {began=timestampMs}
  lastPhase=timestampMs
  if phase == 4 {
   if let began,timestampMs-began>=800 {completedReps+=1}
   interrupt()
  } else {phase+=1}
 }
}
