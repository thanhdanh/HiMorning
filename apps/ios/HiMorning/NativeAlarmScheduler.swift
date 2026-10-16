import AlarmKit
import ActivityKit
import AppIntents
import SwiftUI
import HiMorningCore
struct MorningMetadata: AlarmMetadata {let alarmID:String}
struct OpenMorningIntent: LiveActivityIntent {
 static var title:LocalizedStringResource = "Open HiMorning challenge"
 static var openAppWhenRun=true
 @Parameter(title:"Alarm") var alarmID:String
 init() {alarmID=""}
 init(id:UUID) {alarmID=id.uuidString}
 func perform() async throws -> some IntentResult {
  UserDefaults.standard.set(alarmID,forKey:"pendingAlarmID")
  return .result()
 }
}
actor NativeAlarmScheduler: AlarmScheduler {
 func schedule(_ alarm:SavedAlarm) async throws {
  let manager=AlarmManager.shared
  guard try await manager.requestAuthorization() == .authorized else {throw NativeAlarmError.denied}
  let days:[Locale.Weekday] = [.sunday,.monday,.tuesday,.wednesday,.thursday,.friday,.saturday]
  let recurrence:Alarm.Schedule.Relative.Recurrence=alarm.time.weekdays.isEmpty ? .never : .weekly(alarm.time.weekdays.sorted().map {days[$0-1]})
  let relative=Alarm.Schedule.Relative(time:.init(hour:alarm.time.hour,minute:alarm.time.minute),repeats:recurrence)
  let alert=AlarmPresentation.Alert(title:LocalizedStringResource(stringLiteral:appText("Good morning ☀️")),stopButton:nil,secondaryButton:AlarmButton(text:LocalizedStringResource(stringLiteral:appText("Open HiMorning")),textColor:.black,systemImageName:"sun.max"),secondaryButtonBehavior:.custom,shouldDismissWhenTapped:false)
  let attributes=AlarmAttributes<MorningMetadata>(presentation:AlarmPresentation(alert:alert),metadata:MorningMetadata(alarmID:alarm.id.uuidString),tintColor:.yellow,showsInFocusDisplay:true)
  let sound:AlertConfiguration.AlertSound = alarm.sound == .system ? .default : .named(alarm.sound.rawValue+".wav")
  let configuration=AlarmManager.AlarmConfiguration<MorningMetadata>.alarm(schedule:.relative(relative),attributes:attributes,secondaryIntent:OpenMorningIntent(id:alarm.id),sound:sound)
  _ = try await manager.schedule(id:alarm.id,configuration:configuration)
 }
 func cancel(id:UUID) async throws {
  let manager=AlarmManager.shared
  if try manager.alarms.contains(where:{$0.id==id}) {try manager.cancel(id:id)}
 }
 func stop(id:UUID) async throws {
  // A system Stop may already have removed a one-time alarm.
  if let alarm=try AlarmManager.shared.alarms.first(where:{$0.id==id}),alarm.state != .scheduled {try AlarmManager.shared.stop(id:id)}
 }
 func scheduledIDs() async throws -> Set<UUID> {guard AlarmManager.shared.authorizationState == .authorized else {return []};return Set(try AlarmManager.shared.alarms.map(\.id))}
}
enum NativeAlarmError:Error {case denied}