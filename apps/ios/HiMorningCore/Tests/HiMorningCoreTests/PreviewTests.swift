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
