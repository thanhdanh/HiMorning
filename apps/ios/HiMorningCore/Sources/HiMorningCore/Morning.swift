import Foundation

public enum MorningAccess:Equatable,Sendable {
 case free,preview,pro
 public static func verifiedPeriod(expiresAt:Date?,graceUntil:Date?=nil,now:Date=Date())->MorningAccess {
  if let expiresAt,expiresAt>now {return .pro}
  if let graceUntil,graceUntil>now {return .pro}
  return .free
 }
 public var hasFullAccess:Bool {self != .free}
 public var historyDays:Int {hasFullAccess ? 30 : 0}
 public func weeklyGoal(stored:Int)->Int {hasFullAccess ? stored : 3}
 public func allows(mode:WakeMode)->Bool {hasFullAccess || mode != .focused}
 public func allows(sound:AlarmSound)->Bool {hasFullAccess || sound == .system}
 public func effectiveMode(_ saved:WakeMode)->WakeMode {allows(mode:saved) ? saved : .balanced}
 public func effectiveSound(_ saved:AlarmSound)->AlarmSound {allows(sound:saved) ? saved : .system}
 public func effectiveChallenge(_ saved:ChallengeSelection)->ChallengeSelection {
  guard !hasFullAccess,saved.kind == .pushUps else {return saved}
  return .pushUps(repetitions:min(saved.repetitions ?? 5,WakeMode.balanced.policy.reps))
 }
 public func effectiveAlarm(_ saved:SavedAlarm)->SavedAlarm {
  var effective=SavedAlarm(id:saved.id,time:saved.time,mode:effectiveMode(saved.mode),sound:effectiveSound(saved.sound),challenge:effectiveChallenge(saved.challenge))
  effective.enabled=saved.enabled;effective.state=saved.state
  return effective
 }
}

/// A no-card preview, started only after the first alarm is successfully saved.
/// Persist every observation so a later clock rollback cannot restore elapsed time.
public struct PreviewPeriod:Codable,Equatable,Sendable {
 public private(set) var startedAt:Date?
 public private(set) var lastSeenAt:Date?
 private static let duration:TimeInterval=30*86400
 public init() {}
 public var expiresAt:Date? {startedAt?.addingTimeInterval(Self.duration)}
 public mutating func start(now:Date=Date()) {
  guard startedAt == nil else {return}
  startedAt=now;lastSeenAt=now
 }
 public mutating func observe(now:Date=Date()) {
  guard let startedAt else {return}
  lastSeenAt=max(now,lastSeenAt ?? startedAt,startedAt)
 }
 public func access(now:Date=Date())->MorningAccess {
  remainingDays(now:now)>0 ? .preview : .free
 }
 public func remainingDays(now:Date=Date())->Int {
  guard let startedAt,let expiresAt else {return 0}
  let effectiveNow=max(now,lastSeenAt ?? startedAt,startedAt)
  return max(0,Int(ceil(expiresAt.timeIntervalSince(effectiveNow)/86400)))
 }
}

public struct MorningEntry:Codable,Identifiable,Sendable {
 public let id:UUID
 public let alarmID:UUID?
 public let mode:WakeMode?
 public let challenge:ChallengeSelection?
 public let date:Date
 public let outcome:WakeOutcome
 public init(id:UUID=UUID(),alarmID:UUID?=nil,mode:WakeMode?=nil,challenge:ChallengeSelection?=nil,date:Date=Date(),outcome:WakeOutcome) {
  self.id=id;self.alarmID=alarmID;self.mode=mode;self.challenge=challenge;self.date=date;self.outcome=outcome
 }
}

public enum MorningJournalError:Error {case invalidGoal}

public enum ConsistencyRating:Equatable,Sendable {case noData,gettingStarted,building,consistent,excellent}

