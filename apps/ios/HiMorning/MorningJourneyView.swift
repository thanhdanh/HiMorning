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
 var icon:String {switch self {case .clearStart:return "lightbulb";case .gentleMovement:return "hand.wave";case .findYourVoice:return "text.bubble";case .energize:return "figure.strengthtraining.traditional"}}
 func missionReason(_ selection:ChallengeSelection)->String {
  switch selection.kind {
  case .readAndChoose:return appText("Give your attention one small place to land.")
  case .riddle:return appText("A little curiosity can be a reason to get going.")
  case .readAloud:return appText("Let one short sentence be your first sound of the day.")
  case .waveHand:return appText("A small hello is enough to begin moving.")
  case .neckRotation:return appText("Take a moment to move gently, at your own pace.")
  case .guidedRhythm:return selection.rhythmVariant == .seated ? appText("Follow an easy rhythm. Seated movement counts too.") : appText("Follow an easy rhythm while standing.")
  default:return appText("Make time for a little movement before the day gets busy.")
  }
 }
}

struct MorningJourneyCard:View {
 @ObservedObject var model:PilotModel
 @ObservedObject var store:JourneyStore
 let choosePurpose:()->Void
 let plan:(ChallengeSelection,SavedAlarm?)->Void
 let showProgress:()->Void
 let showPro:()->Void
 @State private var restarting=false
 var body:some View {
  TimelineView(.everyMinute) {context in
   VStack(alignment:.leading,spacing:16) {
    if let journey=store.journey {
     journeyContent(journey,now:context.date)
    } else {
     Label(appText("Give tomorrow a reason."),systemImage:"sunrise.fill").font(.title2.weight(.semibold))
     Text(appText("Choose a purpose. Try a different small mission over seven successful mornings. No streak to lose."))
      .font(.subheadline).fixedSize(horizontal:false,vertical:true)
     Button(appText("Choose my morning purpose"),action:choosePurpose)
      .buttonStyle(MorningButtonStyle()).accessibilityIdentifier("chooseMorningPurpose")
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
    Text(appText("%lld of 7 mornings earned",count:journey.completedCount)).font(.subheadline).accessibilityIdentifier("journeyProgress")
   }
   Spacer(minLength:0)
   Button(action:choosePurpose) {Image(systemName:"slider.horizontal.3").frame(width:44,height:44)}
    .accessibilityLabel(appText("Change my purpose")).accessibilityIdentifier("changeMorningPurpose")
  }
  HStack(spacing:8) {ForEach(0..<7,id:\.self) {step in
   Image(systemName:step<journey.completedCount ? "checkmark.circle.fill" : "circle")
    .font(.system(size:22)).foregroundStyle(step<journey.completedCount ? MorningTheme.success : MorningTheme.muted)
  }}.accessibilityHidden(true)
  if journey.completedJourneys>0 && !journey.isComplete {
   Text(appText("Completed rounds on this device: %lld",count:journey.completedJourneys)).font(.footnote).foregroundStyle(MorningTheme.muted).accessibilityIdentifier("journeyRounds")
  }
  if journey.isComplete {
   Label(appText("Seven mornings. You made room for yourself."),systemImage:"star.circle.fill")
    .font(.title3.weight(.semibold)).fixedSize(horizontal:false,vertical:true).accessibilityIdentifier("journeyMilestone")
   Text(appText("You finished this path without needing a perfect streak. Keep the purpose, or try a different one next round."))
    .font(.subheadline).fixedSize(horizontal:false,vertical:true)
   Button(appText("Begin another seven mornings")) {restarting=true}.buttonStyle(MorningButtonStyle()).accessibilityIdentifier("restartJourney")
   Text(appText("Completed rounds on this device: %lld",count:journey.completedJourneys+1)).font(.footnote).foregroundStyle(MorningTheme.muted).accessibilityIdentifier("journeyRounds")
  } else if today {
   if journey.completedCount == 0 {
    Text(appText("Your next round begins tomorrow. Today’s win stays in your finished round.")).font(.subheadline.weight(.medium))
   }
   Label(appText("You showed up for your morning."),systemImage:"checkmark.seal.fill")
    .font(.title3.weight(.semibold)).accessibilityIdentifier("journeyTodayWin")
   if journey.completedCount == 3 {
    Text(appText("Three mornings earned. Coming back matters more than a perfect streak."))
     .font(.subheadline.weight(.medium)).accessibilityIdentifier("journeyMilestone")
   }
   teaser(journey,at:journey.completedCount,prefix:"Tomorrow’s small mission: %@")
   missionPlan(journey.focus.mission(at:journey.completedCount,access:model.access),title:appText("Prepare tomorrow’s mission"))
   Text(appText("Your alarm keeps its current challenge until you save a change.")).font(.footnote).foregroundStyle(MorningTheme.muted)
  } else {
   if let last=journey.completions.last,let gap=Calendar.current.dateComponents([.day],from:Calendar.current.startOfDay(for:last),to:Calendar.current.startOfDay(for:now)).day,gap>1 {
    Text(appText("Welcome back. Your wins are still here. Continue with one small morning."))
     .font(.subheadline.weight(.medium)).accessibilityIdentifier("journeyWelcomeBack")
   }
   Text(appText("Suggested for this morning")).font(.caption.weight(.semibold)).foregroundStyle(MorningTheme.muted)
   Label(mission.displayTitle,systemImage:mission.kind.icon).font(.title3.weight(.semibold))
    .fixedSize(horizontal:false,vertical:true).accessibilityIdentifier("journeyMission")
   Text(journey.focus.missionReason(mission)).font(.subheadline).fixedSize(horizontal:false,vertical:true)
   if journey.focus.requiresFullAccess && !model.access.hasFullAccess {
    Text(appText("Your preview has ended. Your path continues with gentle movement, and your earned mornings stay."))
     .font(.footnote).foregroundStyle(MorningTheme.muted)
   }
   Button {model.practiceMission(mission)} label:{Label(appText("Try today’s mission"),systemImage:"play.circle")}
    .buttonStyle(MorningButtonStyle(primary:false)).accessibilityIdentifier("tryJourneyMission")
   missionPlan(mission,title:appText("Plan this mission with an alarm"))
   Text(appText("You review the alarm before saving. Any completed real challenge earns one step; practice does not."))
    .font(.footnote).foregroundStyle(MorningTheme.muted).fixedSize(horizontal:false,vertical:true)
   teaser(journey,at:min(6,journey.completedCount+1),prefix:"Coming next: %@")
  }
  DisclosureGroup(appText("What’s working for me?")) {reflection.padding(.top,12)}
   .font(.subheadline.weight(.medium))
 }
 @ViewBuilder private func missionPlan(_ mission:ChallengeSelection,title:String)->some View {
  let upcoming=model.alarms.filter {$0.canPrepareJourney()}
  if upcoming.isEmpty {
   Button(title) {plan(mission,nil)}.buttonStyle(MorningButtonStyle()).accessibilityIdentifier("planJourneyMission")
  } else {
   Menu {
    ForEach(upcoming) {alarm in
     Button(String(format:"%02d:%02d",alarm.time.hour,alarm.time.minute)+(alarm.label.isEmpty ? "" : " · "+alarm.label)) {plan(mission,alarm)}
      .accessibilityIdentifier("journeyAlarm-"+alarm.id.uuidString)
    }
    Button(appText("New alarm")) {plan(mission,nil)}.accessibilityIdentifier("journeyNewAlarm")
   } label:{Text(title).frame(maxWidth:.infinity)}
    .buttonStyle(MorningButtonStyle()).accessibilityIdentifier("planJourneyMission")
  }
 }
 private func teaser(_ journey:MorningJourney,at index:Int,prefix:String)->some View {
  Text(String(format:appText(prefix),locale:appLocale(),journey.focus.mission(at:index,access:model.access).displayTitle))
   .font(.subheadline).fixedSize(horizontal:false,vertical:true).accessibilityIdentifier("journeyNextMission")
 }
 @ViewBuilder private var reflection:some View {
  if model.access.hasFullAccess {
   let reflection=MorningReflection(entries:model.journal?.entries ?? [])
   Text(appText("%lld of the past 30 days with a completed challenge",count:reflection.completedDays))
    .fixedSize(horizontal:false,vertical:true).accessibilityIdentifier("journeyReflectionDays")
   if let kind=reflection.goToChallenge {
    Text(String(format:appText("You returned to %@ on %lld days."),locale:appLocale(),kind.title,Int64(reflection.goToDays)))
     .fixedSize(horizontal:false,vertical:true)
    Text(appText("Repeat what felt useful, or choose a new purpose for your next round. This describes your completions, not your sleep quality."))
     .font(.footnote).foregroundStyle(MorningTheme.muted).fixedSize(horizontal:false,vertical:true)
   } else if reflection.completedDays>=3 {
    Text(appText("No repeated pattern yet. Keep trying the missions and notice what feels useful."))
     .font(.footnote).foregroundStyle(MorningTheme.muted).fixedSize(horizontal:false,vertical:true)
   } else {
    Text(appText("After three completed mornings, look here for the challenges you return to most."))
     .font(.footnote).foregroundStyle(MorningTheme.muted).fixedSize(horizontal:false,vertical:true)
   }
   Button(appText("See my 30-day progress"),action:showProgress).frame(minHeight:44)
  } else {
   Text(appText("Your starter paths and earned mornings stay free. Pro adds the energetic workout path and 30-day patterns to help you choose your next routine."))
    .font(.footnote).foregroundStyle(MorningTheme.muted).fixedSize(horizontal:false,vertical:true)
   Button(appText("Explore deeper routines"),action:showPro).frame(minHeight:44)
  }
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
      .font(.title2.weight(.semibold)).fixedSize(horizontal:false,vertical:true)
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
       }.padding(20).frame(maxWidth:.infinity,alignment:.leading).background(MorningTheme.soft,in:RoundedRectangle(cornerRadius:20))
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
