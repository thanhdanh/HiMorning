import XCTest
@testable import HiMorning
import HiMorningCore

final class ChallengePromptsTests:XCTestCase {
 func testShufflingKeepsTheCorrectAnswerMapped() {
  let source=ReadAndChoosePrompt(id:"mapping",sentence:"Choose the blue door.",choices:["Red door","Blue door","Green door"],correctChoiceIndex:1)
  let prompt=ChallengePrompts.readAndChoose(source)
  XCTAssertEqual(prompt.id,"mapping")
  XCTAssertEqual(prompt.choices.count,3)
  XCTAssertEqual(Set(prompt.choices),Set(source.choices))
  XCTAssertTrue(prompt.isCorrect(choiceIndex:prompt.choices.firstIndex(of:"Blue door")!))
  for (index,choice) in prompt.choices.enumerated() where choice != "Blue door" {XCTAssertFalse(prompt.isCorrect(choiceIndex:index))}
 }

 func testEveryShuffleKeepsTheAnswerAndTheText() {
  let source=ReadAndChoosePrompt(id:"loop",sentence:"Pick the second.",choices:["one","two","three"],correctChoiceIndex:1)
  for _ in 0..<50 {
   let prompt=ChallengePrompts.readAndChoose(source)
   XCTAssertEqual(prompt.text,"Pick the second.")
   XCTAssertEqual(prompt.choices[prompt.correctChoiceIndex],"two")
  }
 }
}
