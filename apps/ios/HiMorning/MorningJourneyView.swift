import SwiftUI
import HiMorningCore

extension SavedAlarm {
 func canPrepareJourney(now:Date=Date())->Bool {
  guard enabled,state == .confirmed else {return false}
  if time.weekdays.isEmpty {return scheduledOccurrence.map {$0>now} ?? false}
  return time.next(after:now) != nil
 }
}

extension MorningFocus {
 var title:String {switch self {
  case .clearStart:return appText("A clear start")
  case .gentleMovement:return appText("Wake up gently")
  case .findYourVoice:return appText("Find your morning voice")
  case .energize:return appText("Move with energy")
 }}
 var detail:String {switch self {
  case .clearStart:return appText("One small decision or riddle before work or study.")
  case .gentleMovement:return appText("Wave, turn gently and follow a seated rhythm. Camera checked on this device.")
  case .findYourVoice:return appText("Start with a short sentence, then try reading aloud in your app language.")
  case .energize:return appText("A standing workout mix with 5 push-ups, stretches and 10 jumping jacks. Choose what fits you.")
 }}
 var icon:String {switch self {case .clearStart:return "puzzlepiece.extension.fill";case .gentleMovement:return "hand.wave.fill";case .findYourVoice:return "waveform.badge.mic";case .energize:return "figure.strengthtraining.traditional"}}

}

