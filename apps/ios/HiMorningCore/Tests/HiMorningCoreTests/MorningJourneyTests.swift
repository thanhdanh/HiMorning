import Foundation
#if !PORTABLE_TESTS
import XCTest
@testable import HiMorningCore
#endif

final class MorningJourneyTests:XCTestCase {
 private var calendar:Calendar {
  var value=Calendar(identifier:.gregorian)
  value.timeZone=TimeZone(secondsFromGMT:0)!
  return value
 }
 private func date(_ day:Int,hour:Int=7)->Date {
  calendar.date(from:DateComponents(year:2026,month:1,day:day,hour:hour))!
 }
 private func successful(_ day:Int,for journey:inout MorningJourney,now:Date?=nil)->Bool {
  journey.record(date:date(day),outcome:.localCompleted,now:now ?? date(day),calendar:calendar)
 }

 func testSevenSuccessfulDistinctDaysCompleteJourneyAndCapProgress() {
  var journey=MorningJourney(focus:.clearStart,now:date(1))
  for day in 1...7 {XCTAssertTrue(successful(day,for:&journey))}
  XCTAssertTrue(journey.isComplete)
  XCTAssertEqual(journey.completedCount,7)
  XCTAssertEqual(journey.completions.count,7)
  XCTAssertFalse(journey.record(date:date(8),outcome:.localCompleted,now:date(8),calendar:calendar))
  XCTAssertEqual(journey.completions.count,7)
 }

 func testDuplicateLocalDateAndUnsuccessfulOrRehearsalOutcomesDoNotAdvance() {
  var journey=MorningJourney(focus:.gentleMovement,now:date(1))
  XCTAssertFalse(journey.record(date:date(1),outcome:.localCompleted,rehearsal:true,now:date(1),calendar:calendar))
  for outcome in [WakeOutcome.selfConfirmed,.dismissed] {
   XCTAssertFalse(journey.record(date:date(1),outcome:outcome,now:date(1),calendar:calendar))
  }
  XCTAssertTrue(journey.record(date:date(1),outcome:.aiVerified,now:date(1),calendar:calendar))
  XCTAssertFalse(journey.record(date:date(1,hour:20),outcome:.openaiVerified,now:date(1,hour:20),calendar:calendar))
  XCTAssertEqual(journey.completedCount,1)
 }

 func testMissedDaysAndThirtyOneDayGapDoNotResetOrExpireJourney() throws {
  var journey=MorningJourney(focus:.clearStart,now:date(1))
  XCTAssertTrue(successful(1,for:&journey))
  XCTAssertTrue(successful(40,for:&journey))
  let restored=try JSONDecoder().decode(MorningJourney.self,from:JSONEncoder().encode(journey))
  XCTAssertEqual(restored.completedCount,2)
  XCTAssertEqual(restored.startedAt,date(1))
  XCTAssertFalse(restored.isComplete)
 }

 func testEnrollmentAndFutureDatesAreRejected() {
  var journey=MorningJourney(focus:.findYourVoice,now:date(3))
  XCTAssertFalse(journey.record(date:date(2),outcome:.localCompleted,now:date(3),calendar:calendar))
  XCTAssertFalse(journey.record(date:date(4),outcome:.localCompleted,now:date(3),calendar:calendar))
  XCTAssertEqual(journey.completedCount,0)
 }

 func testChangingFocusPreservesJourneyProgress() {
  var journey=MorningJourney(focus:.clearStart,now:date(1))
  XCTAssertTrue(successful(1,for:&journey))
  journey.changeFocus(.findYourVoice)
  XCTAssertEqual(journey.focus,.findYourVoice)
  XCTAssertEqual(journey.startedAt,date(1))
  XCTAssertEqual(journey.completedCount,1)
  XCTAssertEqual(journey.missionIndex(now:date(2),calendar:calendar),1)
 }

 func testEnergizeUsesGentleMissionsWithoutFullAccess() {
  for index in 0...6 {
   XCTAssertEqual(MorningFocus.energize.mission(at:index,access:.free),MorningFocus.gentleMovement.mission(at:index,access:.free))
  }
  XCTAssertEqual(MorningFocus.energize.mission(at:1,access:.preview),.pushUps(repetitions:5))
  let pro=[0,1,2,3,4,5,6].map {MorningFocus.energize.mission(at:$0,access:.pro)}
  XCTAssertEqual(pro,[.init(kind:.waveHand),.pushUps(repetitions:5),.init(kind:.stretching),.init(kind:.jumpingJacks),.pushUps(repetitions:5),.guidedRhythm(variant:.standing),.pushUps(repetitions:5)])
  XCTAssertEqual(pro.filter {$0.kind == .pushUps}.compactMap(\.repetitions),[5,5,5])
 }

