import XCTest
@testable import HiMorning
import HiMorningCore

final class ChallengePromptsTests:XCTestCase {
 func testShufflingKeepsTheCorrectAnswerMapped() {
  let source=ReadAndChoosePrompt(id:"mapping",sentence:"Choose the blue door.",choices:["Red door","Blue door","Green door"],correctChoiceIndex:1)
  let prompt=ChallengePrompts.readAndChoose([source])!
  XCTAssertEqual(prompt.id,"mapping")
  XCTAssertEqual(prompt.choices.count,3)
  XCTAssertEqual(Set(prompt.choices),Set(source.choices))
  XCTAssertTrue(prompt.isCorrect(choiceIndex:prompt.choices.firstIndex(of:"Blue door")!))
  for (index,choice) in prompt.choices.enumerated() where choice != "Blue door" {XCTAssertFalse(prompt.isCorrect(choiceIndex:index))}
 }

 func testPromptBanksVaryAndAvoidImmediateRepeats() {
  XCTAssertEqual(ChallengePrompts.reading.count,8)
  XCTAssertNotEqual(ChallengePrompts.readAndChoose(previousID:"morning-window")?.id,"morning-window")
  XCTAssertNotEqual(ChallengePrompts.riddle(previousID:"piano")?.id,"piano")
 }
}
