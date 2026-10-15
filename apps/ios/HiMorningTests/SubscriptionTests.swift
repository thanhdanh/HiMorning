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
  session.locale=Locale(identifier:"en_US");session.storefront="USA"
  return session
 }
 private func purchase(_ store:SubscriptionStore,productID:String=SubscriptionStore.monthlyProductID) async throws {
  let products=try await Product.products(for:[productID])
  let product=try XCTUnwrap(products.first)
  await store.complete(try await product.purchase())
 }
 func testBothPlansAreAvailableWithoutAnIntroductoryOffer() async throws {
  let session=try session()
  defer {session.clearTransactions()}
  let products=try await Product.products(for:SubscriptionStore.productIDs)
  XCTAssertEqual(Set(products.map(\.id)),Set([SubscriptionStore.monthlyProductID,SubscriptionStore.annualProductID]))
  for product in products {XCTAssertNil(product.subscription?.introductoryOffer)}
  XCTAssertEqual(products.first {$0.id == SubscriptionStore.monthlyProductID}?.price,Decimal(2))
  XCTAssertEqual(products.first {$0.id == SubscriptionStore.annualProductID}?.price,Decimal(20))
  XCTAssertEqual(Set(products.compactMap {$0.subscription?.subscriptionGroupID}).count,1)
 }
 func testAnnualPurchaseRestoresAndRefundUpdateRemovesAccess() async throws {
  let session=try session(),store=SubscriptionStore()
  defer {session.clearTransactions()}
  try await purchase(store,productID:SubscriptionStore.annualProductID)
  XCTAssertTrue(store.isPro)
  let restored=SubscriptionStore()
  restored.start()
  try await AppStore.sync()
  await restored.refresh()
  XCTAssertTrue(restored.isPro)
  let refunded=expectation(description:"Annual refund revokes restored access")
  let observer=restored.$access.dropFirst().filter {$0 == .free}.prefix(1).sink {_ in refunded.fulfill()}
  defer {observer.cancel()}
  let transaction=try XCTUnwrap(session.allTransactions().first)
  try session.refundTransaction(identifier:transaction.identifier)
  await fulfillment(of:[refunded],timeout:15)
  XCTAssertFalse(restored.isPro)
 }
 func testAnnualCancellationKeepsAccessUntilSignedExpiry() async throws {
  var now=Date()
  let session=try session(),store=SubscriptionStore(now:{now})
  defer {session.clearTransactions()}
  store.start()
  try await purchase(store,productID:SubscriptionStore.annualProductID)
  let transaction=try XCTUnwrap(session.allTransactions().first)
  try session.disableAutoRenewForTransaction(identifier:transaction.identifier)
  await store.refresh()
  XCTAssertTrue(store.isPro)
  guard case .verified(let signed)?=await Transaction.latest(for:SubscriptionStore.annualProductID) else {
   return XCTFail("Expected a verified annual transaction")
  }
  let expiration=try XCTUnwrap(signed.expirationDate)
  now=expiration.addingTimeInterval(-0.001)
  await store.refresh()
  XCTAssertTrue(store.isPro,"Cancellation must keep annual access before signed expiry")
  now=expiration
  await store.refresh()
  XCTAssertFalse(store.isPro,"Annual access must end exactly at signed expiry")
 }
 func testSwitchingFromMonthlyToAnnualKeepsAccess() async throws {
  let session=try session(),store=SubscriptionStore()
  defer {session.clearTransactions()}
  try await purchase(store)
  XCTAssertTrue(store.isPro)
  try await purchase(store,productID:SubscriptionStore.annualProductID)
  await store.refresh()
  XCTAssertTrue(store.isPro)
 }
 func testAnnualPurchaseAndRefundComposeWithExpiredCorruptAndActivePreview() async throws {
  let session=try session(),subscriptions=SubscriptionStore()
  defer {session.clearTransactions()}
  var now=Date()
  let expired=PreviewStore(subscriptions:subscriptions,load:{nil},save:{_ in},now:{now})
  expired.start()
  now.addTimeInterval(31*86_400)
  expired.refresh()
  let corrupt=PreviewStore(subscriptions:subscriptions,load:{Data("bad".utf8)},save:{_ in})
  let active=PreviewStore(subscriptions:subscriptions,load:{nil},save:{_ in})
  active.start()
  XCTAssertEqual(expired.access,.free)
  XCTAssertEqual(corrupt.access,.free)
  XCTAssertEqual(active.access,.preview)
  subscriptions.start()
  try await purchase(subscriptions,productID:SubscriptionStore.annualProductID)
  XCTAssertEqual(expired.access,.pro)
  XCTAssertEqual(corrupt.access,.pro)
  XCTAssertEqual(active.access,.pro)
  let refunded=expectation(description:"Annual refund restores each preview policy")
  let observer=subscriptions.$access.dropFirst().filter {$0 == .free}.prefix(1).sink {_ in refunded.fulfill()}
  defer {observer.cancel()}
  let transaction=try XCTUnwrap(session.allTransactions().first)
  try session.refundTransaction(identifier:transaction.identifier)
  await fulfillment(of:[refunded],timeout:15)
  XCTAssertEqual(expired.access,.free)
  XCTAssertEqual(corrupt.access,.free)
  XCTAssertEqual(active.access,.preview)
 }
 func testSignedExpiredPurchasesCannotUnlockEitherPlan() async throws {
  let session=try session()
  defer {session.clearTransactions()}
  for productID in SubscriptionStore.productIDs {
   session.clearTransactions()
   let store=SubscriptionStore()
   let transaction=try await session.buyProduct(identifier:productID,options:[
    .purchaseDate(Date().addingTimeInterval(-400*86_400),renewalBehavior:.cancelImmediately)
   ])
   let expiration=try XCTUnwrap(transaction.expirationDate)
   XCTAssertLessThanOrEqual(expiration,Date(),"The seeded signed transaction must already be expired")
   await store.complete(.success(.verified(transaction)))
   await store.refresh()
   XCTAssertFalse(store.isPro,"An expired \(productID) transaction must not grant Pro")
  }
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
 func testTurningOffRenewalKeepsAccessUntilSignedExpiry() async throws {
  var now=Date()
  let session=try session(),store=SubscriptionStore(now:{now})
  defer {session.clearTransactions()}
  store.start()
  try await purchase(store)
  let transaction=try XCTUnwrap(session.allTransactions().first)
  try session.disableAutoRenewForTransaction(identifier:transaction.identifier)
  await store.refresh()
  XCTAssertTrue(store.isPro)
  guard case .verified(let signed)?=await Transaction.latest(for:SubscriptionStore.monthlyProductID) else {
   return XCTFail("Expected a verified monthly transaction")
  }
  let expiration=try XCTUnwrap(signed.expirationDate)
  now=expiration.addingTimeInterval(-0.001)
  await store.refresh()
  XCTAssertTrue(store.isPro,"Cancellation must keep monthly access before signed expiry")
  now=expiration
  await store.refresh()
  XCTAssertFalse(store.isPro,"Monthly access must end exactly at signed expiry")
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
