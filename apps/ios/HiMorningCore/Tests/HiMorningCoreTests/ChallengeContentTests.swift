import Foundation
#if !PORTABLE_TESTS
import XCTest
@testable import HiMorningCore
#endif

final class ChallengeContentTests:XCTestCase {
 private func fixturePack() throws -> ChallengeContentPack {
  #if PORTABLE_TESTS
  let root=URL(fileURLWithPath:CommandLine.arguments[1])
  #else
  let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("shared/contracts/v1")
  #endif
  return try JSONDecoder().decode(ChallengeContentPack.self,from:Data(contentsOf:root.appendingPathComponent("fixtures/challenge-content.sample.json")))
 }

 private func words(_ count:Int) -> String {(0..<count).map {"word\($0)"}.joined(separator:" ")}

 private func item(_ id:String,_ kind:ContentKind = .riddle,language:String="en",text:String="What am I?") -> ChallengeContentItem {
  let choices:[String]?=kind == .readAloud ? nil:["a","b","c"]
  return ChallengeContentItem(id:id,kind:kind,language:language,text:kind == .readAloud ? "\(id) "+words(19):(text == "What am I?" ? "What am I \(id)?":text),choices:choices,answerIndex:kind == .readAloud ? nil:1,source:"himorning",license:"original",attribution:nil)
 }

 private func pack(_ version:Int,_ items:[ChallengeContentItem]) -> ChallengeContentPack {
  ChallengeContentPack(version:version,generatedAt:"2026-10-18T00:00:00Z",items:items)
 }

 func testStoreLoadsFixtureAndFiltersByLanguage() throws {
  let store=ChallengeContentStore(bundled:try fixturePack(),cached:nil)
  XCTAssertEqual(store.version,1)
  for kind in [ContentKind.readAloud,.readAndChoose,.riddle] {
   for language in ["en","vi"] {
    let found=store.items(kind:kind,language:language)
    XCTAssertEqual(found.count,2)
    XCTAssertTrue(found.allSatisfy {$0.kind == kind && $0.language == language})
   }
  }
  let reading=store.items(kind:.readAndChoose,language:"vi")[0]
  XCTAssertNotNil(reading.readAndChoosePrompt)
  XCTAssertNil(reading.readAloudPrompt)
  XCTAssertNotNil(store.items(kind:.readAloud,language:"en")[0].readAloudPrompt)
 }

 func testInvalidRemoteItemsAreDroppedAndBundledStays() throws {
  let bundled=try fixturePack()
  let tooShort=ChallengeContentItem(id:"short",kind:.readAloud,language:"en",text:words(12),choices:nil,answerIndex:nil,source:"himorning",license:"original",attribution:nil)
  let good=item("remote-riddle")
  let store=ChallengeContentStore(bundled:bundled,cached:pack(2,[tooShort,good]))
  XCTAssertEqual(store.version,2)
  XCTAssertTrue(store.items(kind:.readAloud,language:"en").isEmpty)
  XCTAssertEqual(store.items(kind:.riddle,language:"en").map(\.id),["remote-riddle"])
  let empty=ChallengeContentStore(bundled:bundled,cached:pack(3,[tooShort]))
  XCTAssertEqual(empty.version,1)
  XCTAssertEqual(empty.items(kind:.readAloud,language:"en").count,2)
 }

 func testItemRulesRejectMalformedItems() {
  var badAnswer=item("bad-answer");badAnswer.answerIndex=3
  var twoChoices=item("two-choices");twoChoices.choices=["a","b"]
  var emptyChoice=item("empty-choice");emptyChoice.choices=["a","","c"]
  let unknownLanguage=item("fr",language:"fr")
  var noSource=item("no-source");noSource.source=""
  var readAloudWithChoices=item("ra",.readAloud);readAloudWithChoices.choices=["a","b","c"]
  let tooLong=ChallengeContentItem(id:"long",kind:.readAloud,language:"en",text:words(31),choices:nil,answerIndex:nil,source:"himorning",license:"original",attribution:nil)
  let bad=[badAnswer,twoChoices,emptyChoice,unknownLanguage,noSource,readAloudWithChoices,tooLong]
  XCTAssertTrue(ChallengeContentStore.validItems(pack(1,bad)).isEmpty)
  let kept=ChallengeContentStore.validItems(pack(1,[item("dup"),item("dup"),item("ok",.readAloud)]))
  XCTAssertEqual(kept.map(\.id),["dup","ok"])
 }

