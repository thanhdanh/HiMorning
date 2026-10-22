import Combine
import Foundation
import HiMorningCore

@MainActor final class JourneyStore:ObservableObject {
 static let storageKey="morningJourney.v1"
 @Published private(set) var journey:MorningJourney?
 @Published private(set) var message:String?

 private let saveData:(Data)throws->Void
 private var healthy=true

 init(load:@escaping()throws->Data? = {UserDefaults.standard.data(forKey:JourneyStore.storageKey)},
      save:@escaping(Data)throws->Void = {UserDefaults.standard.set($0,forKey:JourneyStore.storageKey)}) {
  self.saveData=save
  do {
   if let data=try load() {journey=try JSONDecoder().decode(MorningJourney.self,from:data)}
  } catch {
   healthy=false
   message=appText("Your progress could not be read. Your alarms are unchanged.")
  }
 }

 @discardableResult func choose(_ focus:MorningFocus,access:MorningAccess,now:Date=Date())->Bool {
  guard healthy else {return false}
  guard !focus.requiresFullAccess || access.hasFullAccess else {
   message=appText("Move with energy is a Pro routine.")
   return false
  }
  var next=journey ?? MorningJourney(focus:focus,now:now)
  if journey != nil {next.changeFocus(focus)}
  return commit(next)
 }

 @discardableResult func record(date:Date,outcome:WakeOutcome,rehearsal:Bool,now:Date=Date(),calendar:Calendar = .current)->Bool {
  guard healthy,var next=journey,
   next.record(date:date,outcome:outcome,rehearsal:rehearsal,now:now,calendar:calendar) else {return false}
  return commit(next)
 }

 @discardableResult func restart(now:Date=Date(),calendar:Calendar = .current)->Bool {
  guard healthy,var next=journey,next.restart(now:now,calendar:calendar) else {return false}
  return commit(next)
 }

 private func commit(_ next:MorningJourney)->Bool {
  do {
   let data=try JSONEncoder().encode(next)
   try saveData(data)
   journey=next
   message=nil
   return true
  } catch {
   message=appText("Your goal could not be saved. Please try again.")
   return false
  }
 }
}
