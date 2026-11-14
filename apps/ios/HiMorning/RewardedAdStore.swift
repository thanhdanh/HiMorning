import Combine
import Foundation
import GoogleMobileAds
import Synchronization
import UIKit
import UserMessagingPlatform

@MainActor final class RewardedAdStore:ObservableObject {
 var isConfigured:Bool {driver.isConfigured}
 @Published private(set) var isReady=false
 @Published private(set) var busy=false
 @Published private(set) var privacyOptionsRequired=false
 private let driver:RewardedAdDriver
 private var generation=UUID()
 private var loadedAt:Date?
 private var consentUpdated=false
 private var consentUpdate:Task<Void,Error>?
 private var continuation:CheckedContinuation<Bool,Error>?
 private var earned=false
 private var cancelled=false
 private var taskCancelled:RewardedAdCancellation?
 private var earnedHandler:(@MainActor()->Void)?
 private var eligible:(()->Bool)?
 init() {driver=GoogleRewardedAdDriver()}
 init(driver:RewardedAdDriver) {self.driver=driver}

 func refreshConsent() async throws {
  guard driver.isConfigured else {throw RewardedAdFailure.unavailable}
  if consentUpdated {return}
  if let consentUpdate {return try await consentUpdate.value}
  let task=Task {
   defer {privacyOptionsRequired=driver.privacyOptionsRequired}
   try await driver.updateConsent()
   consentUpdated=true
  }
  consentUpdate=task
  defer {consentUpdate=nil}
  try await task.value
 }
 func prepare(isEligible:@escaping()->Bool) async throws {
  guard !busy,isEligible() else {throw RewardedAdFailure.unavailable}
  cancel()
  let current=generation
  busy=true
  defer {busy=false;privacyOptionsRequired=driver.privacyOptionsRequired}
  do {
   do {try await refreshConsent()}
   catch {
    // UMP can allow ads using the consent it already holds from a previous session.
    guard driver.canRequestAds else {throw error}
   }
   try Task.checkCancellation()
   guard generation==current,isEligible() else {throw CancellationError()}
   do {try await driver.gatherConsent()}
   catch {
    guard driver.canRequestAds else {throw error}
   }
   guard driver.canRequestAds else {throw RewardedAdFailure.consent}
   try Task.checkCancellation()
   guard generation==current,isEligible() else {throw CancellationError()}
   try await driver.load()
   try Task.checkCancellation()
   guard generation==current,isEligible(),driver.canRequestAds else {throw CancellationError()}
   loadedAt=Date();isReady=true
  } catch {
   driver.clear()
   if error is CancellationError || error is RewardedAdFailure {throw error}
   throw RewardedAdFailure.unavailable
  }
 }
 func watch(isEligible:@escaping()->Bool,onEarned:@escaping @MainActor()->Void = {}) async throws ->Bool {
  try Task.checkCancellation()
  guard !busy else {throw RewardedAdFailure.unavailable}
  guard isReady,isEligible(),driver.canRequestAds,
        let loadedAt,Date().timeIntervalSince(loadedAt)<3_600 else {
   cancel();throw RewardedAdFailure.unavailable
  }
  isReady=false;busy=true;earned=false;cancelled=false;eligible=isEligible;earnedHandler=onEarned
  let current=generation
  let cancellation=RewardedAdCancellation()
  taskCancelled=cancellation
  let result:Bool=try await withTaskCancellationHandler {
   try await withCheckedThrowingContinuation { continuation in
    self.continuation=continuation
    do {try driver.present { [weak self] event in self?.receive(event,generation:current)}}
    catch {finish(.failure(RewardedAdFailure.unavailable))}
   }
  } onCancel: {
   cancellation.flag.withLock {$0=true}
  }
  if result {return true}
  try Task.checkCancellation()
  return false
 }
 func cancel() {
  isReady=false;loadedAt=nil;cancelled=true
  if continuation == nil {generation=UUID();driver.clear()}
 }
 func showPrivacyOptions() async throws {
  guard !busy else {throw RewardedAdFailure.unavailable}
  cancel();busy=true
  defer {busy=false;privacyOptionsRequired=driver.privacyOptionsRequired}
  do {try await driver.showPrivacyOptions()}
  catch {throw RewardedAdFailure.unavailable}
 }
 private func receive(_ event:RewardedAdEvent,generation:UUID) {
  guard self.generation==generation,continuation != nil else {return}
  switch event {
  case .earned:
   if !earned,!cancelled,taskCancelled?.flag.withLock({$0}) != true,eligible?() == true,driver.canRequestAds {
    earned=true;earnedHandler?()
   }
  // Google-only ads deliver reward before dismissal; a late callback must not reopen a completed grant.
  case .dismissed:finish(.success(earned))
  case .failed:finish(earned ? .success(true) : .failure(RewardedAdFailure.unavailable))
  }
 }
 private func finish(_ result:Result<Bool,Error>) {
  let completion=continuation
  continuation=nil;eligible=nil;earnedHandler=nil;taskCancelled=nil;busy=false;isReady=false;loadedAt=nil;generation=UUID();driver.clear()
  completion?.resume(with:result)
 }
}

