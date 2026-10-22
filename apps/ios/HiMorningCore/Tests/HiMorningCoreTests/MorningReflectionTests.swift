import Foundation
#if !PORTABLE_TESTS
import XCTest
@testable import HiMorningCore
#endif
final class MorningReflectionTests:XCTestCase {
 func testReflectionUsesActualDistinctDaysAndWaitsForThreeMornings() {
  var calendar=Calendar(identifier:.gregorian);calendar.timeZone=TimeZone(secondsFromGMT:0)!
  let now=calendar.date(from:DateComponents(year:2026,month:10,day:23,hour:8))!
  func day(_ offset:Int)->Date {calendar.date(byAdding:.day,value:offset,to:now)!}
  var entries=[MorningEntry(challenge:.readAndChoose,date:now,outcome:.localCompleted),MorningEntry(challenge:.readAndChoose,date:now,outcome:.localCompleted)]
  let early=MorningReflection(entries:entries,now:now,calendar:calendar)
  XCTAssertEqual(early.completedDays,1);XCTAssertNil(early.goToChallenge)
  entries += [MorningEntry(challenge:.readAndChoose,date:day(-1),outcome:.localCompleted),MorningEntry(challenge:.init(kind:.riddle),date:day(-2),outcome:.openaiVerified),MorningEntry(challenge:.readAloud,date:day(-3),outcome:.selfConfirmed),MorningEntry(challenge:.readAloud,date:day(-4),outcome:.dismissed),MorningEntry(challenge:.readAloud,date:day(-30),outcome:.localCompleted),MorningEntry(challenge:.readAloud,date:day(1),outcome:.localCompleted)]
  let varied=[MorningEntry(challenge:.readAndChoose,date:now,outcome:.localCompleted),MorningEntry(challenge:.readAloud,date:day(-1),outcome:.localCompleted),MorningEntry(challenge:.init(kind:.riddle),date:day(-2),outcome:.localCompleted)]
  XCTAssertNil(MorningReflection(entries:varied,now:now,calendar:calendar).goToChallenge)
  let reflection=MorningReflection(entries:entries,now:now,calendar:calendar)
  XCTAssertEqual(reflection.completedDays,3);XCTAssertEqual(reflection.goToChallenge,.readAndChoose);XCTAssertEqual(reflection.goToDays,2)
 }
}
