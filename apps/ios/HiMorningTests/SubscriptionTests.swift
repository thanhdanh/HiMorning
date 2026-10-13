import XCTest
import StoreKit
import StoreKitTest
@testable import HiMorning

@MainActor final class SubscriptionTests:XCTestCase {
 private func session() throws ->SKTestSession {
  let url=try XCTUnwrap(Bundle(for:Self.self).url(forResource:"HiMorning",withExtension:"storekit"))
  let session=try SKTestSession(contentsOf:url)
  session.resetToDefaultState();session.clearTransactions();session.disableDialogs=true
  return session
 }
 private func purchase(_ store:SubscriptionStore) async throws {
  let products=try await Product.products(for:[SubscriptionStore.monthlyProductID])
  let product=try XCTUnwrap(products.first)
  await store.complete(try await product.purchase())
 }
 func testPurchaseRestoresAcrossStoreInstancesAndRefundRemovesAccess() async throws {
  let session=try session(),store=SubscriptionStore()
  await store.refresh()
  XCTAssertFalse(store.isPro)
  try await purchase(store)
  XCTAssertTrue(store.isPro)
  let restored=SubscriptionStore()
  try await AppStore.sync()
  await restored.refresh()
  XCTAssertTrue(restored.isPro)
  let transaction=try XCTUnwrap(session.allTransactions().first)
  try session.refundTransaction(identifier:transaction.identifier)
  await restored.refresh()
  XCTAssertFalse(restored.isPro)
 }
 func testTurningOffRenewalKeepsAccessUntilExpiry() async throws {
  let session=try session(),store=SubscriptionStore()
  try await purchase(store)
  let transaction=try XCTUnwrap(session.allTransactions().first)
  try session.disableAutoRenewForTransaction(identifier:transaction.identifier)
  await store.refresh()
  XCTAssertTrue(store.isPro)
  try session.expireSubscription(productIdentifier:SubscriptionStore.monthlyProductID)
  await store.refresh()
  XCTAssertFalse(store.isPro)
 }
 func testPendingCancellationAndUnverifiedResultsDoNotGrantAccess() async throws {
  _=try session()
  let store=SubscriptionStore()
  await store.complete(.pending)
  XCTAssertFalse(store.isPro)
  XCTAssertNotNil(store.message)
  await store.complete(.userCancelled)
  XCTAssertFalse(store.isPro)
  let products=try await Product.products(for:[SubscriptionStore.monthlyProductID])
  let product=try XCTUnwrap(products.first)
  if case .success(.verified(let transaction))=try await product.purchase() {
   await store.complete(.success(.unverified(transaction,NSError(domain:"test",code:1))))
   XCTAssertFalse(store.isPro)
  } else {XCTFail("Expected a verified local StoreKit test purchase")}
 }
 func testUnrelatedProductCannotUnlockPro() async throws {
  _=try session()
  let store=SubscriptionStore()
  let products=try await Product.products(for:["com.himorning.test.unrelated"])
  let product=try XCTUnwrap(products.first)
  await store.complete(try await product.purchase())
  await store.refresh()
  XCTAssertFalse(store.isPro)
 }
}
