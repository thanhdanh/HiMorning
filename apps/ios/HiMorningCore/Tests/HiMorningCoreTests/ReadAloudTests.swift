import Foundation
#if !PORTABLE_TESTS
import XCTest
@testable import HiMorningCore
#endif

final class ReadAloudTests:XCTestCase {
 func testPromptsHaveEnoughContentForARealReading() {
  let prompts=EnglishChallengeContent.readAloud
  XCTAssertGreaterThan(prompts.count,23)
  XCTAssertEqual(Set(prompts.map(\.id)).count,prompts.count)
  XCTAssertEqual(Set(prompts.map {RecognizedWordMatch.tokens(in:$0.text).joined(separator:" ")}).count,prompts.count)
  for prompt in prompts {
   let count=RecognizedWordMatch.tokens(in:prompt.text).count
   XCTAssertTrue((18...30).contains(count))
  }
  let durations=prompts.map {ReadAloudAttempt(target:$0.text).listeningDuration}
  XCTAssertGreaterThan(durations.max() ?? 0,durations.min() ?? 0)
 }

 func testFinishingRequiresMatchingWordsInsteadOfOnlySpeechLength() {
  var reading=ReadAloudAttempt(target:"The quiet morning brings a chance to begin again today.")
  reading.observe("A peaceful start gives me time for something new today.")
  XCTAssertFalse(reading.finish())
  XCTAssertTrue(reading.ended)
  var correct=ReadAloudAttempt(target:"The quiet morning brings a chance to begin again today.")
  correct.observe("the quiet morning brings a chance to begin again today")
  XCTAssertEqual(correct.progress,1,accuracy:0.0001)
  XCTAssertTrue(correct.finish())
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

 func testLiveFeedbackDistinguishesCorrectWrongAndUnreadWords() {
  let feedback=RecognizedWordMatch.feedback(target:"Small steps create steady progress.",recognized:"small stops",finished:false)
  XCTAssertEqual(feedback.words.map(\.text),["small","steps","create","steady","progress"])
  XCTAssertEqual(feedback.words.map(\.status),[.correct,.incorrect,.pending,.pending,.pending])
  XCTAssertEqual(feedback.score,0.2,accuracy:0.0001)
 }

 func testSkippedWordsDoNotShiftLaterMatches() {
  let feedback=RecognizedWordMatch.feedback(target:"Small steps create steady progress.",recognized:"small create steady progress",finished:false)
  XCTAssertEqual(feedback.words.map(\.status),[.correct,.incorrect,.correct,.correct,.correct])
  XCTAssertEqual(feedback.score,0.8,accuracy:0.0001)
 }

 func testExtraAndRepeatedWordsLowerTheScore() {
  let extra=RecognizedWordMatch.feedback(target:"small steps",recognized:"small big steps",finished:true)
  XCTAssertEqual(extra.words.map(\.status),[.correct,.correct])
  XCTAssertEqual(extra.extraWords,["big"])
  XCTAssertEqual(extra.score,2.0/3,accuracy:0.0001)
  let repeated=RecognizedWordMatch.feedback(target:"small steps",recognized:"small small steps",finished:true)
  XCTAssertEqual(repeated.extraWords,["small"])
  XCTAssertEqual(repeated.score,2.0/3,accuracy:0.0001)
 }

 func testFinalFeedbackMarksUnreadWordsAsMissed() {
  let feedback=RecognizedWordMatch.feedback(target:"Small steps create steady progress.",recognized:"small steps",finished:true)
  XCTAssertEqual(feedback.words.map(\.status),[.correct,.correct,.incorrect,.incorrect,.incorrect])
  XCTAssertEqual(feedback.score,0.4,accuracy:0.0001)
 }

 func testLiveRecognitionRevisionsReplaceThePreviousWordAssessment() {
  var reading=ReadAloudAttempt(target:"Small steps create steady progress.")
  reading.observe("small stops")
  XCTAssertEqual(reading.feedback.words[1].status,.incorrect)
  reading.observe("SMALL steps, create steady progress!")
  XCTAssertEqual(reading.feedback.words.map(\.status),Array(repeating:.correct,count:5))
  XCTAssertEqual(reading.progress,1,accuracy:0.0001)
  XCTAssertTrue(reading.finish())
  reading.observe("unrelated speech")
  XCTAssertEqual(reading.progress,1,accuracy:0.0001)
 }

 func testAHighPartialScoreDoesNotAutoFinishBeforeTheLastWords() {
  var reading=ReadAloudAttempt(target:"one two three four five")
  reading.observe("one two three four")
  XCTAssertEqual(reading.progress,0.8,accuracy:0.0001)
  XCTAssertFalse(reading.hasEnoughSpeech)
  reading.observe("one two three four five")
  XCTAssertTrue(reading.hasEnoughSpeech)
 }

 func testSilenceAndUnrelatedSpeechNeverReceiveCorrectWordFeedback() {
  let silent=RecognizedWordMatch.feedback(target:"one two three",recognized:" ... ",finished:false)
  XCTAssertEqual(silent.words.map(\.status),[.pending,.pending,.pending])
  XCTAssertEqual(silent.score,0,accuracy:0.0001)
  let wrong=RecognizedWordMatch.feedback(target:"one two three",recognized:"red green blue",finished:true)
  XCTAssertEqual(wrong.words.map(\.status),[.incorrect,.incorrect,.incorrect])
  XCTAssertEqual(wrong.score,0,accuracy:0.0001)
 }
}
