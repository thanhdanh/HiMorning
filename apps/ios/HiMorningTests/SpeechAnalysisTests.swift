import XCTest
import AVFoundation
import CoreMedia
#if canImport(HiMorning)
@testable import HiMorning
#endif

final class SpeechAnalysisTests:XCTestCase {
 func testPartialSpeechReplacesTheVolatileSegment() {
  var transcript=SpeechTranscript()
  transcript.update(text:"Small",range:range(0,1),isFinal:false)
  transcript.update(text:"Small steps",range:range(0,2),isFinal:false)
  XCTAssertEqual(transcript.text,"Small steps")
 }

 func testFinalSpeechAccumulatesWithoutEndingTheAttempt() {
  var transcript=SpeechTranscript()
  transcript.update(text:"Small steps",range:range(0,2),isFinal:false)
  transcript.update(text:"Small steps",range:range(0,2),isFinal:true)
  transcript.update(text:"create",range:range(2,1),isFinal:false)
  transcript.update(text:"create steady progress.",range:range(2,3),isFinal:true)
  XCTAssertEqual(transcript.text,"Small steps create steady progress.")
 }

 func testDuplicateFinalAndStalePartialDoNotRepeatWords() {
  var transcript=SpeechTranscript()
  transcript.update(text:"Small steps",range:range(0,2),isFinal:true)
  transcript.update(text:"Small steps",range:range(0,2),isFinal:true)
  transcript.update(text:"Small",range:range(0,1),isFinal:false)
  XCTAssertEqual(transcript.text,"Small steps")
 }

 func testEmptyFinalClearsThePreviousPartial() {
  var transcript=SpeechTranscript()
  transcript.update(text:"noise",range:range(0,1),isFinal:false)
  transcript.update(text:" \n",range:range(0,1),isFinal:true)
  XCTAssertEqual(transcript.text,"")
 }

 func testAudioConversionChangesRateAndDoesNotReplayTheInput() throws {
  let source=try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate:48_000,channels:1))
  let destination=try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate:16_000,channels:1))
  let converter=try SpeechBufferConverter(inputFormat:source,outputFormat:destination)
  for _ in 0..<3 {
   let input=try XCTUnwrap(AVAudioPCMBuffer(pcmFormat:source,frameCapacity:4_800))
   input.frameLength=4_800
   for index in 0..<4_800 {input.floatChannelData![0][index]=0.25}
   let output=try XCTUnwrap(converter.convert(input))
   XCTAssertEqual(output.format,destination)
   XCTAssertEqual(output.frameLength,1_600)
   XCTAssertEqual(output.floatChannelData![0][800],0.25,accuracy:0.001)
  }
 }

 func testAudioConversionCopiesMatchingFormatAndRejectsRouteChanges() throws {
  let format=try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate:16_000,channels:1))
  let converter=try SpeechBufferConverter(inputFormat:format,outputFormat:format)
  let input=try XCTUnwrap(AVAudioPCMBuffer(pcmFormat:format,frameCapacity:32))
  input.frameLength=32
  for index in 0..<32 {input.floatChannelData![0][index]=0.5}
  let output=try XCTUnwrap(converter.convert(input))
  input.floatChannelData![0][0]=0
  XCTAssertEqual(output.frameLength,32)
  XCTAssertEqual(output.floatChannelData![0][0],0.5)
  let changed=try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate:44_100,channels:1))
  let changedInput=try XCTUnwrap(AVAudioPCMBuffer(pcmFormat:changed,frameCapacity:32))
  changedInput.frameLength=32
  XCTAssertThrowsError(try converter.convert(changedInput))
 }

 func testMicrophoneSizedBuffersProduceSignedIntegerAnalyzerAudio() throws {
  let source=try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate:48_000,channels:1))
  let destination=try XCTUnwrap(AVAudioFormat(commonFormat:.pcmFormatInt16,sampleRate:16_000,channels:1,interleaved:false))
  let converter=try SpeechBufferConverter(inputFormat:source,outputFormat:destination)
  var frames:AVAudioFrameCount=0
  for _ in 0..<30 {
   let input=try XCTUnwrap(AVAudioPCMBuffer(pcmFormat:source,frameCapacity:1_024))
   input.frameLength=1_024
   for index in 0..<1_024 {input.floatChannelData![0][index]=0.25}
   let output=try XCTUnwrap(converter.convert(input))
   frames+=output.frameLength
   XCTAssertEqual(output.format,destination)
   XCTAssertEqual(Int(output.int16ChannelData![0][Int(output.frameLength)/2]),8_192,accuracy:2)
  }
  XCTAssertEqual(Double(frames),10_240,accuracy:2)
 }

 func testEmptyAudioBufferProducesNoAnalyzerInput() throws {
  let format=try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate:16_000,channels:1))
  let converter=try SpeechBufferConverter(inputFormat:format,outputFormat:format)
  let input=try XCTUnwrap(AVAudioPCMBuffer(pcmFormat:format,frameCapacity:32))
  XCTAssertNil(try converter.convert(input))
 }

 private func range(_ start:Int64,_ duration:Int64) -> CMTimeRange {
  CMTimeRange(start:CMTime(value:start,timescale:1),duration:CMTime(value:duration,timescale:1))
 }
}

#if canImport(HiMorning)
final class SpeechCaptureCancellationTests:XCTestCase {
 @MainActor func testFinishCannotCompleteAnUnstartedOrStoppedCapture() async {
  let capture=SpeechChallengeCapture(target:"The quiet morning brings a chance to begin again today.") {_ in
   XCTFail("Finishing without a live microphone must not publish or complete")
  }
  capture.finishReading()
  capture.stop()
  capture.finishReading()
  await capture.start()
  await capture.stopAndWait()
 }

 @MainActor func testStoppingDuringPreparationNeverStartsTheMicrophoneOrPublishesAgain() async {
  let probe=SpeechCaptureProbe()
  let capture=SpeechChallengeCapture(target:"Small steps create steady progress.") {update in
   MainActor.assumeIsolated {
    probe.updates.append(update)
    probe.capture?.stop()
   }
  }
  probe.capture=capture
  await capture.start()
  await capture.stopAndWait()
  await capture.start()
  XCTAssertEqual(probe.updates.count,1)
  XCTAssertFalse(probe.updates[0].completed)
  XCTAssertFalse(probe.updates[0].ended)
  probe.capture=nil
 }

 @MainActor func testCancelledStartupDoesNotRequestPermissionOrPublish() async {
  let capture=SpeechChallengeCapture(target:"Small steps create steady progress.") {_ in XCTFail("Cancelled capture must not publish")}
  let startup=Task {await capture.start()}
  startup.cancel()
  await startup.value
  await capture.stopAndWait()
 }
}

@MainActor private final class SpeechCaptureProbe {
 var capture:SpeechChallengeCapture?
 var updates:[SpeechUpdate]=[]
}
#endif
