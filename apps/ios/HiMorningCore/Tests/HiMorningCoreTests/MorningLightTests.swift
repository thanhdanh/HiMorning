import Foundation
#if !PORTABLE_TESTS
import XCTest
@testable import HiMorningCore
#endif

final class MorningLightTests: XCTestCase {
 func testDarkRoomStaysSeekingLight() {
  var evaluator = MorningLightEvaluator()
  XCTAssertEqual(evaluator.process(luminance: 0.25, timestamp: 1.0), .seekingLight)
  XCTAssertEqual(evaluator.process(luminance: 0.50, timestamp: 2.0), .seekingLight)
 }

 func testBriefFlashDoesNotComplete() {
  var evaluator = MorningLightEvaluator()
  XCTAssertEqual(evaluator.process(luminance: 0.72, timestamp: 10.0), .holding(progress: 0))
  XCTAssertEqual(evaluator.process(luminance: 0.75, timestamp: 11.0), .holding(progress: 0.5))
  XCTAssertEqual(evaluator.process(luminance: 0.30, timestamp: 11.5), .seekingLight)
  XCTAssertEqual(evaluator.process(luminance: 0.72, timestamp: 12.0), .holding(progress: 0))
 }

 func testHysteresisPreservesHoldAboveDropThreshold() {
  var evaluator = MorningLightEvaluator()
  _ = evaluator.process(luminance: 0.65, timestamp: 0.0)
  let mid = evaluator.process(luminance: 0.52, timestamp: 1.0)
  XCTAssertEqual(mid, .holding(progress: 0.5))
  XCTAssertEqual(evaluator.process(luminance: 0.55, timestamp: 2.0), .completed)
 }

 func testSustainedBrightWindowCompletes() {
  var evaluator = MorningLightEvaluator()
  XCTAssertEqual(evaluator.process(luminance: 0.60, timestamp: 5.0), .holding(progress: 0))
  XCTAssertEqual(evaluator.process(luminance: 0.65, timestamp: 6.0), .holding(progress: 0.5))
  XCTAssertEqual(evaluator.process(luminance: 0.70, timestamp: 7.0), .completed)
  XCTAssertEqual(evaluator.process(luminance: 0.10, timestamp: 8.0), .completed)
 }

 func testExposureBrightnessDistinguishesDarkBedroomFromSunlitWindow() {
  // Dim room: f/1.8, 1/15s, ISO 800 -> low EV100 (~2.6) -> 0.0
  let dark = MorningLightEvaluator.exposureBrightness(aperture: 1.8, exposureDuration: 1.0 / 15.0, iso: 800)
  XCTAssertTrue(dark < 0.25)

  // Bright window: f/1.8, 1/250s, ISO 100 -> high EV100 (~9.7) -> 1.0
  let bright = MorningLightEvaluator.exposureBrightness(aperture: 1.8, exposureDuration: 1.0 / 250.0, iso: 100)
  XCTAssertTrue(bright >= MorningLightEvaluator.defaultBrightThreshold)

  // Invalid sensor values safely fall back to 0.
  XCTAssertEqual(MorningLightEvaluator.exposureBrightness(aperture: 0, exposureDuration: 0.01, iso: 100), 0)
  XCTAssertEqual(MorningLightEvaluator.exposureBrightness(aperture: 1.8, exposureDuration: .nan, iso: 100), 0)
 }
}
