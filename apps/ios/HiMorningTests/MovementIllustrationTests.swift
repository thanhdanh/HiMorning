import XCTest
import SwiftUI
import HiMorningCore
@testable import HiMorning

final class MovementIllustrationTests:XCTestCase {
 private var selections:[ChallengeSelection] {
  [.pushUps(repetitions:10),.init(kind:.waveHand),.init(kind:.neckRotation),.init(kind:.jumpingJacks),.init(kind:.stretching),.guidedRhythm(variant:.standing),.guidedRhythm(variant:.seated)]
 }
 func testEveryMovementStaysInsideBothIconAndGuideArtboardsThroughTheLoop() {
  for selection in selections {
   for rect in [CGRect(x:0,y:0,width:32,height:30),CGRect(x:12,y:8,width:126,height:114)] {
    for phase in stride(from:0.0,through:1.0,by:0.025) {
     let path=MovementFigure(selection:selection,phase:phase).path(in:rect)
     XCTAssertFalse(path.isEmpty)
     XCTAssertTrue(rect.contains(path.boundingRect),"Clipped \(selection.kind) at phase \(phase)")
    }
   }
  }
 }
 func testMovementHasDistinctPosesAndLoopsWithoutAnEndpointJump() {
  let rect=CGRect(x:0,y:0,width:120,height:100)
  for selection in selections {
   let start=MovementFigure(selection:selection,phase:0).path(in:rect).cgPath
   let pose=MovementFigure(selection:selection,phase:0.25).path(in:rect).cgPath
   let end=MovementFigure(selection:selection,phase:1).path(in:rect).cgPath
   XCTAssertFalse(start == pose,"Static guide for \(selection.kind)")
   XCTAssertTrue(start == end,"Loop must return to its starting pose")
  }
  XCTAssertFalse(MovementFigure(selection:.guidedRhythm(variant:.standing),phase:0.25).path(in:rect).cgPath == MovementFigure(selection:.guidedRhythm(variant:.seated),phase:0.25).path(in:rect).cgPath)
 }
}
