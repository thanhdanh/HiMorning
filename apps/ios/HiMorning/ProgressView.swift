import SwiftUI
import StoreKit
import HiMorningCore

struct MorningProgressView:View {
 @ObservedObject var model:PilotModel
 @ObservedObject var store:SubscriptionStore
 @Environment(\.dismiss) private var dismiss
 @Environment(\.dynamicTypeSize) private var typeSize
 @State private var pro=false
 @State private var manage=false
 private var week:[MorningScore] {model.journal?.weeklyScores() ?? []}
 private var days:Int {week.filter {$0.completed>0}.count}
 private var goal:Int {model.access.weeklyGoal(stored:model.journal?.weeklyGoal ?? 3)}
 private var entries:[MorningEntry] {model.journal?.recent(days:model.access.historyDays) ?? []}
 var body:some View {
  NavigationStack {
   ScrollView {
    VStack(alignment:.leading,spacing:24) {
     if let error=model.progressError {
      Label(error,systemImage:"exclamationmark.circle").font(.subheadline).foregroundStyle(MorningTheme.muted)
     }
     if model.access.hasFullAccess,let month=model.journal?.monthlyScore() {
      monthlyCard(month)
      weeklyCard
      DisclosureGroup(appText("Past 30 days")) {
       if entries.isEmpty {Text(appText("Your next morning is a fresh start.")).font(.subheadline).foregroundStyle(MorningTheme.muted)}
       ForEach(entries) {entry in
        HStack(alignment:.top,spacing:12) {
         Image(systemName:entry.outcome.progressIcon).foregroundStyle(MorningTheme.accent).accessibilityHidden(true)
         VStack(alignment:.leading,spacing:4) {
          Text(entry.date,format:.dateTime.day().month().hour().minute().locale(appLocale())).font(.subheadline.weight(.medium))
          Text(entry.outcome.progressTitle).font(.footnote).foregroundStyle(MorningTheme.muted)
         }
         Spacer(minLength:0)
        }.frame(maxWidth:.infinity,alignment:.leading).padding(.top,12)
       }
      }.font(.headline).padding(20).background(MorningTheme.surface,in:RoundedRectangle(cornerRadius:24))
      ShareLink(item:appText(days == 1 ? "%lld morning with a completed challenge in the past 7 days." : "%lld mornings with completed challenges in the past 7 days.",count:days)) {
       Label(appText("Share my progress"),systemImage:"square.and.arrow.up").frame(maxWidth:.infinity)
      }.buttonStyle(MorningButtonStyle(primary:false))
     }
     if !model.access.hasFullAccess {
      VStack(alignment:.leading,spacing:16) {
       Label(appText("Your progress"),systemImage:"chart.bar.xaxis").font(.title2.bold())
       Text(appText("Your free preview has ended. Basic alarms and challenges stay free. Pro unlocks your progress, Focused mode and more sounds.")).font(.subheadline).foregroundStyle(MorningTheme.muted)
       Button(appText("Explore Pro")) {pro=true}.buttonStyle(MorningButtonStyle()).accessibilityIdentifier("explorePro")
      }.padding(24).background(MorningTheme.surface,in:RoundedRectangle(cornerRadius:24))
     } else if store.isPro {
      Button(appText("Manage subscription")) {manage=true}.font(.subheadline).frame(maxWidth:.infinity,minHeight:44)
     }
    }.padding(20)
   }.background(MorningTheme.canvas.ignoresSafeArea()).foregroundStyle(MorningTheme.ink).tint(MorningTheme.accent)
    .navigationTitle(appText("Your progress")).navigationBarTitleDisplayMode(.inline)
    .toolbar {ToolbarItem(placement:.cancellationAction) {Button(appText("Close")) {dismiss()}.accessibilityIdentifier("closeProgress")}}
    .sheet(isPresented:$pro) {ProView(store:store,preview:model.preview)}
    .manageSubscriptionsSheet(isPresented:$manage)
    .task {await store.refresh()}
  }
 }
 private func monthlyCard(_ month:MorningScore)->some View {
  VStack(alignment:.leading,spacing:18) {
   HStack(alignment:.firstTextBaseline) {
    Text(appText("This month")).font(.headline)
    Spacer(minLength:8)
    Text(month.date,format:.dateTime.month(.wide).year().locale(appLocale())).font(.subheadline)
   }
   Label(month.rating.title,systemImage:month.score == nil ? "sunrise" : "medal")
    .font(.title2.bold()).fixedSize(horizontal:false,vertical:true).accessibilityIdentifier("monthlyRating")
   HStack(alignment:.firstTextBaseline,spacing:6) {
    Text(month.score.map {String($0)} ?? "—").font(.system(.largeTitle,design:.rounded).weight(.bold)).monospacedDigit()
     .accessibilityIdentifier("monthlyScore")
    Text(appText("/ 100 points")).font(.subheadline)
   }
   ProgressView(value:Double(month.score ?? 0),total:100).tint(MorningTheme.onYellow)
    .accessibilityLabel(appText("Monthly consistency"))
    .accessibilityValue(month.score.map {"\($0)/100"} ?? appText("No record"))
   if month.attempts>0 {
    Text(String(format:appText("%lld of %lld challenges completed"),locale:appLocale(),Int64(month.completed),Int64(month.attempts))).font(.subheadline.weight(.medium))
   } else {
    Text(appText("Complete your first challenge to see your rating.")).font(.subheadline.weight(.medium))
   }
   Text(appText("Based on recorded mornings this month. Days without a record are not scored."))
    .font(.footnote).fixedSize(horizontal:false,vertical:true)
  }.padding(24).frame(maxWidth:.infinity,alignment:.leading)
   .foregroundStyle(MorningTheme.onYellow).background(MorningTheme.hero,in:RoundedRectangle(cornerRadius:24))
 }
 private var weeklyCard:some View {
  VStack(alignment:.leading,spacing:20) {
   VStack(alignment:.leading,spacing:4) {
    Text(appText("Past 7 days")).font(.title3.bold())
    Text(appText("Your morning scores")).font(.subheadline).foregroundStyle(MorningTheme.muted)
   }
   if typeSize.isAccessibilitySize {
    ForEach(week) {day in
     HStack {
      Text(day.date,format:.dateTime.weekday(.abbreviated).day().month().locale(appLocale()))
      Spacer(minLength:8)
      Text(day.score.map {"\($0)/100"} ?? "—").bold().monospacedDigit()
     }.accessibilityElement(children:.ignore).accessibilityLabel(daySummary(day))
      .accessibilityIdentifier("morningScore-\(Calendar.current.component(.day,from:day.date))")
    }
   } else {
    HStack(alignment:.bottom,spacing:6) {
     ForEach(week) {day in
      VStack(spacing:8) {
       Text(day.score.map {String($0)} ?? "—").font(.subheadline.bold()).monospacedDigit()
       ZStack(alignment:.bottom) {
        Capsule().fill(MorningTheme.soft)
        if let score=day.score {
         Capsule().fill(score == 100 ? MorningTheme.success : MorningTheme.accent)
          .frame(height:max(4,CGFloat(score)*0.72))
        }
       }.frame(width:18,height:72)
       Text(day.date,format:.dateTime.weekday(.abbreviated).locale(appLocale())).font(.caption2)
       Text(day.date,format:.dateTime.day().locale(appLocale())).font(.caption.weight(.semibold))
      }.frame(maxWidth:.infinity).foregroundStyle(day.score == nil ? MorningTheme.muted : MorningTheme.ink)
       .accessibilityElement(children:.ignore).accessibilityLabel(daySummary(day))
       .accessibilityIdentifier("morningScore-\(Calendar.current.component(.day,from:day.date))")
     }
    }
   }
   Text(appText("100 for completing a challenge, 0 for skipping. Multiple attempts in a morning are averaged. — means no record."))
    .font(.footnote).foregroundStyle(MorningTheme.muted).fixedSize(horizontal:false,vertical:true)
   Divider()
   HStack {
    Text(appText("Weekly goal")).font(.headline)
    Spacer(minLength:8)
    Text("\(days) / \(goal)").font(.headline).monospacedDigit()
   }
   ProgressView(value:Double(min(days,goal)),total:Double(goal)).tint(MorningTheme.success)
    .accessibilityLabel(appText("Weekly goal")).accessibilityValue("\(days)/\(goal)")
   Picker(appText("Weekly goal"),selection:Binding(get:{goal},set:{model.setGoal($0)})) {
    ForEach(1...7,id:\.self) {value in Text(morningCountText(value)).tag(value)}
   }.disabled(model.journal == nil)
   Text(appText("Only completed challenges count. Confirming you are awake or stopping the alarm earns no points."))
    .font(.footnote).foregroundStyle(MorningTheme.muted)
   DisclosureGroup(appText("How ratings work")) {
    Text(appText("Excellent: 90–100 · Consistent: 75–89 · Building: 50–74 · Getting started: 0–49. Your monthly score is the percentage of recorded challenges completed."))
     .font(.footnote).foregroundStyle(MorningTheme.muted).padding(.top,8)
   }.font(.subheadline)
  }.padding(20).background(MorningTheme.surface,in:RoundedRectangle(cornerRadius:24))
 }
 private func daySummary(_ day:MorningScore)->String {
  let date=day.date.formatted(.dateTime.weekday(.wide).day().month().locale(appLocale()))
  let score=day.score.map {String(format:appText("%lld out of 100 points"),locale:appLocale(),Int64($0))} ?? appText("No record")
  return "\(date), \(score)"
 }
}

extension ConsistencyRating {
 var title:String {
  switch self {
  case .noData:return appText("A fresh start")
  case .gettingStarted:return appText("Getting started")
  case .building:return appText("Building consistency")
  case .consistent:return appText("Consistent")
  case .excellent:return appText("Excellent")
  }
 }
}

extension WakeOutcome {
 var progressIcon:String {
  switch self {
  case .openaiVerified,.aiVerified,.localCompleted:return "checkmark.circle.fill"
  case .selfConfirmed,.dismissed:return "minus.circle"
  }
 }
 var progressTitle:String {
  switch self {
  case .openaiVerified,.aiVerified:return appText("AI checked")
  case .selfConfirmed:return appText("You confirmed")
  case .localCompleted:return appText("Local challenge completed")
  case .dismissed:return appText("Stopped")
  }
 }
}
