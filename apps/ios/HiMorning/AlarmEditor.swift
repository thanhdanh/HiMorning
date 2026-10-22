import SwiftUI
import AVFoundation
import UIKit
import HiMorningCore
struct AlarmEditor:View {
 @Environment(\.dismiss) private var dismiss
 @Environment(\.openURL) private var openURL
 @Environment(\.accessibilityReduceMotion) private var reduceMotion
 private enum ChoiceSection:Equatable {case challenge,sound}
 @State private var expanded:ChoiceSection? = .challenge
 @State private var time=Date()
 @State private var mode:WakeMode = .gentle
 @State private var sound:AlarmSound = .system
 @State private var challenge:ChallengeSelection = .none
 @State private var pushUpTarget=10
 @State private var rhythmVariant:GuidedRhythmVariant = .standing
 @State private var choseChallenge=false
 @State private var days:Set<Int>=[]
 @State private var label=""
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
 var body:some View {
  NavigationStack {
   VStack(spacing:0) {
    choiceHeaders
   ScrollViewReader {scroll in
   ScrollView {
    VStack(alignment:.leading,spacing:20) {
     Text(appText("Wake-up time")).font(.subheadline.weight(.semibold)).foregroundStyle(MorningTheme.muted)
     DatePicker(appText("Wake-up time"),selection:$time,displayedComponents:.hourAndMinute)
      .datePickerStyle(.wheel).labelsHidden().frame(height:150).clipped()
      .frame(maxWidth:.infinity).background(MorningTheme.soft,in:RoundedRectangle(cornerRadius:20))
      .accessibilityIdentifier("alarmTimePicker").accessibilityValue(DateFormatter.localizedString(from:time,dateStyle:.none,timeStyle:.short))
     VStack(alignment:.leading,spacing:10) {
      Text(appText("Label")).font(.subheadline.weight(.semibold)).foregroundStyle(MorningTheme.muted)
      TextField(appText("Optional label"),text:$label).textFieldStyle(.roundedBorder).accessibilityIdentifier("alarmLabel")
     }
     VStack(alignment:.leading,spacing:10) {
      Text(appText("Repeat")).font(.subheadline.weight(.semibold)).foregroundStyle(MorningTheme.muted)
      LazyVGrid(columns:[GridItem(.adaptive(minimum:44),spacing:4)],spacing:8) {
       ForEach(weekdays,id:\.self) {day in
        Button {if days.contains(day) {days.remove(day)} else {days.insert(day)}} label: {
         Text(dayNames[day-1]).font(.subheadline.weight(.semibold)).frame(maxWidth:.infinity,minHeight:44)
          .foregroundStyle(days.contains(day) ? MorningTheme.onYellow : MorningTheme.muted)
          .background(days.contains(day) ? MorningTheme.yellow : MorningTheme.soft,in:Circle())
        }.buttonStyle(.plain).accessibilityIdentifier("alarmRepeatDay-\(day)").accessibilityAddTraits(days.contains(day) ? .isSelected : [])
       }
      }
      Text(days.isEmpty ? appText("Rings once") : appText("Uses your phone’s local time")).font(.caption).foregroundStyle(MorningTheme.muted)
     }
     if expanded == .challenge {
     VStack(alignment:.leading,spacing:12) {
      Text(appText("Your morning")).font(.subheadline.weight(.semibold)).foregroundStyle(MorningTheme.muted)
      HStack(spacing:4) {
       ForEach(WakeMode.allCases,id:\.self) {value in
        modeButton(value)
       }
      }.padding(4).background(MorningTheme.soft,in:RoundedRectangle(cornerRadius:16))
      Text(challenge.kind == .pushUps ? appText("Try %lld push-ups",count:pushUpTarget) : challenge.kind == .none ? appText("Wake up at your own pace") : challenge.kind.summary).font(.subheadline).accessibilityIdentifier("modeExplanation")
     }.id("editorOptions")
     VStack(alignment:.leading,spacing:12) {
      Text(appText("Challenge")).font(.subheadline.weight(.semibold)).foregroundStyle(MorningTheme.muted)
      if !ChallengeKind.available(in:mode).contains(challenge.kind) {challengeButton(challenge.kind,legacy:true)}
      ForEach(ChallengeKind.available(in:mode),id:\.self) {kind in
       challengeButton(kind)
      }
     }
     }
     if expanded == .sound {
      SoundSelection(sound:$sound,volume:$volume,access:preview.access,unlock:{pro=true},preview:playPreview,stopPreview:{soundPreview.stop()})
       .id("editorOptions")
     }
    }.padding(20)
   }.background(MorningTheme.canvas.ignoresSafeArea()).foregroundStyle(MorningTheme.ink)
   .onChange(of:expanded) {_,section in
    soundPreview.stop()
    if section != nil {scroll.scrollTo("editorOptions",anchor:.top)}
   }
   }
    saveBar
   }.background(MorningTheme.canvas.ignoresSafeArea())
   .navigationTitle(appText(editing ? "Edit alarm" : "New alarm")).navigationBarTitleDisplayMode(.inline)
   .toolbar(.visible,for:.navigationBar).toolbarBackground(MorningTheme.canvas,for:.navigationBar).toolbarBackground(.visible,for:.navigationBar)
   .toolbar {ToolbarItem(placement:.cancellationAction) {Button(appText("Cancel")) {soundPreview.stop();dismiss()}.disabled(saving)}}

   .disabled(saving).interactiveDismissDisabled(saving)
   .tint(MorningTheme.accent).onDisappear {soundPreview.stop()}
   .onChange(of:volume) {_,value in soundPreview.setVolume(value)}
   .onChange(of:preview.access) {_,_ in
    soundPreview.stop()
   }
   .sheet(isPresented:$pro) {ProView(store:store,preview:preview)}
  }
 }
 private var choiceHeaders:some View {
  HStack(spacing:10) {
   sectionHeader(.challenge,title:appText("Challenge"),summary:challenge.displayTitle,icon:challenge.kind.icon,id:"editorChallengeSection")
   sectionHeader(.sound,title:appText("Sound"),summary:sound.title,icon:"music.note",id:"chooseSound")
  }.padding(.horizontal,20).padding(.vertical,10)
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
      saving=true;saveError=nil;alarmAccessDenied=false;soundPreview.stop()
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
      HStack {if saving {ProgressView()};Text(appText(saving ? "Saving…" : "Save"))}
     }.buttonStyle(MorningButtonStyle()).disabled(saving).accessibilityIdentifier("saveAlarm")
      .accessibilityLabel(appText(saving ? "Saving…" : "Save"))
    }.padding(.horizontal,20).padding(.vertical,12).background(MorningTheme.canvas)
 }
 private func sectionHeader(_ section:ChoiceSection,title:String,summary:String,icon:String,id:String)->some View {
  Button {
   if reduceMotion {expanded=expanded == section ? nil : section}
   else {withAnimation(.snappy(duration:0.25)) {expanded=expanded == section ? nil : section}}
  } label: {
   VStack(alignment:.leading,spacing:5) {
    HStack(spacing:6) {
     Image(systemName:icon)
     Text(title).font(.subheadline.weight(.semibold))
     Spacer(minLength:0)
     Image(systemName:expanded == section ? "chevron.up" : "chevron.down").font(.caption.weight(.semibold))
    }
    Text(summary).font(.caption).foregroundStyle(MorningTheme.muted).lineLimit(1)
   }.padding(12).frame(maxWidth:.infinity,minHeight:64,alignment:.leading).contentShape(Rectangle())
    .background(expanded == section ? MorningTheme.surface : MorningTheme.soft,in:RoundedRectangle(cornerRadius:16))
    .overlay {RoundedRectangle(cornerRadius:16).strokeBorder(expanded == section ? MorningTheme.accent : MorningTheme.line)}
  }.buttonStyle(.plain).accessibilityIdentifier(id)
   .accessibilityLabel(title+", "+summary).accessibilityValue(appText(expanded == section ? "Expanded" : "Collapsed"))
 }
 private func challengeButton(_ kind:ChallengeKind,legacy:Bool=false)->some View {
  VStack(alignment:.leading,spacing:0) {
   Button {
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
    HStack(spacing:14) {
     Image(systemName:kind.icon).frame(width:32)
     Text(legacy ? String(format:appText("%@ · saved choice"),kind.title) : kind.title).font(.body.weight(.medium))
     if kind.usesLocalMovement {Text(appText("On-device camera")).font(.caption).foregroundStyle(MorningTheme.muted)}
     Spacer()
     Image(systemName:challenge.kind == kind ? "checkmark.circle.fill" : "circle").foregroundStyle(MorningTheme.accent)
    }.padding(14).contentShape(Rectangle())
   }.buttonStyle(.plain).accessibilityIdentifier("challenge-"+kind.editorIdentifier)
    .accessibilityAddTraits(challenge.kind == kind ? .isSelected : [])
   if challenge.kind == kind {
    VStack(alignment:.leading,spacing:12) {
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
    }.padding(.horizontal,14).padding(.bottom,14)
   }
  }.background(MorningTheme.surface,in:RoundedRectangle(cornerRadius:14))
   .overlay {RoundedRectangle(cornerRadius:14).strokeBorder(challenge.kind == kind ? MorningTheme.accent : MorningTheme.line,lineWidth:challenge.kind == kind ? 2 : 1)}
   .accessibilityElement(children:.contain).accessibilityIdentifier("challenge-card-"+kind.editorIdentifier)
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
   VStack(spacing:8) {
    Image(systemName:value == .gentle ? "leaf" : value == .balanced ? "sun.max" : "bolt")
    Text(value.title).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center)
    HStack(spacing:3) {
     ForEach(0..<3) {index in
      Capsule().fill(index < (value == .gentle ? 1 : value == .balanced ? 2 : 3) ? MorningTheme.accent : MorningTheme.line).frame(width:14,height:4)
     }
    }.accessibilityHidden(true)
    Text(appText(value == .gentle ? "Default: No challenge" : value == .balanced ? "Default: Read & Choose" : "Default: 10 push-ups"))
     .font(.caption).multilineTextAlignment(.center).fixedSize(horizontal:false,vertical:true)
    if !preview.access.allows(mode:value) {Image(systemName:"lock.fill").font(.caption)}
   }.padding(10).frame(maxWidth:.infinity,minHeight:128)
    .background(mode == value ? MorningTheme.surface : .clear,in:RoundedRectangle(cornerRadius:12))
    .overlay {RoundedRectangle(cornerRadius:12).strokeBorder(mode == value ? MorningTheme.accent : .clear,lineWidth:2)}
  }.buttonStyle(.plain).accessibilityIdentifier("mode-"+value.rawValue)
   .accessibilityAddTraits(mode == value ? .isSelected : [])
 }
 private func playPreview(_ value:AlarmSound) {
  preview.refresh()
  guard preview.access.allows(sound:value) else {soundPreview.stop();pro=true;return}
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
