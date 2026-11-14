import XCTest
@testable import HiMorning

@MainActor final class RewardedAdStoreTests:XCTestCase {
 func testDismissWithoutEarnedRewardDoesNotGrant() async throws {
  let driver=TestRewardedAdDriver()
  let subject=RewardedAdStore(driver:driver)
  try await subject.prepare(isEligible:{true})
  var grants=0
  let task=Task {try await subject.watch(isEligible:{true},onEarned:{grants+=1})}
  await fulfillment(of:[driver.presented],timeout:1)
  driver.emit(.dismissed)
  let result=try await task.value
  XCTAssertFalse(result);XCTAssertEqual(grants,0);XCTAssertFalse(subject.isReady);XCTAssertFalse(subject.busy)
 }
 func testEarnedRewardGrantsOnceOnlyAfterDismissal() async throws {
  let driver=TestRewardedAdDriver()
  let subject=RewardedAdStore(driver:driver)
  try await subject.prepare(isEligible:{true})
  var grants=0
  let task=Task {try await subject.watch(isEligible:{true},onEarned:{grants+=1})}
  await fulfillment(of:[driver.presented],timeout:1)
  driver.emit(.earned);driver.emit(.earned)
  XCTAssertTrue(subject.busy);XCTAssertEqual(grants,1)
  driver.emit(.dismissed);driver.emit(.dismissed)
  let result=try await task.value
  XCTAssertTrue(result);XCTAssertFalse(subject.busy);XCTAssertEqual(grants,1)
 }
 func testAcceptedRewardSurvivesCancellationProAndConsentChange() async throws {
  let driver=TestRewardedAdDriver()
  let subject=RewardedAdStore(driver:driver)
  var eligible=true,grants=0
  try await subject.prepare(isEligible:{eligible})
  let task=Task {try await subject.watch(isEligible:{eligible},onEarned:{grants+=1})}
  await fulfillment(of:[driver.presented],timeout:1)
  driver.emit(.earned)
  XCTAssertEqual(grants,1)
  task.cancel();subject.cancel();eligible=false;driver.canRequestAds=false
  driver.emit(.earned);driver.emit(.dismissed)
  let result=try await task.value
  XCTAssertTrue(result);XCTAssertEqual(grants,1)
 }
 func testEligibilityLostDuringLoadDoesNotBecomeReady() async {
  let driver=TestRewardedAdDriver()
  let subject=RewardedAdStore(driver:driver)
  var eligible=true
  driver.onLoad={eligible=false}
  do {try await subject.prepare(isEligible:{eligible});XCTFail("Expected cancellation")} catch is CancellationError {} catch {XCTFail("Unexpected error")}
  XCTAssertFalse(subject.isReady);XCTAssertFalse(subject.busy)
 }
 func testConsentRevokedBeforePresentationCannotGrant() async throws {
  let driver=TestRewardedAdDriver()
  let subject=RewardedAdStore(driver:driver)
  try await subject.prepare(isEligible:{true})
  driver.canRequestAds=false
  do {_=try await subject.watch(isEligible:{true});XCTFail("Expected consent failure")} catch {}
  XCTAssertNil(driver.callback);XCTAssertFalse(subject.isReady)
 }
 func testLateRewardAfterDismissalIsIgnored() async throws {
  let driver=TestRewardedAdDriver()
  let store=RewardedAdStore(driver:driver)
  try await store.prepare(isEligible:{true})
  let task=Task {try await store.watch(isEligible:{true})}
  await fulfillment(of:[driver.presented],timeout:1)
  driver.emit(.dismissed);driver.emit(.earned)
  let result=try await task.value
  XCTAssertFalse(result)
 }
 func testProOrContextChangeWhileWatchingDiscardsReward() async throws {
  let driver=TestRewardedAdDriver()
  let subject=RewardedAdStore(driver:driver)
  var eligible=true
  try await subject.prepare(isEligible:{eligible})
  let task=Task {try await subject.watch(isEligible:{eligible})}
  await fulfillment(of:[driver.presented],timeout:1)
  eligible=false
  driver.emit(.earned);driver.emit(.dismissed)
  let result=try await task.value
  XCTAssertFalse(result)
 }
 func testExplicitCancelDiscardsReward() async throws {
  let driver=TestRewardedAdDriver()
  let subject=RewardedAdStore(driver:driver)
  try await subject.prepare(isEligible:{true})
  let task=Task {try await subject.watch(isEligible:{true})}
  await fulfillment(of:[driver.presented],timeout:1)
  subject.cancel();driver.emit(.earned);driver.emit(.dismissed)
  let result=try await task.value
  XCTAssertFalse(result)
 }
 func testTaskCancellationDoesNotGrant() async throws {
  let driver=TestRewardedAdDriver()
  let store=RewardedAdStore(driver:driver)
  try await store.prepare(isEligible:{true})
  let task=Task {try await store.watch(isEligible:{true})}
  await fulfillment(of:[driver.presented],timeout:1)
  task.cancel();driver.emit(.earned);driver.emit(.dismissed)
  do {_=try await task.value;XCTFail("Expected cancellation")} catch is CancellationError {} catch {XCTFail("Unexpected error")}
 }
 func testConsentRefreshFailureUsesPriorConsentWhenUMPAllowsAds() async throws {
  let driver=TestRewardedAdDriver()
  driver.shouldFailConsentUpdate=true
  let store=RewardedAdStore(driver:driver)
  try await store.prepare(isEligible:{true})
  XCTAssertTrue(store.isReady)
  XCTAssertEqual(driver.loads,1)
 }

