import SwiftUI
import StoreKit

struct ProView:View {
 @ObservedObject var store:SubscriptionStore
 @Environment(\.dismiss) private var dismiss
 var body:some View {
  NavigationStack {
   VStack(spacing:12) {
    VStack(alignment:.leading,spacing:12) {
     HStack {MorningSun(size:60);Text(appText("More room for your progress.")).font(.title2.bold())}
     Label(appText("30-day morning history"),systemImage:"calendar")
     Label(appText("A weekly goal you choose"),systemImage:"sun.max")
     Text(appText("Basic alarms and Stop stay free. History stays on this device.")).font(.footnote).foregroundStyle(MorningTheme.muted)
     if store.isPro {Text(appText("Pro is active")).foregroundStyle(MorningTheme.success)}
     if let message=store.message {Text(message).font(.footnote).accessibilityIdentifier("purchaseMessage")}
    }.padding(.horizontal,24)
    SubscriptionStoreView(productIDs:[SubscriptionStore.monthlyProductID])
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
  }
 }
}

struct MorningPrivacyView:View {
 var body:some View {
  ScrollView {
   VStack(alignment:.leading,spacing:20) {
    Text(appText("Your morning history and goal are saved on this device. New entries keep the most recent 30 days. You can clear all history from Progress at any time."))
    Text(appText("Apple handles subscription payments. HiMorning uses verified purchases to unlock Pro and does not receive your card or wallet details."))
    Text(appText("Cloud challenges use a guest Firebase account. Movement photos are sent to OpenAI only after you agree. Progress history contains dates and outcomes, not camera photos or audio."))
    Link(appText("OpenAI data policies"),destination:URL(string:"https://platform.openai.com/docs/guides/your-data")!)
   }.padding(24)
  }.background(MorningTheme.canvas).foregroundStyle(MorningTheme.ink).navigationTitle(appText("Privacy policy"))
 }
}
