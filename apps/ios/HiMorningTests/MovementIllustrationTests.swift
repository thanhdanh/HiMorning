import XCTest
import AVFoundation
import UIKit
import HiMorningCore
@testable import HiMorning

final class MovementIllustrationTests:XCTestCase {
 private var selections:[ChallengeSelection] {
  [.pushUps(repetitions:10),.init(kind:.waveHand),.init(kind:.neckRotation),.init(kind:.jumpingJacks),.init(kind:.stretching),.guidedRhythm(variant:.standing),.guidedRhythm(variant:.seated)]
 }

 func testEveryMovementHasBundledStudioVideoAndPoster() {
  var keys=Set<String>()
  for selection in selections {
   guard let asset=StudioMotionAsset.forSelection(selection) else {
    XCTFail("Missing StudioMotionAsset for \(selection)")
    continue
   }
   XCTAssertTrue(keys.insert(asset.key).inserted,"Duplicate studio key \(asset.key)")
   XCTAssertNotEqual(asset.phase1CueKey,asset.phase2CueKey,"Phase cues must differ for \(asset.key)")
   XCTAssertNotNil(asset.videoURL,"Missing bundled MP4 motion_\(asset.key).mp4")
   XCTAssertNotNil(asset.posterImage,"Missing bundled poster motion_\(asset.key)_poster.jpg")
   if let poster=asset.posterImage {
    let ratio=poster.size.width / max(1,poster.size.height)
    XCTAssertEqual(ratio,16.0/9.0,accuracy:0.05,"Poster for \(asset.key) must be 16:9")
   }
  }
 }

 func testStandingAndSeatedGuidedRhythmUseDistinctStudioAssets() {
  let standing=StudioMotionAsset.forSelection(.guidedRhythm(variant:.standing))
  let seated=StudioMotionAsset.forSelection(.guidedRhythm(variant:.seated))
  XCTAssertNotNil(standing)
  XCTAssertNotNil(seated)
  XCTAssertNotEqual(standing?.key,seated?.key)
 }
}
