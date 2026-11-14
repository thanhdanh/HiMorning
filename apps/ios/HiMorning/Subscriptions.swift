import Combine
import StoreKit
import HiMorningCore

@MainActor final class SubscriptionStore:ObservableObject {
 enum Catalog {
  case loading,unavailable,failed
  case available([Product])
 }
 nonisolated static let monthlyProductID="com.himorning.pro.monthly"
 nonisolated static let annualProductID="com.himorning.pro.annual"
 nonisolated static let productIDs=[monthlyProductID,annualProductID]
 @Published private(set) var access:MorningAccess = .free
 @Published private(set) var message:String?
 @Published private(set) var catalog:Catalog = .loading
 @Published private(set) var isRestoring=false
 private var updates:Task<Void,Never>?
 private var statuses:Task<Void,Never>?
 private var generation=0
 private var refreshing:Task<Void,Never>?
 private let now:()->Date
 init(now:@escaping()->Date = {Date()}) {self.now=now}
 var isPro:Bool {access == .pro}
 func loadProducts() async {
  catalog = .loading
  do {
   let products=try await Product.products(for:Self.productIDs)
   guard !Task.isCancelled else {return}
   let plans=Self.productIDs.compactMap {id in
    let unit:Product.SubscriptionPeriod.Unit=id == Self.annualProductID ? .year : .month
    return products.first {
     $0.id == id && $0.type == .autoRenewable &&
      $0.subscription?.subscriptionPeriod.unit == unit && $0.subscription?.subscriptionPeriod.value == 1
    }
   }
   let groups=Set(plans.compactMap {$0.subscription?.subscriptionGroupID})
   catalog=groups.count == 1 ? .available(plans) : .unavailable
  } catch {
   guard !Task.isCancelled else {return}
   catalog = .failed
  }
 }
 func restorePurchases() async {
  guard !isRestoring else {return}
  isRestoring=true
  message=nil
  defer {isRestoring=false}
  do {
   try await AppStore.sync()
   await refresh()
   message=appText(isPro ? "Your Pro subscription is restored." : "No active Pro subscription was found.")
  } catch StoreKitError.userCancelled {
   return
  } catch {
   message=appText("Could not restore purchases. Try again.")
  }
 }
 func reportPurchaseFailure() {
  message=appText("The purchase could not finish. Please try again.")
 }
 func start() {
  guard updates == nil else {return}
  updates=Task { [weak self] in
   for await result in Transaction.updates {
    guard let self else {return}
    guard case .verified(let transaction)=result,Self.productIDs.contains(transaction.productID) else {continue}
    await self.refresh();await transaction.finish()
   }
  }
  statuses=Task { [weak self] in
   for await status in Product.SubscriptionInfo.Status.updates {
    guard let self else {return}
    guard case .verified(let transaction)=status.transaction,Self.productIDs.contains(transaction.productID) else {continue}
    await self.refresh()
   }
  }
 }
 func refresh() async {
  generation+=1;let request=generation
  let previous=refreshing
  let task=Task { [weak self] in
   await previous?.value
   guard let self else {return}
   await self.refreshOnce()
  }
  refreshing=task
  await task.value
  if request==generation {refreshing=nil}
 }
 private func refreshOnce() async {
  var next=MorningAccess.free
  for await result in Transaction.currentEntitlements {
   guard case .verified(let transaction)=result,Self.productIDs.contains(transaction.productID),
    transaction.productType == .autoRenewable,transaction.revocationDate == nil,!transaction.isUpgraded else {continue}
   var current=transaction
   var grace:Date?
   if let status=await transaction.subscriptionStatus {
    guard status.state == .subscribed || status.state == .inGracePeriod,
     case .verified(let latest)=status.transaction,Self.productIDs.contains(latest.productID),
     latest.productType == .autoRenewable,latest.revocationDate == nil,!latest.isUpgraded else {continue}
    current=latest
    // A verified grace period can outlive the original signed transaction expiry.
    if status.state == .inGracePeriod,case .verified(let renewal)=status.renewalInfo {grace=renewal.gracePeriodExpirationDate}
   }
   if MorningAccess.verifiedPeriod(expiresAt:current.expirationDate,graceUntil:grace,now:now()) == .pro {next = .pro}
  }
  if access != next {
   message=nil
   access=next
  }
 }
 func complete(_ result:Product.PurchaseResult) async {
  message=nil
  switch result {
  case .success(let verification):
   guard case .verified(let transaction)=verification,Self.productIDs.contains(transaction.productID),
    transaction.productType == .autoRenewable else {message=appText("This purchase could not be verified. Please try restoring it.");return}
   await refresh();await transaction.finish()
  case .pending:message=appText("Waiting for purchase approval. Your alarms are unchanged.")
  case .userCancelled:break
  @unknown default:reportPurchaseFailure()
  }
 }
 deinit {updates?.cancel();statuses?.cancel();refreshing?.cancel()}
}
