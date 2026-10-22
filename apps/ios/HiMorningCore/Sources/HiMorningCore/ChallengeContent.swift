import Foundation

public enum ContentKind: String, Codable, Sendable {case readAloud,readAndChoose,riddle}

public struct ChallengeContentItem: Codable, Equatable, Identifiable, Sendable {
 public var id:String
 public var kind:ContentKind
 public var language:String
 public var text:String
 public var choices:[String]?
 public var answerIndex:Int?
 public var source:String
 public var license:String
 public var attribution:String?
 public var theme:String?
 public var explanation:String?

 public init(id:String,kind:ContentKind,language:String,text:String,choices:[String]?,answerIndex:Int?,source:String,license:String,attribution:String?,theme:String?=nil,explanation:String?=nil) {
  self.id=id;self.kind=kind;self.language=language;self.text=text;self.choices=choices;self.answerIndex=answerIndex
  self.source=source;self.license=license;self.attribution=attribution;self.theme=theme;self.explanation=explanation
 }

 public var readAndChoosePrompt:ReadAndChoosePrompt? {
  guard kind != .readAloud,let choices,let answerIndex else {return nil}
  return ReadAndChoosePrompt(id:id,sentence:text,choices:choices,correctChoiceIndex:answerIndex)
 }

 public var readAloudPrompt:ReadAloudPrompt? {
  kind == .readAloud ? ReadAloudPrompt(id:id,text:text):nil
 }
}

public struct ChallengeContentPack: Codable, Sendable {
 public var version:Int
 public var generatedAt:String
 public var items:[ChallengeContentItem]
 public init(version:Int,generatedAt:String,items:[ChallengeContentItem]) {
  self.version=version;self.generatedAt=generatedAt;self.items=items
 }
}

public struct ContentHistory: Codable, Equatable, Sendable {
 public static let limit=128
 private struct Entry:Codable,Equatable,Sendable {
  let kind:ContentKind
  let language:String
  let id:String
  let theme:String?
 }
 private var entries:[Entry]=[]

 public init() {}

 public mutating func record(_ item:ChallengeContentItem) {
  entries.append(Entry(kind:item.kind,language:item.language,id:item.id,theme:item.theme))
  let overflow=entries.filter {$0.kind == item.kind && $0.language == item.language}.count-Self.limit
  guard overflow>0 else {return}
  var toDrop=overflow
  entries.removeAll {
   guard toDrop>0,$0.kind == item.kind,$0.language == item.language else {return false}
   toDrop-=1
   return true
  }
 }

 public func recent(kind:ContentKind,language:String) -> [String] {
  entries.filter {$0.kind == kind && $0.language == language}.map(\.id)
 }

 fileprivate func lastTheme(kind:ContentKind,language:String) -> String? {
  entries.last {$0.kind == kind && $0.language == language}?.theme
 }

 fileprivate mutating func clear(kind:ContentKind,language:String) {
  entries.removeAll {$0.kind == kind && $0.language == language}
 }
}

public struct ChallengeContentStore: Sendable {
 public static let supportedLanguages:Set<String>=["en","vi"]
 public static let readAloudTokenRange=18...30
 public static let themes:Set<String>=["workAndStudy","everydayLife","peopleAndPlans","creativeBreaks","cityAndTravel","curiosity"]
 public let version:Int
 private let items:[ChallengeContentItem]

 public init(bundled:ChallengeContentPack,cached:ChallengeContentPack?) {
  if let cached,cached.version>bundled.version {
   let valid=Self.validItems(cached)
   if !valid.isEmpty {
    version=cached.version;items=valid
    return
   }
  }
  version=bundled.version;items=Self.validItems(bundled)
 }

 public static func validItems(_ pack:ChallengeContentPack) -> [ChallengeContentItem] {
  var ids=Set<String>(),texts=Set<String>()
  return pack.items.filter {item in
   guard isValid(item),!ids.contains(item.id) else {return false}
   let normalized="\(item.language)|\(RecognizedWordMatch.tokens(in:item.text,language:item.language).joined(separator:" "))"
   guard texts.insert(normalized).inserted else {return false}
   ids.insert(item.id)
   return true
  }
 }

 private static func isValid(_ item:ChallengeContentItem) -> Bool {
  func filled(_ value:String) -> Bool {!value.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty}
  guard filled(item.id),filled(item.text),filled(item.source),filled(item.license),supportedLanguages.contains(item.language) else {return false}
  if let theme=item.theme,!themes.contains(theme) {return false}
  if let explanation=item.explanation,!filled(explanation) {return false}
  switch item.kind {
  case .readAloud:
   return item.choices == nil && item.answerIndex == nil && readAloudTokenRange.contains(RecognizedWordMatch.tokens(in:item.text,language:item.language).count)
  case .readAndChoose,.riddle:
   guard let choices=item.choices,choices.count == 3,choices.allSatisfy(filled),let answer=item.answerIndex else {return false}
   return choices.indices.contains(answer) && Set(choices.map {$0.trimmingCharacters(in:.whitespacesAndNewlines).lowercased()}).count == choices.count
  }
 }

 public func items(kind:ContentKind,language:String) -> [ChallengeContentItem] {
  items.filter {$0.kind == kind && $0.language == language}
 }

 public func next(kind:ContentKind,language:String,history:inout ContentHistory) -> ChallengeContentItem? {
  let pool=items(kind:kind,language:language)
  guard !pool.isEmpty else {return nil}
  let previousTheme=history.lastTheme(kind:kind,language:language)
  let recent=Set(history.recent(kind:kind,language:language))
  var candidates=pool.filter {!recent.contains($0.id)}
  if candidates.isEmpty {
   let previous=history.recent(kind:kind,language:language).last
   history.clear(kind:kind,language:language)
   candidates=pool.count>1 ? pool.filter {$0.id != previous}:pool
  }
  if let previousTheme {
   let otherThemes=candidates.filter {$0.theme != nil && $0.theme != previousTheme}
   if !otherThemes.isEmpty {candidates=otherThemes}
  }
  guard let picked=candidates.randomElement() else {return nil}
  history.record(picked)
  return picked
 }
}
