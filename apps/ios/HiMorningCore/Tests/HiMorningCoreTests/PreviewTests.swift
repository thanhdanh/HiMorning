import Foundation
#if !PORTABLE_TESTS
import XCTest
@testable import HiMorningCore
#endif

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
  XCTAssertEqual(MorningAccess.free.effectiveMode(.balanced),.balanced)
  XCTAssertTrue(MorningAccess.free.allows(sound:.system))
  XCTAssertFalse(MorningAccess.free.allows(sound:.sunrise))
  XCTAssertFalse(MorningAccess.free.allows(sound:.softChime))
  XCTAssertEqual(MorningAccess.free.effectiveSound(.sunrise),.system)
  XCTAssertEqual(MorningAccess.free.effectiveSound(.system),.system)
  for sound in AlarmSound.allCases {
   XCTAssertEqual(MorningAccess.free.allows(sound:sound),sound == .system)
   XCTAssertEqual(MorningAccess.free.effectiveSound(sound),.system)
  }
  let saved=SavedAlarm(time:try AlarmTime(hour:6,minute:30,weekdays:[]),mode:.focused,sound:.sunrise)
  _=MorningAccess.free.effectiveMode(saved.mode)
  XCTAssertEqual(saved.mode,.focused)
  XCTAssertEqual(saved.sound,.sunrise)
 }
 func testPaidVerificationNeverReturnsPreview() {
  XCTAssertEqual(MorningAccess.verifiedPeriod(expiresAt:now,now:now),.free)
  XCTAssertEqual(MorningAccess.verifiedPeriod(expiresAt:now.addingTimeInterval(1),now:now),.pro)
 }
 func testAccessPreservesExplicitLocalChallengesAndCapsOnlyFreePushUps() {
  let local:[ChallengeSelection]=[.none,.readAndChoose,.guidedRhythm(variant:.standing),.guidedRhythm(variant:.seated),.readAloud]
  for challenge in local {XCTAssertEqual(MorningAccess.free.effectiveChallenge(challenge),challenge)}
  for target in 1...5 {
   let challenge=ChallengeSelection.pushUps(repetitions:target)
   XCTAssertEqual(MorningAccess.free.effectiveChallenge(challenge),.pushUps(repetitions:min(target,3)))
   for access in [MorningAccess.preview,.pro] {XCTAssertEqual(access.effectiveChallenge(challenge),challenge)}
  }
 }
 func testEffectiveAlarmPreservesIdentityStateAndSavedPreferences() throws {
  for challenge:ChallengeSelection in [.readAndChoose,.pushUps(repetitions:5)] {
   var saved=SavedAlarm(time:try AlarmTime(hour:6,minute:30,weekdays:[2,4]),mode:.focused,sound:.sunrise,challenge:challenge)
   saved.enabled=false;saved.state = .needsReview
   let effective=MorningAccess.free.effectiveAlarm(saved)
   XCTAssertEqual(effective.id,saved.id);XCTAssertEqual(effective.time,saved.time)
   XCTAssertEqual(effective.enabled,saved.enabled);XCTAssertEqual(effective.state,saved.state)
   XCTAssertEqual(effective.mode,.balanced);XCTAssertEqual(effective.sound,.system)
   XCTAssertEqual(effective.challenge,challenge.kind == .pushUps ? .pushUps(repetitions:3) : challenge)
   XCTAssertEqual(saved.mode,.focused);XCTAssertEqual(saved.sound,.sunrise);XCTAssertEqual(saved.challenge,challenge)
   for access in [MorningAccess.preview,.pro] {XCTAssertEqual(access.effectiveAlarm(saved),saved)}
  }
 }
}

