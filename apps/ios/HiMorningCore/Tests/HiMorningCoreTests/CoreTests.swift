import Foundation
#if !PORTABLE_TESTS
import XCTest
@testable import HiMorningCore
#endif
final class CoreTests: XCTestCase {
 func testLanguageSelectionAndFallback() {
  XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages:["vi-VN","en"]), "vi")
  XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages:["fr","en-GB"]), "en")
  XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages:["fr-FR","EN_gb"]), "en")
  XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages:["fr","vi"]), "vi")
  XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages:["fr"]), "en")
  XCTAssertNil(AppLanguage(rawValue:"fr"))
  XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages:[]), "en")
  XCTAssertEqual(AppLanguage.english.resolved(preferredLanguages:["vi"]), "en")
  XCTAssertEqual(AppLanguage.vietnamese.resolved(preferredLanguages:["en"]), "vi")
 }
 func testPresetsAreGentleAndBounded() {
  XCTAssertEqual(WakeMode.gentle.policy.snoozes, 2)
  XCTAssertEqual(WakeMode.gentle.policy.reps, 0)
  XCTAssertEqual(WakeMode.balanced.policy.reps, 5)
  XCTAssertEqual(WakeMode.focused.policy.reps, 10)
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
 func testVerifiedResultCanOnlyApplyOnce() {
  var flow=WakeSession(mode:.balanced)
  XCTAssertNil(flow.outcome)
  let generation=flow.beginVerification()
  XCTAssertTrue(flow.applyVerified(generation:generation))
  XCTAssertFalse(flow.applyVerified(generation:generation))
  XCTAssertEqual(flow.outcome,.aiVerified)
 }
 func testFallbackAndSnoozeRemainExplicit() {
  var flow=WakeSession(mode:.gentle)
  XCTAssertTrue(flow.snooze());XCTAssertTrue(flow.snooze());XCTAssertFalse(flow.snooze())
  flow.selfConfirm();XCTAssertEqual(flow.outcome,.selfConfirmed)
  var focused=WakeSession(mode:.focused);XCTAssertFalse(focused.snooze())
 }
 func testEvidenceBufferNeverExceedsCap() {
  var evidence=EvidenceBuffer(maxFrames:2,maxBytes:6)
  XCTAssertTrue(evidence.append(Data([1,2,3]),timestampMs:0))
  XCTAssertFalse(evidence.append(Data([1]),timestampMs:0))
  XCTAssertTrue(evidence.append(Data([4,5,6]),timestampMs:300))
  XCTAssertFalse(evidence.append(Data([7]),timestampMs:600))
  XCTAssertEqual(evidence.frames.count,2)
  evidence.clear();XCTAssertTrue(evidence.frames.isEmpty)
 }

 func testChallengeDefaultsUseModeFloorsButRemainIndependent() throws {
  let time=try AlarmTime(hour:6,minute:30,weekdays:[])
  XCTAssertEqual(SavedAlarm(time:time,mode:.gentle).challenge,.none)
  XCTAssertEqual(SavedAlarm(time:time,mode:.balanced).challenge,.pushUps(repetitions:5))
  XCTAssertEqual(SavedAlarm(time:time,mode:.focused).challenge,.pushUps(repetitions:10))
  XCTAssertEqual(ChallengeSelection.pushUps(repetitions:0).repetitions,1)
  XCTAssertEqual(ChallengeSelection.pushUps(repetitions:99).repetitions,50)

  let focusedReading=SavedAlarm(time:time,mode:.focused,challenge:.readAloud)
  XCTAssertEqual(focusedReading.mode,.focused)
  XCTAssertEqual(focusedReading.challenge.kind,.readAloud)
  XCTAssertNil(focusedReading.challenge.repetitions)
 }

 func testSavedAlarmDecodesLegacyPayloadAndRoundTripsExplicitChallenge() throws {
  let time=try AlarmTime(hour:7,minute:15,weekdays:[2,4,6])
  let explicit=SavedAlarm(time:time,mode:.gentle,sound:.softChime,challenge:.guidedRhythm(variant:.seated))
  let encoded=try JSONEncoder().encode(explicit)
  XCTAssertEqual(try JSONDecoder().decode(SavedAlarm.self,from:encoded),explicit)

  var legacyObject=try XCTUnwrap(JSONSerialization.jsonObject(with:encoded) as? [String:Any])
  legacyObject.removeValue(forKey:"challenge")
  for (mode,expected) in [(WakeMode.gentle,ChallengeSelection.none),(.balanced,.pushUps(repetitions:3)),(.focused,.pushUps(repetitions:5))] {
   legacyObject["mode"]=mode.rawValue
   let legacyData=try JSONSerialization.data(withJSONObject:legacyObject)
   let migrated=try JSONDecoder().decode(SavedAlarm.self,from:legacyData)
   XCTAssertEqual(migrated.challenge,expected)
  }
 }

 func testHistoricalExplicitTargetsDecodeWithoutBeingRaised() throws {
  for target in 1...5 {
   let data=Data("{\"kind\":\"push_ups\",\"repetitions\":\(target)}".utf8)
   XCTAssertEqual(try JSONDecoder().decode(ChallengeSelection.self,from:data).repetitions,target)
  }
 }
 func testCaptureStoresFiftyCompleteCyclesWithinEvidenceBounds() {
  var capture=CycleCapture(target:50)
  for index in 0..<250 {
   capture.observe(angle:[165.0,120,80,120,165][index%5],visible:true,jpeg:Data(repeating:1,count:50000),timestampMs:index*1200)
  }
  XCTAssertTrue(capture.ready);XCTAssertEqual(capture.completedReps,50);XCTAssertEqual(capture.frames.count,250)
  capture.observe(angle:165,visible:true,jpeg:Data([1]),timestampMs:300000)
  XCTAssertEqual(capture.frames.count,250)
  var buffer=EvidenceBuffer()
  for index in 0..<250 {XCTAssertTrue(buffer.append(Data(repeating:1,count:50000),timestampMs:index*1200))}
  XCTAssertFalse(buffer.append(Data([1]),timestampMs:300000))
  var expired=EvidenceBuffer()
  XCTAssertFalse(expired.append(Data([1]),timestampMs:300001))
  XCTAssertEqual(ChallengeSelection.pushUps(repetitions:51).repetitions,50)
 }

 func testLocalCompletionInvalidatesPendingCloudResult() {
  var flow=WakeSession(mode:.balanced)
  let generation=flow.beginVerification()
  XCTAssertTrue(flow.completeLocally())
  XCTAssertEqual(flow.outcome,.localCompleted)
  XCTAssertFalse(flow.applyVerified(generation:generation))
  XCTAssertFalse(flow.completeLocally())
 }

 func testRecognizedWordScoreUsesNormalizedTokenEditDistanceAndPassesAtEightyPercent() {
  XCTAssertEqual(RecognizedWordMatch.score(target:"Good morning, WORLD!",recognized:"good morning world"),1,accuracy:0.0001)
  XCTAssertEqual(RecognizedWordMatch.score(target:"one two three four five",recognized:"one two tree four five"),0.8,accuracy:0.0001)
  XCTAssertTrue(RecognizedWordMatch.passes(target:"one two three four five",recognized:"one two tree four five"))
  XCTAssertFalse(RecognizedWordMatch.passes(target:"one two three four",recognized:"one too four"))
  XCTAssertFalse(RecognizedWordMatch.passes(target:"",recognized:""))
 }

 func testCuratedEnglishChallengesAreValidAndStable() {
  XCTAssertFalse(EnglishChallengeContent.readAndChoose.isEmpty)
  XCTAssertFalse(EnglishChallengeContent.readAloud.isEmpty)
  for item in EnglishChallengeContent.readAndChoose {
   XCTAssertFalse(item.sentence.isEmpty)
   XCTAssertTrue(item.choices.indices.contains(item.correctChoiceIndex))
  }
  XCTAssertEqual(Set(EnglishChallengeContent.readAloud.map(\.id)).count,EnglishChallengeContent.readAloud.count)
 }

 func testGuidedRhythmSupportsStandingAndSeatedWithoutImageEvidence() {
  var standing=GuidedRhythmSession(variant:.standing,maxSequenceDurationMs:3_000)
  XCTAssertFalse(standing.observe(.standing,timestampMs:0,visible:true))
  XCTAssertFalse(standing.observe(.standing,timestampMs:250,visible:true))
  XCTAssertFalse(standing.observe(.lowered,timestampMs:500,visible:true))
  XCTAssertTrue(standing.observe(.standing,timestampMs:1_000,visible:true))
  XCTAssertEqual(standing.completedCycles,1)

  var seated=GuidedRhythmSession(variant:.seated,maxSequenceDurationMs:3_000)
  XCTAssertFalse(seated.observe(.armsDown,timestampMs:0,visible:true))
  XCTAssertFalse(seated.observe(.armsDown,timestampMs:250,visible:true))
  XCTAssertFalse(seated.observe(.armsUp,timestampMs:500,visible:true))
  XCTAssertTrue(seated.observe(.armsDown,timestampMs:1_000,visible:true))
  XCTAssertEqual(seated.completedCycles,1)
 }

 func testGuidedRhythmResetsOnOcclusionOutOfOrderAndExpiredWindow() {
  var rhythm=GuidedRhythmSession(variant:.standing,maxSequenceDurationMs:1_000)
  XCTAssertFalse(rhythm.observe(.standing,timestampMs:100,visible:true))
  XCTAssertFalse(rhythm.observe(.lowered,timestampMs:200,visible:false))
  XCTAssertFalse(rhythm.observe(.lowered,timestampMs:300,visible:true))
  XCTAssertFalse(rhythm.observe(.standing,timestampMs:250,visible:true))
  XCTAssertFalse(rhythm.observe(.standing,timestampMs:500,visible:true))
  XCTAssertFalse(rhythm.observe(.lowered,timestampMs:700,visible:true))
  XCTAssertFalse(rhythm.observe(.standing,timestampMs:1_501,visible:true))
  XCTAssertEqual(rhythm.completedCycles,0)
  XCTAssertFalse(rhythm.observe(.standing,timestampMs:2_000,visible:true))
  XCTAssertFalse(rhythm.observe(.lowered,timestampMs:2_200,visible:true))
  XCTAssertTrue(rhythm.observe(.standing,timestampMs:2_400,visible:true))
  XCTAssertEqual(rhythm.completedCycles,1)
  rhythm.interrupt()
  XCTAssertEqual(rhythm.completedCycles,1)
 }
}
