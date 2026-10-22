import SwiftUI
import AVFoundation
import UIKit
import HiMorningCore
struct AlarmEditor:View {
 @Environment(\.dismiss) private var dismiss
 @Environment(\.dynamicTypeSize) private var dynamicTypeSize
 @Environment(\.openURL) private var openURL
 @Environment(\.accessibilityReduceMotion) private var reduceMotion
 @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
 @State private var choosingSound=false
 @State private var soundPro=false
 @State private var time=Date()
 @State private var mode:WakeMode = .gentle
 @State private var sound:AlarmSound = .system
 @State private var challenge:ChallengeSelection = .none
 @State private var pushUpTarget=10
 @State private var rhythmVariant:GuidedRhythmVariant = .standing
 @State private var choseChallenge=false
 @State private var days:Set<Int>=[]
 @State private var label=""
 @FocusState private var labelFocused:Bool
 @State private var volume:Double=0.3
 @State private var soundPreview=SoundPreview()
 @State private var pro=false
 @State private var saving=false
 @State private var saveError:String?
 @State private var alarmAccessDenied=false
 @ObservedObject var store:SubscriptionStore
 @ObservedObject var preview:PreviewStore
 @State private var alarmID:UUID
 let editing:Bool
 let save:(SavedAlarm) async throws ->Void
 init(alarm:SavedAlarm?=nil,store:SubscriptionStore,preview:PreviewStore,save:@escaping (SavedAlarm) async throws ->Void) {
  self.store=store;self.preview=preview;self.save=save;_alarmID=State(initialValue:alarm?.id ?? UUID());editing=alarm != nil
  if let alarm {
   _time=State(initialValue:Calendar.current.date(from:DateComponents(hour:alarm.time.hour,minute:alarm.time.minute)) ?? Date())
   _mode=State(initialValue:alarm.mode);_sound=State(initialValue:alarm.sound)
   _challenge=State(initialValue:alarm.challenge);_days=State(initialValue:alarm.time.weekdays)
   _label=State(initialValue:alarm.label)
   _pushUpTarget=State(initialValue:alarm.challenge.repetitions ?? 5)
   _rhythmVariant=State(initialValue:alarm.challenge.rhythmVariant ?? .standing)
   _choseChallenge=State(initialValue:true)
  }
 }
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
 private var challengeColor:Color {AlarmComposerPalette.color(for:challenge.kind)}
 var body:some View {
  NavigationStack {
   ZStack {
    AlarmComposerBackdrop(tint:challengeColor)
    ScrollView {
     VStack(alignment:.leading,spacing:24) {
      challengeHero
      VStack(alignment:.leading,spacing:12) {
       Text(appText("Find your energy")).font(.headline)
       GlassEffectContainer(spacing:8) {
        HStack(spacing:8) {ForEach(WakeMode.allCases,id:\.self) {modeButton($0)}}
       }
      }
      VStack(alignment:.leading,spacing:14) {
       HStack {
        Text(appText("Pick your first win")).font(.title3.weight(.bold))
        Spacer()
        Image(systemName:"sparkles").foregroundStyle(challengeColor).accessibilityHidden(true)
       }
       LazyVGrid(columns:dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible(),spacing:12),GridItem(.flexible(),spacing:12)],spacing:12) {
        if !ChallengeKind.available(in:mode).contains(challenge.kind) {challengeButton(challenge.kind,legacy:true)}
        ForEach(ChallengeKind.available(in:mode),id:\.self) {challengeButton($0)}
       }
       if challenge.kind == .pushUps || challenge.kind == .guidedRhythm {challengeSettings}
      }
      VStack(alignment:.leading,spacing:12) {
       Text(appText("The little details")).font(.headline)
       settingsGroup
       Text(days.isEmpty ? appText("Rings once") : appText("Uses your phone’s local time"))
        .font(.footnote).foregroundStyle(MorningTheme.muted).padding(.horizontal,4)
      }
     }.padding(.horizontal,20).padding(.top,12).padding(.bottom,24)
    }.scrollDismissesKeyboard(.interactively)
   }.foregroundStyle(MorningTheme.ink)
    .safeAreaInset(edge:.bottom,spacing:0) {saveBar}
    .navigationTitle(appText(editing ? "Edit alarm" : "New alarm")).navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.hidden,for:.navigationBar)
    .toolbar {
     ToolbarItem(placement:.cancellationAction) {Button(appText("Cancel")) {soundPreview.stop();dismiss()}.disabled(saving)}
    }
    .disabled(saving).interactiveDismissDisabled(saving)
    .tint(MorningTheme.accent).preferredColorScheme(testingColorScheme).onDisappear {soundPreview.stop()}
    .onChange(of:volume) {_,value in soundPreview.setVolume(value)}
    .onChange(of:preview.access) {_,_ in soundPreview.stop()}
    .sensoryFeedback(.selection,trigger:challenge.kind)
    .sensoryFeedback(.selection,trigger:mode)
    .animation(motionReduced ? nil : .spring(response:0.4,dampingFraction:0.82),value:challenge.kind)
    .environment(\.composerReduceMotion,motionReduced)
    .environment(\.composerReduceTransparency,transparencyReduced)
    .sheet(isPresented:$pro) {ProView(store:store,preview:preview)}
    .sheet(isPresented:$choosingSound) {soundPicker}
  }
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
   HStack {
    Label(appText("Wake-up time"),systemImage:"sunrise.fill").font(.subheadline.weight(.semibold))
    Spacer(minLength:8)
    Text(occurrenceSummary).font(.caption.weight(.semibold)).foregroundStyle(MorningTheme.muted)
     .multilineTextAlignment(.trailing).accessibilityIdentifier("alarmOccurrence")
   }
   DatePicker(appText("Wake-up time"),selection:$time,displayedComponents:.hourAndMinute)
    .datePickerStyle(.wheel).labelsHidden().frame(height:180).clipped()
    .frame(maxWidth:.infinity)
    .accessibilityIdentifier("alarmTimePicker")
    .accessibilityValue(DateFormatter.localizedString(from:time,dateStyle:.none,timeStyle:.short))
   Divider().overlay(challengeColor.opacity(0.16))
   HStack(alignment:.center,spacing:12) {
    VStack(alignment:.leading,spacing:8) {
     Text(appText("Your morning")).font(.caption.weight(.semibold)).foregroundStyle(MorningTheme.muted)
     Text(challenge.kind == .none ? appText("A gentle start") : challenge.displayTitle)
      .font(.system(.title2,design:.rounded,weight:.bold)).fixedSize(horizontal:false,vertical:true)
      .accessibilityIdentifier("composerChallengeTitle")
     Text(challenge.kind == .pushUps ? appText("Try %lld push-ups",count:pushUpTarget) : challenge.kind == .none ? appText("Wake up at your own pace") : challenge.kind.summary)
      .font(.footnote).foregroundStyle(MorningTheme.muted).fixedSize(horizontal:false,vertical:true)
      .accessibilityIdentifier("modeExplanation")
    }.frame(maxWidth:.infinity,alignment:.leading)
    if !dynamicTypeSize.isAccessibilitySize {
     AlarmComposerEmblem(symbol:AlarmComposerPalette.symbol(for:challenge.kind),tint:challengeColor)
      .scaleEffect(0.75).frame(width:80,height:90).accessibilityHidden(true)
    }
   }
  }.padding(24).frame(maxWidth:.infinity,alignment:.leading)
   .composerGlass(tint:challengeColor.opacity(0.12),cornerRadius:32)
 }
 private var soundPicker:some View {
  NavigationStack {
   ScrollView {
    VStack(alignment:.leading,spacing:24) {
     Label(appText("Set the mood"),systemImage:"waveform").font(.title2.bold()).fontDesign(.rounded)
     SoundSelection(sound:$sound,volume:$volume,access:preview.access,unlock:{soundPro=true},preview:playPreview,stopPreview:{soundPreview.stop()})
    }.padding(20)
   }.background(MorningTheme.canvas).foregroundStyle(MorningTheme.ink)
    .navigationTitle(appText("Sound")).navigationBarTitleDisplayMode(.inline)
    .toolbar {ToolbarItem(placement:.confirmationAction) {Button(appText("Done")) {soundPreview.stop();choosingSound=false}.accessibilityIdentifier("doneSound")}}
  }.tint(MorningTheme.accent).presentationDragIndicator(.visible).onDisappear {soundPreview.stop()}
   .sheet(isPresented:$soundPro) {ProView(store:store,preview:preview)}
 }
 private var repeatSummary:String {
  if days.isEmpty {return appText("Never")}
  if days.count == 7 {return appText("Every day")}
  return weekdays.filter {days.contains($0)}.map {dayNames[$0-1]}.joined(separator:", ")
 }
 private var settingsGroup:some View {
  VStack(spacing:0) {
   Button {labelFocused=false;soundPreview.stop();choosingSound=true} label: {
    settingsRow(title:appText("Sound"),summary:sound.title)
   }.buttonStyle(.plain).accessibilityIdentifier("chooseSound")
   settingsDivider
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
   HStack(spacing:16) {
    Text(appText("Label")).foregroundStyle(MorningTheme.ink)
    TextField(appText("Optional label"),text:$label)
     .textFieldStyle(.plain).multilineTextAlignment(.trailing).foregroundStyle(MorningTheme.muted)
     .focused($labelFocused).submitLabel(.done).onSubmit {labelFocused=false}
     .accessibilityLabel(appText("Label")).accessibilityIdentifier("alarmLabel")
   }.font(.body).padding(.horizontal,16).frame(minHeight:54)

  }.background(MorningTheme.surface,in:RoundedRectangle(cornerRadius:16))
   .overlay {RoundedRectangle(cornerRadius:16).strokeBorder(MorningTheme.line.opacity(0.6))}
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
     if alarmAccessDenied {
      Button {
       if let url=URL(string:UIApplication.openSettingsURLString) {openURL(url)}
      } label: {Text(appText("Open Settings")).frame(minHeight:44)}
       .buttonStyle(.plain).font(.subheadline.weight(.semibold)).accessibilityIdentifier("openAlarmSettings")
     }
     Button {
      guard !saving else {return}
      labelFocused=false;saving=true;saveError=nil;alarmAccessDenied=false;soundPreview.stop()
      Task { @MainActor in
       do {
        let c=Calendar.current.dateComponents([.hour,.minute],from:time)
        let value=try AlarmTime(hour:c.hour ?? 6,minute:c.minute ?? 30,weekdays:days)
        try await save(SavedAlarm(id:alarmID,time:value,mode:mode,sound:sound,challenge:challenge,label:label))
        dismiss()
       } catch NativeAlarmError.denied {
        saveError=appText("Alarm access is off. Allow alarms for HiMorning in Settings, then try again.")
        alarmAccessDenied=true;saving=false
       } catch AlarmSaveError.soundUnavailable {
        saveError=appText("This sound is no longer available. Choose System sound or unlock Pro.");saving=false
       } catch AlarmSaveError.challengeUnavailable {
        saveError=appText("These challenge settings require Pro. Choose another challenge or unlock Pro.");saving=false
       } catch {
        saveError=appText("This alarm could not be confirmed. Please check your system alarms before relying on it.")
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
       Text(time,style:.time).monospacedDigit()
      }.font(.headline).padding(.horizontal,18).frame(maxWidth:.infinity,minHeight:56)
     }.buttonStyle(.glassProminent).tint(MorningTheme.yellow).foregroundStyle(MorningTheme.onYellow)
      .disabled(saving).accessibilityIdentifier("saveAlarm")
      .accessibilityLabel(appText(saving ? "Saving…" : "Save"))
    }.padding(.horizontal,20).padding(.top,12).padding(.bottom,labelFocused ? 32 : 8)
     .background {LinearGradient(colors:[MorningTheme.canvas.opacity(0),MorningTheme.canvas.opacity(0.96)],startPoint:.top,endPoint:.bottom).ignoresSafeArea(edges:.bottom)}

 }
 private func challengeButton(_ kind:ChallengeKind,legacy:Bool=false)->some View {
  let selected=challenge.kind == kind
  let tint=AlarmComposerPalette.color(for:kind)
  return Button {
    choseChallenge=true
    switch kind {
    case .none:challenge = .none
    case .pushUps:
     pushUpTarget=max(mode == .focused ? 10 : 5,pushUpTarget)
     challenge = .pushUps(repetitions:pushUpTarget)
    case .readAndChoose:challenge = .readAndChoose
    case .guidedRhythm:challenge = .guidedRhythm(variant:rhythmVariant)
    case .waveHand,.neckRotation,.riddle,.jumpingJacks,.stretching:challenge=ChallengeSelection(kind:kind)
    case .readAloud:challenge = .readAloud
    }
   } label: {
    VStack(alignment:.leading,spacing:18) {
     HStack {
      Image(systemName:AlarmComposerPalette.symbol(for:kind))
       .font(.system(size:25,weight:.medium)).foregroundStyle(tint)
       .frame(width:50,height:50).background(tint.opacity(0.13),in:RoundedRectangle(cornerRadius:17))
      Spacer(minLength:0)
      if selected {Image(systemName:"checkmark.circle.fill").font(.title3).foregroundStyle(tint).accessibilityHidden(true)}
     }
     Text(legacy ? String(format:appText("%@ · saved choice"),kind.title) : kind.title)
      .font(.subheadline.weight(.bold)).multilineTextAlignment(.leading).fixedSize(horizontal:false,vertical:true)
     if kind.usesLocalMovement {
      HStack(alignment:.top,spacing:5) {
       Image(systemName:"camera.fill").accessibilityHidden(true)
       Text(appText("On-device camera")).fixedSize(horizontal:false,vertical:true)
      }.font(.caption2).foregroundStyle(MorningTheme.muted)
     }
    }.padding(16).frame(minWidth:0,maxWidth:.infinity,minHeight:142,alignment:.topLeading)
     .background(selected ? tint.opacity(0.12) : MorningTheme.surface.opacity(0.8),in:RoundedRectangle(cornerRadius:24))
     .overlay {RoundedRectangle(cornerRadius:24).strokeBorder(selected ? tint.opacity(0.85) : MorningTheme.line.opacity(0.7),lineWidth:selected ? 2 : 1)}
     .contentShape(RoundedRectangle(cornerRadius:24))
   }.buttonStyle(AlarmComposerPressStyle()).accessibilityIdentifier("challenge-"+kind.editorIdentifier)
    .accessibilityAddTraits(selected ? .isSelected : [])
 }
 private var challengeSettings:some View {
  let kind=challenge.kind
  return VStack(alignment:.leading,spacing:12) {

     Text(kind.summary).font(.footnote).foregroundStyle(MorningTheme.muted).accessibilityIdentifier("challenge-summary-"+kind.editorIdentifier)
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
  Button {
   preview.refresh()
   if preview.access.allows(mode:value) {
     guard value != mode else {return}
     let oldMode=mode
     mode=value
    if value != oldMode && !ChallengeKind.available(in:value).contains(challenge.kind) {
     challenge=value == .gentle ? .none : value == .balanced ? .readAndChoose : .pushUps(repetitions:10)
     pushUpTarget=challenge.repetitions ?? pushUpTarget
    } else if !choseChallenge {challenge=value == .gentle ? .none : value == .balanced ? .readAndChoose : .pushUps(repetitions:10);pushUpTarget=challenge.repetitions ?? pushUpTarget}
     if challenge.kind == .pushUps {pushUpTarget=min(ChallengeSelection.maximumPushUps,max(value == .focused ? 10 : 5,pushUpTarget));challenge = .pushUps(repetitions:pushUpTarget)}
   } else {pro=true}
  } label: {
   VStack(spacing:6) {
    HStack(spacing:5) {
     Image(systemName:value == .gentle ? "leaf.fill" : value == .balanced ? "sun.max.fill" : "bolt.fill")
     if !preview.access.allows(mode:value) {Image(systemName:"lock.fill").font(.caption2)}
    }.font(.body.weight(.semibold))
    Text(value.title).font(.caption.weight(.semibold)).multilineTextAlignment(.center).fixedSize(horizontal:false,vertical:true)
   }.padding(.vertical,13).padding(.horizontal,4).frame(maxWidth:.infinity,minHeight:70)
    .foregroundStyle(mode == value ? MorningTheme.ink : MorningTheme.muted)
    .composerGlass(tint:mode == value ? MorningTheme.yellow.opacity(0.3) : .clear,cornerRadius:23,interactive:true)
  }.buttonStyle(.plain).accessibilityIdentifier("mode-"+value.rawValue)
   .accessibilityAddTraits(mode == value ? .isSelected : [])
 }
 private func playPreview(_ value:AlarmSound) {
  preview.refresh()
  guard preview.access.allows(sound:value) else {soundPreview.stop();if choosingSound {soundPro=true} else {pro=true};return}
  guard value != .system,let url=Bundle.main.url(forResource:value.rawValue,withExtension:"wav") else {soundPreview.stop();return}
  soundPreview.play(url:url,volume:volume)
 }
}
private struct SoundSelection:View {
 @Environment(\.scenePhase) private var scenePhase
 @Binding var sound:AlarmSound
 @Binding var volume:Double
 let access:MorningAccess
 let unlock:()->Void
 let preview:(AlarmSound)->Void
 let stopPreview:()->Void
 var body:some View {
   VStack(alignment:.leading,spacing:24) {
    ForEach(AlarmSound.groups,id:\.title) {group in
     VStack(alignment:.leading,spacing:0) {
      Text(group.title).font(.subheadline.weight(.semibold)).foregroundStyle(MorningTheme.muted).padding(.bottom,4)
      ForEach(group.sounds,id:\.self) {value in
       HStack(spacing:8) {
        Button {stopPreview();if access.allows(sound:value) {sound=value} else {unlock()}} label: {
         HStack(spacing:14) {
          Image(systemName:value == .system ? "alarm" : value == .sunrise ? "sunrise" : "music.note")
           .frame(width:44,height:44).background(MorningTheme.soft,in:RoundedRectangle(cornerRadius:12))
          Text(value.title).font(.body.weight(.medium))
          if !access.allows(sound:value) {Image(systemName:"lock.fill").font(.caption)}
          Spacer()
          Image(systemName:sound == value ? "checkmark.circle.fill" : "circle").foregroundStyle(MorningTheme.accent)
         }.padding(.vertical,14).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("sound-"+value.rawValue).accessibilityAddTraits(sound == value ? .isSelected : [])
        if value != .system {
         Button {stopPreview();if access.allows(sound:value) {preview(value)} else {unlock()}} label: {Image(systemName:"play.fill").frame(width:44,height:44)}
          .buttonStyle(.plain).foregroundStyle(MorningTheme.accent)
          .accessibilityLabel(String(format:appText("Preview %@"),locale:appLocale(),value.title))
          .accessibilityIdentifier("preview-"+value.rawValue)
        }
       }
       Divider().overlay(MorningTheme.line)
      }
     }
    }
    if sound != .system {
     VStack(alignment:.leading,spacing:12) {
      Text(appText("Preview volume")).font(.subheadline.weight(.semibold))
      Slider(value:$volume,in:0...0.7).accessibilityLabel(appText("Preview volume")).accessibilityIdentifier("previewVolume")
     }
    }
    Text(appText("This slider changes the preview only. The alarm uses system volume. Please check it on your phone.")).font(.footnote).foregroundStyle(MorningTheme.muted)
   }.tint(MorningTheme.accent)
   .onDisappear(perform:stopPreview)
   .onChange(of:scenePhase) {_,phase in if phase != .active {stopPreview()}}
 }
}
