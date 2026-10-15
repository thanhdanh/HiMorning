import Foundation

public enum ChallengeKind: String, Codable, CaseIterable, Sendable {
 case none
 case pushUps = "push_ups"
 case readAndChoose = "read_and_choose"
 case guidedRhythm = "guided_rhythm"
 case readAloud = "read_aloud"
}

public enum GuidedRhythmVariant: String, Codable, CaseIterable, Sendable {
 case standing
 case seated
}

public struct ChallengeSelection: Codable, Equatable, Sendable {
 public let kind:ChallengeKind
 public let repetitions:Int?
 public let rhythmVariant:GuidedRhythmVariant?

 public init(kind:ChallengeKind,repetitions:Int?=nil,rhythmVariant:GuidedRhythmVariant?=nil) {
  self.kind=kind
  self.repetitions=kind == .pushUps ? min(5,max(1,repetitions ?? 3)) : nil
  self.rhythmVariant=kind == .guidedRhythm ? rhythmVariant ?? .standing : nil
 }

 public static let none=ChallengeSelection(kind:.none)
 public static func pushUps(repetitions:Int) -> ChallengeSelection {ChallengeSelection(kind:.pushUps,repetitions:repetitions)}
 public static let readAndChoose=ChallengeSelection(kind:.readAndChoose)
 public static func guidedRhythm(variant:GuidedRhythmVariant) -> ChallengeSelection {ChallengeSelection(kind:.guidedRhythm,rhythmVariant:variant)}
 public static let readAloud=ChallengeSelection(kind:.readAloud)

 public static func legacyDefault(for mode:WakeMode) -> ChallengeSelection {
  switch mode {
  case .gentle:return .none
  case .balanced:return .pushUps(repetitions:3)
  case .focused:return .pushUps(repetitions:5)
  }
 }

 private enum CodingKeys:String,CodingKey {case kind,repetitions,rhythmVariant}
 public init(from decoder:Decoder) throws {
  let values=try decoder.container(keyedBy:CodingKeys.self)
  self.init(
   kind:try values.decode(ChallengeKind.self,forKey:.kind),
   repetitions:try values.decodeIfPresent(Int.self,forKey:.repetitions),
   rhythmVariant:try values.decodeIfPresent(GuidedRhythmVariant.self,forKey:.rhythmVariant)
  )
 }
}

public struct ReadAndChoosePrompt: Codable, Equatable, Identifiable, Sendable {
 public let id:String
 public let sentence:String
 public let choices:[String]
 public let correctChoiceIndex:Int
 public init(id:String,sentence:String,choices:[String],correctChoiceIndex:Int) {
  self.id=id;self.sentence=sentence;self.choices=choices;self.correctChoiceIndex=correctChoiceIndex
 }
 public func isCorrect(choiceIndex:Int) -> Bool {choiceIndex == correctChoiceIndex}
}

public struct ReadAloudPrompt: Codable, Equatable, Identifiable, Sendable {
 public let id:String
 public let text:String
 public init(id:String,text:String) {self.id=id;self.text=text}
}

public enum EnglishChallengeContent {
 public static let readAndChoose:[ReadAndChoosePrompt]=[
  ReadAndChoosePrompt(id:"morning-window",sentence:"Please open the window and welcome the morning.",choices:["Open the window to greet the morning.","Close the door and go to sleep.","Make dinner before going outside."],correctChoiceIndex:0),
  ReadAndChoosePrompt(id:"fresh-start",sentence:"Today is a fresh start.",choices:["Yesterday must happen again.","Today is a new beginning.","The day has already ended."],correctChoiceIndex:1),
  ReadAndChoosePrompt(id:"small-step",sentence:"A small step can begin a great day.",choices:["You must do everything at once.","Small actions never matter.","One little action can start a good day."],correctChoiceIndex:2)
 ]
 public static let readAloud:[ReadAloudPrompt]=[
  ReadAloudPrompt(id:"ready-for-day",text:"I am ready for a bright new day."),
  ReadAloudPrompt(id:"steady-progress",text:"Small steps create steady progress."),
  ReadAloudPrompt(id:"morning-energy",text:"This morning is full of new energy.")
 ]
}

