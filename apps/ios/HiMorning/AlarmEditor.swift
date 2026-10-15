import SwiftUI
import AVFoundation
import UIKit
import HiMorningCore
struct AlarmEditor:View {
 @Environment(\.dismiss) private var dismiss
 @Environment(\.openURL) private var openURL
 @State private var time=Calendar.current.date(from:DateComponents(hour:6,minute:30)) ?? Date()
 @State private var mode:WakeMode = .gentle
 @State private var sound:AlarmSound = .system
 @State private var challenge:ChallengeSelection = .none
 @State private var pushUpTarget=3
 @State private var rhythmVariant:GuidedRhythmVariant = .standing
 @State private var choseChallenge=false
 @State private var days:Set<Int>=[2,3,4,5,6]
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
   _pushUpTarget=State(initialValue:alarm.challenge.repetitions ?? 3)
   _rhythmVariant=State(initialValue:alarm.challenge.rhythmVariant ?? .standing)
   _choseChallenge=State(initialValue:true)
  }
 }
 private let weekdays=[2,3,4,5,6,7,1]
 private var dayNames:[String] {[appText("Sun"),appText("Mon"),appText("Tue"),appText("Wed"),appText("Thu"),appText("Fri"),appText("Sat")]}
 var body:some View {
  NavigationStack {
   ScrollView {
    VStack(alignment:.leading,spacing:20) {
     Text(appText("Wake-up time")).font(.subheadline.weight(.semibold)).foregroundStyle(MorningTheme.muted)
     DatePicker(appText("Wake-up time"),selection:$time,displayedComponents:.hourAndMinute)
      .datePickerStyle(.wheel).labelsHidden().frame(height:150).clipped()
      .frame(maxWidth:.infinity).background(MorningTheme.soft,in:RoundedRectangle(cornerRadius:20))
     VStack(alignment:.leading,spacing:10) {
      Text(appText("Repeat")).font(.subheadline.weight(.semibold)).foregroundStyle(MorningTheme.muted)
      LazyVGrid(columns:[GridItem(.adaptive(minimum:44),spacing:4)],spacing:8) {
       ForEach(weekdays,id:\.self) {day in
        Button {if days.contains(day) {days.remove(day)} else {days.insert(day)}} label: {
         Text(dayNames[day-1]).font(.subheadline.weight(.semibold)).frame(maxWidth:.infinity,minHeight:44)
          .foregroundStyle(days.contains(day) ? MorningTheme.onYellow : MorningTheme.muted)
          .background(days.contains(day) ? MorningTheme.yellow : MorningTheme.soft,in:Circle())
        }.buttonStyle(.plain).accessibilityAddTraits(days.contains(day) ? .isSelected : [])
       }
      }
      Text(days.isEmpty ? appText("Rings once") : appText("Uses your phone’s local time")).font(.caption).foregroundStyle(MorningTheme.muted)
     }
     VStack(alignment:.leading,spacing:12) {
      Text(appText("Your morning")).font(.subheadline.weight(.semibold)).foregroundStyle(MorningTheme.muted)
      HStack(spacing:4) {
       ForEach(WakeMode.allCases,id:\.self) {value in
        modeButton(value)
       }
      }.padding(4).background(MorningTheme.soft,in:RoundedRectangle(cornerRadius:16))
      Text(challenge.kind == .pushUps ? appText("Try %lld push-ups",count:challenge.repetitions ?? 3) : appText("Wake up at your own pace")).font(.subheadline).accessibilityIdentifier("modeExplanation")
      Text(appText("Defaults get more active from Gentle to Focused. Your own challenge choice stays selected.")).font(.footnote).foregroundStyle(MorningTheme.muted)
      Text(appText("You can always confirm you are awake or stop.")).font(.footnote).foregroundStyle(MorningTheme.muted)
     }
     VStack(alignment:.leading,spacing:12) {
      Text(appText("Challenge")).font(.subheadline.weight(.semibold)).foregroundStyle(MorningTheme.muted)
      ForEach(ChallengeKind.allCases,id:\.self) {kind in
       challengeButton(kind)
      }
     }
     NavigationLink {
      SoundSelection(sound:$sound,volume:$volume,access:preview.access,unlock:{pro=true},preview:playPreview,stopPreview:{soundPreview.stop()})
     } label: {
      HStack(spacing:12) {
       Image(systemName:"music.note")
       Text(appText("Sound"))
       Spacer()
       Text(sound.title).font(.subheadline).foregroundStyle(MorningTheme.muted)
       Image(systemName:"chevron.right").font(.caption)
      }.padding(16).background(MorningTheme.surface,in:RoundedRectangle(cornerRadius:16))
       .overlay {RoundedRectangle(cornerRadius:16).strokeBorder(MorningTheme.line)}
     }.buttonStyle(.plain).accessibilityIdentifier("chooseSound")
    }.padding(20)
   }.background(MorningTheme.canvas.ignoresSafeArea()).foregroundStyle(MorningTheme.ink)
   .navigationTitle(appText(editing ? "Edit alarm" : "New alarm")).navigationBarTitleDisplayMode(.inline)
   .toolbar(.visible,for:.navigationBar).toolbarBackground(MorningTheme.canvas,for:.navigationBar).toolbarBackground(.visible,for:.navigationBar)
   .toolbar {ToolbarItem(placement:.cancellationAction) {Button(appText("Cancel")) {soundPreview.stop();dismiss()}.disabled(saving)}}
   .safeAreaInset(edge:.bottom) {
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
        try await save(SavedAlarm(id:alarmID,time:value,mode:mode,sound:sound,challenge:challenge))
        dismiss()
       } catch NativeAlarmError.denied {
        saveError=appText("Alarm access is off. Allow alarms for HiMorning in Settings, then try again.")
        alarmAccessDenied=true;saving=false
       } catch {
        saveError=appText("This alarm could not be confirmed. Please check your system alarms before relying on it.")
        saving=false
       }
      }
     } label: {
      HStack {if saving {ProgressView()};Text(appText(saving ? "Saving…" : "Save"))}
     }.buttonStyle(MorningButtonStyle()).disabled(saving).accessibilityIdentifier("saveAlarm")
      .accessibilityLabel(appText(saving ? "Saving…" : "Save"))
    }.padding(.horizontal,20).padding(.vertical,12).background(MorningTheme.canvas)
   }
   .disabled(saving).interactiveDismissDisabled(saving)
   .tint(MorningTheme.accent).onDisappear {soundPreview.stop()}
   .onChange(of:volume) {_,value in soundPreview.setVolume(value)}
   .onChange(of:preview.access) {_,access in
    mode=access.effectiveMode(mode);sound=access.effectiveSound(sound);soundPreview.stop()
    challenge=access.effectiveChallenge(choseChallenge ? challenge : .legacyDefault(for:mode))
    pushUpTarget=access.effectiveChallenge(.pushUps(repetitions:pushUpTarget)).repetitions ?? 3
   }
   .sheet(isPresented:$pro) {ProView(store:store,preview:preview)}
  }
 }
 private func challengeButton(_ kind:ChallengeKind)->some View {
  VStack(alignment:.leading,spacing:0) {
   Button {
    choseChallenge=true
    switch kind {
    case .none:challenge = .none
    case .pushUps:challenge = .pushUps(repetitions:pushUpTarget)
    case .readAndChoose:challenge = .readAndChoose
    case .guidedRhythm:challenge = .guidedRhythm(variant:rhythmVariant)
    case .readAloud:challenge = .readAloud
    }
   } label: {
    HStack(spacing:14) {
     Image(systemName:kind.icon).frame(width:32)
     Text(kind.title).font(.body.weight(.medium))
     Spacer()
     Image(systemName:challenge.kind == kind ? "checkmark.circle.fill" : "circle").foregroundStyle(MorningTheme.accent)
    }.padding(14).contentShape(Rectangle())
   }.buttonStyle(.plain).accessibilityIdentifier("challenge-"+kind.editorIdentifier)
    .accessibilityAddTraits(challenge.kind == kind ? .isSelected : [])
   if challenge.kind == kind {
    VStack(alignment:.leading,spacing:12) {
     Text(kind.summary).font(.footnote).foregroundStyle(MorningTheme.muted).accessibilityIdentifier("challenge-summary-"+kind.editorIdentifier)
     if kind == .pushUps {
      Stepper(appText("%lld push-ups",count:pushUpTarget),value:$pushUpTarget,in:1...(preview.access.hasFullAccess ? 5 : 3))
       .onChange(of:pushUpTarget) {_,value in if challenge.kind == .pushUps {challenge = .pushUps(repetitions:value)}}
       .accessibilityIdentifier("pushUpTarget")
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
    mode=value
    if !choseChallenge {challenge = .legacyDefault(for:value);pushUpTarget=challenge.repetitions ?? 3}
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
    Text(appText(value == .gentle ? "Default: No challenge" : value == .balanced ? "Default: 3 push-ups" : "Default: 5 push-ups"))
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
  ScrollView {
   VStack(alignment:.leading,spacing:24) {
    Text(appText("Choose a sound for your morning.")).font(.title2.weight(.semibold))
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
   }.padding(20)
  }.background(MorningTheme.canvas.ignoresSafeArea()).foregroundStyle(MorningTheme.ink)
   .navigationTitle(appText("Sound")).navigationBarTitleDisplayMode(.inline).tint(MorningTheme.accent)
   .onDisappear(perform:stopPreview)
   .onChange(of:scenePhase) {_,phase in if phase != .active {stopPreview()}}
 }
}
