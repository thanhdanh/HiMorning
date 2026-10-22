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

public struct ReadAloudAttempt:Sendable {
 private let target:String
 private let language:String
 private let expectedWords:Int
 public private(set) var transcript=""
 public private(set) var ended=false
 public private(set) var completed=false

 public init(target:String,language:String="en") {self.target=target;self.language=language;expectedWords=RecognizedWordMatch.tokens(in:target,language:language).count}
 public var listeningDuration:TimeInterval {max(45,Double(expectedWords)*3+15)}
 public var feedback:RecognizedWordMatch.Feedback {RecognizedWordMatch.feedback(target:target,recognized:transcript,finished:ended,language:language)}
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

 public static func score(target:String,recognized:String,language:String="en") -> Double {
  feedback(target:target,recognized:recognized,finished:true,language:language).score
 }

 public static func passes(target:String,recognized:String,language:String="en") -> Bool {
  score(target:target,recognized:recognized,language:language)>=passingScore
 }

 public static func feedback(target:String,recognized:String,finished:Bool,language:String="en") -> Feedback {
  let expected=tokens(in:target,language:language),actual=tokens(in:recognized,language:language)
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

 public static func tokens(in text:String,language:String="en") -> [String] {
  let folded=language == "vi"
   ? text.folding(options:.caseInsensitive,locale:Locale(identifier:"vi_VN"))
   : text.folding(options:[.caseInsensitive,.diacriticInsensitive],locale:Locale(identifier:"en_US_POSIX"))
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
 private var candidatePose:GuidedRhythmPose?
 private var candidateSinceMs=0
 private var lostSinceMs:Int?
 private let holdMs=150
 private let lossGraceMs=600

 public init(variant:GuidedRhythmVariant,maxSequenceDurationMs:Int=8_000) {
  self.variant=variant
  self.maxSequenceDurationMs=max(500,maxSequenceDurationMs)
 }

 public mutating func interrupt() {
  step=0
  sequenceStartedAtMs=nil
  lastAcceptedPose=nil
  candidatePose=nil
  lostSinceMs=nil
 }

 /// Intermediate angles break a pose hold without discarding the completed sequence steps.
 public mutating func transition(timestampMs:Int) {
  guard timestampMs>=0,latestTimestampMs.map({timestampMs>$0}) ?? true else {interrupt();return}
  if let last=latestTimestampMs,timestampMs-last>lossGraceMs {interrupt()}
  latestTimestampMs=timestampMs;candidatePose=nil
  if let started=sequenceStartedAtMs,timestampMs-started>maxSequenceDurationMs {interrupt()}
 }

 @discardableResult public mutating func observe(_ pose:GuidedRhythmPose,timestampMs:Int,visible:Bool) -> Bool {
  guard timestampMs>=0 else {interrupt();return false}
  guard latestTimestampMs.map({timestampMs>$0}) ?? true else {interrupt();return false}
  if let last=latestTimestampMs,timestampMs-last>lossGraceMs {interrupt()}
  latestTimestampMs=timestampMs
  guard visible else {
   let since=lostSinceMs ?? timestampMs
   if timestampMs-since>lossGraceMs {interrupt()} else {lostSinceMs=since;candidatePose=nil}
   return false
  }
  if let since=lostSinceMs {
   lostSinceMs=nil
   if timestampMs-since>lossGraceMs {interrupt()}
  }
  if let started=sequenceStartedAtMs,timestampMs-started>maxSequenceDurationMs {interrupt();return false}

  if pose != candidatePose {candidatePose=pose;candidateSinceMs=timestampMs}
  guard timestampMs-candidateSinceMs>=holdMs else {return false}

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
