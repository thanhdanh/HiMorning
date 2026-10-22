import Foundation
import HiMorningCore

struct ChallengePrompt: Equatable {
 let id:String
 let text:String
 let choices:[String]
 let correctChoiceIndex:Int
 func isCorrect(choiceIndex:Int)->Bool {choiceIndex == correctChoiceIndex}
}

enum ChallengePrompts {
 static func readAndChoose(_ prompt:ReadAndChoosePrompt)->ChallengePrompt {
  let order=prompt.choices.indices.shuffled()
  return ChallengePrompt(id:prompt.id,text:prompt.sentence,choices:order.map {prompt.choices[$0]},correctChoiceIndex:order.firstIndex(of:prompt.correctChoiceIndex)!)
 }
}