public struct MorningScore:Identifiable,Sendable {
 public var id:Date {date}
 public let date:Date
 public let entries:[MorningEntry]
 public let attempts:Int
 public let completed:Int
 public var score:Int? {attempts == 0 ? nil : Int((Double(completed)*100/Double(attempts)).rounded())}
 public var rating:ConsistencyRating {
  guard let score else {return .noData}
  switch score {
  case 90...100:return .excellent
  case 75..<90:return .consistent
  case 50..<75:return .building
  default:return .gettingStarted
  }
 }
 init(date:Date,entries:[MorningEntry]) {
  self.date=date;self.entries=entries;attempts=entries.count
  completed=entries.filter { [.localCompleted,.openaiVerified,.aiVerified].contains($0.outcome) }.count
 }
}

public struct MorningJournal:Sendable {
 private struct State:Codable,Sendable {var entries:[MorningEntry]=[];var weeklyGoal=3}
 private var state:State
 private let url:URL
 public var entries:[MorningEntry] {state.entries}
 public var weeklyGoal:Int {state.weeklyGoal}
 public init(url:URL) throws {
  self.url=url
  state=FileManager.default.fileExists(atPath:url.path) ? try JSONDecoder().decode(State.self,from:Data(contentsOf:url)) : State()
  guard (1...7).contains(state.weeklyGoal) else {throw MorningJournalError.invalidGoal}
 }
 public func recent(days:Int,now:Date=Date(),calendar:Calendar = .current)->[MorningEntry] {
  guard (1...31).contains(days),let start=calendar.date(byAdding:.day,value:1-days,to:calendar.startOfDay(for:now)) else {return []}
  return state.entries.filter {$0.date>=start && $0.date<=now}.sorted {$0.date>$1.date}
 }
 public func completedDays(inLast days:Int,now:Date=Date(),calendar:Calendar = .current)->Int {
  Set(recent(days:days,now:now,calendar:calendar).filter {$0.outcome != .dismissed}.map {calendar.startOfDay(for:$0.date)}).count
 }
 public func completedToday(alarmID:UUID,now:Date=Date(),calendar:Calendar = .current)->Bool {
  recent(days:1,now:now,calendar:calendar).contains {$0.alarmID==alarmID && [.localCompleted,.openaiVerified,.aiVerified].contains($0.outcome)}
 }
 public func weeklyScores(now:Date=Date(),calendar:Calendar = .current)->[MorningScore] {
  let entries=recent(days:7,now:now,calendar:calendar)
  return (-6...0).compactMap {offset in
   guard let day=calendar.date(byAdding:.day,value:offset,to:calendar.startOfDay(for:now)) else {return nil}
   return MorningScore(date:day,entries:entries.filter {calendar.isDate($0.date,inSameDayAs:day)})
  }
 }
 public func monthlyScore(now:Date=Date(),calendar:Calendar = .current)->MorningScore {
  let start=calendar.dateInterval(of:.month,for:now)?.start ?? calendar.startOfDay(for:now)
  return MorningScore(date:start,entries:recent(days:31,now:now,calendar:calendar).filter {$0.date>=start})
 }
 @discardableResult public mutating func record(_ entry:MorningEntry,rehearsal:Bool=false,now:Date=Date(),calendar:Calendar = .current) throws ->Bool {
  guard !rehearsal,!state.entries.contains(where:{$0.id==entry.id}),
   let start=calendar.date(byAdding:.day,value:-30,to:calendar.startOfDay(for:now)),entry.date>=start,entry.date<=now else {return false}
  var next=state
  next.entries=recent(days:31,now:now,calendar:calendar)+[entry]
  try commit(next);return true
 }
 public mutating func setWeeklyGoal(_ goal:Int) throws {
  guard (1...7).contains(goal) else {throw MorningJournalError.invalidGoal}
  var next=state;next.weeklyGoal=goal;try commit(next)
 }
 private mutating func commit(_ next:State) throws {
  try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
  try JSONEncoder().encode(next).write(to:url,options:.atomic)
  state=next
 }
}
