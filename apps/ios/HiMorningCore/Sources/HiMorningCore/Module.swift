import Foundation
public struct WakePolicy: Equatable, Sendable { public let reps: Int; public let snoozes: Int }
public enum WakeMode: String, Codable, CaseIterable, Sendable {
 case gentle, balanced, focused
 public var policy: WakePolicy {
  switch self { case .gentle: return WakePolicy(reps:0,snoozes:2);case .balanced:return WakePolicy(reps:3,snoozes:1);case .focused:return WakePolicy(reps:5,snoozes:0) }
 }
}
public enum DomainError: Error { case invalidAlarmTime }
public struct AlarmTime: Codable, Equatable, Sendable {
 public let hour: Int; public let minute: Int; public let weekdays: Set<Int>
 public init(hour:Int,minute:Int,weekdays:Set<Int>) throws {
  guard (0...23).contains(hour),(0...59).contains(minute),weekdays.allSatisfy({(1...7).contains($0)}) else { throw DomainError.invalidAlarmTime }
  self.hour=hour;self.minute=minute;self.weekdays=weekdays
 }
 private enum CodingKeys: String, CodingKey {case hour,minute,weekdays}
 public init(from decoder:Decoder) throws {
  let values=try decoder.container(keyedBy:CodingKeys.self)
  try self.init(hour:values.decode(Int.self,forKey:.hour),minute:values.decode(Int.self,forKey:.minute),weekdays:values.decode(Set<Int>.self,forKey:.weekdays))
 }
 public func next(after date:Date,calendar:Calendar = .current) -> Date? {
  if weekdays.isEmpty { return calendar.nextDate(after:date,matching:DateComponents(hour:hour,minute:minute,second:0),matchingPolicy:.nextTime,repeatedTimePolicy:.first) }
  return weekdays.compactMap { calendar.nextDate(after:date,matching:DateComponents(hour:hour,minute:minute,second:0,weekday:$0),matchingPolicy:.nextTime,repeatedTimePolicy:.first) }.min()
 }
}
public enum WakeOutcome: String, Codable, Sendable { case selfConfirmed = "self_confirmed", openaiVerified = "openai_verified", localCompleted = "local_completed", dismissed }
public struct WakeSession: Sendable {
 public let mode: WakeMode
 public private(set) var outcome: WakeOutcome?
 public private(set) var localReps=0
 public private(set) var snoozesUsed=0
 public private(set) var generation=0
 private var pending=false
 public init(mode:WakeMode) {self.mode=mode}
 public mutating func recordLocalRep() {if outcome == nil && !pending {localReps=min(localReps+1,mode.policy.reps)}}
 @discardableResult public mutating func beginVerification() -> Int {generation+=1;pending=outcome == nil;return generation}
 @discardableResult public mutating func applyVerified(generation:Int) -> Bool {
  guard pending,outcome == nil,generation == self.generation else {return false}
  pending=false;outcome = .openaiVerified;return true
 }
 public mutating func interruptVerification() {generation+=1;pending=false}
 @discardableResult public mutating func completeLocally() -> Bool {
  guard outcome == nil else {return false}
  generation+=1;pending=false;outcome = .localCompleted;return true
 }
 public mutating func stop() {generation+=1;pending=false;if outcome == nil {outcome = .dismissed}}
 public mutating func selfConfirm() {generation+=1;pending=false;if outcome == nil {outcome = .selfConfirmed}}
 @discardableResult public mutating func snooze() -> Bool {
  guard outcome == nil,snoozesUsed<mode.policy.snoozes else{return false}
  snoozesUsed+=1;generation+=1;pending=false;return true
 }
}
// Provisional motion signal only. Camera visibility/geometry must be calibrated on-device.
public struct RepCounter: Sendable {
 private enum Phase: Sendable {case uncalibrated,up,down}
 private var phase:Phase = .uncalibrated
 public private(set) var count=0
 public init() {}
 public mutating func interrupt() {phase = .uncalibrated}
 @discardableResult public mutating func observe(angle:Double,visible:Bool) -> Bool {
  guard visible,angle.isFinite,(0...180).contains(angle) else {interrupt();return false}
  switch phase {
  case .uncalibrated: if angle>=160 {phase = .up}
  case .up: if angle<=90 {phase = .down}
  case .down: if angle>=160 {phase = .up;count+=1;return true}
  }
  return false
 }
}
public struct EvidenceFrame: Sendable { public let jpeg:Data; public let timestampMs:Int }
public struct EvidenceBuffer: Sendable {
 public private(set) var frames:[EvidenceFrame]=[]
 private var totalBytes=0
 private let maxFrames:Int;private let maxBytes:Int
 public init(maxFrames:Int=25,maxBytes:Int=1250000) {self.maxFrames=maxFrames;self.maxBytes=maxBytes}
 @discardableResult public mutating func append(_ jpeg:Data,timestampMs:Int) -> Bool {
  guard !jpeg.isEmpty,jpeg.count<=50000,timestampMs>=0,timestampMs<=120000,frames.count<maxFrames,totalBytes+jpeg.count<=maxBytes,frames.last.map({timestampMs>$0.timestampMs}) ?? true else {return false}
  frames.append(EvidenceFrame(jpeg:jpeg,timestampMs:timestampMs));totalBytes+=jpeg.count;return true
 }
 public mutating func clear() {frames.removeAll(keepingCapacity:false);totalBytes=0}
}
