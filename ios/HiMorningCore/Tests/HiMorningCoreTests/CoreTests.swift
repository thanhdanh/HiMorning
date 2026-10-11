import XCTest
@testable import HiMorningCore
final class CoreTests: XCTestCase {
 func testLanguageSelectionAndFallback() {
  XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages:["vi-VN","en"]), "vi")
  XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages:["fr","en-GB"]), "en")
  XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages:[]), "en")
  XCTAssertEqual(AppLanguage.english.resolved(preferredLanguages:["vi"]), "en")
  XCTAssertEqual(AppLanguage.vietnamese.resolved(preferredLanguages:["en"]), "vi")
 }

 func testLanguageSelectionAndFallback() {
  XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages:["vi-VN","en"]), "vi")
  XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages:["fr","en-GB"]), "en")
  XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages:[]), "en")
  XCTAssertEqual(AppLanguage.english.resolved(preferredLanguages:["vi"]), "en")
  XCTAssertEqual(AppLanguage.vietnamese.resolved(preferredLanguages:["en"]), "vi")
 }
 func testPresetsAreGentleAndBounded() {
  XCTAssertEqual(WakeMode.gentle.policy.snoozes, 2)
  XCTAssertEqual(WakeMode.gentle.policy.reps, 0)
  XCTAssertEqual(WakeMode.balanced.policy.reps, 3)
  XCTAssertEqual(WakeMode.focused.policy.reps, 5)
  XCTAssertEqual(WakeMode.focused.policy.snoozes, 0)
 }
 func testAlarmValidation() throws {
  XCTAssertThrowsError(try AlarmTime(hour:24,minute:0,weekdays:[]))
  XCTAssertThrowsError(try AlarmTime(hour:6,minute:60,weekdays:[]))
  XCTAssertThrowsError(try AlarmTime(hour:6,minute:30,weekdays:[0]))
  XCTAssertNoThrow(try AlarmTime(hour:6,minute:30,weekdays:[2,3,4,5,6]))
 }
 func testNextWeekdayInVietnamAndOneTimeTomorrow() throws {
  var calendar=Calendar(identifier:.gregorian); calendar.timeZone=TimeZone(identifier:"Asia/Ho_Chi_Minh")!
  let now=ISO8601DateFormatter().date(from:"2026-10-11T22:15:00+07:00")!
  let next=try AlarmTime(hour:6,minute:30,weekdays:[2,3,4,5,6]).next(after:now,calendar:calendar)
  XCTAssertEqual(calendar.component(.weekday,from:next!),2)
  XCTAssertEqual(calendar.component(.hour,from:next!),6)
  let tomorrow=try AlarmTime(hour:6,minute:30,weekdays:[]).next(after:now,calendar:calendar)!
  XCTAssertEqual(calendar.component(.day,from:tomorrow),12)
 }
 func testSpringDSTDoesNotCreatePastAlarm() throws {
  var calendar=Calendar(identifier:.gregorian); calendar.timeZone=TimeZone(identifier:"America/New_York")!
  let now=ISO8601DateFormatter().date(from:"2026-03-08T00:00:00-05:00")!
  let next=try AlarmTime(hour:2,minute:30,weekdays:[]).next(after:now,calendar:calendar)!
  XCTAssertGreaterThan(next,now)
  XCTAssertEqual(calendar.component(.day,from:next),8)
 }
 func testStopInvalidatesPendingResponseAndDoesNotCountAsSuccess() {
  var flow=WakeSession(mode:.balanced)
  let generation=flow.beginVerification()
  flow.stop()
  XCTAssertFalse(flow.applyVerified(generation:generation))
  XCTAssertEqual(flow.outcome,.dismissed)
 }
 func testLocalCountNeverCompletesCloudChallengeAndDuplicateResultCannotApply() {
  var flow=WakeSession(mode:.balanced)
  flow.recordLocalRep(); XCTAssertNil(flow.outcome)
  let generation=flow.beginVerification()
  XCTAssertTrue(flow.applyVerified(generation:generation))
  XCTAssertFalse(flow.applyVerified(generation:generation))
  XCTAssertEqual(flow.outcome,.openaiVerified)
 }
 func testFallbackAndSnoozeRemainExplicit() {
  var flow=WakeSession(mode:.gentle)
  XCTAssertTrue(flow.snooze());XCTAssertTrue(flow.snooze());XCTAssertFalse(flow.snooze())
  flow.selfConfirm();XCTAssertEqual(flow.outcome,.selfConfirmed)
  var focused=WakeSession(mode:.focused);XCTAssertFalse(focused.snooze())
 }
 func testInterruptedRepResetsButRetainsCompletedReps() {
  var counter=RepCounter()
  XCTAssertFalse(counter.observe(angle:165,visible:true))
  XCTAssertFalse(counter.observe(angle:80,visible:true))
  XCTAssertFalse(counter.observe(angle:165,visible:false))
  XCTAssertFalse(counter.observe(angle:165,visible:true))
  XCTAssertEqual(counter.count,0)
  XCTAssertFalse(counter.observe(angle:80,visible:true))
  XCTAssertTrue(counter.observe(angle:165,visible:true))
  XCTAssertEqual(counter.count,1)
  counter.interrupt();XCTAssertEqual(counter.count,1)
 }
 func testNoiseDoesNotCountAndBufferNeverExceedsCap() {
  var counter=RepCounter()
  for angle in [Double.nan,140,100,150,120] { XCTAssertFalse(counter.observe(angle:angle,visible:true)) }
  XCTAssertEqual(counter.count,0)
  var evidence=EvidenceBuffer(maxFrames:2,maxBytes:6)
  XCTAssertTrue(evidence.append(Data([1,2,3]),timestampMs:0))
  XCTAssertFalse(evidence.append(Data([1]),timestampMs:0))
  XCTAssertTrue(evidence.append(Data([4,5,6]),timestampMs:300))
  XCTAssertFalse(evidence.append(Data([7]),timestampMs:600))
  XCTAssertEqual(evidence.frames.count,2)
  evidence.clear();XCTAssertTrue(evidence.frames.isEmpty)
 }
}
