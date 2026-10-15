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
 private var goal:Int {model.access.weeklyGoal(stored:model.journal?.weeklyGoal ?? 3)}
 private var entries:[MorningEntry] {model.journal?.recent(days:model.access.historyDays) ?? []}
 var body:some View {
  NavigationStack {
   List {
    if model.access.hasFullAccess {Section {
     Text(appText("Past 7 days")).font(.headline)
     Text(morningCountText(days)).font(.largeTitle.bold())
     ProgressView(value:Double(min(days,goal)),total:Double(goal)).tint(MorningTheme.accent)
     Picker(appText("Weekly goal"),selection:Binding(get:{goal},set:{model.setGoal($0)})) {
      ForEach(1...7,id:\.self) {value in Text(morningCountText(value)).tag(value)}
     }.disabled(model.journal == nil)
     Text(appText("Self-confirmed mornings count too. Stopping an alarm does not count as completion.")).font(.footnote).foregroundStyle(MorningTheme.muted)
    }}
    if let error=model.progressError {Section {Text(error).foregroundStyle(MorningTheme.muted)}}
    if !model.access.hasFullAccess {
     Section {
      Button(appText("Explore Pro")) {pro=true}.accessibilityIdentifier("explorePro")
      Text(appText("Your free preview has ended. Basic alarms and challenges stay free. Pro unlocks your progress, Focused mode and more sounds.")).font(.footnote).foregroundStyle(MorningTheme.muted)
     }
    } else if store.isPro {Section {Button(appText("Manage subscription")) {manage=true}}}
    if model.access.hasFullAccess {Section(appText("Past 30 days")) {
     if entries.isEmpty {Text(appText("Your next morning is a fresh start.")).foregroundStyle(MorningTheme.muted)}
     ForEach(entries) {entry in
      VStack(alignment:.leading,spacing:4) {
       Text(entry.date,format:.dateTime.day().month().hour().minute().locale(appLocale()))
       Text(entry.outcome.progressTitle).font(.subheadline).foregroundStyle(MorningTheme.muted)
      }
     }
    }}
    Section {
     if model.access.hasFullAccess {ShareLink(item:appText(days == 1 ? "%lld morning in the past 7 days with HiMorning. A fresh start, at my pace." : "%lld mornings in the past 7 days with HiMorning. A fresh start, at my pace.",count:days)) {
      Label(appText("Share my progress"),systemImage:"square.and.arrow.up")
     }}
     Button(appText("Clear history"),role:.destructive) {clear=true}.disabled(model.journal == nil)
    }
   }.scrollContentBackground(.hidden).background(MorningTheme.canvas).foregroundStyle(MorningTheme.ink).tint(MorningTheme.accent)
    .navigationTitle(appText("Your progress")).navigationBarTitleDisplayMode(.inline)
    .toolbar {ToolbarItem(placement:.cancellationAction) {Button(appText("Close")) {dismiss()}.accessibilityIdentifier("closeProgress")}}
    .sheet(isPresented:$pro) {ProView(store:store,preview:model.preview)}
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
  case .localCompleted:return appText("Local challenge completed")
  case .dismissed:return appText("Stopped")
  }
 }
}