/// Deterministic similarity of recognized word tokens. This does not grade accent quality.
public enum RecognizedWordMatch {
 public static let passingScore=0.8

 public static func score(target:String,recognized:String) -> Double {
  let expected=tokens(in:target)
  let actual=tokens(in:recognized)
  guard !expected.isEmpty else {return 0}
  let denominator=max(expected.count,actual.count)
  guard denominator>0 else {return 0}
  return max(0,1-Double(editDistance(expected,actual))/Double(denominator))
 }

 public static func passes(target:String,recognized:String) -> Bool {
  score(target:target,recognized:recognized)>=passingScore
 }

 public static func tokens(in text:String) -> [String] {
  let folded=text.folding(options:[.caseInsensitive,.diacriticInsensitive],locale:Locale(identifier:"en_US_POSIX"))
  var normalized=""
  normalized.reserveCapacity(folded.count)
  for character in folded {
   if character.isLetter || character.isNumber {normalized.append(character)}
   else {normalized.append(" ")}
  }
  return normalized.split(whereSeparator:\.isWhitespace).map(String.init)
 }

 private static func editDistance(_ left:[String],_ right:[String]) -> Int {
  guard !left.isEmpty else {return right.count}
  guard !right.isEmpty else {return left.count}
  var previous=Array(0...right.count)
  for (leftIndex,leftToken) in left.enumerated() {
   var current=Array(repeating:0,count:right.count+1)
   current[0]=leftIndex+1
   for (rightIndex,rightToken) in right.enumerated() {
    current[rightIndex+1]=min(
     current[rightIndex]+1,
     previous[rightIndex+1]+1,
     previous[rightIndex]+(leftToken == rightToken ? 0 : 1)
    )
   }
   previous=current
  }
  return previous[right.count]
 }
}

public enum GuidedRhythmPose: String, Codable, Sendable {
 case standing
 case lowered
 case seated
 case armsUp
 case armsDown
}

/// Local-only motion sequence. It accepts pose labels and timestamps, never image bytes.
public struct GuidedRhythmSession: Sendable {
 public let variant:GuidedRhythmVariant
 public private(set) var completedCycles=0
 private let maxSequenceDurationMs:Int
 private var step=0
 private var sequenceStartedAtMs:Int?
 private var latestTimestampMs:Int?
 private var lastAcceptedPose:GuidedRhythmPose?

 public init(variant:GuidedRhythmVariant,maxSequenceDurationMs:Int=8_000) {
  self.variant=variant
  self.maxSequenceDurationMs=max(500,maxSequenceDurationMs)
 }

 public mutating func interrupt() {
  step=0
  sequenceStartedAtMs=nil
  lastAcceptedPose=nil
 }

 @discardableResult public mutating func observe(_ pose:GuidedRhythmPose,timestampMs:Int,visible:Bool) -> Bool {
  guard timestampMs>=0 else {interrupt();return false}
  guard latestTimestampMs.map({timestampMs>$0}) ?? true else {interrupt();return false}
  latestTimestampMs=timestampMs
  guard visible else {interrupt();return false}
  if let started=sequenceStartedAtMs,timestampMs-started>maxSequenceDurationMs {interrupt();return false}

  let sequence:[GuidedRhythmPose]=variant == .standing ? [.standing,.lowered,.standing] : [.armsDown,.armsUp,.armsDown]
  if pose == lastAcceptedPose {return false}
  guard pose == sequence[step] else {
   interrupt()
   return false
  }
  if step == 0 {sequenceStartedAtMs=timestampMs}
  lastAcceptedPose=pose
  step+=1
  guard step == sequence.count else {return false}
  completedCycles+=1
  interrupt()
  return true
 }
}
