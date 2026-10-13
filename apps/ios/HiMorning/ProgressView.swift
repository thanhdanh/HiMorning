import SwiftUI
import StoreKit
import HiMorningCore

struct MorningProgressView:View {
 @ObservedObject var model:PilotModel
 @ObservedObject var store:SubscriptionStore
 @Environment(\.dismiss) private var dismiss
 @State private var pro=false
 @State private var clear=false
 @State private var manage=false
 private var days:Int {model.journal?.completedDays(inLast:7) ?? 0}
 private var goal:Int {store.access.weeklyGoal(stored:model.journal?.weeklyGoal ?? 3)}
 private var entries:[MorningEntry] {model.journal?.recent(days:store.access.historyDays) ?? []}
 var body:some View {
  NavigationStack {
   List {
    Section {
     Text(appText("Past 7 days")).font(.headline)
     Text(morningCountText(days)).font(.largeTitle.bold())
     ProgressView(value:Double(min(days,goal)),total:Double(goal)).tint(MorningTheme.accent)
     Picker(appText("Weekly goal"),selection:Binding(get:{goal},set:{model.setGoal($0)})) {
      ForEach(1...7,id:\.self) {value in Text(morningCountText(value)).tag(value)}
     }.disabled(!store.isPro || model.journal == nil)
     Text(appText("Self-confirmed mornings count too. Stopping an alarm does not count as completion.")).font(.footnote).foregroundStyle(MorningTheme.muted)
    }
    if let error=model.progressError {Section {Text(error).foregroundStyle(MorningTheme.muted)}}
    if !store.isPro {
     Section {
      Button(appText("Explore Pro")) {pro=true}.accessibilityIdentifier("explorePro")
      Text(appText("Free shows 7 days and a goal of 3 mornings. Pro adds 30-day history and a goal you choose.")).font(.footnote).foregroundStyle(MorningTheme.muted)
     }
    } else {Section {Button(appText("Manage subscription")) {manage=true}}}
    Section(appText(store.isPro ? "Past 30 days" : "Past 7 days")) {
     if entries.isEmpty {Text(appText("Your next morning is a fresh start.")).foregroundStyle(MorningTheme.muted)}
     ForEach(entries) {entry in
      VStack(alignment:.leading,spacing:4) {
       Text(entry.date,format:.dateTime.day().month().hour().minute().locale(appLocale()))
       Text(entry.outcome.progressTitle).font(.subheadline).foregroundStyle(MorningTheme.muted)
      }
     }
    }
    Section {
     ShareLink(item:appText(days == 1 ? "%lld morning in the past 7 days with HiMorning. A fresh start, at my pace." : "%lld mornings in the past 7 days with HiMorning. A fresh start, at my pace.",count:days)) {
      Label(appText("Share my progress"),systemImage:"square.and.arrow.up")
     }
     Button(appText("Clear history"),role:.destructive) {clear=true}.disabled(model.journal == nil)
    }
   }.scrollContentBackground(.hidden).background(MorningTheme.canvas).foregroundStyle(MorningTheme.ink).tint(MorningTheme.accent)
    .navigationTitle(appText("Your progress")).navigationBarTitleDisplayMode(.inline)
    .toolbar {ToolbarItem(placement:.cancellationAction) {Button(appText("Close")) {dismiss()}.accessibilityIdentifier("closeProgress")}}
    .sheet(isPresented:$pro) {ProView(store:store)}
    .manageSubscriptionsSheet(isPresented:$manage)
    .confirmationDialog(appText("Clear all morning history? Your alarms stay as they are."),isPresented:$clear,titleVisibility:.visible) {
     Button(appText("Clear history"),role:.destructive) {model.clearHistory()}
     Button(appText("Cancel"),role:.cancel) {}
    }
    .task {await store.refresh()}
  }
 }
}

extension WakeOutcome {
 var progressTitle:String {
  switch self {
  case .openaiVerified:return appText("AI checked")
  case .selfConfirmed:return appText("You confirmed")
  case .dismissed:return appText("Stopped")
  }
 }
}
