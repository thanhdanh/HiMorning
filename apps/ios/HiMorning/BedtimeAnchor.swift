import Combine
import Foundation
import UserNotifications

struct BedtimeAnchorSettings: Codable, Equatable {
 var enabled: Bool = false
 var bedtimeHour: Int = 22
 var bedtimeMinute: Int = 30
 var windDownMinutes: Int = 30
 var sunriseRampEnabled: Bool = true
 var healthSyncEnabled: Bool = false

 var bedtimeDate: Date {
  var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
  components.hour = bedtimeHour
  components.minute = bedtimeMinute
  return Calendar.current.date(from: components) ?? Date()
 }

 var reminderComponents: DateComponents {
  let totalMinutes = (bedtimeHour * 60 + bedtimeMinute - windDownMinutes + 1440) % 1440
  return DateComponents(hour: totalMinutes / 60, minute: totalMinutes % 60)
 }
}

@MainActor final class BedtimeAnchorStore: ObservableObject {
 static let storageKey = "bedtimeAnchorSettings.v1"
 private static let notificationID = "com.himorning.bedtime.winddown"

 @Published var settings: BedtimeAnchorSettings
 @Published var statusMessage: String?

 init() {
  if let data = UserDefaults.standard.data(forKey: Self.storageKey),
     let decoded = try? JSONDecoder().decode(BedtimeAnchorSettings.self, from: data) {
   settings = decoded
  } else {
   settings = BedtimeAnchorSettings()
  }
 }

 func update(_ mutate: (inout BedtimeAnchorSettings) -> Void) {
  var next = settings
  mutate(&next)
  settings = next
  if let data = try? JSONEncoder().encode(next) {
   UserDefaults.standard.set(data, forKey: Self.storageKey)
  }
  Task { await syncReminder() }
 }

 func syncReminder() async {
  let center = UNUserNotificationCenter.current()
  center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
  guard settings.enabled else {
   statusMessage = nil
   return
  }
  do {
   let granted = try await center.requestAuthorization(options: [.alert, .sound])
   guard granted else {
    statusMessage = appText("Enable notifications in Settings to receive wind-down reminders.")
    return
   }
   let content = UNMutableNotificationContent()
   content.title = appText("Time to wind down")
   content.body = appText("Putting screens away soon helps tomorrow’s morning feel lighter.")
   content.sound = .default

   let trigger = UNCalendarNotificationTrigger(dateMatching: settings.reminderComponents, repeats: true)
   let request = UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: trigger)
   try await center.add(request)
   statusMessage = nil
  } catch {
   statusMessage = appText("Could not schedule the wind-down reminder.")
  }
 }
}
