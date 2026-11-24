import SwiftUI
import AVFoundation
import UIKit
import AlarmKit
import HiMorningCore
enum AlarmEditorScope {case all,schedule,challenge}

struct AlarmEditor:View {
 @Environment(\.dismiss) private var dismiss
 @Environment(\.dynamicTypeSize) private var dynamicTypeSize
 @Environment(\.openURL) private var openURL
 @Environment(\.accessibilityReduceMotion) private var reduceMotion
 @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
 @State private var choosingSound=false
 @State private var soundPro=false
 @State private var time=Calendar.current.date(bySettingHour:7,minute:0,second:0,of:Date()) ?? Date()
 @State private var mode:WakeMode = .gentle
 @State private var sound:AlarmSound = .system
 @State private var challenge:ChallengeSelection = .none
 @State private var pushUpTarget=10
 @State private var rhythmVariant:GuidedRhythmVariant = .standing
 @State private var filter:WakeMode = .gentle
 @State private var days:Set<Int>=[]
 @State private var label=""
 @FocusState private var labelFocused:Bool
 @State private var volume:Double=0.3
 @State private var soundPreview=SoundPreview(playsInSilentMode:true)
 @State private var soundPreviewFailed=false
 @State private var playingSound:AlarmSound?
 @State private var previewID=UUID()
 @State private var practiceAlarm:SavedAlarm?
 @State private var detail:ChallengeInfo?
 @State private var trialCredit:ChallengeCredit?
 @State private var removeTrial=false
 @ObservedObject private var ads:RewardedAdStore
 private let original:SavedAlarm?
 @State private var saving=false
 @State private var saveError:String?
 @State private var alarmAccessDenied=false
 @State private var offeringAllSettings=false
 @ObservedObject var store:SubscriptionStore
 @ObservedObject var preview:PreviewStore
 @State private var alarmID:UUID
 let practiceModel:PilotModel
 let editing:Bool
 @State private var scope:AlarmEditorScope
 init(alarm:SavedAlarm?=nil,scope:AlarmEditorScope = .all,suggestedChallenge:ChallengeSelection?=nil,store:SubscriptionStore,preview:PreviewStore,practiceModel:PilotModel) {
  _scope=State(initialValue:scope);self.store=store;self.preview=preview;self.practiceModel=practiceModel;self.original=alarm;_ads=ObservedObject(wrappedValue:practiceModel.rewardedAds);_alarmID=State(initialValue:alarm?.id ?? UUID());editing=alarm != nil
  if let alarm {
   _time=State(initialValue:Calendar.current.date(from:DateComponents(hour:alarm.time.hour,minute:alarm.time.minute)) ?? Date())
   _mode=State(initialValue:alarm.mode);_sound=State(initialValue:alarm.sound)
   _challenge=State(initialValue:alarm.challenge);_days=State(initialValue:alarm.time.weekdays)
   _label=State(initialValue:alarm.label)
   _pushUpTarget=State(initialValue:alarm.challenge.repetitions ?? 5)
   _rhythmVariant=State(initialValue:alarm.challenge.rhythmVariant ?? .standing)
   _filter=State(initialValue:alarm.mode)
  }
  if let suggestedChallenge {
   _challenge=State(initialValue:suggestedChallenge)
   _mode=State(initialValue:suggestedChallenge.kind.preferredMode)
   _pushUpTarget=State(initialValue:suggestedChallenge.repetitions ?? 5)
   _rhythmVariant=State(initialValue:suggestedChallenge.rhythmVariant ?? .seated)
   _filter=State(initialValue:suggestedChallenge.kind.preferredMode)
  }
 }
 @Environment(\.scenePhase) private var scenePhase
 private let weekdays=[2,3,4,5,6,7,1]
 private var dayNames:[String] {[appText("Sun"),appText("Mon"),appText("Tue"),appText("Wed"),appText("Thu"),appText("Fri"),appText("Sat")]}
 private var motionReduced:Bool {
  #if DEBUG
  reduceMotion || ProcessInfo.processInfo.arguments.contains("--ui-reduce-motion")
  #else
  reduceMotion
  #endif
 }
 private var transparencyReduced:Bool {
  #if DEBUG
  reduceTransparency || ProcessInfo.processInfo.arguments.contains("--ui-reduce-transparency")
  #else
  reduceTransparency
  #endif
 }
 private var testingColorScheme:ColorScheme? {
  #if DEBUG
  ProcessInfo.processInfo.arguments.contains("--ui-dark-mode") ? .dark : nil
  #else
  nil
  #endif
 }
 private var challengeColor:Color {MorningTheme.modeAccent(mode)}
 var body:some View {
  NavigationStack {
   ZStack {
    AlarmComposerBackdrop()
    ScrollView {
     VStack(alignment:.leading,spacing:24) {
      if scope != .challenge {challengeHero}
      if scope != .challenge {
      VStack(alignment:.leading,spacing:12) {
       settingsGroup
      }
      }
      if scope != .schedule {
      VStack(alignment:.leading,spacing:12) {
       Text(appText("When the alarm rings")).font(.headline)
       HStack {
        ChallengeIcon(kind:challenge.kind,seated:challenge.rhythmVariant == .seated,size:20)
         .foregroundStyle(challengeColor)
        let title=Text(challenge.displayTitle).font(.subheadline.weight(.semibold))
         .accessibilityIdentifier("composerChallengeTitle")
        if dynamicTypeSize.isAccessibilitySize {title}
        else {title.lineLimit(2,reservesSpace:true)}
        Spacer()
        Button(appText("Try")) {startPractice()}
         .buttonStyle(.bordered).frame(minHeight:44).accessibilityIdentifier("trySelectedChallenge")
         .opacity(challenge.kind == .none ? 0 : 1)
         .disabled(challenge.kind == .none).accessibilityHidden(challenge.kind == .none)
       }
       if let trialSelection {
        HStack {
         Label(String(format:appText("Next ring only: %@"),locale:appLocale(),trialSelection.displayTitle),systemImage:"ticket")
          .font(.footnote.weight(.semibold)).foregroundStyle(MorningTheme.accent)
         Spacer(minLength:8)
         Button(appText("Remove")) {trialCredit=nil;removeTrial=true}
          .font(.footnote.weight(.semibold)).frame(minHeight:44)
        }.accessibilityIdentifier("selectedChallengeTrial")
       }
       Text(appText("Choose a challenge type")).font(.caption.weight(.semibold)).foregroundStyle(MorningTheme.muted)
       HStack(spacing:8) {ForEach(WakeMode.allCases,id:\.self) {modeButton($0)}}
      }
      VStack(alignment:.leading,spacing:14) {
       Text(appText("Choose a challenge")).modifier(MorningTypography.heading(size:20,relativeTo:.title3))
       challengeGrid
       if challenge.kind == .pushUps || challenge.kind == .guidedRhythm {challengeSettings}
       ChallengeRequirementsView(selection:challenge).accessibilityIdentifier("modeExplanation")
      }
      }
     }.padding(.horizontal,20).padding(.top,12).padding(.bottom,96)
    }.scrollDismissesKeyboard(.interactively)
   }.foregroundStyle(MorningTheme.ink)
    .safeAreaInset(edge:.bottom,spacing:0) {saveBar}
    .navigationTitle(appText(scope == .schedule ? "Edit time and label" : scope == .challenge ? "Change challenge" : editing ? "Edit alarm" : "New alarm")).navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.hidden,for:.navigationBar)
    .toolbar {
     ToolbarItem(placement:.cancellationAction) {Button(appText("Cancel")) {soundPreview.stop();dismiss()}.disabled(saving)}
    }
    .disabled(saving).interactiveDismissDisabled(saving)
    .tint(MorningTheme.accent).preferredColorScheme(testingColorScheme).onDisappear {soundPreview.stop()}
    .onChange(of:scenePhase) {_,phase in
     if phase == .active,alarmAccessDenied,AlarmManager.shared.authorizationState == .authorized {
      alarmAccessDenied=false;saveError=nil
     }
    }
    .onChange(of:volume) {_,value in soundPreview.setVolume(value)}
    .sensoryFeedback(.selection,trigger:challenge.kind)
    .sensoryFeedback(.selection,trigger:filter)
    .environment(\.composerReduceMotion,motionReduced)
    .environment(\.composerReduceTransparency,transparencyReduced)
    .sheet(isPresented:$choosingSound) {soundPicker}
    .sheet(item:$detail) {info in
     ChallengeInfoSheet(info:info,store:store,preview:preview,
                        trialAlreadySelected:trialSelection?.kind == info.selection.kind,
                        trialPossible:trialPossible,credit:practiceModel.challengeCredit(for:info.selection.kind),
                        ads:ads,model:practiceModel,onTrial:{credit in
      trialCredit=credit;removeTrial=false;detail=nil
     })
    }
    .fullScreenCover(item:$practiceAlarm) {alarm in
     ChallengeView(alarm:alarm,model:practiceModel,rehearsal:true)
    }
  }
 }
 private var trialSelection:ChallengeSelection? {
  if let trialCredit {return trialCredit.challenge}
  guard !removeTrial,let trial=original?.challengeTrial,trial.occurrence>Date() else {return nil}
  return trial.challenge
 }
 private var trialPossible:Bool {
  guard let original else {return true}
  guard original.enabled,let time=try? draftTime() else {return false}
  return !(time == original.time && time.weekdays.isEmpty && original.scheduledOccurrence.map {$0<=Date()} == true)
 }
 private func draftTime() throws ->AlarmTime {
  let components=Calendar.current.dateComponents([.hour,.minute],from:time)
  return try AlarmTime(hour:components.hour ?? 6,minute:components.minute ?? 30,weekdays:days)
 }
 private func info(for kind:ChallengeKind) {
  labelFocused=false;soundPreview.stop()
  let selection=challenge.kind == kind ? challenge : ChallengeSelection(
   kind:kind,repetitions:kind == .pushUps ? max(kind.preferredMode.policy.reps,pushUpTarget) : nil,rhythmVariant:rhythmVariant)
  detail=ChallengeInfo(selection:selection,mode:ChallengeKind.available(in:filter).contains(kind) ? filter : mode)
 }
 private func startPractice() {
  labelFocused=false;soundPreview.stop()
  let components=Calendar.current.dateComponents([.hour,.minute],from:time)
  guard challenge.kind != .none,
        let alarmTime=try? AlarmTime(hour:components.hour ?? 0,minute:components.minute ?? 0,weekdays:days) else {return}
  practiceAlarm=SavedAlarm(time:alarmTime,mode:mode,sound:sound,challenge:challenge,label:label)
 }
 private var occurrenceSummary:String {
  guard days.isEmpty else {return repeatSummary}
  let components=Calendar.current.dateComponents([.hour,.minute],from:time)
  guard let alarmTime=try? AlarmTime(hour:components.hour ?? 0,minute:components.minute ?? 0,weekdays:[]),
        let next=alarmTime.next(after:Date(),calendar:.current) else {return appText("Rings once")}
  return appText(Calendar.current.isDateInToday(next) ? "Today · Once" : "Tomorrow · Once")
 }
 private var challengeHero:some View {
  VStack(alignment:.leading,spacing:18) {
   if scope != .challenge {
   HStack {
    Label(appText("Wake-up time"),systemImage:"sunrise.fill").font(.subheadline.weight(.semibold))
    Spacer(minLength:8)
    Text(occurrenceSummary).font(.caption.weight(.semibold)).foregroundStyle(MorningTheme.muted)
     .multilineTextAlignment(.trailing).accessibilityIdentifier("alarmOccurrence")
   }
   DatePicker(appText("Wake-up time"),selection:$time,displayedComponents:.hourAndMinute)
    .datePickerStyle(.wheel).environment(\.locale,Locale.autoupdatingCurrent).labelsHidden().frame(height:180).clipped()
    .frame(maxWidth:.infinity)
    .accessibilityIdentifier("alarmTimePicker")
    .accessibilityValue(alarmTimeText(time))
   }
  }.padding(24).frame(maxWidth:.infinity,alignment:.leading)
   .composerGlass(tint:.clear,cornerRadius:32)
 }
 private var soundPicker:some View {
  NavigationStack {
   ScrollView {
    VStack(alignment:.leading,spacing:24) {
     Label(appText("Set the mood"),systemImage:"waveform").font(.title2.bold()).fontDesign(.rounded)
     SoundSelection(sound:$sound,volume:$volume,access:preview.access,playing:playingSound,unlock:{soundPro=true},preview:playPreview,stopPreview:stopSoundPreview,onSelection:{choosingSound=false})
    }.padding(20)
   }.background(MorningTheme.canvas).foregroundStyle(MorningTheme.ink)
    .navigationTitle(appText("Sound")).navigationBarTitleDisplayMode(.inline)
    .toolbar {ToolbarItem(placement:.confirmationAction) {Button(appText("Done")) {stopSoundPreview();choosingSound=false}.accessibilityIdentifier("doneSound")}}
  }.tint(MorningTheme.accent).presentationDragIndicator(.visible).onDisappear(perform:stopSoundPreview)
   .sheet(isPresented:$soundPro) {ProView(store:store,preview:preview,ads:ads)}
   .alert(appText("Couldn’t play this sound"),isPresented:$soundPreviewFailed) {
    Button(appText("Done"),role:.cancel) {}
   }
 }
 private var repeatSummary:String {
  if days.isEmpty {return appText("Never")}
  if days.count == 7 {return appText("Every day")}
  return weekdays.filter {days.contains($0)}.map {dayNames[$0-1]}.joined(separator:", ")
 }
 private var settingsGroup:some View {
  VStack(spacing:0) {
   VStack(alignment:.leading,spacing:14) {
    HStack(alignment:.firstTextBaseline) {
     Text(appText("Repeat")).accessibilityIdentifier("alarmRepeat")
     Spacer(minLength:8)
     Text(repeatSummary).font(.subheadline).foregroundStyle(MorningTheme.muted)
      .multilineTextAlignment(.trailing).accessibilityIdentifier("alarmRepeatSummary")
    }
    HStack(spacing:0) {
     ForEach(weekdays,id:\.self) {day in
      Button {
       if days.contains(day) {days.remove(day)} else {days.insert(day)}
      } label: {
       Text(dayNames[day-1]).font(.system(size:13,weight:.semibold,design:.rounded))
        .frame(width:34,height:34)
        .foregroundStyle(days.contains(day) ? MorningTheme.onYellow : MorningTheme.muted)
        .background(days.contains(day) ? MorningTheme.yellow : MorningTheme.soft,in:Circle())
        .overlay {Circle().strokeBorder(days.contains(day) ? MorningTheme.accent.opacity(0.5) : MorningTheme.line)}
        .frame(maxWidth:.infinity,minHeight:44)
        .contentShape(Rectangle())
      }.buttonStyle(AlarmComposerPressStyle()).accessibilityIdentifier("alarmRepeatDay-\(day)")
       .accessibilityLabel(weekdayName(day)).accessibilityAddTraits(days.contains(day) ? .isSelected : [])
     }
    }
   }.padding(.horizontal,12).padding(.vertical,16)
    .sensoryFeedback(.selection,trigger:days)
   settingsDivider
   if scope == .all {
    Button {labelFocused=false;soundPreview.stop();choosingSound=true} label: {
     settingsRow(title:appText("Sound"),summary:sound.title)
    }.buttonStyle(.plain).accessibilityIdentifier("chooseSound")
    settingsDivider
   }
   HStack(spacing:16) {
    Text(appText("Label")).foregroundStyle(MorningTheme.ink)
    TextField(appText("Optional label"),text:$label)
     .textFieldStyle(.plain).multilineTextAlignment(.trailing).foregroundStyle(MorningTheme.ink)
     .focused($labelFocused).submitLabel(.done).onSubmit {labelFocused=false}
     .accessibilityLabel(appText("Label")).accessibilityIdentifier("alarmLabel")
   }.font(.body).padding(.horizontal,16).frame(minHeight:54)

  }.background(MorningTheme.surface,in:RoundedRectangle(cornerRadius:MorningTheme.Radius.card))
   .overlay {RoundedRectangle(cornerRadius:MorningTheme.Radius.card).strokeBorder(MorningTheme.line.opacity(0.6))}
 }
 private var settingsDivider:some View {
  Divider().overlay(MorningTheme.line).padding(.leading,16)
 }
 private func settingsRow(title:String,summary:String,expanded:Bool=false)->some View {
  HStack(spacing:16) {
   Text(title).foregroundStyle(MorningTheme.ink).fixedSize(horizontal:false,vertical:true)
   Spacer(minLength:0)
   Text(summary).foregroundStyle(MorningTheme.muted).lineLimit(1).truncationMode(.tail)
   Image(systemName:"chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(MorningTheme.muted.opacity(0.7))
    .rotationEffect(.degrees(expanded ? 90 : 0)).accessibilityHidden(true)
  }.font(.body).padding(.horizontal,16).padding(.vertical,14).frame(minHeight:54).contentShape(Rectangle())
 }
 private func weekdayName(_ day:Int)->String {
  var calendar=Calendar.current;calendar.locale=appLocale()
  return calendar.weekdaySymbols[day-1]
 }
 private var saveBar:some View {
    VStack(spacing:8) {
     if let saveError {Text(saveError).font(.footnote).foregroundStyle(MorningTheme.ink).accessibilityIdentifier("alarmSaveError")}
     if offeringAllSettings {
      Button(appText("Edit all settings")) {scope = .all;saveError=nil;offeringAllSettings=false}
       .buttonStyle(.plain).font(.subheadline.weight(.semibold)).frame(minHeight:44)
       .accessibilityIdentifier("editAllAlarmSettings")
     }
     if alarmAccessDenied {
      Button {
       if let url=URL(string:UIApplication.openSettingsURLString) {openURL(url)}
      } label: {Text(appText("Open Settings")).frame(minHeight:44)}
       .buttonStyle(.plain).font(.subheadline.weight(.semibold)).accessibilityIdentifier("openAlarmSettings")
     }
     Button {
      guard !saving else {return}
      labelFocused=false;saving=true;saveError=nil;alarmAccessDenied=false;offeringAllSettings=false;soundPreview.stop()
      Task { @MainActor in
       do {
        let value=try draftTime()
        try await practiceModel.save(SavedAlarm(id:alarmID,time:value,mode:mode,sound:sound,challenge:challenge,label:label),credit:trialCredit,removeTrial:removeTrial)
        dismiss()
       } catch AlarmScheduleError.accessDenied {
        saveError=appText("Alarm wasn’t scheduled. Allow alarms for HiMorning in Settings.")
        alarmAccessDenied=true;saving=false
       } catch AlarmSaveError.soundUnavailable {
        saveError=appText(scope == .all ? "This sound is no longer available. Choose System sound or unlock Pro." : "Some settings are no longer available. Open all settings to update them.");offeringAllSettings=scope != .all;saving=false
       } catch AlarmSaveError.trialAlarmOff {
        saveError=appText("Turn on this alarm to use a trial.");saving=false
       } catch AlarmSaveError.trialUnavailable {
        saveError=appText("Choose a future ring time to use this trial.");saving=false
       } catch AlarmSaveError.challengeUnavailable {
        saveError=appText(scope == .all ? "These challenge settings require Pro. Choose another challenge or unlock Pro." : "Some settings are no longer available. Open all settings to update them.");offeringAllSettings=scope != .all;saving=false
       } catch {
        saveError=appText("Alarm schedule unconfirmed")
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
         let native=error as NSError
         saveError! += " [\(native.domain):\(native.code)] \(native.localizedDescription)"
        }
        #endif
        saving=false
       }
      }
     } label: {
      HStack(spacing:8) {
       if saving {ProgressView()} else {Image(systemName:"checkmark")}
       Text(appText(saving ? "Saving…" : "Save"))
       Spacer(minLength:12)
       if scope != .challenge {Text(alarmTimeText(time)).monospacedDigit()}
      }.font(.headline).padding(.horizontal,18).frame(maxWidth:.infinity,minHeight:56)
     }.buttonStyle(.glassProminent).tint(MorningTheme.yellow).foregroundStyle(MorningTheme.onYellow)
      .disabled(saving).accessibilityIdentifier("saveAlarm")
      .accessibilityLabel(appText(saving ? "Saving…" : "Save"))
    }.padding(.horizontal,20).padding(.top,12).padding(.bottom,8)
     .overlay(alignment:.top) {Rectangle().fill(MorningTheme.line.opacity(0.6)).frame(height:0.5)}
     .background {MorningTheme.canvas.ignoresSafeArea(edges:.bottom)}

 }
 private var challengeGrid:some View {
  let available=ChallengeKind.available(in:filter)
  let last=available.count.isMultiple(of:2) ? nil : available.last
  let oneColumn=dynamicTypeSize.isAccessibilitySize
  return VStack(spacing:12) {
   LazyVGrid(columns:oneColumn ? [GridItem(.flexible())] : [GridItem(.flexible(),spacing:12),GridItem(.flexible(),spacing:12)],spacing:12) {
    ForEach(available.filter {$0 != last},id:\.self) {challengeButton($0,wide:oneColumn)}
   }
   if let last {challengeButton(last,wide:true).id(last)}
   if !available.contains(challenge.kind) {challengeButton(challenge.kind,legacy:true,wide:true)}
  }
 }
 private func challengeButton(_ kind:ChallengeKind,legacy:Bool=false,wide:Bool=false)->some View {
  let selected=challenge.kind == kind
  let tint=MorningTheme.modeAccent(legacy ? mode : filter)
  let locked = !preview.access.allows(challenge:kind)
  let usesCamera=kind == .pushUps || kind == .guidedRhythm || kind.usesLocalMovement
  let layout=wide ? AnyLayout(HStackLayout(alignment:.center,spacing:12)) : AnyLayout(VStackLayout(alignment:.leading,spacing:8))
  let reserveTitleLines = !wide && dynamicTypeSize <= .large && !legacy
  let infoAlignment:Alignment = wide ? .trailing : .topTrailing
  let shape=RoundedRectangle(cornerRadius:MorningTheme.Radius.card)
  return ZStack(alignment:infoAlignment) {
   Button {
    if locked {info(for:kind)} else {selectChallenge(kind)}
   } label: {
    layout {
     ChallengeIcon(kind:kind,seated:rhythmVariant == .seated,size:26)
      .foregroundStyle(tint)
      .frame(width:40,height:40).background(tint.opacity(0.13),in:RoundedRectangle(cornerRadius:13))
     VStack(alignment:.leading,spacing:wide ? 4 : 8) {
     let title=Text(legacy ? String(format:appText("%@ · saved choice"),kind.title) : kind.title)
      .font(.subheadline.weight(.bold)).multilineTextAlignment(.leading).fixedSize(horizontal:false,vertical:true)
     if reserveTitleLines {title.lineLimit(2,reservesSpace:true)} else {title}
     ZStack(alignment:.leading) {
      Text(verbatim:" ").accessibilityHidden(true)
      if locked {
       ProLockBadge(compact:true).accessibilityHidden(true)
      } else if selected && !locked {
       Label(appText("Selected"),systemImage:"checkmark.circle.fill").foregroundStyle(tint)
      } else if kind == .stretching {
       Text(appText("Free"))
      } else if usesCamera {
       Label(appText("Camera"),systemImage:"camera.fill")
      } else if kind == .readAloud {
       Label(appText("Microphone"),systemImage:"mic.fill")
      }
     }.font(.caption2).foregroundStyle(MorningTheme.muted)
     }
    }.padding(.leading,14).padding(.trailing,wide ? 48 : 14)
     .padding(.vertical,12)
     .frame(minWidth:0,maxWidth:.infinity,minHeight:wide ? 70 : 124,alignment:wide ? .leading : .topLeading)
     .background(MorningTheme.surface,in:shape)
     .overlay {shape.strokeBorder(selected ? tint : locked ? MorningTheme.proOutline : MorningTheme.line,lineWidth:selected ? 2 : 1)}
     .contentShape(shape)
     .accessibilityElement(children:.combine)
     .accessibilityValue(locked ? appText("Requires Pro") : "")
   }.buttonStyle(AlarmComposerPressStyle()).accessibilityIdentifier("challenge-"+kind.editorIdentifier)
    .accessibilityAddTraits(selected ? .isSelected : [])
   Button {info(for:kind)} label: {
    Image(systemName:"info.circle").font(.system(size:17,weight:.medium))
     .foregroundStyle(MorningTheme.muted).frame(width:44,height:44).contentShape(Rectangle())
   }.buttonStyle(.plain).padding(5)
    .accessibilityLabel(String(format:appText("About %@"),locale:appLocale(),kind.title))
    .accessibilityIdentifier("challengeInfo-"+kind.editorIdentifier)
  }
 }
 private func selectChallenge(_ kind:ChallengeKind) {
    guard challenge.kind != kind else {return}
    mode=filter
    switch kind {
    case .none:challenge = .none
    case .pushUps:
     pushUpTarget=max(mode == .focused ? 10 : 5,pushUpTarget)
     challenge = .pushUps(repetitions:pushUpTarget)
    case .readAndChoose:challenge = .readAndChoose
    case .guidedRhythm:challenge = .guidedRhythm(variant:rhythmVariant)
    case .waveHand,.neckRotation,.riddle,.jumpingJacks,.stretching,.morningLight:challenge=ChallengeSelection(kind:kind)
    case .readAloud:challenge = .readAloud
    }
 }
 private var challengeSettings:some View {
  let kind=challenge.kind
  return VStack(alignment:.leading,spacing:12) {

     if kind == .pushUps {
      HStack {
       Text(appText("%lld push-ups",count:pushUpTarget)).font(.headline).monospacedDigit().accessibilityIdentifier("pushUpTarget")
       Spacer()
       Button {
        pushUpTarget-=1;challenge = .pushUps(repetitions:pushUpTarget)
       } label:{Image(systemName:"minus").frame(width:44,height:44).contentShape(Rectangle())}
        .buttonStyle(.plain).background(MorningTheme.soft,in:Circle())
        .disabled(pushUpTarget <= (mode == .focused ? 10 : 5))
        .accessibilityLabel(appText("Decrease push-up target")).accessibilityIdentifier("decreasePushUpTarget")
       Button {
        pushUpTarget=max(mode == .focused ? 10 : 5,pushUpTarget+1);challenge = .pushUps(repetitions:pushUpTarget)
       } label:{Image(systemName:"plus").frame(width:44,height:44).contentShape(Rectangle())}
        .buttonStyle(.plain).background(MorningTheme.soft,in:Circle())
       .disabled(pushUpTarget >= (preview.access.hasFullAccess ? ChallengeSelection.maximumPushUps : 5))
        .accessibilityLabel(appText("Increase push-up target")).accessibilityIdentifier("increasePushUpTarget")
      }
     }
     if kind == .guidedRhythm {
      Picker(appText("Rhythm style"),selection:$rhythmVariant) {
       Text(appText("Standing")).tag(GuidedRhythmVariant.standing)
       Text(appText("Seated")).tag(GuidedRhythmVariant.seated)
      }.pickerStyle(.segmented)
       .onChange(of:rhythmVariant) {_,value in challenge = .guidedRhythm(variant:value)}
     }
  }.padding(18).background(MorningTheme.surface.opacity(0.85),in:RoundedRectangle(cornerRadius:24))
   .accessibilityElement(children:.contain).accessibilityIdentifier("challenge-settings-"+kind.editorIdentifier)
 }
 private func modeButton(_ value:WakeMode)->some View {
  let selected=filter == value
  let tint=MorningTheme.modeAccent(value)
  return Button {
   preview.refresh()
   filter=value
  } label: {
   VStack(spacing:6) {
    HStack(spacing:5) {
     Image(systemName:value == .gentle ? "leaf.fill" : value == .balanced ? "sun.max.fill" : "bolt.fill")
    }.font(.body.weight(.semibold)).foregroundStyle(selected ? tint : MorningTheme.muted)
    Text(value.title).font(.caption.weight(.semibold)).multilineTextAlignment(.center).fixedSize(horizontal:false,vertical:true)
   }.padding(.vertical,8).padding(.horizontal,4).frame(maxWidth:.infinity,minHeight:58)
    .contentShape(Rectangle())
    .foregroundStyle(selected ? MorningTheme.ink : MorningTheme.muted)
    .background(MorningTheme.surface,in:RoundedRectangle(cornerRadius:23))
    .overlay {RoundedRectangle(cornerRadius:23).strokeBorder(selected ? tint : MorningTheme.line,lineWidth:selected ? 2 : 1)}
  }.buttonStyle(.plain).accessibilityIdentifier("mode-"+value.rawValue)
   .accessibilityAddTraits(selected ? .isSelected : [])
 }
 private func playPreview(_ value:AlarmSound) {
  if playingSound == value {stopSoundPreview();return}
  guard value != .system else {return}
  guard let url=Bundle.main.url(forResource:value.rawValue,withExtension:"wav") else {
   stopSoundPreview();soundPreviewFailed=true;return
  }
  let id=UUID()
  previewID=id;playingSound=value
  soundPreview.play(url:url,volume:volume,onEnd:{played in
   guard previewID == id else {return}
   playingSound=nil
   soundPreviewFailed = !played
  })
 }
 private func stopSoundPreview() {
  previewID=UUID();playingSound=nil
  soundPreview.stop()
 }
}
private struct SoundSelection:View {
 @Environment(\.scenePhase) private var scenePhase
 @Binding var sound:AlarmSound
 @Binding var volume:Double
 let access:MorningAccess
 let playing:AlarmSound?
 let unlock:()->Void
 let preview:(AlarmSound)->Void
 let stopPreview:()->Void
 let onSelection:()->Void
 var body:some View {
   VStack(alignment:.leading,spacing:24) {
    ForEach(AlarmSound.groups,id:\.title) {group in
     VStack(alignment:.leading,spacing:0) {
      Text(group.title).font(.subheadline.weight(.semibold)).foregroundStyle(MorningTheme.muted).padding(.bottom,4)
      ForEach(group.sounds,id:\.self) {value in
       let locked = !access.allows(sound:value)
       HStack(spacing:8) {
        Button {stopPreview();if locked {unlock()} else {sound=value;onSelection()}} label: {
         HStack(spacing:10) {
          Image(systemName:value == .system ? "alarm" : value == .sunrise ? "sunrise" : "music.note")
           .frame(width:44,height:44).background(MorningTheme.soft,in:RoundedRectangle(cornerRadius:12))
           .accessibilityHidden(true)
          Text(value.title).font(.body.weight(.medium))
           .multilineTextAlignment(.leading).fixedSize(horizontal:false,vertical:true)
           .frame(maxWidth:.infinity,alignment:.leading)
          if locked {
           ProLockBadge(compact:true).fixedSize()
          } else {
           Image(systemName:sound == value ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(MorningTheme.accent).accessibilityHidden(true)
          }
         }.padding(.vertical,14).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("sound-"+value.rawValue).accessibilityAddTraits(sound == value ? .isSelected : [])
        if value != .system {
         Button {preview(value)} label: {Image(systemName:playing == value ? "stop.fill" : "play.fill").frame(width:44,height:44)}
          .buttonStyle(.plain).foregroundStyle(MorningTheme.accent)
          .accessibilityLabel(playing == value ? appText("Stop preview") : String(format:appText("Preview %@"),locale:appLocale(),value.title))
          .accessibilityIdentifier("preview-"+value.rawValue)
        }
       }
       Divider().overlay(MorningTheme.line)
      }
     }
    }
    if sound != .system || !access.hasFullAccess {
     VStack(alignment:.leading,spacing:12) {
      Text(appText("Preview volume")).font(.subheadline.weight(.semibold))
      Slider(value:$volume,in:0...0.7).accessibilityLabel(appText("Preview volume")).accessibilityIdentifier("previewVolume")
      Text(appText("Preview volume only. Alarms use your phone’s alarm volume.")).font(.footnote).foregroundStyle(MorningTheme.muted)
     }
    }
   }.tint(MorningTheme.accent)
   .onDisappear(perform:stopPreview)
   .onChange(of:scenePhase) {_,phase in if phase != .active {stopPreview()}}
 }
}
