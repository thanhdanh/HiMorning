import XCTest
import AlarmKit
#if canImport(HiMorning)
@testable import HiMorning

final class NativeAlarmSchedulerTests:XCTestCase {
 func testCancellingAnAbsentAlarmSucceeds() async throws {
  let before=Set(try AlarmManager.shared.alarms.map(\.id)),missing=UUID()
  XCTAssertFalse(before.contains(missing))
  let scheduler=NativeAlarmScheduler()
  try await scheduler.cancel(id:missing)
  try await scheduler.cancel(id:missing)
  XCTAssertEqual(Set(try AlarmManager.shared.alarms.map(\.id)),before)
 }
}
#endif