struct MorningJourneyCard:View {
 @ObservedObject var model:PilotModel
 @ObservedObject var store:JourneyStore
 let choosePurpose:()->Void
 let plan:(ChallengeSelection,SavedAlarm?)->Void
 @State private var restarting=false
 var body:some View {
  TimelineView(.everyMinute) {context in
   VStack(alignment:.leading,spacing:12) {
    if let journey=store.journey {
     journeyContent(journey,now:context.date)
    } else {
     Label(appText("Morning goal"),systemImage:"sunrise.fill").font(.headline)
     Text(appText("Complete 7 mornings at your own pace."))
      .font(.subheadline).fixedSize(horizontal:false,vertical:true)
     Button(appText("Choose my morning purpose"),action:choosePurpose)
      .buttonStyle(MorningButtonStyle(primary:false)).accessibilityIdentifier("chooseMorningPurpose")
    }
    if let message=store.message {Text(message).font(.footnote).foregroundStyle(MorningTheme.muted).accessibilityIdentifier("journeyError")}
   }.padding(20).frame(maxWidth:.infinity,alignment:.leading)
    .background(MorningTheme.soft,in:RoundedRectangle(cornerRadius:24))
  }
  .alert(appText("Start another seven mornings?"),isPresented:$restarting) {
   Button(appText("Start a new round")) {_=store.restart()}.accessibilityIdentifier("confirmRestartJourney")
   Button(appText("Cancel"),role:.cancel) {}
  } message:{Text(appText("Your finished round stays recorded. Keep your purpose or choose another one."))}
 }
 @ViewBuilder private func journeyContent(_ journey:MorningJourney,now:Date)->some View {
  let today=journey.completedToday(now:now)
  let mission=journey.focus.mission(at:journey.missionIndex(now:now),access:model.access)
  HStack(alignment:.top,spacing:12) {
   Image(systemName:journey.focus.icon).font(.title2).accessibilityHidden(true)
   VStack(alignment:.leading,spacing:4) {
    Text(journey.focus.title).font(.headline).fixedSize(horizontal:false,vertical:true).accessibilityIdentifier("journeyPurpose")
   }
   Spacer(minLength:0)
   Button(action:choosePurpose) {
    HStack(spacing:4) {
     Text(appText("Change goal"))
     Image(systemName:"chevron.right").font(.caption2.weight(.semibold))
    }
    .font(.subheadline.weight(.medium))
    .foregroundStyle(MorningTheme.accent)
    .frame(minHeight:44)
   }
    .accessibilityLabel(appText("Change my purpose")).accessibilityIdentifier("changeMorningPurpose")
  }
  ViewThatFits(in:.horizontal) {
   HStack(spacing:12) {journeyCount(journey);journeyDots(journey)}
   VStack(alignment:.leading,spacing:8) {journeyCount(journey);journeyDots(journey)}
  }
  if journey.completedJourneys>0 && !journey.isComplete {
   Text(appText("Completed rounds on this device: %lld",count:journey.completedJourneys)).font(.footnote).foregroundStyle(MorningTheme.muted).accessibilityIdentifier("journeyRounds")
  }
  if journey.isComplete {
   Label(appText("Seven mornings. You made room for yourself."),systemImage:"star.circle.fill")
    .font(.title3.weight(.semibold)).fixedSize(horizontal:false,vertical:true).accessibilityIdentifier("journeyMilestone")
   Button(appText("Begin another seven mornings")) {restarting=true}.buttonStyle(MorningButtonStyle()).accessibilityIdentifier("restartJourney")
   Text(appText("Completed rounds on this device: %lld",count:journey.completedJourneys+1)).font(.footnote).foregroundStyle(MorningTheme.muted).accessibilityIdentifier("journeyRounds")
  } else if today {
   Label(appText(journey.completedCount == 0 ? "Next round starts tomorrow" : "Done for today"),systemImage:"checkmark.circle.fill")
    .font(.subheadline.weight(.medium)).accessibilityIdentifier("journeyTodayWin")
   missionPlan(journey.focus.mission(at:journey.completedCount,access:model.access),title:appText("Choose a challenge for tomorrow"),forTomorrow:true)
  } else {
   if let last=journey.completions.last,let gap=Calendar.current.dateComponents([.day],from:Calendar.current.startOfDay(for:last),to:Calendar.current.startOfDay(for:now)).day,gap>1 {
    Text(appText("Welcome back. Your wins are still here. Continue with one small morning."))
     .font(.subheadline.weight(.medium)).accessibilityIdentifier("journeyWelcomeBack")
   }
   Text(appText("Suggested for this morning")).font(.caption.weight(.semibold)).foregroundStyle(MorningTheme.muted)
   Label {
    Text(mission.displayTitle)
   } icon: {
    ChallengeIcon(kind:mission.kind,seated:mission.rhythmVariant == .seated,size:22)
     .foregroundStyle(MorningTheme.modeAccent(mission.kind.preferredMode))
   }.font(.title3.weight(.semibold))
    .fixedSize(horizontal:false,vertical:true).accessibilityIdentifier("journeyMission")
   if journey.focus.requiresFullAccess && !model.access.hasFullAccess {
    Text(appText("Your preview has ended. Your path continues with gentle movement, and your earned mornings stay."))
     .font(.footnote).foregroundStyle(MorningTheme.muted)
   }
   Button {model.practiceMission(mission)} label:{Label(appText("Try today’s mission"),systemImage:"play.circle")}
    .buttonStyle(MorningButtonStyle(primary:false)).accessibilityIdentifier("tryJourneyMission")
   missionPlan(mission,title:appText("Plan this mission with an alarm"))
  }
 }
 @ViewBuilder private func missionPlan(_ mission:ChallengeSelection,title:String,forTomorrow:Bool=false)->some View {
  let calendar=Calendar.current
  let threshold=forTomorrow ? (calendar.dateInterval(of:.day,for:Date())?.end ?? Date()).addingTimeInterval(-1) : Date()
  let upcoming=model.alarms.filter {$0.canPrepareJourney(now:threshold)}
  if upcoming.isEmpty {
   Button(forTomorrow ? title : appText("Set an alarm with this challenge")) {plan(mission,nil)}.buttonStyle(MorningButtonStyle(primary:false)).accessibilityIdentifier("planJourneyMission")
  } else if upcoming.count == 1,let alarm=upcoming.first {
   Button(forTomorrow ? title : String(format:appText("Add to the %@ alarm"),locale:appLocale(),alarmTimeText(alarm.time))) {plan(mission,alarm)}
    .buttonStyle(MorningButtonStyle(primary:false)).accessibilityIdentifier("planJourneyMission")
  } else {
   Menu {
    ForEach(upcoming) {alarm in
     Button(alarmTimeText(alarm.time)+(alarm.label.isEmpty ? "" : " · "+alarm.label)) {plan(mission,alarm)}
      .accessibilityIdentifier("journeyAlarm-"+alarm.id.uuidString)
    }
    Button(appText("New alarm")) {plan(mission,nil)}.accessibilityIdentifier("journeyNewAlarm")
   } label:{Text(title).frame(maxWidth:.infinity)}
    .buttonStyle(MorningButtonStyle(primary:false)).accessibilityIdentifier("planJourneyMission")
  }
 }
 private func journeyCount(_ journey:MorningJourney)->some View {
  Text(appText("%lld/7 mornings",count:journey.completedCount)).font(.subheadline.weight(.medium))
   .accessibilityIdentifier("journeyProgress")
 }
 private func journeyDots(_ journey:MorningJourney)->some View {
  HStack(spacing:6) {ForEach(0..<7,id:\.self) {step in
   Image(systemName:step<journey.completedCount ? "checkmark.circle.fill" : "circle")
    .font(.system(size:16)).foregroundStyle(step<journey.completedCount ? MorningTheme.success : MorningTheme.muted)
  }}.accessibilityHidden(true)
 }

}

