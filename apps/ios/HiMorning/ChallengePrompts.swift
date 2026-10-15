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
 static let reading:[ReadAndChoosePrompt]=EnglishChallengeContent.readAndChoose + [
  .init(id:"tea",sentence:"A warm cup of tea can make a quiet morning feel special.",choices:["Tea can make a calm morning feel pleasant.","Tea makes every morning noisy.","A cup of tea is always cold."],correctChoiceIndex:0),
  .init(id:"walk",sentence:"Mina takes a short walk before starting work.",choices:["Mina walks after work is finished.","Mina takes a brief walk before working.","Mina stays home all day."],correctChoiceIndex:1),
  .init(id:"umbrella",sentence:"Bring an umbrella because rain is expected this afternoon.",choices:["It will be sunny all afternoon.","The umbrella is broken.","Rain may come later today."],correctChoiceIndex:2),
  .init(id:"plant",sentence:"The plant grew new leaves after it received water and sunlight.",choices:["Water and sunlight helped the plant grow.","The plant lost all its leaves.","The plant grew without light or water."],correctChoiceIndex:0),
  .init(id:"listening",sentence:"Leo listened carefully before sharing his idea.",choices:["Leo spoke before anyone else.","Leo paid attention before speaking.","Leo forgot to share his idea."],correctChoiceIndex:1)
 ]
 static func readAndChoose(_ prompts:[ReadAndChoosePrompt]=ChallengePrompts.reading,previousID:String?=nil)->ChallengePrompt? {
  let available=prompts.filter {$0.id != previousID}
  guard let prompt=(available.isEmpty ? prompts : available).randomElement() else {return nil}
  let order=prompt.choices.indices.shuffled()
  return ChallengePrompt(id:prompt.id,text:prompt.sentence,choices:order.map {prompt.choices[$0]},correctChoiceIndex:order.firstIndex(of:prompt.correctChoiceIndex)!)
 }

 static let riddles:[ReadAndChoosePrompt]=[
  .init(id:"piano",sentence:"What has keys but cannot open a door?",choices:["A piano","A window","A shoe"],correctChoiceIndex:0),
  .init(id:"clock-riddle",sentence:"I have hands but cannot clap, and I show you the time. What am I?",choices:["A clock","A bird","A glove"],correctChoiceIndex:0),
  .init(id:"shadow",sentence:"I follow you in sunlight but disappear in darkness. What am I?",choices:["A shadow","A cloud","A sound"],correctChoiceIndex:0)
 ]
 static func riddle(previousID:String?=nil)->ChallengePrompt? {
  readAndChoose(riddles,previousID:previousID)
 }
}
