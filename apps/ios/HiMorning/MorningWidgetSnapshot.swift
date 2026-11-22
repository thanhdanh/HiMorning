import ActivityKit
import Foundation

public struct MorningWidgetSnapshot: Codable, Equatable, Sendable {
 public let nextAlarmTime: Date?
 public let challengeTitle: String?
 public let modeTitle: String?
 public let journeyCompleted: Int
 public let journeyTotal: Int
 public let updatedAt: Date

 public init(
  nextAlarmTime: Date?,
  challengeTitle: String?,
  modeTitle: String?,
  journeyCompleted: Int,
  journeyTotal: Int,
  updatedAt: Date = Date()
 ) {
  self.nextAlarmTime = nextAlarmTime
  self.challengeTitle = challengeTitle
  self.modeTitle = modeTitle
  self.journeyCompleted = journeyCompleted
  self.journeyTotal = journeyTotal
  self.updatedAt = updatedAt
 }
}

public enum MorningWidgetStore {
 public static let appGroupID = "group.com.himorning.shared"
 private static let snapshotKey = "morningWidgetSnapshot.v1"

 private static var defaults: UserDefaults {
  UserDefaults(suiteName: appGroupID) ?? .standard
 }

 public static func save(_ snapshot: MorningWidgetSnapshot) {
  guard let data = try? JSONEncoder().encode(snapshot) else { return }
  defaults.set(data, forKey: snapshotKey)
 }

 public static func load() -> MorningWidgetSnapshot {
  guard let data = defaults.data(forKey: snapshotKey),
        let snapshot = try? JSONDecoder().decode(MorningWidgetSnapshot.self, from: data) else {
   return MorningWidgetSnapshot(nextAlarmTime: nil, challengeTitle: nil, modeTitle: nil, journeyCompleted: 0, journeyTotal: 7)
  }
  return snapshot
 }
}

public struct MorningAlarmAttributes: ActivityAttributes {
 public struct ContentState: Codable, Hashable {
  public var wakeTime: Date
  public var completed: Bool

  public init(wakeTime: Date, completed: Bool) {
   self.wakeTime = wakeTime
   self.completed = completed
  }
 }

 public var challengeTitle: String
 public var modeTitle: String

 public init(challengeTitle: String, modeTitle: String) {
  self.challengeTitle = challengeTitle
  self.modeTitle = modeTitle
 }
}
