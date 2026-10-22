import Foundation

public enum MovementObservation:Sendable {
 case unavailable
 case transition
 case jumpingJack(open:Bool)
 case stretch(overhead:Bool)
}

public enum ReachUpPose:Equatable,Sendable {
 case lowered,raised,transition,unclear
 public var observation:MovementObservation {
  switch self {
  case .lowered:return .stretch(overhead:false)
  case .raised:return .stretch(overhead:true)
  case .transition:return .transition
  case .unclear:return .unavailable
  }
 }
}

public struct ReachUpAssessment:Sendable {
 public let pose:ReachUpPose
 public let hint:FramingHint
}

public enum ReachUpGeometry {
 public static func assess(_ joints:[BodyJoint:JointSample],imageWidth:Double,imageHeight:Double)->ReachUpAssessment {
  let hint=BodyFraming.upperBodyHint(joints)
  guard hint == .ok else {return .init(pose:.unclear,hint:hint)}
  guard imageWidth.isFinite,imageHeight.isFinite,imageWidth>0,imageHeight>0 else {return .init(pose:.unclear,hint:.showArms)}
  let leftShoulder=joints[.leftShoulder]!,rightShoulder=joints[.rightShoulder]!
  let leftElbow=joints[.leftElbow]!,rightElbow=joints[.rightElbow]!
  let dx=(rightShoulder.x-leftShoulder.x)*imageWidth,dy=(rightShoulder.y-leftShoulder.y)*imageHeight
  let shoulderWidth=hypot(dx,dy)
  guard shoulderWidth.isFinite,shoulderWidth>=min(imageWidth,imageHeight)*0.06 else {return .init(pose:.unclear,hint:.comeCloser)}
  // Measure upper-arm elevation against the shoulder line, so a tilted phone
  // does not turn a level arm into a lowered one. Forearms may leave the image.
  var upX = -dy/shoulderWidth,upY=dx/shoulderWidth
  if upY<0 {upX = -upX;upY = -upY}
  func offset(_ elbow:JointSample,_ shoulder:JointSample)->(x:Double,y:Double) {
   ((elbow.x-shoulder.x)*imageWidth,(elbow.y-shoulder.y)*imageHeight)
  }
  let left=offset(leftElbow,leftShoulder),right=offset(rightElbow,rightShoulder)
  guard hypot(left.x,left.y)>=shoulderWidth*0.12,hypot(right.x,right.y)>=shoulderWidth*0.12 else {return .init(pose:.unclear,hint:.showArms)}
  let leftHeight=left.x*upX+left.y*upY,rightHeight=right.x*upX+right.y*upY
  let raisedTolerance=max(4,shoulderWidth*0.13)
  let loweredMargin=max(8,shoulderWidth*0.4)
  let raised=leftHeight >= -raisedTolerance && rightHeight >= -raisedTolerance
  let lowered=leftHeight <= -loweredMargin && rightHeight <= -loweredMargin
  return .init(pose:raised ? .raised:lowered ? .lowered:.transition,hint:.ok)
 }
}

public struct WaveCounter:Sendable {
 private static let swingThreshold=0.62
 private static let minimumSwingMs=80
 private static let acquisitionMs=150
 private static let pairWindowMs=2_000
 private static let lossGraceMs=600
 private let target:Int
 private var horizontalFilter=OneEuroFilter(minCutoff:3.0,beta:0.3,derivativeCutoff:1.0)
 private var verticalFilter=OneEuroFilter(minCutoff:3.0,beta:0.3,derivativeCutoff:1.0)
 // Scale displacement, never absolute screen coordinates, so hand rotation cannot create travel.
 private var widthFilter=OneEuroFilter(minCutoff:0.3,beta:0)
 private var lastCenterX:Double?
 private var lastCenterY:Double?
 private var travelX=0.0
 private var travelY=0.0
 private var extremeX=0.0
 private var extremeY=0.0
 private var extremeMs=0
 private var direction=0
 private var seedLow=(x:0.0,y:0.0,time:0)
 private var seedHigh=(x:0.0,y:0.0,time:0)
 private var acquiredAtMs:Int?
 private var pendingSwingMs:Int?
 private var lossSinceMs:Int?
 private var lastSampleMs:Int?
 public private(set) var completed=0
 public var ready:Bool {completed>=target}

 public init(target:Int) {self.target=max(1,target)}
 public mutating func reset() {clearTracking();completed=0}

