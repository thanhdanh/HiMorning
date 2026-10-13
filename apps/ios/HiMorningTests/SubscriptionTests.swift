import XCTest
import Combine
import StoreKit
import StoreKitTest
@testable import HiMorning

@MainActor final class SubscriptionTests:XCTestCase {
 private func session() throws ->SKTestSession {
  let url=try XCTUnwrap(Bundle(for:Self.self).url(forResource:"HiMorning",withExtension:"storekit"))
  let session=try SKTestSession(contentsOf:url)
  session.resetToDefaultState();session.clearTransactions();session.disableDialogs=true;session.timeRate = .realTime
  return session
 }
 private func purchase(_ store:SubscriptionStore) async throws {
  let products=try await Product.products(for:[SubscriptionStore.monthlyProductID])
  let product=try XCTUnwrap(products.first)
  await store.complete(try await product.purchase())
 }
 func testPurchaseRestoresAcrossStoreInstancesAndRefundRemovesAccess() async throws {
  let session=try session(),store=SubscriptionStore()
  defer {session.clearTransactions()}
  await store.refresh()
  XCTAssertFalse(store.isPro)
  try await purchase(store)
  XCTAssertTrue(store.isPro)
  let restored=SubscriptionStore()
  restored.start()
  try await AppStore.sync()
  await restored.refresh()
  XCTAssertTrue(restored.isPro)
  let refunded=expectation(description:"Restored access is revoked")
  let observer=restored.$access.dropFirst().filter {$0 == .free}.prefix(1).sink {_ in refunded.fulfill()}
  defer {observer.cancel()}
  let transaction=try XCTUnwrap(session.allTransactions().first)
  try session.refundTransaction(identifier:transaction.identifier)
  await fulfillment(of:[refunded],timeout:15)
  await restored.refresh()
  XCTAssertFalse(restored.isPro)
 }
 func testTurningOffRenewalKeepsAccessUntilExpiry() async throws {
  let session=try session(),store=SubscriptionStore()
  defer {session.clearTransactions()}
  try await purchase(store)
  let transaction=try XCTUnwrap(session.allTransactions().first)
  try session.disableAutoRenewForTransaction(identifier:transaction.identifier)
  await store.refresh()
  XCTAssertTrue(store.isPro)
  try session.expireSubscription(productIdentifier:SubscriptionStore.monthlyProductID)
  // StoreKit propagates the test-session mutation asynchronously.
  let deadline=Date().addingTimeInterval(5)
  repeat {
   await store.refresh()
   if store.isPro {try await Task.sleep(for:.milliseconds(100))}
  } while store.isPro && Date()<deadline
  XCTAssertFalse(store.isPro)
 }
 func testPendingCancellationAndUnverifiedResultsDoNotGrantAccess() async throws {
  let session=try session()
  defer {session.clearTransactions()}
  let store=SubscriptionStore()
  await store.complete(.pending)
  XCTAssertFalse(store.isPro)
  XCTAssertNotNil(store.message)
  await store.complete(.userCancelled)
  XCTAssertFalse(store.isPro)
  let products=try await Product.products(for:[SubscriptionStore.monthlyProductID])
  let product=try XCTUnwrap(products.first)
  if case .success(.verified(let transaction))=try await product.purchase() {
   await store.complete(.success(.unverified(transaction,.invalidSignature)))
   XCTAssertFalse(store.isPro)
  } else {XCTFail("Expected a verified local StoreKit test purchase")}
 }
 func testExternalRefundUpdateRemovesAccessWithoutManualRefresh() async throws {
  let session=try session(),store=SubscriptionStore()
  defer {session.clearTransactions()}
  store.start()
  try await purchase(store)
  XCTAssertTrue(store.isPro)
  let revoked=expectation(description:"Refund updates Pro access")
  let observer=store.$access.dropFirst().filter {$0 == .free}.prefix(1).sink {_ in revoked.fulfill()}
  defer {observer.cancel()}
  let transaction=try XCTUnwrap(session.allTransactions().first)
  try session.refundTransaction(identifier:transaction.identifier)
  await fulfillment(of:[revoked],timeout:15)
  XCTAssertFalse(store.isPro)
 }
 func testUnrelatedProductCannotUnlockPro() async throws {
  let session=try session()
  defer {session.clearTransactions()}
  let store=SubscriptionStore()
  let products=try await Product.products(for:["com.himorning.test.unrelated"])
  let product=try XCTUnwrap(products.first)
  await store.complete(try await product.purchase())
  await store.refresh()
  XCTAssertFalse(store.isPro)
 }
}
