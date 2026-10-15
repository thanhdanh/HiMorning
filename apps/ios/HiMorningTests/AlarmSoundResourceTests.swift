import AVFoundation
import HiMorningCore
import XCTest
@testable import HiMorning

final class AlarmSoundResourceTests:XCTestCase {
 func testSoundGroupsContainEveryChoiceExactlyOnce() {
  let grouped=AlarmSound.groups.flatMap(\.sounds)
  XCTAssertEqual(grouped,AlarmSound.allCases)
 }
 func testEveryCustomSoundDecodesFromTheSameBundleUsedByAlarmKit() throws {
  XCTAssertEqual(AlarmSound.allCases.count,15)
  for sound in AlarmSound.allCases where sound != .system {
   let url=try XCTUnwrap(Bundle.main.url(forResource:sound.rawValue,withExtension:"wav"),sound.rawValue)
   let audio=try AVAudioFile(forReading:url)
   XCTAssertEqual(audio.fileFormat.streamDescription.pointee.mFormatID,kAudioFormatLinearPCM,sound.rawValue)
   XCTAssertEqual(audio.fileFormat.channelCount,1,sound.rawValue)
   XCTAssertEqual(audio.fileFormat.sampleRate,sound == .sunrise || sound == .softChime ? 22_050 : 44_100,sound.rawValue)
   XCTAssertGreaterThan(audio.length,0,sound.rawValue)
   let buffer=try XCTUnwrap(AVAudioPCMBuffer(pcmFormat:audio.processingFormat,frameCapacity:AVAudioFrameCount(audio.length)))
   try audio.read(into:buffer)
   XCTAssertEqual(AVAudioFramePosition(buffer.frameLength),audio.length,sound.rawValue)
   let player=try AVAudioPlayer(contentsOf:url)
   XCTAssertGreaterThan(player.duration,0,sound.rawValue)
   XCTAssertLessThanOrEqual(player.duration,12,sound.rawValue)
  }
 }
 func testOriginalSoundsHaveHeadroomAndSilentEdges() throws {
  for sound in [AlarmSound.sunrise,.softChime] {
   let url=try XCTUnwrap(Bundle.main.url(forResource:sound.rawValue,withExtension:"wav"))
   let audio=try AVAudioFile(forReading:url)
   let buffer=try XCTUnwrap(AVAudioPCMBuffer(pcmFormat:audio.processingFormat,frameCapacity:AVAudioFrameCount(audio.length)))
   try audio.read(into:buffer)
   let channel=try XCTUnwrap(buffer.floatChannelData?[0])
   let samples=Array(UnsafeBufferPointer(start:channel,count:Int(buffer.frameLength)))
   let peak=samples.map(abs).max() ?? 0
   XCTAssertGreaterThanOrEqual(Double(audio.length)/audio.fileFormat.sampleRate,7,sound.rawValue)
   XCTAssertGreaterThan(peak,0.15,sound.rawValue)
   XCTAssertLessThanOrEqual(peak,0.501,sound.rawValue)
   XCTAssertTrue(samples.allSatisfy(\.isFinite),sound.rawValue)
   XCTAssertLessThan(samples.prefix(220).map(abs).max() ?? 0,0.002,sound.rawValue)
   XCTAssertLessThan(samples.suffix(220).map(abs).max() ?? 0,0.002,sound.rawValue)
  }
 }
}
