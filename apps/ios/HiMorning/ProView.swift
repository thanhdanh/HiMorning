import SwiftUI
import StoreKit

struct ProView:View {
 @ObservedObject var store:SubscriptionStore
 @ObservedObject var preview:PreviewStore
 @Environment(\.dismiss) private var dismiss
 var body:some View {
  NavigationStack {
   VStack(spacing:12) {
    VStack(alignment:.leading,spacing:12) {
     HStack {MorningSun(size:60);Text(appText("Find a routine worth returning to.")).font(.title2.bold()).fixedSize(horizontal:false,vertical:true)}
     Label(appText("Your patterns over 30 days"),systemImage:"calendar")
     Label(appText("A weekly goal you choose"),systemImage:"sun.max")
     Label(appText("An energetic seven-morning workout path"),systemImage:"bolt")
     Text(appText("Try all features free for 30 days. No card needed. Subscribe only when you choose."))
      .font(.footnote).foregroundStyle(MorningTheme.muted)
     if preview.access == .preview,preview.hasStarted {Text(appText("%lld free days left. No automatic charge.",count:preview.remainingDays)).font(.footnote)}
     Text(appText("Starter paths, earned mornings and basic alarms stay free. Your data stays on this device.")).font(.footnote).foregroundStyle(MorningTheme.muted)
     if store.isPro {Text(appText("Pro is active")).foregroundStyle(MorningTheme.success)}
     if let message=store.message {Text(message).font(.footnote).accessibilityIdentifier("purchaseMessage")}
    }.padding(.horizontal,24)
    SubscriptionStoreView(productIDs:SubscriptionStore.productIDs)
     .subscriptionStoreControlStyle(.prominentPicker)
     .storeButton(.visible,for:.restorePurchases)
     .storeButton(.visible,for:.redeemCode)
     .subscriptionStorePolicyDestination(for:.privacyPolicy) {MorningPrivacyView()}
     .subscriptionStorePolicyDestination(url:URL(string:"https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!,for:.termsOfService)
     .onInAppPurchaseCompletion {_,result in
      if case .success(let purchase)=result {await store.complete(purchase)}
     }
   }.background(MorningTheme.canvas).foregroundStyle(MorningTheme.ink).tint(MorningTheme.accent)
    .navigationTitle("HiMorning Pro").navigationBarTitleDisplayMode(.inline)
    .toolbar {ToolbarItem(placement:.cancellationAction) {Button(appText("Close")) {dismiss()}.accessibilityIdentifier("closePro")}}
    .task {await store.refresh()}
    .onDisappear {Task {await store.refresh()}}
  }
 }
}

struct MorningPrivacyView:View {
 var body:some View {
  ScrollView {
   VStack(alignment:.leading,spacing:20) {
    Text(appText("Your morning history and goal are saved on this device. New entries keep the most recent 31 days, so monthly ratings include every day of the month."))
    Text(appText("Apple handles subscription payments. HiMorning uses verified purchases to unlock Pro and does not receive your card or wallet details."))
    Text(appText("Camera challenges are checked on this iPhone. Video and sound are not saved or uploaded."))
   }.padding(24)
  }.background(MorningTheme.canvas).foregroundStyle(MorningTheme.ink).navigationTitle(appText("Privacy policy"))
 }
}