private final class RewardedAdCancellation:Sendable {let flag=Mutex(false)}
enum RewardedAdEvent {case earned,dismissed,failed}
enum RewardedAdFailure:LocalizedError {
 case unavailable,consent
 var errorDescription:String? {
  switch self {
  case .unavailable:return appText("Ads are unavailable right now. Your free alarms still work.")
  case .consent:return appText("Your privacy choices do not allow this ad. Your free alarms still work.")
  }
 }
}
@MainActor protocol RewardedAdDriver:AnyObject {
 var isConfigured:Bool {get}
 var canRequestAds:Bool {get}
 var privacyOptionsRequired:Bool {get}
 func updateConsent() async throws
 func gatherConsent() async throws
 func load() async throws
 func present(_ event:@escaping(RewardedAdEvent)->Void) throws
 func showPrivacyOptions() async throws
 func clear()
}

enum RewardedAdConfiguration {
 static func isValid(appID:String,adUnitID:String,production:Bool)->Bool {
  let appPattern=#"^ca-app-pub-[0-9]{16}~[0-9]{10}$"#
  let unitPattern=#"^ca-app-pub-[0-9]{16}/[0-9]{10}$"#
  return appID.range(of:appPattern,options:.regularExpression) != nil &&
   adUnitID.range(of:unitPattern,options:.regularExpression) != nil &&
   appID.split(separator:"~").first == adUnitID.split(separator:"/").first &&
   (!production || (!appID.contains("3940256099942544") && !adUnitID.contains("3940256099942544")))
 }
}

@MainActor private final class GoogleRewardedAdDriver:NSObject,RewardedAdDriver,FullScreenContentDelegate {
 private var ad:RewardedAd?
 private var event:((RewardedAdEvent)->Void)?
 private var started=false
 private var adUnitID:String {
  Bundle.main.object(forInfoDictionaryKey:"HiMorningRewardedAdUnitID") as? String ?? ""
 }
 var isConfigured:Bool {
  #if DEBUG || TESTFLIGHT_DEMO_ADS
  let production=false
  #else
  let production=true
  #endif
  return RewardedAdConfiguration.isValid(appID:Bundle.main.object(forInfoDictionaryKey:"GADApplicationIdentifier") as? String ?? "",adUnitID:adUnitID,production:production)
 }
 var canRequestAds:Bool {ConsentInformation.shared.canRequestAds}
 var privacyOptionsRequired:Bool {ConsentInformation.shared.privacyOptionsRequirementStatus == .required}
 func updateConsent() async throws {
  guard isConfigured else {throw RewardedAdFailure.unavailable}
  try await ConsentInformation.shared.requestConsentInfoUpdate(with:RequestParameters())
 }
 func gatherConsent() async throws {
  guard let presenter=presenter() else {throw RewardedAdFailure.unavailable}
  try await ConsentForm.loadAndPresentIfRequired(from:presenter)
 }
 func load() async throws {
  guard isConfigured,canRequestAds else {throw RewardedAdFailure.unavailable}
  if !started {
   MobileAds.shared.requestConfiguration.setPublisherFirstPartyIDEnabled(false)
   MobileAds.shared.requestConfiguration.publisherPrivacyPersonalizationState = .disabled
   await MobileAds.shared.start()
   started=true
  }
  let request=Request(),extras=Extras()
  extras.additionalParameters=["npa":"1"]
  request.register(extras)
  ad=try await RewardedAd.load(with:adUnitID,request:request)
  ad?.fullScreenContentDelegate=self
 }
 func present(_ event:@escaping(RewardedAdEvent)->Void) throws {
  guard canRequestAds,let ad,let presenter=presenter() else {throw RewardedAdFailure.unavailable}
  try ad.canPresent(from:presenter)
  self.event=event
  ad.present(from:presenter) { [weak self] in self?.event?(.earned)}
 }
 func showPrivacyOptions() async throws {
  guard isConfigured,let presenter=presenter() else {throw RewardedAdFailure.unavailable}
  try await ConsentForm.presentPrivacyOptionsForm(from:presenter)
 }
 func clear() {ad=nil;event=nil}
 func adDidDismissFullScreenContent(_ ad:FullScreenPresentingAd) {event?(.dismissed)}
 func ad(_ ad:FullScreenPresentingAd,didFailToPresentFullScreenContentWithError error:Error) {event?(.failed)}
 private func presenter()->UIViewController? {
  guard let scene=UIApplication.shared.connectedScenes.compactMap({$0 as? UIWindowScene}).first(where:{$0.activationState == .foregroundActive}),
        var view=scene.windows.first(where:{$0.isKeyWindow})?.rootViewController else {return nil}
  while let presented=view.presentedViewController {view=presented}
  return view.isBeingDismissed ? nil : view
 }
}
