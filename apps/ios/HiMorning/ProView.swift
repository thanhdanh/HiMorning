import SwiftUI
import StoreKit

struct ProView:View {
 @ObservedObject var store:SubscriptionStore
 @ObservedObject var preview:PreviewStore
 @ObservedObject var ads:RewardedAdStore
 @Environment(\.dismiss) private var dismiss
 @Environment(\.purchase) private var purchase
 @State private var catalogRequest=0
 @State private var showsManagement=false
 @State private var selectedID=SubscriptionStore.monthlyProductID
 @State private var purchasing=false
 private let termsURL=URL(string:"https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

 var body:some View {
  NavigationStack {
   ScrollView {
    VStack(alignment:.leading,spacing:22) {
     benefits
     if store.isPro {
      Label(appText("Pro is active"),systemImage:"checkmark.circle.fill").foregroundStyle(MorningTheme.success)
       .font(.subheadline.weight(.semibold))
      Button(appText("Manage subscription")) {showsManagement=true}
       .buttonStyle(MorningButtonStyle()).accessibilityIdentifier("manageSubscription")
     } else {
      plans
     }
     subscriptionActions
    }.frame(maxWidth:530).padding(24).frame(maxWidth:.infinity)
   }
   .background(MorningTheme.canvas).foregroundStyle(MorningTheme.ink).tint(MorningTheme.accent)
   .navigationTitle("HiMorning Pro").navigationBarTitleDisplayMode(.inline)
   .toolbar {
    ToolbarItem(placement:.cancellationAction) {
     Button(appText("Close")) {dismiss()}.disabled(purchasing).accessibilityIdentifier("closePro")
    }
   }
   .interactiveDismissDisabled(purchasing)
   .manageSubscriptionsSheet(isPresented:$showsManagement)
   .onChange(of:showsManagement) {_,presented in if !presented {Task {await store.refresh()}}}
   .task(id:catalogRequest) {await store.loadProducts()}
   .task {await store.refresh()}
  }
 }

 private var benefits:some View {
  VStack(alignment:.leading,spacing:14) {
   Text(appText("More ways to wake up")).modifier(MorningTypography.heading(size:24))
    .accessibilityAddTraits(.isHeader).accessibilityIdentifier("proHeadline")
   VStack(alignment:.leading,spacing:12) {
    benefit("More challenges and sounds","Choose push-ups, jumping jacks, and more alarm sounds.",icon:"bell.badge")
    Divider()
    benefit("Track your mornings","See your last 30 days and set your own weekly goal.",icon:"chart.bar")
    Divider()
    benefit("7 mornings of movement","Follow a routine with a different activity on some days.",icon:"figure.walk")
   }.padding(16).background(MorningTheme.surface,in:RoundedRectangle(cornerRadius:18))
    .overlay {RoundedRectangle(cornerRadius:18).strokeBorder(MorningTheme.line)}
   if !store.isPro,preview.access == .preview {
    Text(preview.hasStarted
      ? appText("%lld free days left. No automatic charge.",count:preview.remainingDays)
      : appText("Your 30-day preview starts when you save your first alarm. No card needed."))
     .font(.footnote).foregroundStyle(MorningTheme.muted)
   }
  }
 }

 private func benefit(_ title:String,_ description:String,icon:String)->some View {
  HStack(alignment:.top,spacing:12) {
   Image(systemName:icon).font(.body.weight(.semibold)).foregroundStyle(MorningTheme.proInk)
    .frame(width:36,height:36).background(MorningTheme.proSurface,in:RoundedRectangle(cornerRadius:10))
    .overlay {RoundedRectangle(cornerRadius:10).strokeBorder(MorningTheme.proGoldEdge.opacity(0.4),lineWidth:0.75)}
    .accessibilityHidden(true)
   VStack(alignment:.leading,spacing:3) {
    Text(appText(title)).font(.subheadline.weight(.semibold))
    Text(appText(description)).font(.footnote).foregroundStyle(MorningTheme.muted)
   }.fixedSize(horizontal:false,vertical:true)
  }.accessibilityElement(children:.combine)
 }

 @ViewBuilder private var plans:some View {
  switch store.catalog {
  case .available(let products):
   if let selected=products.first(where:{$0.id == selectedID}) ?? products.first {
    let monthly=products.first {$0.id == SubscriptionStore.monthlyProductID}
    VStack(alignment:.leading,spacing:10) {
     Text(appText("Choose a plan")).font(.headline).accessibilityAddTraits(.isHeader)
     ForEach(products) {product in
      planRow(product,selected:product.id == selected.id,monthly:monthly)
     }
     if products.count < SubscriptionStore.productIDs.count {
      Text(appText("One plan is unavailable right now.")).font(.footnote).foregroundStyle(MorningTheme.muted)
      Button(appText("Try again")) {catalogRequest+=1}.frame(minHeight:44).buttonStyle(.plain)
     }
     Text(appText("Renews automatically. Manage or cancel in App Store settings."))
      .font(.footnote).foregroundStyle(MorningTheme.muted)
     Button {
      guard !purchasing else {return}
      purchasing=true
      Task {await buy(selected)}
     } label: {
      if purchasing {ProgressView(appText("Opening the App Store…"))}
      else {Text(appText("Subscribe to Pro"))}
     }.buttonStyle(MorningButtonStyle()).disabled(purchasing || store.isRestoring)
      .accessibilityIdentifier("subscribeToPro")
     Text(appText("Basic alarms and Reach up are free.")).font(.footnote).foregroundStyle(MorningTheme.muted)
    }
   }
  case .loading:
   VStack(spacing:10) {
    ForEach(0..<2,id:\.self) { _ in
     RoundedRectangle(cornerRadius:14).fill(MorningTheme.soft).frame(height:68)
    }
   }.accessibilityIdentifier("subscriptionLoading")
  case .unavailable:
   unavailable(appText("Plans are unavailable right now."))
  case .failed:
   unavailable(appText("Could not load plans. Check your connection."))
  }
 }

 private func planRow(_ product:Product,selected:Bool,monthly:Product?)->some View {
  let annual=product.id == SubscriptionStore.annualProductID
  let savings=annual ? annualSavings(for:product,monthly:monthly) : nil
  return Button {
   selectedID=product.id
  } label: {
   HStack(alignment:.center,spacing:12) {
    VStack(alignment:.leading,spacing:4) {
     if let savings {
      ViewThatFits(in:.horizontal) {
       HStack(spacing:8) {
        planTitle(annual:true).fixedSize()
        savingsBadge(savings).fixedSize()
       }
       VStack(alignment:.leading,spacing:4) {
        planTitle(annual:true)
        savingsBadge(savings)
       }
      }
     } else {
      planTitle(annual:annual)
     }
     Text(String(format:appText(annual ? "%@ per year" : "%@ per month"),locale:appLocale(),product.displayPrice))
      .font(.headline).monospacedDigit()
     if annual,product.price > 0 {
      let equivalent=(product.price/12).formatted(product.priceFormatStyle)
      Text(String(format:appText("Equivalent to %@ per month"),locale:appLocale(),equivalent))
       .font(.footnote).foregroundStyle(MorningTheme.muted)
     }
    }.frame(maxWidth:.infinity,alignment:.leading)
    Image(systemName:selected ? "checkmark.circle.fill" : "circle")
     .foregroundStyle(selected ? MorningTheme.accent : MorningTheme.muted)
     .accessibilityHidden(true)
   }.padding(14).foregroundStyle(MorningTheme.ink)
    .background(selected ? MorningTheme.soft : MorningTheme.surface,in:RoundedRectangle(cornerRadius:14))
    .overlay {RoundedRectangle(cornerRadius:14).strokeBorder(selected ? MorningTheme.accent : MorningTheme.line,lineWidth:selected ? 1.5 : 1)}
    .contentShape(RoundedRectangle(cornerRadius:14))
  }.buttonStyle(.plain).disabled(purchasing).accessibilityAddTraits(selected ? .isSelected : [])
   .accessibilityIdentifier(annual ? "annualProPlan" : "monthlyProPlan")
 }

 private func planTitle(annual:Bool)->some View {
  Text(appText(annual ? "Yearly" : "Monthly")).font(.subheadline.weight(.semibold))
 }

 private func savingsBadge(_ percentage:Decimal)->some View {
  let formatted=percentage.formatted(.percent.precision(.fractionLength(0)).rounded(rule:.down).locale(appLocale()))
  return Text(String(format:appText("Save %@"),locale:appLocale(),formatted))
   .font(.caption2.weight(.semibold))
   .fixedSize(horizontal:false,vertical:true)
   .padding(.horizontal,8).padding(.vertical,3)
   .foregroundStyle(MorningTheme.proInk).background(MorningTheme.proGoldLight,in:Capsule())
   .accessibilityLabel(String(format:appText("Save %@ compared with the monthly plan"),locale:appLocale(),formatted))
 }

 private func annualSavings(for annual:Product,monthly:Product?)->Decimal? {
  guard let monthly,annual.price > 0,
        annual.priceFormatStyle.currencyCode == monthly.priceFormatStyle.currencyCode else {return nil}
  let monthlyTotal=monthly.price*12
  guard monthlyTotal > annual.price else {return nil}
  let savings=(monthlyTotal-annual.price)/monthlyTotal
  return savings >= Decimal(sign:.plus,exponent:-2,significand:1) ? savings : nil
 }

 private func buy(_ product:Product) async {
  defer {purchasing=false}
  do {await store.complete(try await purchase(product))}
  catch StoreKitError.userCancelled {}
  catch {store.reportPurchaseFailure()}
 }

 private var subscriptionActions:some View {
  VStack(alignment:.leading,spacing:4) {
   if let message=store.message {
    Text(message).font(.footnote).accessibilityIdentifier("purchaseMessage")
   }
   ViewThatFits(in:.horizontal) {
    HStack(spacing:16) {
     restoreButton
     policyLinks
    }
    VStack(spacing:4) {
     restoreButton
     HStack(spacing:16) {policyLinks}
    }
   }.font(.footnote).foregroundStyle(MorningTheme.muted).frame(maxWidth:.infinity)
  }
 }
 private var restoreButton:some View {
  Button {Task {await store.restorePurchases()}} label: {
   Group {
    if store.isRestoring {ProgressView(appText("Restoring purchases…"))}
    else {Text(appText("Restore purchases"))}
   }.frame(minHeight:44)
  }.buttonStyle(.plain).disabled(store.isRestoring || purchasing).accessibilityIdentifier("restorePurchases")
 }

 private var policyLinks:some View {
  Group {
   NavigationLink {MorningPrivacyView(ads:ads)} label: {Text(appText("Privacy policy")).frame(minHeight:44)}
   Link(appText("Terms of Use"),destination:termsURL).frame(minHeight:44)
  }
 }

 private func unavailable(_ message:String)->some View {
  VStack(alignment:.leading,spacing:8) {
   Text(message).accessibilityIdentifier("subscriptionUnavailable")
   Button(appText("Try again")) {catalogRequest+=1}
    .buttonStyle(MorningButtonStyle()).accessibilityIdentifier("retrySubscriptionLoad")
  }
 }
}

struct MorningPrivacyView:View {
 @ObservedObject var ads:RewardedAdStore
 @State private var adPrivacyStatus:String?
 private let privacyPolicyURL=URL(string:"https://himorning-support.onrender.com/#quyen-rieng-tu")!

