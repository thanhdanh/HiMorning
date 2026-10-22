import XCTest
import HiMorningCore
@testable import HiMorning

@MainActor final class JourneyStoreTests:XCTestCase {
 private var calendar:Calendar {
  var value=Calendar(identifier:.gregorian)
  value.timeZone=TimeZone(secondsFromGMT:0)!
  return value
 }
 private func date(_ day:Int)->Date {
  calendar.date(from:DateComponents(year:2026,month:2,day:day,hour:7))!
 }

 func testJourneyPersistsAcrossStoreRelaunchAndLongGap() throws {
  var data:Data?
  let first=JourneyStore(load:{data},save:{data=$0})
  XCTAssertTrue(first.choose(.clearStart,access:.free,now:date(1)))
  XCTAssertTrue(first.record(date:date(1),outcome:.localCompleted,rehearsal:false,now:date(1),calendar:calendar))
  XCTAssertTrue(first.record(date:date(40),outcome:.aiVerified,rehearsal:false,now:date(40),calendar:calendar))

  let relaunched=JourneyStore(load:{data},save:{data=$0})
  XCTAssertEqual(relaunched.journey?.focus,.clearStart)
  XCTAssertEqual(relaunched.journey?.completedCount,2)
  XCTAssertEqual(relaunched.journey?.startedAt,date(1))
 }

 func testCorruptDataDoesNotGetOverwrittenWhenChoosingFocus() {
  var saveCount=0
  let store=JourneyStore(load:{Data("not-json".utf8)},save:{_ in saveCount+=1})
  XCTAssertNil(store.journey)
  XCTAssertNotNil(store.message)
  XCTAssertFalse(store.choose(.gentleMovement,access:.free,now:date(1)))
  XCTAssertEqual(saveCount,0)
 }

 func testSaveFailurePreservesPreviouslyLoadedJourneyState() throws {
  var original=MorningJourney(focus:.clearStart,now:date(1))
  XCTAssertTrue(original.record(date:date(1),outcome:.localCompleted,now:date(1),calendar:calendar))
  let data=try JSONEncoder().encode(original)
  let store=JourneyStore(load:{data},save:{_ in throw NSError(domain:"save",code:1)})

  XCTAssertFalse(store.choose(.findYourVoice,access:.free,now:date(2)))
  XCTAssertEqual(store.journey,original)
  XCTAssertNotNil(store.message)
  XCTAssertFalse(store.record(date:date(2),outcome:.localCompleted,rehearsal:false,now:date(2),calendar:calendar))
  XCTAssertEqual(store.journey,original)
 }

 func testFreeAccessCannotChooseEnergizeButProCan() {
  var savedData:Data?
  let store=JourneyStore(load:{savedData},save:{savedData=$0})
  XCTAssertFalse(store.choose(.energize,access:.free,now:date(1)))
  XCTAssertNil(store.journey)
  XCTAssertNotNil(store.message)

  XCTAssertTrue(store.choose(.energize,access:.pro,now:date(1)))
  XCTAssertEqual(store.journey?.focus,.energize)
 }

 func testChangingGoalAndRestartPreserveAndAdvanceSavedJourney() {
  var savedData:Data?
  let store=JourneyStore(load:{savedData},save:{savedData=$0})
  XCTAssertTrue(store.choose(.gentleMovement,access:.free,now:date(1)))
  for day in 1...7 {
   XCTAssertTrue(store.record(date:date(day),outcome:.localCompleted,rehearsal:false,now:date(day),calendar:calendar))
  }
  XCTAssertTrue(store.restart(now:date(7),calendar:calendar))
  XCTAssertFalse(store.record(date:date(7),outcome:.localCompleted,rehearsal:false,now:date(7),calendar:calendar))
  XCTAssertFalse(store.restart(now:date(8),calendar:calendar))
  XCTAssertEqual(store.journey?.completedJourneys,1)
  XCTAssertEqual(store.journey?.completedCount,0)
  XCTAssertEqual(store.journey?.focus,.gentleMovement)
 }
}
