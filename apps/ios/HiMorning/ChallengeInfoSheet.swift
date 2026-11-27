import SwiftUI
import HiMorningCore

struct ChallengeInfo:Identifiable {
 let selection:ChallengeSelection
 let mode:WakeMode
 var id:ChallengeKind {selection.kind}
}

struct ChallengeInfoSheet:View {
 let info:ChallengeInfo
 @ObservedObject var store:SubscriptionStore
 @ObservedObject var preview:PreviewStore
 let trialAlreadySelected:Bool
 let trialPossible:Bool
 @State var credit:ChallengeCredit?
 @ObservedObject var ads:RewardedAdStore
 let model:PilotModel
 let onTrial:(ChallengeCredit)->Void
 @Environment(\.dismiss) private var dismiss
 @Environment(\.dynamicTypeSize) private var dynamicTypeSize
 @State private var watching=false
 @State private var status:String?
 @State private var showsPro=false

 private var kind:ChallengeKind {info.selection.kind}
 private var locked:Bool {!preview.access.allows(challenge:kind)}

 var body:some View {
  let tint=MorningTheme.modeAccent(info.mode)
  NavigationStack {
   ScrollView {
    VStack(alignment:.leading,spacing:20) {
     HStack(spacing:12) {
      if !kind.hasMovementIllustration {
       ChallengeIcon(kind:kind,size:24)
        .foregroundStyle(tint)
        .frame(width:44,height:44).background(tint.opacity(0.13),in:RoundedRectangle(cornerRadius:14))
      }
      VStack(alignment:.leading,spacing:8) {
       Text(kind.title).modifier(MorningTypography.heading()).accessibilityAddTraits(.isHeader)
       Label(info.mode.title,systemImage:info.mode.icon)
        .font(.caption.weight(.semibold)).foregroundStyle(tint)
        .padding(.horizontal,10).padding(.vertical,5)
        .background(tint.opacity(0.12),in:Capsule())
        .accessibilityLabel(String(format:appText("Challenge level: %@"),locale:appLocale(),info.mode.title))
        .accessibilityIdentifier("challengeInfoLevel")
      }
     }
     if locked {proCard}
     if kind.hasMovementIllustration {
      MovementGuide(selection:info.selection,mode:info.mode,compact:false,showInstructions:false)
     }
     VStack(alignment:.leading,spacing:12) {
      Text(appText(instruction)).font(.body).lineSpacing(3).fixedSize(horizontal:false,vertical:true)
       .accessibilityIdentifier("challengeInfoInstruction")
      if kind.hasMovementIllustration {
       Label(appText("challenge_info_ai_count",count:movementTarget),systemImage:"sparkles")
        .font(.subheadline.weight(.medium)).foregroundStyle(MorningTheme.muted)
        .fixedSize(horizontal:false,vertical:true)
        .accessibilityIdentifier("challengeInfoAICount")
      }
     }
     if locked {
      Divider()
      trialActions
     }
    }.frame(maxWidth:.infinity,alignment:.leading).padding(24)
   }.background(MorningTheme.canvas).foregroundStyle(MorningTheme.ink)
    .navigationTitle(appText("Challenge details")).navigationBarTitleDisplayMode(.inline)
    .toolbar {ToolbarItem(placement:.confirmationAction) {Button(appText("Done")) {dismiss()}.disabled(watching)}}
  }.tint(MorningTheme.accent).presentationDragIndicator(.visible).interactiveDismissDisabled(watching)
   .sheet(isPresented:$showsPro) {ProView(store:store,preview:preview,ads:ads)}
 }