struct MorningPurposePicker:View {
 @ObservedObject var model:PilotModel
 @ObservedObject var store:JourneyStore
 let showPro:()->Void
 @Environment(\.dismiss) private var dismiss
 var body:some View {
  NavigationStack {
   ScrollView {
    VStack(alignment:.leading,spacing:16) {
     Text(appText("What would make your morning worth getting up for?"))
      .modifier(MorningTypography.heading()).fixedSize(horizontal:false,vertical:true)
     Text(appText("Seven successful mornings, at your pace. Changing purpose keeps the mornings you have already earned."))
      .font(.subheadline).foregroundStyle(MorningTheme.muted).fixedSize(horizontal:false,vertical:true)
     ForEach(MorningFocus.allCases,id:\.self) {focus in
      Button {
       if focus.requiresFullAccess && !model.access.hasFullAccess {showPro()}
       else if store.choose(focus,access:model.access) {dismiss()}
      } label: {
       HStack(alignment:.top,spacing:12) {
        Image(systemName:focus.icon).font(.title2).frame(width:32)
        VStack(alignment:.leading,spacing:8) {
         Text(focus.title).font(.headline)
         Text(focus.detail).font(.subheadline)
         if focus.requiresFullAccess {Text(appText(model.access == .preview ? "Pro routine · included in your free preview" : "Pro routine")).font(.caption.weight(.semibold))}
        }.fixedSize(horizontal:false,vertical:true)
        Spacer(minLength:0)
        if store.journey?.focus == focus {Image(systemName:"checkmark.circle.fill")}
       }.padding(20).frame(maxWidth:.infinity,alignment:.leading)
        .background(MorningTheme.surface,in:RoundedRectangle(cornerRadius:MorningTheme.Radius.card))
        .overlay {RoundedRectangle(cornerRadius:MorningTheme.Radius.card).strokeBorder(store.journey?.focus == focus ? MorningTheme.accent : MorningTheme.line,lineWidth:store.journey?.focus == focus ? 1.5 : 1)}
      }.buttonStyle(.plain).accessibilityIdentifier("morningPurpose-"+focus.rawValue)
     }
     if let message=store.message {Text(message).font(.footnote).foregroundStyle(MorningTheme.muted)}
    }.padding(20)
   }.background(MorningTheme.canvas).foregroundStyle(MorningTheme.ink).tint(MorningTheme.accent)
    .navigationTitle(appText("My morning purpose")).navigationBarTitleDisplayMode(.inline)
    .toolbar {ToolbarItem(placement:.cancellationAction) {Button(appText("Close")) {dismiss()}.accessibilityIdentifier("closeMorningPurpose")}}
  }
 }
}
