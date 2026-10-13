import Foundation

public enum MorningAccess:Equatable,Sendable {
 case free,pro
 public static func verifiedPeriod(expiresAt:Date?,graceUntil:Date?=nil,now:Date=Date())->MorningAccess {
  if let expiresAt,expiresAt>now {return .pro}
  if let graceUntil,graceUntil>now {return .pro}
  return .free
 }
 public var historyDays:Int {self == .pro ? 30 : 7}
 public func weeklyGoal(stored:Int)->Int {self == .pro ? stored : 3}
}

public struct MorningEntry:Codable,Identifiable,Sendable {
 public let id:UUID
 public let date:Date
 public let outcome:WakeOutcome
 public init(id:UUID=UUID(),date:Date=Date(),outcome:WakeOutcome) {
  self.id=id;self.date=date;self.outcome=outcome
 }
}

public enum MorningJournalError:Error {case invalidGoal}

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
  guard (1...30).contains(days),let start=calendar.date(byAdding:.day,value:1-days,to:calendar.startOfDay(for:now)) else {return []}
  return state.entries.filter {$0.date>=start && $0.date<=now}.sorted {$0.date>$1.date}
 }
 public func completedDays(inLast days:Int,now:Date=Date(),calendar:Calendar = .current)->Int {
  Set(recent(days:days,now:now,calendar:calendar).filter {$0.outcome != .dismissed}.map {calendar.startOfDay(for:$0.date)}).count
 }
 @discardableResult public mutating func record(_ entry:MorningEntry,rehearsal:Bool=false,now:Date=Date(),calendar:Calendar = .current) throws ->Bool {
  guard !rehearsal,!state.entries.contains(where:{$0.id==entry.id}),
   let start=calendar.date(byAdding:.day,value:-29,to:calendar.startOfDay(for:now)),entry.date>=start,entry.date<=now else {return false}
  var next=state
  next.entries=recent(days:30,now:now,calendar:calendar)+[entry]
  try commit(next);return true
 }
 public mutating func setWeeklyGoal(_ goal:Int) throws {
  guard (1...7).contains(goal) else {throw MorningJournalError.invalidGoal}
  var next=state;next.weeklyGoal=goal;try commit(next)
 }
 public mutating func clear() throws {var next=state;next.entries=[];try commit(next)}
 private mutating func commit(_ next:State) throws {
  try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
  try JSONEncoder().encode(next).write(to:url,options:.atomic)
  state=next
 }
}
