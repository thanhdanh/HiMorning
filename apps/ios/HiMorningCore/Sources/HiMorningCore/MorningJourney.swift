import Foundation

public enum MorningFocus:String,Codable,CaseIterable,Sendable {
 case clearStart
 case gentleMovement
 case findYourVoice
 case energize

 public var requiresFullAccess:Bool {self == .energize}

 public func mission(at index:Int,access:MorningAccess)->ChallengeSelection {
  let day=min(6,max(0,index))
  switch self {
  case .clearStart:
   let missions:[ChallengeSelection]=[.readAndChoose,.init(kind:.riddle),.readAndChoose,.init(kind:.riddle),.readAndChoose,.init(kind:.riddle),.readAndChoose]
   return missions[day]
  case .gentleMovement:
   let missions:[ChallengeSelection]=[.init(kind:.waveHand),.init(kind:.neckRotation),.guidedRhythm(variant:.seated),.init(kind:.waveHand),.guidedRhythm(variant:.seated),.init(kind:.neckRotation),.guidedRhythm(variant:.seated)]
   return missions[day]
  case .findYourVoice:
   let missions:[ChallengeSelection]=[.readAndChoose,.readAloud,.readAndChoose,.readAloud,.init(kind:.riddle),.readAloud,.readAloud]
   return missions[day]
  case .energize:
   guard access.hasFullAccess else {return MorningFocus.gentleMovement.mission(at:day,access:access)}
   let missions:[ChallengeSelection]=[.init(kind:.waveHand),.pushUps(repetitions:5),.init(kind:.stretching),.init(kind:.jumpingJacks),.pushUps(repetitions:5),.guidedRhythm(variant:.standing),.pushUps(repetitions:5)]
   return missions[day]
  }
 }
}

public struct MorningJourney:Codable,Equatable,Sendable {
 public private(set) var focus:MorningFocus
 public private(set) var startedAt:Date
 public private(set) var completions:[Date]=[]
 public private(set) var completedJourneys=0
 private var lastCompletionAt:Date?

 public init(focus:MorningFocus,now:Date=Date()) {
  self.focus=focus;startedAt=now
 }

 public var completedCount:Int {completions.count}
 public var isComplete:Bool {completedCount == 7}

 public mutating func changeFocus(_ focus:MorningFocus) {
  self.focus=focus
 }

 @discardableResult public mutating func record(date:Date,outcome:WakeOutcome,rehearsal:Bool=false,now:Date=Date(),calendar:Calendar = .current)->Bool {
  guard !rehearsal,Self.isSuccessful(outcome),completions.count<7,date>=startedAt,date<=now else {return false}
  let day=calendar.startOfDay(for:date)
  guard !completions.contains(where:{calendar.isDate($0,inSameDayAs:day)}),
   lastCompletionAt.map({!calendar.isDate($0,inSameDayAs:day)}) ?? true else {return false}
  completions.append(date)
  completions.sort()
  lastCompletionAt=max(lastCompletionAt ?? date,date)
  return true
 }

 public func completedToday(now:Date=Date(),calendar:Calendar = .current)->Bool {
  lastCompletionAt.map {calendar.isDate($0,inSameDayAs:now)} ?? false
 }

 public func missionIndex(now:Date=Date(),calendar:Calendar = .current)->Int {
  if completedToday(now:now,calendar:calendar) {return max(0,min(6,completedCount-1))}
  return min(completedCount,6)
 }

 @discardableResult public mutating func restart(now:Date=Date(),calendar:Calendar = .current)->Bool {
  guard isComplete,now >= (lastCompletionAt ?? startedAt) else {return false}
  completedJourneys+=1
  startedAt=now
  completions=[]
  return true
 }

 private static func isSuccessful(_ outcome:WakeOutcome)->Bool {
  outcome == .localCompleted || outcome == .openaiVerified || outcome == .aiVerified
 }

 private enum CodingKeys:String,CodingKey {case focus,startedAt,completions,completedJourneys,lastCompletionAt}
 public init(from decoder:Decoder)throws {
  let values=try decoder.container(keyedBy:CodingKeys.self)
  let focus=try values.decode(MorningFocus.self,forKey:.focus)
  let startedAt=try values.decode(Date.self,forKey:.startedAt)
  let completions=try values.decode([Date].self,forKey:.completions)
  let completedJourneys=try values.decode(Int.self,forKey:.completedJourneys)
  let lastCompletionAt=try values.decodeIfPresent(Date.self,forKey:.lastCompletionAt)
  guard (0...7).contains(completions.count),completedJourneys>=0,completions.allSatisfy({$0>=startedAt}) else {
   throw DecodingError.dataCorrupted(.init(codingPath:decoder.codingPath,debugDescription:"Invalid morning journey progress"))
  }
  self.focus=focus;self.startedAt=startedAt;self.completions=completions
  self.completedJourneys=completedJourneys;self.lastCompletionAt=[lastCompletionAt,completions.max()].compactMap {$0}.max()
 }
}
