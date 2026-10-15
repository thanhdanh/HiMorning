import Foundation

public enum MovementObservation:Sendable {
 case unavailable
 case transition
 case wave(direction:Int)
 case headYaw(Double)
 case jumpingJack(open:Bool)
 case stretch(overhead:Bool)
}

/// Counts ordered, stable Vision poses. An interruption clears the current cycle but keeps completed reps.
public struct MovementChallengeProgress:Sendable {
 private enum Pose:Equatable {case left,center,right,closed,open,lowered,overhead}
 private let kind:ChallengeKind
 private let target:Int
 private var candidate:Pose?
 private var candidateSince=0
 private var candidateConsumed=false
 private var lastTimestamp:Int?
 private var phase=0
 private var lastWaveDirection:Int?
 private var waveReversals=0
 public private(set) var completed=0
 public var ready:Bool {completed>=target}

 public init(kind:ChallengeKind,target:Int?=nil) {
  precondition(kind.usesLocalMovement)
  self.kind=kind;self.target=max(1,target ?? kind.localMovementTarget!)
 }

 public mutating func interrupt() {
  candidate=nil;candidateSince=0;candidateConsumed=false;phase=0;lastWaveDirection=nil;waveReversals=0
 }

 @discardableResult public mutating func observe(_ observation:MovementObservation,timestampMs:Int)->Int {
  guard !ready else {return completed}
  guard (0...90_000).contains(timestampMs),lastTimestamp.map({timestampMs>$0 && timestampMs-$0<=2_000}) ?? true else {
   interrupt();lastTimestamp=(0...90_000).contains(timestampMs) ? timestampMs:nil;return completed
  }
  lastTimestamp=timestampMs
  if case .transition=observation {candidate=nil;candidateConsumed=false;return completed}
  let pose:Pose
  switch (kind,observation) {
  case (.waveHand,.wave(let direction)) where direction == -1:pose = .left
  case (.waveHand,.wave(let direction)) where direction == 1:pose = .right
  case (.neckRotation,.headYaw(let yaw)) where yaw.isFinite && yaw <= -0.30:pose = .left
  case (.neckRotation,.headYaw(let yaw)) where yaw.isFinite && yaw >= 0.30:pose = .right
  case (.neckRotation,.headYaw(let yaw)) where yaw.isFinite && abs(yaw) <= 0.15:pose = .center
  case (.jumpingJacks,.jumpingJack(let open)):pose = open ? .open:.closed
  case (.stretching,.stretch(let overhead)):pose = overhead ? .overhead:.lowered
  default:interrupt();return completed
  }
  if pose != candidate {candidate=pose;candidateSince=timestampMs;candidateConsumed=false;return completed}
  let requiredDuration=(kind == .stretching && pose == .overhead) ? 700:300
  guard timestampMs-candidateSince>=requiredDuration,!candidateConsumed else {return completed}
  candidateConsumed=true
  consume(pose)
  return completed
 }

 private mutating func consume(_ pose:Pose) {
  switch kind {
  case .waveHand:
   guard pose == .left || pose == .right else {interrupt();return}
   guard let previous=lastWaveDirection else {lastWaveDirection=pose == .left ? -1:1;return}
   let direction=pose == .left ? -1:1
   if direction != previous {waveReversals+=1;lastWaveDirection=direction;if waveReversals==2 {completed+=1;waveReversals=0}}
  case .neckRotation:
   let expected:[Pose]=[.center,.left,.center,.right,.center]
   guard pose==expected[phase] else {phase=pose == .center ? 1:0;return}
   phase+=1
   if phase==expected.count {completed+=1;phase=1}
  case .jumpingJacks:
   let expected:[Pose]=[.closed,.open,.closed]
   guard pose==expected[phase] else {phase=pose == .closed ? 1:0;return}
   phase+=1
   if phase==expected.count {completed+=1;phase=1}
  case .stretching:
   let expected:[Pose]=[.lowered,.overhead,.lowered]
   guard pose==expected[phase] else {phase=pose == .lowered ? 1:0;return}
   phase+=1
   if phase==expected.count {completed+=1;phase=1}
  default:break
  }
 }
}
