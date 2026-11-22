import Foundation
import HealthKit

enum MorningHealthSync {
 private static let store = HKHealthStore()

 static var isAvailable: Bool {
  HKHealthStore.isHealthDataAvailable()
 }

 static func requestAuthorization() async -> Bool {
  guard isAvailable,
        let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
   return false
  }
  do {
   try await store.requestAuthorization(toShare: [mindfulType], read: [])
   return true
  } catch {
   return false
  }
 }

 static func recordMorningWin(completedAt: Date = Date()) async {
  guard isAvailable,
        let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession),
        store.authorizationStatus(for: mindfulType) == .sharingAuthorized else {
   return
  }
  let start = completedAt.addingTimeInterval(-60)
  let sample = HKCategorySample(
   type: mindfulType,
   value: HKCategoryValue.notApplicable.rawValue,
   start: start,
   end: completedAt
  )
  _ = try? await store.save(sample)
 }
}
