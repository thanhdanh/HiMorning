import XCTest
import HiMorningCore
import Security
@testable import HiMorning

@MainActor final class PreviewStoreTests:XCTestCase {
 func testKeychainWritesUpdatesAndReadsPreview() throws {
  let service="com.himorning.preview.tests."+UUID().uuidString
  defer {SecItemDelete([kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service] as CFDictionary)}
  XCTAssertNil(try PreviewKeychain.load(service:service))
  let first=Data("first".utf8),updated=Data("updated".utf8)
  try PreviewKeychain.save(first,service:service)
  XCTAssertEqual(try PreviewKeychain.load(service:service),first)
  try PreviewKeychain.save(updated,service:service)
  XCTAssertEqual(try PreviewKeychain.load(service:service),updated)
 }
 func testPreviewStartsOnceAndSurvivesNewStore() throws {
  var data:Data?
  var now=Date(timeIntervalSince1970:1_000_000)
  let subscriptions=SubscriptionStore()
  let store=PreviewStore(subscriptions:subscriptions,load:{data},save:{data=$0},now:{now})
  XCTAssertEqual(store.access,.preview)
  XCTAssertFalse(store.hasStarted)
  store.start()
  XCTAssertTrue(store.hasStarted)
  XCTAssertEqual(store.remainingDays,30)
  now.addTimeInterval(29*86_400)
  store.start()
  let restored=PreviewStore(subscriptions:subscriptions,load:{data},save:{data=$0},now:{now})
  XCTAssertEqual(restored.remainingDays,1)
  now.addTimeInterval(86_400)
  restored.refresh()
  XCTAssertEqual(restored.access,.free)
  now.addTimeInterval(-10*86_400)
  restored.refresh()
  XCTAssertEqual(restored.access,.free)
 }
 func testUnreadableOrUnwritablePreviewDoesNotGrantFullAccess() {
  enum Failure:Error {case storage}
  let unreadable=PreviewStore(subscriptions:SubscriptionStore(),load:{throw Failure.storage},save:{_ in})
  XCTAssertEqual(unreadable.access,.free)
  let unwritable=PreviewStore(subscriptions:SubscriptionStore(),load:{nil},save:{_ in throw Failure.storage})
  unwritable.start()
  XCTAssertEqual(unwritable.access,.free)
  XCTAssertNotNil(unwritable.message)
 }
 func testCorruptPreviewDoesNotRestartPeriod() {
  let store=PreviewStore(subscriptions:SubscriptionStore(),load:{Data("bad".utf8)},save:{_ in})
  XCTAssertEqual(store.access,.free)
  store.start()
  XCTAssertEqual(store.access,.free)
 }
}