 @discardableResult public mutating func observe(centerX:Double,centerY:Double,handWidth:Double,timestampMs:Int)->Int {
  guard !ready else {return completed}
  guard (0...90_000).contains(timestampMs),lastSampleMs.map({timestampMs>$0}) ?? true else {clearTracking();return completed}
  guard handWidth>0,handWidth.isFinite,centerX.isFinite,centerY.isFinite,
        (centerX/handWidth).isFinite,(centerY/handWidth).isFinite else {observeLoss(timestampMs:timestampMs);return completed}
  if let last=lastSampleMs,timestampMs-last>Self.lossGraceMs {clearTracking()}
  if let lost=lossSinceMs,timestampMs-lost>Self.lossGraceMs {clearTracking()}
  lossSinceMs=nil;lastSampleMs=timestampMs
  let width=widthFilter.filter(handWidth,timestampMs:timestampMs)
  if let lastCenterX,let lastCenterY {
   travelX+=(centerX-lastCenterX)/width;travelY+=(centerY-lastCenterY)/width
  }
  lastCenterX=centerX;lastCenterY=centerY
  guard travelX.isFinite,travelY.isFinite else {clearTracking();return completed}
  let x=horizontalFilter.filter(travelX,timestampMs:timestampMs)
  let y=verticalFilter.filter(travelY,timestampMs:timestampMs)
  if acquiredAtMs == nil {acquiredAtMs=timestampMs}
  guard timestampMs-(acquiredAtMs ?? timestampMs)>=Self.acquisitionMs else {
   anchor(x:x,y:y,at:timestampMs);return completed
  }
  if direction == 0 {
   // Seed from both observed extremes, so starting at the middle of a wave is valid.
   if x<seedLow.x {seedLow=(x,y,timestampMs)}
   if x>seedHigh.x {seedHigh=(x,y,timestampMs)}
   if seedHigh.x-x>=Self.swingThreshold {
    extremeX=seedHigh.x;extremeY=seedHigh.y;extremeMs=seedHigh.time
   } else if x-seedLow.x>=Self.swingThreshold {
    extremeX=seedLow.x;extremeY=seedLow.y;extremeMs=seedLow.time
   }
  }
  if (direction>0 && x>extremeX) || (direction<0 && x<extremeX) {
   extremeX=x;extremeY=y;extremeMs=timestampMs
  }
  let dx=x-extremeX,dy=abs(y-extremeY)
  // Lifting/lowering the hand must clear a pending swing rather than complete it.
  if dy>0.35 && dy*1.4>abs(dx) {anchor(x:x,y:y,at:timestampMs);return completed}
  let reversing=direction == 0 || (direction>0 && dx<0) || (direction<0 && dx>0)
  guard reversing,abs(dx)>=Self.swingThreshold,abs(dx)>=dy*1.4,
        timestampMs-extremeMs>=Self.minimumSwingMs else {return completed}
  direction=dx>0 ? 1:-1
  extremeX=x;extremeY=y;extremeMs=timestampMs
  swing(at:timestampMs)
  return completed
 }

 public mutating func observeLoss(timestampMs:Int) {
  let lost=lossSinceMs ?? lastSampleMs ?? timestampMs
  lossSinceMs=lost
  if timestampMs-lost>Self.lossGraceMs {clearTracking();lossSinceMs=lost}
 }
 private mutating func anchor(x:Double,y:Double,at timestampMs:Int) {
  extremeX=x;extremeY=y;extremeMs=timestampMs;direction=0;pendingSwingMs=nil
  seedLow=(x,y,timestampMs);seedHigh=(x,y,timestampMs)
 }
 private mutating func swing(at timestampMs:Int) {
  if let pending=pendingSwingMs,timestampMs-pending<=Self.pairWindowMs {completed+=1;pendingSwingMs=nil}
  else {pendingSwingMs=timestampMs}
 }
 private mutating func clearTracking() {
  horizontalFilter.reset();verticalFilter.reset();widthFilter.reset()
  lastCenterX=nil;lastCenterY=nil;travelX=0;travelY=0
  extremeX=0;extremeY=0;extremeMs=0;direction=0;seedLow=(0,0,0);seedHigh=(0,0,0);acquiredAtMs=nil
  pendingSwingMs=nil;lossSinceMs=nil;lastSampleMs=nil
 }
}

/// Counts stable Vision poses. Reach up counts on the raised pose; jumping jacks require a full cycle.
public struct MovementChallengeProgress:Sendable {
 private enum Pose:Equatable {case closed,open,lowered,overhead}
 private let kind:ChallengeKind
 private let target:Int
 private var candidate:Pose?
 private var candidateSince=0
 private var candidateConsumed=false
 private var lastTimestamp:Int?
 private var phase=0
 // Keep this latch across interruptions so reacquiring raised arms cannot count twice.
 private var reachNeedsLowering=false
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
  let requiredDuration=(kind == .stretching && pose == .overhead) ? 120:220
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
   if pose == .lowered {reachNeedsLowering=false}
   else if pose == .overhead && !reachNeedsLowering {
    completed+=1;reachNeedsLowering=true
   }
  default:break
  }
 }
}

public struct NeckTurnCounter:Sendable {
 private enum Zone:Equatable {case left,center,right}
 private static let sideDegrees=20.0
 private static let centerDegrees=8.0
 private static let heldTurnDegrees=15.0
 private static let commitMs=120
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
  guard (0...90_000).contains(timestampMs),lastSampleMs.map({timestampMs>$0}) ?? true else {clearTracking();return completed}
  guard yawDegrees.isFinite else {observeLoss(timestampMs:timestampMs);return completed}
  if let last=lastSampleMs,timestampMs-last>lossLimitMs {clearTracking()}
  if let lost=lossSinceMs,timestampMs-lost>lossLimitMs {clearTracking()}
  lossSinceMs=nil;lastSampleMs=timestampMs
  let y=filter.filter(yawDegrees,timestampMs:timestampMs)
  lastAbsYaw=abs(y)
  let zone:Zone?=y >= Self.sideDegrees ? .right:y <= -Self.sideDegrees ? .left:abs(y) <= Self.centerDegrees ? .center:nil
  guard let zone else {candidate=nil;return completed}
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
  filter.reset();candidate=nil;committed=nil;lastAbsYaw=0;lossSinceMs=nil;lastSampleMs=nil;leftDone=false;rightDone=false
 }
}