 var body:some View {
  ScrollView {
   VStack(alignment:.leading,spacing:20) {
    Link(destination:privacyPolicyURL) {
     Text(appText("Read the full privacy policy")).underline().frame(minHeight:44)
    }.accessibilityIdentifier("externalPrivacyPolicy")
    Text(appText("Your morning history is saved on this device. HiMorning keeps up to 31 days of entries."))
    Text(appText("Apple handles subscription payments. HiMorning uses verified purchases to unlock Pro and does not receive your card or wallet details."))
    Text(appText("Camera challenges are checked on this iPhone. Video and sound are not saved or uploaded."))
    if ads.isConfigured {
     Text(appText("Optional ads use Google AdMob. HiMorning does not send camera images, speech or morning history to AdMob."))
     if ads.privacyOptionsRequired {
      Button(appText("Ad privacy choices")) {
       Task {
        do {try await ads.showPrivacyOptions();adPrivacyStatus=nil}
        catch {adPrivacyStatus=error.localizedDescription}
       }
      }.disabled(ads.busy)
     }
     if let adPrivacyStatus {Text(adPrivacyStatus).font(.footnote)}
    }
   }.padding(24)
  }.background(MorningTheme.canvas).foregroundStyle(MorningTheme.ink).navigationTitle(appText("Privacy policy"))
   .task {if ads.isConfigured {try? await ads.refreshConsent()}}
 }
}
