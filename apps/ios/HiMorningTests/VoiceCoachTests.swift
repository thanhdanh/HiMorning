import XCTest
@testable import HiMorning

@MainActor final class VoiceCoachTests: XCTestCase {
 func testHintIsRateLimitedAndDeduplicated() {
  var spoken: [String] = []
  let start = Date(timeIntervalSince1970: 1000)
  let repeated = VoiceCoach(languageCode: "en", say: { spoken.append($0) }, tick: {})
  repeated.hint("Step back", at: start)
  repeated.hint("Step back", at: start.addingTimeInterval(5))
  XCTAssertEqual(spoken, ["Step back"])

  spoken = []
  let changing = VoiceCoach(languageCode: "en", say: { spoken.append($0) }, tick: {})
  changing.hint("Step back", at: start)
  changing.hint("Show your feet", at: start.addingTimeInterval(1))
  XCTAssertEqual(spoken, ["Step back"])
  changing.hint("Show your feet", at: start.addingTimeInterval(3.1))
  XCTAssertEqual(spoken, ["Step back", "Show your feet"])
 }

 func testHintWaitsThreeSecondsAfterSpeak() {
  var spoken: [String] = []
  let start = Date(timeIntervalSince1970: 1000)
  let coach = VoiceCoach(languageCode: "en", say: { spoken.append($0) }, tick: {})
  coach.speak("Instructions", at: start)
  coach.hint("Step back", at: start.addingTimeInterval(1))
  XCTAssertEqual(spoken, ["Instructions"])
  coach.hint("Step back", at: start.addingTimeInterval(3.1))
  XCTAssertEqual(spoken, ["Instructions", "Step back"])
 }

 func testRepTicksThenSpeaksCount() {
  var events: [String] = []
  let coach = VoiceCoach(languageCode: "en", say: { events.append("say:\($0)") }, tick: { events.append("tick") })
  coach.rep(3)
  XCTAssertEqual(events, ["tick", "say:3"])
 }
}