final class MorningScoreTests:XCTestCase {
 private var calendar:Calendar {
  var calendar=Calendar(identifier:.gregorian)
  calendar.timeZone=TimeZone(identifier:"Asia/Ho_Chi_Minh")!
  return calendar
 }
 private func date(_ value:String)->Date {ISO8601DateFormatter().date(from:value)!}
 func testOnlyCompletedChallengesEarnPointsAndEmptyIsUnrated() {
  let now=date("2026-10-15T06:30:00+07:00")
  let empty=MorningScore(date:now,entries:[])
  XCTAssertNil(empty.score);XCTAssertEqual(empty.rating,.noData)
  for outcome:WakeOutcome in [.localCompleted,.openaiVerified,.aiVerified,.selfConfirmed,.dismissed] {
   let score=MorningScore(date:now,entries:[MorningEntry(date:now,outcome:outcome)])
   XCTAssertEqual(score.score,[.selfConfirmed,.dismissed].contains(outcome) ? 0 : 100)
  }
  let mixed=MorningScore(date:now,entries:[.localCompleted,.selfConfirmed,.dismissed].map {MorningEntry(date:now,outcome:$0)})
  XCTAssertEqual(mixed.score,33);XCTAssertEqual(mixed.completed,1);XCTAssertEqual(mixed.attempts,3)
 }
 func testRatingThresholds() {
  let now=date("2026-10-15T06:30:00+07:00")
  for (completed,rating):(Int,ConsistencyRating) in [(0,.gettingStarted),(49,.gettingStarted),(50,.building),(74,.building),(75,.consistent),(89,.consistent),(90,.excellent),(100,.excellent)] {
   let entries=(0..<100).map {MorningEntry(date:now,outcome:$0<completed ? .localCompleted : .selfConfirmed)}
   let score=MorningScore(date:now,entries:entries)
   XCTAssertEqual(score.score,completed);XCTAssertEqual(score.rating,rating)
  }
 }
 func testWeekUsesLocalDaysAveragesAttemptsAndExcludesPracticeAndFuture() throws {
  let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer {try? FileManager.default.removeItem(at:root)}
  var journal=try MorningJournal(url:root.appendingPathComponent("mornings.json"))
  let now=date("2026-10-15T06:30:00+07:00")
  for (timestamp,outcome):(String,WakeOutcome) in [("2026-10-08T23:59:59+07:00",.localCompleted),("2026-10-09T00:00:00+07:00",.openaiVerified),("2026-10-14T23:59:59+07:00",.selfConfirmed),("2026-10-15T00:00:00+07:00",.localCompleted),("2026-10-15T06:00:00+07:00",.dismissed)] {
   _=try journal.record(MorningEntry(date:date(timestamp),outcome:outcome),now:now,calendar:calendar)
  }
  _=try journal.record(MorningEntry(date:now,outcome:.localCompleted),rehearsal:true,now:now,calendar:calendar)
  _=try journal.record(MorningEntry(date:now.addingTimeInterval(1),outcome:.localCompleted),now:now,calendar:calendar)
  let week=journal.weeklyScores(now:now,calendar:calendar)
  XCTAssertEqual(week.count,7);XCTAssertEqual(week.first?.date,date("2026-10-09T00:00:00+07:00"))
  XCTAssertEqual(week.map(\.score),[100,nil,nil,nil,nil,0,50])
  XCTAssertEqual(week.last?.attempts,2)
 }
 func testMonthRetainsDayOneThroughDayThirtyOneAndSurvivesReload() throws {
  let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer {try? FileManager.default.removeItem(at:root)}
  let url=root.appendingPathComponent("mornings.json")
  var journal=try MorningJournal(url:url)
  let monthEnd=date("2026-10-31T08:00:00+07:00")
  for timestamp in ["2026-09-30T07:00:00+07:00","2026-10-01T07:00:00+07:00","2026-10-31T07:00:00+07:00"] {
   let recorded=date(timestamp)
   _=try journal.record(MorningEntry(date:recorded,outcome:.localCompleted),now:recorded,calendar:calendar)
  }
  let restored=try MorningJournal(url:url)
  XCTAssertEqual(restored.entries.count,2)
  let month=restored.monthlyScore(now:monthEnd,calendar:calendar)
  XCTAssertEqual(month.date,date("2026-10-01T00:00:00+07:00"));XCTAssertEqual(month.completed,2)
  XCTAssertEqual(month.attempts,2);XCTAssertEqual(month.score,100)
  let nextMonth=restored.monthlyScore(now:date("2026-11-01T08:00:00+07:00"),calendar:calendar)
  XCTAssertNil(nextMonth.score);XCTAssertEqual(nextMonth.rating,.noData)
  let midMonth=restored.monthlyScore(now:date("2026-10-15T08:00:00+07:00"),calendar:calendar)
  XCTAssertEqual(midMonth.attempts,1)
 }
}
