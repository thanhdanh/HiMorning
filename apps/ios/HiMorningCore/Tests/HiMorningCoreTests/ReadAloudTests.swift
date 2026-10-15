import Foundation
#if !PORTABLE_TESTS
import XCTest
@testable import HiMorningCore
#endif

final class ReadAloudTests:XCTestCase {
 func testPromptsHaveEnoughContentForARealReading() {
  for prompt in EnglishChallengeContent.readAloud {
   let count=RecognizedWordMatch.tokens(in:prompt.text).count
   XCTAssertTrue((18...25).contains(count))
  }
 }

 func testFinishingAcceptsAReadingWithoutGradingWordAccuracy() {
  var reading=ReadAloudAttempt(target:"The quiet morning brings a chance to begin again today.")
  reading.observe("A peaceful start gives me time for something new today.")
  XCTAssertTrue(reading.finish())
  XCTAssertTrue(reading.ended)
 }

 func testFinishOrTimeoutCannotPassSilenceOrPartialSpeech() {
  var silent=ReadAloudAttempt(target:"The quiet morning brings a chance to begin again today.")
  silent.observe(" ... \n")
  XCTAssertFalse(silent.finish())
  var partial=ReadAloudAttempt(target:"The quiet morning brings a chance to begin again today.")
  partial.observe("The quiet morning")
  XCTAssertFalse(partial.finish())
  partial.observe("The quiet morning brings a chance to begin again today.")
  XCTAssertFalse(partial.finish())
 }

 func testACompleteReadingAtTimeoutCanFinishAndStopRejectsLateResults() {
  var timeout=ReadAloudAttempt(target:"The quiet morning brings a chance to begin again today.")
  timeout.observe("The quiet morning brings a chance to begin again today.")
  XCTAssertTrue(timeout.finish())
  var stopped=ReadAloudAttempt(target:"The quiet morning brings a chance to begin again today.")
  stopped.observe("The quiet morning")
  stopped.stop()
  stopped.observe("The quiet morning brings a chance to begin again today.")
  XCTAssertEqual(stopped.transcript,"The quiet morning")
  XCTAssertFalse(stopped.finish())
 }

 func testLongerSentencesAllowAnUnhurriedReading() {
  let short=ReadAloudAttempt(target:"A fresh start.")
  let longer=ReadAloudAttempt(target:EnglishChallengeContent.readAloud[0].text)
  XCTAssertGreaterThan(short.listeningDuration,20)
  XCTAssertGreaterThan(longer.listeningDuration,short.listeningDuration)
 }

 func testEmptyTargetCannotComplete() {
  var reading=ReadAloudAttempt(target:"")
  reading.observe("A voice was recognized.")
  XCTAssertFalse(reading.finish())
 }
}