 func testConsentRefreshFailureBlocksLoadingWhenUMPDisallowsAds() async {
  let driver=TestRewardedAdDriver()
  driver.shouldFailConsentUpdate=true
  driver.canRequestAds=false
  let store=RewardedAdStore(driver:driver)
  do {try await store.prepare(isEligible:{true});XCTFail("Expected consent update failure")} catch {}
  XCTAssertFalse(store.isReady)
  XCTAssertEqual(driver.loads,0)
 }

 func testNoConsentNeverLoadsAds() async {
  let driver=TestRewardedAdDriver();driver.canRequestAds=false
  let store=RewardedAdStore(driver:driver)
  do {try await store.prepare(isEligible:{true});XCTFail("Expected consent failure")} catch {}
  XCTAssertEqual(driver.loads,0);XCTAssertFalse(store.isReady)
 }
 func testFailedLoadAndPresentationNeverGrant() async throws {
  let driver=TestRewardedAdDriver();driver.shouldFailLoad=true
  let store=RewardedAdStore(driver:driver)
  do {try await store.prepare(isEligible:{true});XCTFail("Expected load failure")} catch {}
  XCTAssertFalse(store.isReady);XCTAssertFalse(store.busy)
  driver.shouldFailLoad=false
  try await store.prepare(isEligible:{true})
  let task=Task {try await store.watch(isEligible:{true})}
  await fulfillment(of:[driver.presented],timeout:1)
  driver.emit(.failed)
  do {_=try await task.value;XCTFail("Expected presentation failure")} catch {}
  XCTAssertFalse(store.isReady);XCTAssertFalse(store.busy)
 }
 func testIneligibleDoesNotLoadOrPresent() async {
  let driver=TestRewardedAdDriver()
  let subject=RewardedAdStore(driver:driver)
  do {try await subject.prepare(isEligible:{false});XCTFail("Expected ineligible")} catch {}
  XCTAssertEqual(driver.loads,0)
 }
 func testPrivacyChangesInvalidateLoadedAd() async throws {
  let driver=TestRewardedAdDriver()
  let subject=RewardedAdStore(driver:driver)
  try await subject.prepare(isEligible:{true})
  XCTAssertTrue(subject.isReady)
  try await subject.showPrivacyOptions()
  XCTAssertFalse(subject.isReady)
 }
 func testProductionRequiresOwnValidIdentifiers() {
  XCTAssertFalse(RewardedAdConfiguration.isValid(appID:"",adUnitID:"",production:true))
  XCTAssertFalse(RewardedAdConfiguration.isValid(appID:"$(ADMOB_APPLICATION_ID)",adUnitID:"$(ADMOB_REWARDED_AD_UNIT_ID)",production:true))
  XCTAssertFalse(RewardedAdConfiguration.isValid(appID:"ca-app-pub-3940256099942544~1458002511",adUnitID:"ca-app-pub-3940256099942544/1712485313",production:true))
  XCTAssertFalse(RewardedAdConfiguration.isValid(appID:"ca-app-pub-1234567890123456~1234567890",adUnitID:"ca-app-pub-9999999999999999/1234567890",production:true))
  XCTAssertTrue(RewardedAdConfiguration.isValid(appID:"ca-app-pub-1234567890123456~1234567890",adUnitID:"ca-app-pub-1234567890123456/1234567890",production:true))
  XCTAssertTrue(RewardedAdConfiguration.isValid(appID:"ca-app-pub-3940256099942544~1458002511",adUnitID:"ca-app-pub-3940256099942544/1712485313",production:false))
 }
}

@MainActor private final class TestRewardedAdDriver:RewardedAdDriver {
 var isConfigured=true
 var canRequestAds=true
 var privacyOptionsRequired=true
 var loads=0
 var shouldFailLoad=false
 var shouldFailConsentUpdate=false
 var onLoad:(()->Void)?
 let presented=XCTestExpectation(description:"Ad presentation")
 var callback:((RewardedAdEvent)->Void)?
 func updateConsent() async throws {if shouldFailConsentUpdate {throw RewardedAdFailure.unavailable}}
 func gatherConsent() async throws {}
 func load() async throws {loads+=1;if shouldFailLoad {throw RewardedAdFailure.unavailable};onLoad?()}
 func present(_ event:@escaping(RewardedAdEvent)->Void) throws {callback=event;presented.fulfill()}
 func showPrivacyOptions() async throws {}
 func clear() {}
 func emit(_ event:RewardedAdEvent) {callback?(event)}
}