 private var proCard:some View {
  let layout=dynamicTypeSize.isAccessibilitySize
   ? AnyLayout(VStackLayout(alignment:.leading,spacing:8))
   : AnyLayout(HStackLayout(spacing:10))
  return Button {showsPro=true} label: {
   VStack(alignment:.leading,spacing:8) {
    layout {
     ProLockBadge().accessibilityHidden(true)
     if !dynamicTypeSize.isAccessibilitySize {Spacer(minLength:0)}
     HStack(spacing:5) {
      Text(appText("View plans"))
      Image(systemName:"chevron.forward").imageScale(.small).accessibilityHidden(true)
     }.font(.subheadline.weight(.semibold)).foregroundStyle(MorningTheme.accent)
    }
    Text(appText("Use this challenge whenever your alarm rings."))
     .font(.subheadline).foregroundStyle(MorningTheme.ink)
     .multilineTextAlignment(.leading).fixedSize(horizontal:false,vertical:true)
   }.padding(14).frame(maxWidth:.infinity,alignment:.leading)
    .background(MorningTheme.proSurface,in:RoundedRectangle(cornerRadius:16))
    .overlay {RoundedRectangle(cornerRadius:16).strokeBorder(MorningTheme.proOutline)}
    .contentShape(RoundedRectangle(cornerRadius:16))
  }.buttonStyle(AlarmComposerPressStyle()).disabled(watching)
   .accessibilityLabel(appText("View Pro plans"))
   .accessibilityHint(appText("Use this challenge whenever your alarm rings."))
   .accessibilityIdentifier("challengeInfoProLock")
 }

 private var instruction:String {
  switch kind {
  case .none:return "Stop the alarm with one tap"
  case .pushUps:return "challenge_info_pushups"
  case .waveHand:return "challenge_info_wave"
  case .neckRotation:return "challenge_info_neck"
  case .jumpingJacks:return "challenge_info_jacks"
  case .stretching:return "challenge_info_reach"
  case .guidedRhythm:return info.selection.rhythmVariant == .seated ? "challenge_info_seated" : "challenge_info_standing"
  case .readAloud:return "challenge_info_read_aloud"
  case .readAndChoose:return "challenge_info_read_choose"
  case .riddle:return "challenge_info_riddle"
  case .morningLight:return "challenge_info_morning_light"
  }
 }

 private var movementTarget:Int {info.selection.repetitions ?? kind.localMovementTarget ?? 3}

 private var trialActions:some View {
  VStack(alignment:.leading,spacing:12) {
   if trialAlreadySelected {
    Label(appText("Next ring only"),systemImage:"ticket")
   } else if !trialPossible {
    Text(appText("This trial needs an active alarm with a future ring."))
     .font(.footnote).foregroundStyle(MorningTheme.muted)
   } else if let credit {
    Text(appText("Save your alarm to use this trial on its next ring."))
     .font(.footnote).foregroundStyle(MorningTheme.muted)
    Button(appText("Use on next ring")) {onTrial(credit)}
     .buttonStyle(MorningButtonStyle(primary:false)).accessibilityIdentifier("applyChallengeTrial")
   } else if ads.isConfigured {
    Text(appText("Save your alarm after the ad to try it on the next ring."))
     .font(.footnote).foregroundStyle(MorningTheme.muted)
    Button {
     Task {await watchAd()}
    } label: {
     if watching {ProgressView(appText("Loading ad…"))}
     else {Label(appText("Watch an ad to try once"),systemImage:"play.rectangle")}
    }.buttonStyle(MorningButtonStyle(primary:false)).disabled(watching || ads.busy)
     .accessibilityIdentifier("watchChallengeAd")
   } else {
    Text(appText("Ad trials are unavailable right now.")).font(.footnote).foregroundStyle(MorningTheme.muted)
   }
   if let status {Text(status).font(.footnote).accessibilityIdentifier("challengeAdStatus")}
  }
 }

 private func watchAd() async {
  watching=true;status=nil
  defer {watching=false}
  let earnedCredit=ChallengeCredit(id:UUID(),challenge:info.selection)
  let eligible={model.selected == nil && !model.access.hasFullAccess}
  do {
   try await ads.prepare(isEligible:eligible)
   if try await ads.watch(isEligible:eligible,onEarned:{model.earnChallengeCredit(earnedCredit)}) {
    credit=model.challengeCredit(for:kind)
   } else {
    status=appText("Finish the ad to earn a trial.")
   }
  } catch is CancellationError {
   return
  } catch {
   status=error.localizedDescription
  }
 }
}
