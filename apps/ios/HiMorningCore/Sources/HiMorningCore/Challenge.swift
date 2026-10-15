import Foundation

public enum ChallengeKind: String, Codable, CaseIterable, Sendable {
 case none
 case pushUps = "push_ups"
 case readAndChoose = "read_and_choose"
 case guidedRhythm = "guided_rhythm"
 case readAloud = "read_aloud"
 case waveHand = "wave_hand"
 case neckRotation = "neck_rotation"
 case riddle
 case jumpingJacks = "jumping_jacks"
 case stretching

 public static func available(in mode:WakeMode)->[ChallengeKind] {
  switch mode {
  case .gentle:[.none,.waveHand,.neckRotation]
  case .balanced:[.readAloud,.readAndChoose,.riddle]
  case .focused:[.pushUps,.jumpingJacks,.stretching]
  }
 }
 public var preferredMode:WakeMode {
  switch self {
  case .none,.waveHand,.neckRotation,.guidedRhythm:return .gentle
  case .readAloud,.readAndChoose,.riddle:return .balanced
  case .pushUps,.jumpingJacks,.stretching:return .focused
  }
 }
 public var usesLocalMovement:Bool {localMovementTarget != nil}
 public var localMovementTarget:Int? {
  switch self {
  case .waveHand,.neckRotation,.stretching:return 3
  case .jumpingJacks:return 10
  default:return nil
  }
 }
}

public enum GuidedRhythmVariant: String, Codable, CaseIterable, Sendable {
 case standing
 case seated
}

public struct ChallengeSelection: Codable, Equatable, Sendable {
 public static let maximumPushUps=50
 public let kind:ChallengeKind
 public let repetitions:Int?
 public let rhythmVariant:GuidedRhythmVariant?

 public init(kind:ChallengeKind,repetitions:Int?=nil,rhythmVariant:GuidedRhythmVariant?=nil) {
  self.kind=kind
  self.repetitions=kind == .pushUps ? min(Self.maximumPushUps,max(1,repetitions ?? 5)) : nil
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
  case .balanced:return .readAndChoose
  case .focused:return .pushUps(repetitions:10)
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
  ReadAloudPrompt(id:"ready-for-day",text:"Before the world asks for my attention, I will take a quiet breath and choose one meaningful thing to begin."),
  ReadAloudPrompt(id:"steady-progress",text:"Progress rarely arrives all at once; it grows when we return with patience, curiosity, and the courage to try again."),
  ReadAloudPrompt(id:"morning-energy",text:"Beyond the familiar path, a small discovery may be waiting, so today I will leave a little room for wonder."),
  ReadAloudPrompt(id:"quiet-attention",text:"Before opening another app, I will decide what deserves my attention and give that task a few quiet minutes."),
  ReadAloudPrompt(id:"corner-bakery",text:"At the corner bakery, warm bread and friendly conversation remind me that ordinary routines can hold small moments of joy."),
  ReadAloudPrompt(id:"unfamiliar-street",text:"Curiosity turns an unfamiliar street into a possibility, especially when I slow down enough to notice the details around me."),
  ReadAloudPrompt(id:"room-for-surprises",text:"A clear plan leaves room for surprises; I can prepare carefully while staying open to a better idea along the way."),
  ReadAloudPrompt(id:"smaller-pieces",text:"When a difficult task feels overwhelming, I will break it into smaller pieces and begin with the part I understand."),
  ReadAloudPrompt(id:"generous-listening",text:"Listening closely is a quiet kind of generosity, because another person may need understanding before they need advice or an answer."),
  ReadAloudPrompt(id:"gentle-beginning",text:"After a restless night, I can treat myself with patience and choose a gentle beginning instead of demanding a perfect morning."),
  ReadAloudPrompt(id:"beyond-the-clouds",text:"Somewhere beyond the clouds, the sun is still rising, and a cloudy sky can offer its own kind of beautiful light."),
  ReadAloudPrompt(id:"learning-with-patience",text:"Learning a new skill means being willing to make awkward attempts, ask useful questions, and return tomorrow with a little more understanding."),
  ReadAloudPrompt(id:"short-walk",text:"On a crowded day, a short walk can create enough space to breathe, notice the weather, and return with a clearer mind."),
  ReadAloudPrompt(id:"bridge-to-action",text:"The strongest bridge between an idea and a result is often a modest action repeated with care, even when progress feels slow."),
  ReadAloudPrompt(id:"while-the-kettle-warms",text:"While the kettle warms, I can stretch my shoulders, drink some water, and let the day begin without rushing into every notification."),
  ReadAloudPrompt(id:"different-approach",text:"An unexpected problem may invite a different approach; I can pause, gather the facts, and choose the next step with a steady mind."),
  ReadAloudPrompt(id:"books-and-conversation",text:"Books can carry us across oceans and centuries, but a good conversation can also reveal a world we have never considered before."),
  ReadAloudPrompt(id:"honest-step",text:"Instead of measuring this morning against the achievements of others, I will notice what matters to me and take one honest step forward."),
  ReadAloudPrompt(id:"patient-growth",text:"A seed grows without announcing its progress, reminding me that patient work can create meaningful change long before the results become visible."),
  ReadAloudPrompt(id:"adjust-the-route",text:"If my plans change, I can adjust the route without abandoning the destination, and I may discover something useful along the way."),
  ReadAloudPrompt(id:"first-few-minutes",text:"The first few minutes of the day do not need to solve everything; they can simply help me arrive with attention and purpose."),
  ReadAloudPrompt(id:"breakfast-promise",text:"Making time for breakfast is a small promise to myself that my energy, comfort, and health deserve a place in a busy schedule."),
  ReadAloudPrompt(id:"quiet-ripple",text:"Across a quiet lake, even a small ripple travels far, just as a thoughtful word can influence a day in ways we cannot see."),
  ReadAloudPrompt(id:"thoughtful-question",text:"Today I will ask one thoughtful question, try one unfamiliar thing, and leave enough space to appreciate what happens between my plans.")
 ]
}

