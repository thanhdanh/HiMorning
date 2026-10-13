import Combine
import StoreKit
import HiMorningCore

@MainActor final class SubscriptionStore:ObservableObject {
 static let monthlyProductID="com.himorning.pro.monthly"
 @Published private(set) var access:MorningAccess = .free
 @Published private(set) var message:String?
 private var updates:Task<Void,Never>?
 private var generation=0
 var isPro:Bool {access == .pro}
 func start() {
  guard updates == nil else {return}
  updates=Task { [weak self] in
   for await result in Transaction.updates {
    guard let self else {return}
    guard case .verified(let transaction)=result,transaction.productID==Self.monthlyProductID else {continue}
    await self.refresh();await transaction.finish()
   }
  }
 }
 func refresh() async {
  generation+=1;let request=generation
  var next=MorningAccess.free
  // StoreKit includes billing grace periods; a past transaction expiry alone is not a denial.
  for await result in Transaction.currentEntitlements {
   if case .verified(let transaction)=result,transaction.productID==Self.monthlyProductID,
    transaction.productType == .autoRenewable,transaction.revocationDate == nil,!transaction.isUpgraded {next = .pro}
  }
  guard request==generation else {return}
  access=next
 }
 func complete(_ result:Product.PurchaseResult) async {
  message=nil
  switch result {
  case .success(let verification):
   guard case .verified(let transaction)=verification,transaction.productID==Self.monthlyProductID,
    transaction.productType == .autoRenewable else {message=appText("This purchase could not be verified. Please try restoring it.");return}
   await refresh();await transaction.finish()
  case .pending:message=appText("Waiting for purchase approval. Your alarms are unchanged.")
  case .userCancelled:break
  @unknown default:message=appText("The purchase could not finish. Please try again.")
  }
 }
 deinit {updates?.cancel()}
}
