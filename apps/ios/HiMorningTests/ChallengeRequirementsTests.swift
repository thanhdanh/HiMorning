import XCTest
import HiMorningCore
@testable import HiMorning

final class ChallengeRequirementsTests:XCTestCase {
 func testEveryChallengeHasAConciseChecklistWithItsActualCompletionTarget() {
  let selections:[ChallengeSelection]=[
   .none,.pushUps(repetitions:7),.readAndChoose,.init(kind:.riddle),.readAloud,
   .init(kind:.waveHand),.init(kind:.neckRotation),.init(kind:.jumpingJacks),
   .init(kind:.stretching),.guidedRhythm(variant:.standing),.guidedRhythm(variant:.seated)
  ]
  for selection in selections {
   let requirements=ChallengeRequirements.forSelection(selection)
   XCTAssertFalse(requirements.isEmpty,"Missing checklist for \(selection.kind)")
   XCTAssertLessThanOrEqual(requirements.count,2,"Checklist should stay concise for \(selection.kind)")
   XCTAssertTrue(requirements.allSatisfy { !$0.localizedCaseInsensitiveContains("video") && !$0.localizedCaseInsensitiveContains("upload") && !$0.localizedCaseInsensitiveContains("saved") },"Checklist should describe actions, not privacy claims")
  }
  XCTAssertTrue(ChallengeRequirements.forSelection(.pushUps(repetitions:7)).joined().contains("7"))
  XCTAssertTrue(ChallengeRequirements.forSelection(.init(kind:.waveHand)).joined().contains("3"))
  XCTAssertTrue(ChallengeRequirements.forSelection(.init(kind:.neckRotation)).joined().contains("3"))
  XCTAssertTrue(ChallengeRequirements.forSelection(.init(kind:.jumpingJacks)).joined().contains("10"))
  XCTAssertTrue(ChallengeRequirements.forSelection(.init(kind:.stretching)).joined().contains("3"))
  XCTAssertTrue(ChallengeRequirements.forSelection(.guidedRhythm(variant:.standing)).joined().contains("3"))
  XCTAssertTrue(ChallengeRequirements.forSelection(.guidedRhythm(variant:.seated)).joined().contains("3"))
 }
}
