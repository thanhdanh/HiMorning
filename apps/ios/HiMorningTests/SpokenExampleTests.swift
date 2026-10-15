import AVFoundation
import XCTest
@testable import HiMorning

@MainActor final class SpokenExampleTests:XCTestCase {
 func testUnavailableVoiceKeepsReadingAvailable() {
  let synthesizer=ExampleSynthesizer()
  let example=SpokenExample(synthesizer:synthesizer,voice:{nil})
  XCTAssertFalse(example.play("Small steps create steady progress."))
  XCTAssertFalse(example.isSpeaking)
  XCTAssertTrue(synthesizer.utterances.isEmpty)
 }

 func testExampleBlocksAnotherPlaybackUntilFinish() async throws {
  let synthesizer=ExampleSynthesizer()
  let example=SpokenExample(synthesizer:synthesizer)
  XCTAssertTrue(example.play("Small steps create steady progress."))
  XCTAssertTrue(example.isSpeaking)
  XCTAssertFalse(example.play("This morning is full of new energy."))
  let utterance=try XCTUnwrap(synthesizer.utterances.first)
  XCTAssertTrue(utterance.voice?.language.hasPrefix("en-") == true)
  XCTAssertEqual(utterance.rate,AVSpeechUtteranceDefaultSpeechRate*0.9,accuracy:0.001)
  XCTAssertFalse(synthesizer.usesApplicationAudioSession)
  synthesizer.delegate?.speechSynthesizer?(synthesizer,didFinish:utterance)
  await fulfillment(of:[XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in !example.isSpeaking},object:nil)],timeout:2)
  XCTAssertTrue(example.play("This morning is full of new energy."))
 }

 func testStopWaitsForCancellationAndIgnoresOldCompletion() async throws {
  let synthesizer=ExampleSynthesizer()
  let example=SpokenExample(synthesizer:synthesizer)
  XCTAssertTrue(example.play("Small steps create steady progress."))
  let old=try XCTUnwrap(synthesizer.utterances.first)
  example.stop()
  XCTAssertEqual(synthesizer.stops,1)
  XCTAssertTrue(example.isSpeaking,"Recording stays blocked until playback actually stops")
  synthesizer.delegate?.speechSynthesizer?(synthesizer,didCancel:old)
  await fulfillment(of:[XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in !example.isSpeaking},object:nil)],timeout:2)
  XCTAssertTrue(example.play("This morning is full of new energy."))
  synthesizer.delegate?.speechSynthesizer?(synthesizer,didFinish:old)
  await Task.yield()
  XCTAssertTrue(example.isSpeaking,"An old callback must not release the new example")
 }

 func testStopWithoutQueuedSpeechReleasesTheExample() {
  let synthesizer=ExampleSynthesizer()
  synthesizer.canStop=false
  let example=SpokenExample(synthesizer:synthesizer)
  XCTAssertTrue(example.play("Small steps create steady progress."))
  example.stop()
  XCTAssertFalse(example.isSpeaking)
 }

 func testExamplePrefersTheBestInstalledEnglishVoice() throws {
  let installed=AVSpeechSynthesisVoice.speechVoices().filter {$0.language.hasPrefix("en-")}
  let preferred=try XCTUnwrap(SpokenExample.preferredVoice())
  XCTAssertTrue(preferred.language.hasPrefix("en-"))
  for voice in installed {XCTAssertGreaterThanOrEqual(preferred.quality.rawValue,voice.quality.rawValue)}
  if installed.contains(where:{$0.quality == preferred.quality && $0.language == "en-US"}) {XCTAssertEqual(preferred.language,"en-US")}
 }
}

private final class ExampleSynthesizer:AVSpeechSynthesizer {
 var utterances:[AVSpeechUtterance]=[]
 var stops=0
 var canStop=true
 override func speak(_ utterance:AVSpeechUtterance) {utterances.append(utterance)}
 override func stopSpeaking(at boundary:AVSpeechBoundary)->Bool {stops+=1;return canStop}
}
