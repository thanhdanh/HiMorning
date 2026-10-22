import XCTest
import AVFoundation
@testable import HiMorning

@MainActor final class VoiceCoachTests:XCTestCase {
 private let start=Date(timeIntervalSince1970:1000)
 func testOnlyStableHintsSpeakAndRepeatedHintsStayQuiet() {
  var spoken:[String]=[]
  let coach=VoiceCoach(say:{spoken.append($0)},tick:{})
  coach.hint("Show both wrists",at:start)
  coach.hint("Show both wrists",at:start.addingTimeInterval(1))
  XCTAssertTrue(spoken.isEmpty)
  coach.hint("Show both wrists",at:start.addingTimeInterval(2.1))
  coach.hint("Show both wrists",at:start.addingTimeInterval(40))
  XCTAssertEqual(spoken,["Show both wrists"])
 }
 func testChangingHintsWaitFifteenSecondsAfterInstructions() {
  var spoken:[String]=[]
  let coach=VoiceCoach(say:{spoken.append($0)},tick:{})
  coach.speak("Instructions",at:start)
  for seconds in [1.0,3,6,10,14.9] {coach.hint("Show both wrists",at:start.addingTimeInterval(seconds))}
  XCTAssertEqual(spoken,["Instructions"])
  coach.hint("Show both wrists",at:start.addingTimeInterval(15.1))
  XCTAssertEqual(spoken,["Instructions","Show both wrists"])
  coach.hint("Come closer",at:start.addingTimeInterval(16))
  coach.hint("Come closer",at:start.addingTimeInterval(18))
  XCTAssertEqual(spoken.count,2)
  coach.hint("Come closer",at:start.addingTimeInterval(30.2))
  XCTAssertEqual(spoken.last,"Come closer")
 }
 func testFlappingTrackingMessagesCannotProduceRepeatedSpeech() {
  var spoken:[String]=[]
  let coach=VoiceCoach(say:{spoken.append($0)},tick:{})
  for index in 0..<60 {coach.hint(index.isMultiple(of:2) ? "Show wrists":"Raise arms",at:start.addingTimeInterval(Double(index)*0.5))}
  XCTAssertTrue(spoken.isEmpty)
  coach.hint("Show wrists",at:start.addingTimeInterval(30))
  coach.hint("Show wrists",at:start.addingTimeInterval(32.1))
  XCTAssertEqual(spoken,["Show wrists"])
 }
 func testHintsAndCountsNeverInterruptAnUtterance() {
  var spoken:[String]=[],busy=true
  let coach=VoiceCoach(say:{spoken.append($0)},tick:{},isSpeaking:{busy})
  coach.hint("Show wrists",at:start)
  coach.hint("Show wrists",at:start.addingTimeInterval(20))
  coach.rep(5,at:start.addingTimeInterval(21))
  XCTAssertTrue(spoken.isEmpty)
  busy=false
  coach.hint("Show wrists",at:start.addingTimeInterval(32))
  coach.hint("Show wrists",at:start.addingTimeInterval(34.1))
  XCTAssertEqual(spoken,["Show wrists"])
 }
 func testRepTicksEveryTimeButOnlyOccasionalMilestonesAreSpoken() {
  var spoken:[String]=[],ticks=0
  let coach=VoiceCoach(say:{spoken.append($0)},tick:{ticks+=1})
  coach.speak("Instructions",at:start)
  for count in 1...10 {coach.rep(count,at:start.addingTimeInterval(Double(count)*2))}
  XCTAssertEqual(ticks,10);XCTAssertEqual(spoken,["Instructions","5","10"])
  coach.rep(15,spoken:false,at:start.addingTimeInterval(30))
  XCTAssertEqual(ticks,11);XCTAssertEqual(spoken.count,3)
 }
 func testProgressPausesRemindersAndStopDiscardsPendingHints() {
  var spoken:[String]=[],ticks=0
  let coach=VoiceCoach(say:{spoken.append($0)},tick:{ticks+=1})
  coach.rep(1,at:start)
  coach.hint("Raise arms",at:start.addingTimeInterval(1))
  coach.hint("Raise arms",at:start.addingTimeInterval(3))
  XCTAssertTrue(spoken.isEmpty)
  coach.stop()
  coach.hint("Raise arms",at:start.addingTimeInterval(30))
  coach.rep(5,at:start.addingTimeInterval(31))
  XCTAssertTrue(spoken.isEmpty);XCTAssertEqual(ticks,1)
  coach.speak("Completed",at:start.addingTimeInterval(32))
  XCTAssertEqual(spoken,["Completed"])
 }
 func testSpeechUsesASlowerRateAndBreathingRoomBetweenSentences() {
  let utterance=VoiceCoach.utterance("Good morning.")
  XCTAssertLessThan(utterance.rate,AVSpeechUtteranceDefaultSpeechRate)
  XCTAssertEqual(utterance.rate,AVSpeechUtteranceDefaultSpeechRate*0.85,accuracy:0.001)
  XCTAssertGreaterThanOrEqual(utterance.postUtteranceDelay,0.3)
 }
}
