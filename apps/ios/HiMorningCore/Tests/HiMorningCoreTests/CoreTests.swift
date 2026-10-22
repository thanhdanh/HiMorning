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
  XCTAssertEqual(SavedAlarm(time:time,mode:.balanced).challenge,.readAndChoose)
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
 func testModeChallengeCatalogAndPreferredDefaults() throws {
  XCTAssertEqual(ChallengeKind.available(in:.gentle),[.none,.waveHand,.neckRotation])
  XCTAssertEqual(ChallengeKind.available(in:.balanced),[.readAloud,.readAndChoose,.riddle])
  XCTAssertEqual(ChallengeKind.available(in:.focused),[.pushUps,.jumpingJacks,.stretching])
  XCTAssertEqual(ChallengeKind.waveHand.rawValue,"wave_hand")
  XCTAssertEqual(ChallengeKind.neckRotation.rawValue,"neck_rotation")
  XCTAssertEqual(ChallengeKind.jumpingJacks.rawValue,"jumping_jacks")
  XCTAssertEqual(ChallengeKind.waveHand.localMovementTarget,3)
  XCTAssertEqual(ChallengeKind.jumpingJacks.localMovementTarget,10)
  XCTAssertTrue(ChallengeKind.stretching.usesLocalMovement)
  XCTAssertEqual(ChallengeKind.riddle.preferredMode,.balanced)
  let time=try AlarmTime(hour:6,minute:30,weekdays:[])
  XCTAssertEqual(SavedAlarm(time:time,mode:.gentle).challenge,.none)
  XCTAssertEqual(SavedAlarm(time:time,mode:.balanced).challenge,.readAndChoose)
  XCTAssertEqual(SavedAlarm(time:time,mode:.focused).challenge,.pushUps(repetitions:10))
 }
 func testLocalMovementRequiresStableOrderedVisiblePoses() {
  var staticPose=MovementChallengeProgress(kind:.jumpingJacks,target:1)
  for timestamp in stride(from:0,through:3_000,by:300) {_ = staticPose.observe(.jumpingJack(open:true),timestampMs:timestamp)}
  XCTAssertEqual(staticPose.completed,0)

  var jumping=MovementChallengeProgress(kind:.jumpingJacks,target:1)
  for (pose,time) in [(false,0),(false,300),(true,600),(true,900)] {
   _ = jumping.observe(.jumpingJack(open:pose),timestampMs:time)
  }
  _ = jumping.observe(.unavailable,timestampMs:1_200)
  for (pose,time) in [(false,1_500),(false,1_800),(true,2_100),(true,2_400),(false,2_700),(false,3_000)] {
   _ = jumping.observe(.jumpingJack(open:pose),timestampMs:time)
  }
  XCTAssertEqual(jumping.completed,1)

  var partial=MovementChallengeProgress(kind:.jumpingJacks,target:1)
  for (pose,time) in [(false,0),(false,300)] {_ = partial.observe(.jumpingJack(open:pose),timestampMs:time)}
  for time in [600,900] {_ = partial.observe(.transition,timestampMs:time)}
  XCTAssertEqual(partial.completed,0)
  for (pose,time) in [(true,1_200),(true,1_500),(false,1_800),(false,2_100)] {_ = partial.observe(.jumpingJack(open:pose),timestampMs:time)}
  XCTAssertEqual(partial.completed,1)


  var stretch=MovementChallengeProgress(kind:.stretching,target:1)
  for (pose,time) in [(false,0),(false,300),(true,600),(true,1_000),(true,1_300),(false,1_600),(false,1_900)] {
   _ = stretch.observe(.stretch(overhead:pose),timestampMs:time)
  }
  XCTAssertTrue(stretch.ready)
 }
 func testBriefTrackingLossKeepsProgressWhileSustainedLossResets() {
  var brief=MovementChallengeProgress(kind:.jumpingJacks,target:1)
  for (open,time) in [(false,0),(false,300),(true,600),(true,900)] {_ = brief.observe(.jumpingJack(open:open),timestampMs:time)}
  _ = brief.observe(.unavailable,timestampMs:1_000)
  _ = brief.observe(.unavailable,timestampMs:1_100)
  for (open,time) in [(false,1_200),(false,1_500)] {_ = brief.observe(.jumpingJack(open:open),timestampMs:time)}
  XCTAssertEqual(brief.completed,1)

  var sustained=MovementChallengeProgress(kind:.jumpingJacks,target:1)
  for (open,time) in [(false,0),(false,300),(true,600),(true,900)] {_ = sustained.observe(.jumpingJack(open:open),timestampMs:time)}
  _ = sustained.observe(.unavailable,timestampMs:1_000)
  _ = sustained.observe(.unavailable,timestampMs:1_700)
  for (open,time) in [(false,2_000),(false,2_300)] {_ = sustained.observe(.jumpingJack(open:open),timestampMs:time)}
  XCTAssertEqual(sustained.completed,0)

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

 func testGuidedRhythmSupportsStandingAndSeatedWithoutImageEvidence() {
  var standing=GuidedRhythmSession(variant:.standing,maxSequenceDurationMs:3_000)
  for time in [0,200,400,600,800] {
   XCTAssertFalse(standing.observe(time < 400 ? .standing : time < 800 ? .lowered : .standing,timestampMs:time,visible:true))
  }
  XCTAssertTrue(standing.observe(.standing,timestampMs:1_000,visible:true))
  XCTAssertEqual(standing.completedCycles,1)

  var seated=GuidedRhythmSession(variant:.seated,maxSequenceDurationMs:3_000)
  for time in [0,200,400,600,800] {
   XCTAssertFalse(seated.observe(time < 400 ? .armsDown : time < 800 ? .armsUp : .armsDown,timestampMs:time,visible:true))
  }
  XCTAssertTrue(seated.observe(.armsDown,timestampMs:1_000,visible:true))
  XCTAssertEqual(seated.completedCycles,1)
 }

 func testGuidedRhythmKeepsProgressThroughBriefOcclusion() {
  var rhythm=GuidedRhythmSession(variant:.standing,maxSequenceDurationMs:3_000)
  for (pose,time) in [(GuidedRhythmPose.standing,0),(.standing,200),(.lowered,400),(.lowered,600)] {
   XCTAssertFalse(rhythm.observe(pose,timestampMs:time,visible:true))
  }
  XCTAssertFalse(rhythm.observe(.lowered,timestampMs:700,visible:false))
  XCTAssertFalse(rhythm.observe(.standing,timestampMs:1_000,visible:true))
  XCTAssertTrue(rhythm.observe(.standing,timestampMs:1_200,visible:true))
  XCTAssertEqual(rhythm.completedCycles,1)
 }

 func testGuidedRhythmResetsAfterSustainedOcclusion() {
  var rhythm=GuidedRhythmSession(variant:.standing,maxSequenceDurationMs:3_000)
  for (pose,time) in [(GuidedRhythmPose.standing,0),(.standing,200),(.lowered,400),(.lowered,600)] {
   XCTAssertFalse(rhythm.observe(pose,timestampMs:time,visible:true))
  }
  XCTAssertFalse(rhythm.observe(.lowered,timestampMs:700,visible:false))
  XCTAssertFalse(rhythm.observe(.standing,timestampMs:1_400,visible:true))
  XCTAssertFalse(rhythm.observe(.standing,timestampMs:1_600,visible:true))
  XCTAssertEqual(rhythm.completedCycles,0)

  var longHidden=GuidedRhythmSession(variant:.standing,maxSequenceDurationMs:3_000)
  for (pose,time) in [(GuidedRhythmPose.standing,0),(.standing,200),(.lowered,400),(.lowered,600)] {
   XCTAssertFalse(longHidden.observe(pose,timestampMs:time,visible:true))
  }
  XCTAssertFalse(longHidden.observe(.lowered,timestampMs:700,visible:false))
  XCTAssertFalse(longHidden.observe(.lowered,timestampMs:1_301,visible:false))
  XCTAssertFalse(longHidden.observe(.standing,timestampMs:1_400,visible:true))
  XCTAssertFalse(longHidden.observe(.standing,timestampMs:1_600,visible:true))
  XCTAssertEqual(longHidden.completedCycles,0)
 }

 func testGuidedTransitionsCannotBridgeUnheldPoses() {
  for variant in [GuidedRhythmVariant.standing,.seated] {
   let rest:GuidedRhythmPose=variant == .standing ? .standing:.armsDown
   let action:GuidedRhythmPose=variant == .standing ? .lowered:.armsUp
   var rhythm=GuidedRhythmSession(variant:variant)
   for time in [0,200] {_=rhythm.observe(rest,timestampMs:time,visible:true)}
   _=rhythm.observe(action,timestampMs:400,visible:true)
   rhythm.transition(timestampMs:500)
   _=rhythm.observe(action,timestampMs:700,visible:true)
   for time in [733,933] {_=rhythm.observe(rest,timestampMs:time,visible:true)}
   XCTAssertEqual(rhythm.completedCycles,0)
  }
 }
 func testMissingCameraFramesCannotCompleteGuidedRhythm() {
  for variant in [GuidedRhythmVariant.standing,.seated] {
   let rest:GuidedRhythmPose=variant == .standing ? .standing:.armsDown
   let action:GuidedRhythmPose=variant == .standing ? .lowered:.armsUp
   var rhythm=GuidedRhythmSession(variant:variant)
   for time in [0,200] {_=rhythm.observe(rest,timestampMs:time,visible:true)}
   for time in [400,1800] {_=rhythm.observe(action,timestampMs:time,visible:true)}
   for time in [2000,2200] {_=rhythm.observe(rest,timestampMs:time,visible:true)}
   XCTAssertEqual(rhythm.completedCycles,0)
  }
 }
 func testJacksAndStretchingRejectSpikesAndPartialCycles() {
  for kind in [ChallengeKind.jumpingJacks,.stretching] {
   var progress=MovementChallengeProgress(kind:kind,target:1)
   let rest:MovementObservation=kind == .jumpingJacks ? .jumpingJack(open:false):.stretch(overhead:false)
   let action:MovementObservation=kind == .jumpingJacks ? .jumpingJack(open:true):.stretch(overhead:true)
   for time in [0,300] {_=progress.observe(rest,timestampMs:time)}
   _=progress.observe(action,timestampMs:400)
   _=progress.observe(.transition,timestampMs:433)
   for time in [600,900] {_=progress.observe(rest,timestampMs:time)}
   XCTAssertEqual(progress.completed,0)
   for time in [1200,1500,1900] {_=progress.observe(action,timestampMs:time)}
   for time in [2200,2500] {_=progress.observe(rest,timestampMs:time)}
   XCTAssertEqual(progress.completed,1)
  }
 }
 func testGuidedRhythmSingleFramePoseIsIgnored() {
  var rhythm=GuidedRhythmSession(variant:.standing,maxSequenceDurationMs:3_000)
  XCTAssertFalse(rhythm.observe(.standing,timestampMs:0,visible:true))
  XCTAssertFalse(rhythm.observe(.standing,timestampMs:200,visible:true))
  XCTAssertFalse(rhythm.observe(.lowered,timestampMs:233,visible:true))
  XCTAssertFalse(rhythm.observe(.standing,timestampMs:266,visible:true))
  XCTAssertFalse(rhythm.observe(.standing,timestampMs:466,visible:true))
  XCTAssertEqual(rhythm.completedCycles,0)
 }

 func testGuidedRhythmResetsOnOutOfOrderAndExpiredWindow() {
  var rhythm=GuidedRhythmSession(variant:.standing,maxSequenceDurationMs:1_000)
  XCTAssertFalse(rhythm.observe(.standing,timestampMs:100,visible:true))
  XCTAssertFalse(rhythm.observe(.standing,timestampMs:300,visible:true))
  XCTAssertFalse(rhythm.observe(.lowered,timestampMs:250,visible:true))
  XCTAssertFalse(rhythm.observe(.standing,timestampMs:500,visible:true))
  XCTAssertFalse(rhythm.observe(.standing,timestampMs:700,visible:true))
  XCTAssertFalse(rhythm.observe(.lowered,timestampMs:900,visible:true))
  XCTAssertFalse(rhythm.observe(.lowered,timestampMs:1_100,visible:true))
  XCTAssertFalse(rhythm.observe(.standing,timestampMs:1_900,visible:true))
  XCTAssertFalse(rhythm.observe(.standing,timestampMs:2_100,visible:true))
  XCTAssertEqual(rhythm.completedCycles,0)
  XCTAssertFalse(rhythm.observe(.standing,timestampMs:2_300,visible:true))
  XCTAssertFalse(rhythm.observe(.lowered,timestampMs:2_500,visible:true))
  XCTAssertFalse(rhythm.observe(.lowered,timestampMs:2_700,visible:true))
  XCTAssertFalse(rhythm.observe(.standing,timestampMs:2_900,visible:true))
  XCTAssertTrue(rhythm.observe(.standing,timestampMs:3_100,visible:true))
  XCTAssertEqual(rhythm.completedCycles,1)
  rhythm.interrupt()
  XCTAssertEqual(rhythm.completedCycles,1)
 }
}