 func testDuplicateTextIsDroppedPerLanguageIgnoringCaseAndPunctuation() {
  var first=item("a");first.text="What has keys, but cannot open a door?"
  var second=item("b");second.text="WHAT has keys but cannot open a door"
  var otherLanguage=item("c",language:"vi");otherLanguage.text=first.text
  XCTAssertEqual(ChallengeContentStore.validItems(pack(1,[first,second,otherLanguage])).map(\.id),["a","c"])
 }

 func testHistoryResetAvoidsTheImmediatelyPreviousPick() {
  let store=ChallengeContentStore(bundled:pack(1,[item("a"),item("b")]),cached:nil)
  var history=ContentHistory()
  var last=store.next(kind:.riddle,language:"en",history:&history)?.id
  for _ in 0..<40 {
   let next=store.next(kind:.riddle,language:"en",history:&history)?.id
   XCTAssertTrue(next != last)
   last=next
  }
 }

 func testOlderCachedPackIsIgnored() throws {
  let bundled=try fixturePack()
  let same=ChallengeContentStore(bundled:bundled,cached:pack(1,[item("same")]))
  XCTAssertEqual(same.version,1)
  XCTAssertTrue(same.items(kind:.riddle,language:"en").allSatisfy {$0.id != "same"})
  let older=ChallengeContentStore(bundled:pack(5,bundled.items),cached:pack(4,[item("older")]))
  XCTAssertEqual(older.version,5)
 }

 func testNoRepeatWithinTwentyPicks() throws {
  let store=ChallengeContentStore(bundled:pack(1,(0..<25).map {item("r\($0)")}),cached:nil)
  var history=ContentHistory()
  var picked:[String]=[]
  for _ in 0..<20 {picked.append(try XCTUnwrap(store.next(kind:.riddle,language:"en",history:&history)).id)}
  XCTAssertEqual(Set(picked).count,20)
  XCTAssertEqual(history.recent(kind:.riddle,language:"en").count,ContentHistory.limit)
  XCTAssertTrue(history.recent(kind:.riddle,language:"vi").isEmpty)
 }

 func testSmallPoolStillPicksAfterHistoryFills() throws {
  let store=ChallengeContentStore(bundled:pack(1,[item("a"),item("b")]),cached:nil)
  var history=ContentHistory()
  for _ in 0..<5 {XCTAssertNotNil(store.next(kind:.riddle,language:"en",history:&history))}
  XCTAssertNil(store.next(kind:.readAloud,language:"en",history:&history))
 }

 func testVietnameseKeepsToneMarksEnglishFolds() {
  XCTAssertEqual(RecognizedWordMatch.tokens(in:"Má mà ma",language:"vi"),["má","mà","ma"])
  XCTAssertFalse(RecognizedWordMatch.passes(target:"má",recognized:"ma",language:"vi"))
  XCTAssertTrue(RecognizedWordMatch.passes(target:"má",recognized:"MÁ",language:"vi"))
  XCTAssertEqual(RecognizedWordMatch.tokens(in:"Café",language:"en"),["cafe"])
  XCTAssertEqual(RecognizedWordMatch.tokens(in:"Café"),["cafe"])
  let attempt=ReadAloudAttempt(target:"Má mà ma",language:"vi")
  XCTAssertEqual(attempt.feedback.words.map(\.text),["má","mà","ma"])
 }
}