public struct ReadAloudAttempt:Sendable {
 private let target:String
 private let expectedWords:Int
 public private(set) var transcript=""
 public private(set) var ended=false
 public private(set) var completed=false

 public init(target:String) {self.target=target;expectedWords=RecognizedWordMatch.tokens(in:target).count}
 public var listeningDuration:TimeInterval {max(45,Double(expectedWords)*3+15)}
 public var feedback:RecognizedWordMatch.Feedback {RecognizedWordMatch.feedback(target:target,recognized:transcript,finished:ended)}
 public var progress:Double {feedback.score}
 public var hasEnoughSpeech:Bool {progress>=RecognizedWordMatch.passingScore && !feedback.words.contains(where:{$0.status == .pending})}

 public mutating func observe(_ text:String) {
  guard !ended else {return}
  transcript=text
 }
 @discardableResult public mutating func finish()->Bool {
  guard !ended else {return completed}
  completed=progress>=RecognizedWordMatch.passingScore;ended=true
  return completed
 }
 public mutating func stop() {ended=true;completed=false}
}

/// Deterministic similarity of recognized word tokens. This does not grade accent quality.
public enum RecognizedWordMatch {
 public static let passingScore=0.8
 public enum WordStatus:Equatable,Sendable {case correct,incorrect,pending}
 public struct Word:Equatable,Sendable {
  public let text:String
  public let status:WordStatus
 }
 public struct Feedback:Equatable,Sendable {
  public let words:[Word]
  public let extraWords:[String]
  public let score:Double
 }

 public static func score(target:String,recognized:String) -> Double {
  feedback(target:target,recognized:recognized,finished:true).score
 }

 public static func passes(target:String,recognized:String) -> Bool {
  score(target:target,recognized:recognized)>=passingScore
 }

 public static func feedback(target:String,recognized:String,finished:Bool) -> Feedback {
  let expected=tokens(in:target),actual=tokens(in:recognized)
  guard !expected.isEmpty else {return Feedback(words:[],extraWords:actual,score:0)}
  var distance=Array(repeating:Array(repeating:0,count:actual.count+1),count:expected.count+1)
  for index in 0...expected.count {distance[index][0]=index}
  for index in 0...actual.count {distance[0][index]=index}
  for (i,word) in expected.enumerated() {
   for (j,heard) in actual.enumerated() {
    distance[i+1][j+1]=min(distance[i][j+1]+1,distance[i+1][j]+1,distance[i][j]+(word == heard ? 0:1))
   }
  }
  var words=expected.map {Word(text:$0,status:.pending)},extras:[String]=[]
  var i=expected.count,j=actual.count,hasLaterSpeech=false
  while i>0 || j>0 {
   if i>0,j>0,expected[i-1] == actual[j-1],distance[i][j] == distance[i-1][j-1] {
    words[i-1]=Word(text:expected[i-1],status:.correct)
    hasLaterSpeech=true;i-=1;j-=1
   } else if i>0,distance[i][j] == distance[i-1][j]+1 {
    // Prefer an unread suffix over shifting a misread word to the end of the sentence.
    words[i-1]=Word(text:expected[i-1],status:finished || hasLaterSpeech ? .incorrect:.pending)
    i-=1
   } else if i>0,j>0,distance[i][j] == distance[i-1][j-1]+1 {
    words[i-1]=Word(text:expected[i-1],status:.incorrect)
    hasLaterSpeech=true;i-=1;j-=1
   } else {
    extras.append(actual[j-1]);j-=1
   }
  }
  let score=max(0,1-Double(distance[expected.count][actual.count])/Double(max(expected.count,actual.count)))
  return Feedback(words:words,extraWords:extras.reversed(),score:score)
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
