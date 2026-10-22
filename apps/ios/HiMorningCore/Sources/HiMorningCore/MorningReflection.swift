import Foundation

/// A description of recorded completions, never a claim about why a user woke up.
public struct MorningReflection:Sendable {
 public let completedDays:Int
 public let goToChallenge:ChallengeKind?
 public let goToDays:Int
 public init(entries:[MorningEntry],now:Date=Date(),calendar:Calendar = .current) {
  let start=calendar.date(byAdding:.day,value:-29,to:calendar.startOfDay(for:now)) ?? now
  let completed=entries.filter {$0.date>=start && $0.date<=now && [.localCompleted,.openaiVerified,.aiVerified].contains($0.outcome)}
  completedDays=Set(completed.map {calendar.startOfDay(for:$0.date)}).count
  var datesByKind:[ChallengeKind:Set<Date>]=[:]
  for entry in completed {
   guard let kind=entry.challenge?.kind,kind != .none else {continue}
   datesByKind[kind,default:[]].insert(calendar.startOfDay(for:entry.date))
  }
  let ranked:[(ChallengeKind,Int)]=datesByKind.map {($0.key,$0.value.count)}.sorted {left,right in
   if left.1 == right.1 {return left.0.rawValue<right.0.rawValue}
   return left.1>right.1
  }
  goToChallenge=completedDays>=3 && (ranked.first?.1 ?? 0)>=2 ? ranked.first?.0 : nil
  goToDays=goToChallenge == nil ? 0 : ranked.first?.1 ?? 0
 }
}
