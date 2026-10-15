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
 @State private var selectedDate=Calendar.current.startOfDay(for:Date())
 private var week:[MorningScore] {model.journal?.weeklyScores() ?? []}
 private var days:Int {week.filter {$0.completed>0}.count}
 private var goal:Int {model.access.weeklyGoal(stored:model.journal?.weeklyGoal ?? 3)}
 private var entries:[MorningEntry] {model.journal?.recent(days:model.access.historyDays) ?? []}
 private var completedEntries:[MorningEntry] {entries.filter {[.localCompleted,.openaiVerified,.aiVerified].contains($0.outcome)}}
 private var selectedDay:MorningScore? {week.first {Calendar.current.isDate($0.date,inSameDayAs:selectedDate)} ?? week.last}
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
      modeSummary
      weeklyGoalCard
      DisclosureGroup(appText("Past 30 days")) {
       if entries.isEmpty {Text(appText("Your next morning is a fresh start.")).font(.subheadline).foregroundStyle(MorningTheme.muted)}
       ForEach(entries) {entry in entryRow(entry,showDate:true).padding(.top,16)}
      }.font(.headline).padding(20).background(MorningTheme.surface,in:RoundedRectangle(cornerRadius:24))
       .overlay {RoundedRectangle(cornerRadius:24).strokeBorder(MorningTheme.line)}
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
  VStack(alignment:.leading,spacing:14) {
   HStack(alignment:.firstTextBaseline) {
    Text(appText("This month")).font(.headline)
    Spacer(minLength:8)
    Text(month.date,format:.dateTime.month(.wide).year().locale(appLocale())).font(.caption).foregroundStyle(MorningTheme.muted)
   }
   ViewThatFits(in:.horizontal) {
    HStack(alignment:.firstTextBaseline,spacing:16) {monthlyMetric(month);Spacer(minLength:0);monthlyRating(month)}
    VStack(alignment:.leading,spacing:8) {monthlyMetric(month);monthlyRating(month)}
   }
   ProgressView(value:Double(month.score ?? 0),total:100).tint(MorningTheme.success)
    .accessibilityHidden(true)
   if month.attempts>0 {
    Text(String(format:appText("%lld of %lld challenges completed"),locale:appLocale(),Int64(month.completed),Int64(month.attempts))).font(.subheadline)
   } else {
    Text(appText("Complete your first challenge to see your rating.")).font(.subheadline)
   }
  }.padding(20).frame(maxWidth:.infinity,alignment:.leading)
   .background(MorningTheme.surface,in:RoundedRectangle(cornerRadius:24))
   .overlay {RoundedRectangle(cornerRadius:24).strokeBorder(MorningTheme.line)}
 }
 private func monthlyMetric(_ month:MorningScore)->some View {
  HStack(alignment:.firstTextBaseline,spacing:5) {
   Text(month.score.map {String($0)} ?? "—").font(.system(.largeTitle,design:.rounded).weight(.bold)).monospacedDigit().accessibilityIdentifier("monthlyScore")
   Text(appText("/ 100 points")).font(.caption).foregroundStyle(MorningTheme.muted)
  }.fixedSize(horizontal:true,vertical:false)
 }
 private func monthlyRating(_ month:MorningScore)->some View {
  Text(month.rating.title).font(.subheadline.weight(.semibold)).foregroundStyle(month.score == nil ? MorningTheme.muted : MorningTheme.success)
   .fixedSize(horizontal:false,vertical:true).accessibilityIdentifier("monthlyRating")
 }
 private var weeklyCard:some View {
  VStack(alignment:.leading,spacing:16) {
   Text(appText("Past 7 days")).font(.headline).padding(.horizontal,8)
   if typeSize.isAccessibilitySize {
    ForEach(week) {day in
     dayButton(day) {
      HStack(alignment:.top,spacing:12) {
       VStack(alignment:.leading,spacing:6) {
        Text(day.date,format:.dateTime.weekday(.abbreviated).day().month().locale(appLocale())).font(.headline)
        Text(dayMode(day)).font(.subheadline).foregroundStyle(MorningTheme.muted)
       }
       Spacer(minLength:0)
       Text(day.score.map {"\($0)/100"} ?? "—").font(.headline).monospacedDigit()
      }.padding(12).frame(maxWidth:.infinity,minHeight:60,alignment:.leading)
     }
    }
   } else {
    HStack(alignment:.top,spacing:0) {
     ForEach(week) {day in
      dayButton(day) {
       VStack(spacing:7) {
        Text(day.score.map {String($0)} ?? "—").font(.caption.weight(.semibold)).monospacedDigit()
        ZStack(alignment:.bottom) {
         Capsule().fill(MorningTheme.line)
         if let score=day.score {
          Capsule().fill(score == 100 ? MorningTheme.success : MorningTheme.accent)
           .frame(height:max(4,CGFloat(score)*0.56))
         }
        }
        .frame(width:12,height:56)
        Text(day.date,format:.dateTime.weekday(.abbreviated).locale(appLocale())).font(.caption2)
        Text(day.date,format:.dateTime.day().locale(appLocale())).font(.subheadline.weight(.semibold))
        Text(dayMode(day,compact:true)).font(.caption2)
         .multilineTextAlignment(.center).fixedSize(horizontal:false,vertical:true).frame(minHeight:30,alignment:.top)
       }.padding(.vertical,10).frame(minWidth:44,maxWidth:.infinity)
      }
     }
    }
   }
   if let day=selectedDay {
    Divider().padding(.horizontal,8)
    VStack(alignment:.leading,spacing:16) {
     Text(day.date,format:.dateTime.weekday(.wide).day().month().locale(appLocale())).font(.subheadline.weight(.semibold))
     if day.entries.isEmpty {
      Text(appText("No challenges recorded")).font(.subheadline).foregroundStyle(MorningTheme.muted)
     }
     ForEach(day.entries) {entry in entryRow(entry,showDate:false)}
    }.padding(.horizontal,8).padding(.bottom,8)
     .accessibilityElement(children:.contain).accessibilityIdentifier("selectedDayChallenges")
   }
  }.padding(12).background(MorningTheme.surface,in:RoundedRectangle(cornerRadius:24))
   .overlay {RoundedRectangle(cornerRadius:24).strokeBorder(MorningTheme.line)}
 }
 private func dayButton<Content:View>(_ day:MorningScore,@ViewBuilder content:()->Content)->some View {
  let selected=Calendar.current.isDate(day.date,inSameDayAs:selectedDate)
  return Button {selectedDate=day.date} label:{
   content().background(selected ? MorningTheme.soft : .clear,in:RoundedRectangle(cornerRadius:14)).contentShape(Rectangle())
  }
   .buttonStyle(.plain).accessibilityLabel(daySummary(day)).accessibilityHint(appText("View this day’s challenges"))
   .accessibilityAddTraits(selected ? .isSelected : [])
   .accessibilityIdentifier("morningScore-\(Calendar.current.component(.day,from:day.date))")
 }
 private func dayMode(_ day:MorningScore,compact:Bool=false)->String {
  let modes=Set(day.entries.compactMap(\.mode))
  if let mode=modes.first {
   let title=modes.count>1 ? appText("Mixed modes") : mode.title
   guard day.entries.contains(where:{$0.mode == nil}) else {return title}
   return title+" · "+(compact ? "—" : appText("Challenge details not recorded"))
  }
  if compact {return "—"}
  return appText(day.entries.isEmpty ? "No challenges recorded" : "Challenge details not recorded")
 }
 private func entryRow(_ entry:MorningEntry,showDate:Bool)->some View {
  HStack(alignment:.top,spacing:12) {
   Image(systemName:entry.outcome.progressIcon).font(.body).foregroundStyle([.localCompleted,.openaiVerified,.aiVerified].contains(entry.outcome) ? MorningTheme.success : MorningTheme.muted)
    .frame(width:20).padding(.top,2).accessibilityHidden(true)
   VStack(alignment:.leading,spacing:5) {
    if showDate {
     Text(entry.date,format:.dateTime.day().month().hour().minute().locale(appLocale())).font(.caption).foregroundStyle(MorningTheme.muted)
    }
    if let challenge=entry.challenge {
     Text(challenge.displayTitle).font(.subheadline.weight(.semibold)).accessibilityIdentifier("historyChallenge-\(entry.id)")
    }
    if let mode=entry.mode {
     Text(mode.title).font(.caption.weight(.medium)).foregroundStyle(MorningTheme.muted).accessibilityIdentifier("historyMode-\(entry.id)")
    }
    if entry.mode == nil || entry.challenge == nil {
     Text(appText("Challenge details not recorded")).font(.caption).foregroundStyle(MorningTheme.muted)
    }
    Text(entry.outcome.progressTitle).font(.caption).foregroundStyle(MorningTheme.muted)
   }.fixedSize(horizontal:false,vertical:true)
   Spacer(minLength:0)
  }.frame(maxWidth:.infinity,alignment:.leading)
 }
 private var modeSummary:some View {
  VStack(alignment:.leading,spacing:16) {
   VStack(alignment:.leading,spacing:5) {
    Text(appText("Challenge modes")).font(.headline)
    Text(appText("Completed challenges")+" · "+appText("Past 30 days")).font(.caption).foregroundStyle(MorningTheme.muted)
   }
   ForEach([WakeMode.gentle,.balanced,.focused],id:\.self) {mode in
    HStack(spacing:10) {
     Image(systemName:mode.icon).foregroundStyle(MorningTheme.muted).frame(width:20).accessibilityHidden(true)
     Text(mode.title).font(.subheadline)
     Spacer(minLength:8)
     Text("\(completedEntries.filter {$0.mode == mode}.count)").font(.subheadline.weight(.semibold)).monospacedDigit()
    }.accessibilityElement(children:.combine)
   }
   let unknown=completedEntries.filter {$0.mode == nil}.count
   if unknown>0 {
    Divider()
    HStack(alignment:.top,spacing:12) {
     Text(appText("Challenge details not recorded")).font(.caption).foregroundStyle(MorningTheme.muted)
     Spacer(minLength:0)
     Text("\(unknown)").font(.subheadline.weight(.semibold)).monospacedDigit()
    }.accessibilityElement(children:.combine)
   }
  }.padding(20).background(MorningTheme.surface,in:RoundedRectangle(cornerRadius:24))
   .overlay {RoundedRectangle(cornerRadius:24).strokeBorder(MorningTheme.line)}
 }
 private var weeklyGoalCard:some View {
  VStack(alignment:.leading,spacing:16) {
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
   DisclosureGroup(appText("How ratings work")) {
    VStack(alignment:.leading,spacing:10) {
     Text(appText("100 for completing a challenge, 0 for skipping. Multiple attempts in a morning are averaged. — means no record."))
     Text(appText("Only completed challenges count. Confirming you are awake or stopping the alarm earns no points."))
     Text(appText("Based on recorded mornings this month. Days without a record are not scored."))
     Text(appText("Excellent: 90–100 · Consistent: 75–89 · Building: 50–74 · Getting started: 0–49. Your monthly score is the percentage of recorded challenges completed."))
    }.font(.footnote).foregroundStyle(MorningTheme.muted).padding(.top,8)
   }.font(.subheadline)
  }.padding(20).background(MorningTheme.surface,in:RoundedRectangle(cornerRadius:24))
   .overlay {RoundedRectangle(cornerRadius:24).strokeBorder(MorningTheme.line)}
 }
 private func daySummary(_ day:MorningScore)->String {
  let date=day.date.formatted(.dateTime.weekday(.wide).day().month().locale(appLocale()))
  let score=day.score.map {String(format:appText("%lld out of 100 points"),locale:appLocale(),Int64($0))} ?? appText("No record")
  return "\(date), \(score), \(dayMode(day))"
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
