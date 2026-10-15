import XCTest
@testable import HiMorningCore

final class PreviewTests:XCTestCase {
 private let now=Date(timeIntervalSince1970:1800000000)
 func testPreviewStartsOnceAndExpiresAtExactlyThirtyDays() {
  var preview=PreviewPeriod()
  XCTAssertNil(preview.startedAt)
  XCTAssertNil(preview.expiresAt)
  XCTAssertEqual(preview.access(now:now),.free)
  preview.observe(now:now)
  XCTAssertNil(preview.lastSeenAt)
  preview.start(now:now)
  preview.start(now:now.addingTimeInterval(86400))
  XCTAssertEqual(preview.startedAt,now)
  XCTAssertEqual(preview.remainingDays(now:now),30)
  let expiry=now.addingTimeInterval(30*86400)
  XCTAssertEqual(preview.expiresAt,expiry)
  preview.observe(now:expiry.addingTimeInterval(-86400))
  XCTAssertEqual(preview.remainingDays(now:now),1)
  XCTAssertEqual(preview.access(now:expiry.addingTimeInterval(-1)),.preview)
  XCTAssertEqual(preview.remainingDays(now:expiry.addingTimeInterval(-1)),1)
  XCTAssertEqual(preview.access(now:expiry),.free)
 }
 func testClockRollbackCannotRestoreExpiredPreviewAfterRelaunch() throws {
  var preview=PreviewPeriod()
  preview.start(now:now)
  let expiry=now.addingTimeInterval(30*86400)
  preview.observe(now:expiry)
  preview.observe(now:now)
  let restored=try JSONDecoder().decode(PreviewPeriod.self,from:JSONEncoder().encode(preview))
  XCTAssertEqual(restored,preview)
  XCTAssertEqual(restored.lastSeenAt,expiry)
  XCTAssertEqual(restored.access(now:now),.free)
  XCTAssertEqual(restored.remainingDays(now:now),0)
 }
 func testPreviewAndProUnlockAllCapabilities() {
  for access in [MorningAccess.preview,.pro] {
   XCTAssertTrue(access.hasFullAccess)
   XCTAssertEqual(access.historyDays,30)
   XCTAssertEqual(access.weeklyGoal(stored:5),5)
   for mode in WakeMode.allCases {XCTAssertTrue(access.allows(mode:mode));XCTAssertEqual(access.effectiveMode(mode),mode)}
   for sound in AlarmSound.allCases {XCTAssertTrue(access.allows(sound:sound));XCTAssertEqual(access.effectiveSound(sound),sound)}
  }
 }
 func testFreeKeepsBasicAlarmCapabilitiesWithoutChangingSavedPreferences() throws {
  XCTAssertFalse(MorningAccess.free.hasFullAccess)
  XCTAssertEqual(MorningAccess.free.historyDays,0)
  XCTAssertEqual(MorningAccess.free.weeklyGoal(stored:5),3)
  XCTAssertTrue(MorningAccess.free.allows(mode:.gentle))
  XCTAssertTrue(MorningAccess.free.allows(mode:.balanced))
  XCTAssertFalse(MorningAccess.free.allows(mode:.focused))
  XCTAssertEqual(MorningAccess.free.effectiveMode(.focused),.balanced)
  XCTAssertEqual(MorningAccess.free.effectiveMode(.gentle),.gentle)
  XCTAssertTrue(MorningAccess.free.allows(sound:.system))
  XCTAssertFalse(MorningAccess.free.allows(sound:.sunrise))
  XCTAssertFalse(MorningAccess.free.allows(sound:.softChime))
  XCTAssertEqual(MorningAccess.free.effectiveSound(.sunrise),.system)
  let saved=SavedAlarm(time:try AlarmTime(hour:6,minute:30,weekdays:[]),mode:.focused,sound:.sunrise)
  _=MorningAccess.free.effectiveMode(saved.mode)
  XCTAssertEqual(saved.mode,.focused)
  XCTAssertEqual(saved.sound,.sunrise)
 }
 func testPaidVerificationNeverReturnsPreview() {
  XCTAssertEqual(MorningAccess.verifiedPeriod(expiresAt:now,now:now),.free)
  XCTAssertEqual(MorningAccess.verifiedPeriod(expiresAt:now.addingTimeInterval(1),now:now),.pro)
 }
}
