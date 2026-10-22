import Foundation
import HiMorningCore

struct ChallengePrompt: Equatable {
 let id:String
 let text:String
 let choices:[String]
 let correctChoiceIndex:Int
 var theme:String?=nil
 var explanation:String?=nil
 func isCorrect(choiceIndex:Int)->Bool {choiceIndex == correctChoiceIndex}
}

enum ChallengePrompts {
 static func fromItem(_ item:ChallengeContentItem)->ChallengePrompt? {
  guard let source=item.readAndChoosePrompt else {return nil}
  var prompt=readAndChoose(source)
  prompt.theme=item.theme;prompt.explanation=item.explanation
  return prompt
 }

 static func themeTitle(_ theme:String)->String {
  switch theme {
  case "workAndStudy":return appText("Work & study")
  case "everydayLife":return appText("Everyday discoveries")
  case "peopleAndPlans":return appText("People & plans")
  case "creativeBreaks":return appText("Creative breaks")
  case "cityAndTravel":return appText("Out & about")
  default:return appText("A little curiosity")
  }
 }

 static func readAndChoose(_ prompt:ReadAndChoosePrompt)->ChallengePrompt {
  let order=prompt.choices.indices.shuffled()
  return ChallengePrompt(id:prompt.id,text:prompt.sentence,choices:order.map {prompt.choices[$0]},correctChoiceIndex:order.firstIndex(of:prompt.correctChoiceIndex)!)
 }
}
