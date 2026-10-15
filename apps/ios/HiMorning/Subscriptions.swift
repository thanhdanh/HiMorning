import Combine
import StoreKit
import HiMorningCore

@MainActor final class SubscriptionStore:ObservableObject {
 static let monthlyProductID="com.himorning.pro.monthly"
 static let annualProductID="com.himorning.pro.annual"
 static let productIDs=[monthlyProductID,annualProductID]
 @Published private(set) var access:MorningAccess = .free
 @Published private(set) var message:String?
 private var updates:Task<Void,Never>?
 private var statuses:Task<Void,Never>?
 private var generation=0
 private var refreshing:Task<Void,Never>?
 private let now:()->Date
 init(now:@escaping()->Date = {Date()}) {self.now=now}
 var isPro:Bool {access == .pro}
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
  access=next
  if isPro {message=nil}
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
  @unknown default:message=appText("The purchase could not finish. Please try again.")
  }
 }
 deinit {updates?.cancel();statuses?.cancel();refreshing?.cancel()}
}
