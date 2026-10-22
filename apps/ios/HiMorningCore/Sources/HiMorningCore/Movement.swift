import Foundation

public enum MovementObservation:Sendable {
 case unavailable
 case transition
 case jumpingJack(open:Bool)
 case stretch(overhead:Bool)
}

public struct WaveCounter:Sendable {
 private static let swingThreshold=0.35
 private static let pairWindowMs=2_000
 private static let lossGraceMs=600
 private let target:Int
 private var filter=OneEuroFilter(minCutoff:1.0,beta:0.3,derivativeCutoff:1.0)
 private var high=0.0
 private var low=0.0
 private var direction=0
 private var started=false
 private var pendingSwingMs:Int?
 private var lossSinceMs:Int?
 private var lastSampleMs:Int?
 public private(set) var completed=0
 public var ready:Bool {completed>=target}

 public init(target:Int) {self.target=max(1,target)}

 public mutating func reset() {clearTracking();completed=0}

 @discardableResult public mutating func observe(centerX:Double,handWidth:Double,timestampMs:Int)->Int {
  guard !ready else {return completed}
  guard handWidth > 0,handWidth.isFinite,centerX.isFinite else {observeLoss(timestampMs:timestampMs);return completed}
  let ratio=centerX/handWidth
  guard ratio.isFinite else {observeLoss(timestampMs:timestampMs);return completed}
  if let lost=lossSinceMs,timestampMs-lost>Self.lossGraceMs {clearTracking()}
  lossSinceMs=nil;lastSampleMs=timestampMs
  let u=filter.filter(ratio,timestampMs:timestampMs)
  guard started else {high=u;low=u;started=true;return completed}
  if direction>=0 {high=max(high,u)}
  if direction<=0 {low=min(low,u)}
  if direction>=0 && high-u>=Self.swingThreshold {direction = -1;low=u;swing(at:timestampMs)}
  else if direction<=0 && u-low>=Self.swingThreshold {direction=1;high=u;swing(at:timestampMs)}
  return completed
 }

 public mutating func observeLoss(timestampMs:Int) {
  let lost=lossSinceMs ?? lastSampleMs ?? timestampMs
  lossSinceMs=lost
  if timestampMs-lost>Self.lossGraceMs {clearTracking();lossSinceMs=lost}
 }

 private mutating func swing(at timestampMs:Int) {
  if let pending=pendingSwingMs,timestampMs-pending<=Self.pairWindowMs {completed+=1;pendingSwingMs=nil}
  else {pendingSwingMs=timestampMs}
 }

 private mutating func clearTracking() {
  filter.reset();started=false;direction=0;pendingSwingMs=nil;lossSinceMs=nil;lastSampleMs=nil
 }
}

/// Counts ordered, stable Vision poses. An interruption clears the current cycle but keeps completed reps.
public struct MovementChallengeProgress:Sendable {
 private enum Pose:Equatable {case closed,open,lowered,overhead}
 private let kind:ChallengeKind
 private let target:Int
 private var candidate:Pose?
 private var candidateSince=0
 private var candidateConsumed=false
 private var lastTimestamp:Int?
 private var phase=0
 private var lossSinceMs:Int?
 public private(set) var completed=0
 public var ready:Bool {completed>=target}

 /// Grace window (ms) before a brief tracking loss resets an in-progress sequence.
 /// One or two low-confidence frames must not throw away rep progress.
 private static let trackingLossGraceMs=600

 public init(kind:ChallengeKind,target:Int?=nil) {
  precondition(kind == .jumpingJacks || kind == .stretching)
  self.kind=kind;self.target=max(1,target ?? kind.localMovementTarget!)
 }

 public mutating func interrupt() {
  candidate=nil;candidateSince=0;candidateConsumed=false;phase=0;lossSinceMs=nil
 }

 /// Clears transient hold state (held pose, wave direction) without discarding completed
 /// reps or the in-progress sequence position. Used to absorb brief tracking loss.
 private mutating func softReset() {
  candidate=nil;candidateSince=0;candidateConsumed=false
 }

 @discardableResult public mutating func observe(_ observation:MovementObservation,timestampMs:Int)->Int {
  guard !ready else {return completed}
  guard (0...90_000).contains(timestampMs),lastTimestamp.map({timestampMs>$0 && timestampMs-$0<=2_000}) ?? true else {
   interrupt();lastTimestamp=(0...90_000).contains(timestampMs) ? timestampMs:nil;return completed
  }
  lastTimestamp=timestampMs
  if case .transition=observation {candidate=nil;candidateConsumed=false;lossSinceMs=nil;return completed}
  if case .unavailable=observation {
   if let lost=lossSinceMs, timestampMs-lost>=Self.trackingLossGraceMs {interrupt();return completed}
   if lossSinceMs == nil {lossSinceMs=timestampMs}
   softReset();return completed
  }
  lossSinceMs=nil
  let pose:Pose
  switch (kind,observation) {
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

public struct NeckTurnCounter:Sendable {
 private enum Zone:Equatable {case left,center,right}
 private static let sideDegrees=20.0
 private static let centerDegrees=8.0
 private static let heldTurnDegrees=15.0
 private static let commitMs=150
 private static let heldTurnLossMs=1_500
 private static let lossGraceMs=600
 private let target:Int
 private var filter=OneEuroFilter(minCutoff:1.0,beta:0.05,derivativeCutoff:1.0)
 private var candidate:Zone?
 private var candidateSinceMs=0
 private var committed:Zone?
 private var leftDone=false
 private var rightDone=false
 private var lastAbsYaw=0.0
 private var lossSinceMs:Int?
 private var lastSampleMs:Int?
 public private(set) var completed=0
 public var ready:Bool {completed>=target}

 public init(target:Int) {self.target=max(1,target)}

 @discardableResult public mutating func observe(yawDegrees:Double,timestampMs:Int)->Int {
  guard !ready else {return completed}
  guard yawDegrees.isFinite else {observeLoss(timestampMs:timestampMs);return completed}
  if let lost=lossSinceMs,timestampMs-lost>lossLimitMs {clearTracking()}
  lossSinceMs=nil;lastSampleMs=timestampMs
  let y=filter.filter(yawDegrees,timestampMs:timestampMs)
  lastAbsYaw=abs(y)
  let zone:Zone?=y >= Self.sideDegrees ? .right:y <= -Self.sideDegrees ? .left:abs(y) <= Self.centerDegrees ? .center:nil
  guard let zone else {return completed}
  if zone != candidate {candidate=zone;candidateSinceMs=timestampMs}
  if zone != committed && timestampMs-candidateSinceMs>=Self.commitMs {commit(zone)}
  return completed
 }

 public mutating func observeLoss(timestampMs:Int) {
  let lost=lossSinceMs ?? lastSampleMs ?? timestampMs
  lossSinceMs=lost
  if timestampMs-lost>lossLimitMs {clearTracking();lossSinceMs=lost}
 }

 private var lossLimitMs:Int {
  committed != nil && committed != .center && lastAbsYaw >= Self.heldTurnDegrees ? Self.heldTurnLossMs:Self.lossGraceMs
 }

 private mutating func commit(_ zone:Zone) {
  if zone == .center {
   if committed == .left {leftDone=true}
   if committed == .right {rightDone=true}
  }
  committed=zone
  if leftDone && rightDone {completed+=1;leftDone=false;rightDone=false}
 }

 private mutating func clearTracking() {
  filter.reset();candidate=nil;committed=nil;lastAbsYaw=0;lossSinceMs=nil;lastSampleMs=nil
 }
}