 func testClearStartUsesOnlyLowPermissionDecisionsAndRiddles() {
  for index in 0...6 {
   let mission=MorningFocus.clearStart.mission(at:index,access:.free)
   XCTAssertTrue(mission.kind == .readAndChoose || mission.kind == .riddle)
  }
 }

 func testGentleMovementNeverUsesIntenseOrStandingChallenges() {
  for focus in [MorningFocus.clearStart,.gentleMovement,.findYourVoice] {
   for index in 0...6 {
    let mission=focus.mission(at:index,access:.pro)
    XCTAssertTrue(mission.kind != .pushUps)
    XCTAssertTrue(mission.kind != .jumpingJacks)
    XCTAssertTrue(mission.rhythmVariant != .standing)
   }
  }
  let gentle=[0,1,2,3,4,5,6].map {MorningFocus.gentleMovement.mission(at:$0,access:.pro)}
  XCTAssertEqual(gentle,[.init(kind:.waveHand),.init(kind:.neckRotation),.guidedRhythm(variant:.seated),.init(kind:.waveHand),.guidedRhythm(variant:.seated),.init(kind:.neckRotation),.guidedRhythm(variant:.seated)])
 }

 func testMissionIndexShowsFinishedMissionTodayAndNextMissionTomorrow() {
  var journey=MorningJourney(focus:.clearStart,now:date(1))
  XCTAssertEqual(journey.missionIndex(now:date(1),calendar:calendar),0)
  XCTAssertTrue(successful(1,for:&journey))
  XCTAssertTrue(journey.completedToday(now:date(1),calendar:calendar))
  XCTAssertEqual(journey.missionIndex(now:date(1,hour:20),calendar:calendar),0)
  XCTAssertFalse(journey.completedToday(now:date(2),calendar:calendar))
  XCTAssertEqual(journey.missionIndex(now:date(2),calendar:calendar),1)
 }

 func testRestartRequiresCompletionAndCannotRepeatCompletionOnSameLocalDate() {
  var journey=MorningJourney(focus:.clearStart,now:date(1))
  XCTAssertFalse(journey.restart(now:date(1),calendar:calendar))
  for day in 1...7 {XCTAssertTrue(successful(day,for:&journey))}
  XCTAssertTrue(journey.restart(now:date(7,hour:20),calendar:calendar))
  XCTAssertFalse(journey.record(date:date(7,hour:21),outcome:.localCompleted,now:date(7,hour:21),calendar:calendar))
  XCTAssertTrue(journey.completedToday(now:date(7,hour:21),calendar:calendar))
  XCTAssertEqual(journey.completedJourneys,1)
  XCTAssertEqual(journey.completedCount,0)
  XCTAssertEqual(journey.startedAt,date(7,hour:20))
  XCTAssertTrue(journey.record(date:date(8,hour:8),outcome:.localCompleted,now:date(8,hour:8),calendar:calendar))
  XCTAssertFalse(journey.record(date:date(8,hour:9),outcome:.localCompleted,now:date(8,hour:9),calendar:calendar))
  XCTAssertTrue(successful(9,for:&journey))
 }

 func testDecodeRejectsMalformedProgressButKeepsLongRunningJourneyDates() throws {
  let fresh=MorningJourney(focus:.clearStart,now:date(1))
  XCTAssertEqual(try JSONDecoder().decode(MorningJourney.self,from:JSONEncoder().encode(fresh)),fresh)
  let decoder=JSONDecoder()
  decoder.dateDecodingStrategy = .iso8601
  let start="2026-02-02T07:00:00Z"
  let before="2026-02-01T07:00:00Z"
  let after="2026-02-03T07:00:00Z"
  let invalid:[[String:Any]]=[
   ["focus":"clearStart","startedAt":start,"completions":Array(repeating:after,count:8),"completedJourneys":0],
   ["focus":"clearStart","startedAt":start,"completions":[],"completedJourneys":-1],
   ["focus":"clearStart","startedAt":start,"completions":[before],"completedJourneys":0]
  ]
  for object in invalid {
   let data=try JSONSerialization.data(withJSONObject:object)
   XCTAssertThrowsError(try decoder.decode(MorningJourney.self,from:data))
  }

  var journey=MorningJourney(focus:.clearStart,now:date(1))
  XCTAssertTrue(successful(1,for:&journey))
  XCTAssertTrue(successful(40,for:&journey))
  let encoded=try JSONEncoder().encode(journey)
  XCTAssertEqual(try JSONDecoder().decode(MorningJourney.self,from:encoded),journey)
 }
}
