import SwiftUI
import AVFoundation
import HiMorningCore
struct AlarmEditor:View {
 @Environment(\.dismiss) private var dismiss
 @State private var time=Calendar.current.date(from:DateComponents(hour:6,minute:30)) ?? Date()
 @State private var mode:WakeMode = .gentle
 @State private var sound:AlarmSound = .system
 @State private var days:Set<Int>=[2,3,4,5,6]
 @State private var volume:Double=0.3
 @State private var soundPreview=SoundPreview()
 @State private var pro=false
 @ObservedObject var store:SubscriptionStore
 @ObservedObject var preview:PreviewStore
 let save:(AlarmTime,WakeMode,AlarmSound)->Void
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
      Text(mode.explanation).font(.subheadline).accessibilityIdentifier("modeExplanation")
      Text(appText("You can always confirm you are awake or stop.")).font(.footnote).foregroundStyle(MorningTheme.muted)
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
   .navigationTitle(appText("New alarm")).navigationBarTitleDisplayMode(.inline)
   .toolbar(.visible,for:.navigationBar).toolbarBackground(MorningTheme.canvas,for:.navigationBar).toolbarBackground(.visible,for:.navigationBar)
   .toolbar {ToolbarItem(placement:.cancellationAction) {Button(appText("Cancel")) {soundPreview.stop();dismiss()}}}
   .safeAreaInset(edge:.bottom) {
    Button(appText("Save")) {
     let c=Calendar.current.dateComponents([.hour,.minute],from:time)
     if let value=try? AlarmTime(hour:c.hour ?? 6,minute:c.minute ?? 30,weekdays:days) {save(value,mode,sound);soundPreview.stop();dismiss()}
    }.buttonStyle(MorningButtonStyle()).padding(.horizontal,20).padding(.vertical,12).background(MorningTheme.canvas)
   }
   .tint(MorningTheme.accent).onDisappear {soundPreview.stop()}
   .onChange(of:volume) {_,value in soundPreview.setVolume(value)}
   .onChange(of:preview.access) {_,access in
    mode=access.effectiveMode(mode);sound=access.effectiveSound(sound);soundPreview.stop()
   }
   .sheet(isPresented:$pro) {ProView(store:store,preview:preview)}
  }
 }
 private func modeButton(_ value:WakeMode)->some View {
  Button {preview.refresh();if preview.access.allows(mode:value) {mode=value} else {pro=true}} label: {
   VStack(spacing:8) {
    Image(systemName:value == .gentle ? "leaf" : value == .balanced ? "sun.max" : "bolt")
    Text(value.title).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center)
    if !preview.access.allows(mode:value) {Image(systemName:"lock.fill").font(.caption)}
   }.padding(10).frame(maxWidth:.infinity,minHeight:72)
    .background(mode == value ? MorningTheme.surface : .clear,in:RoundedRectangle(cornerRadius:12))
  }.buttonStyle(.plain).accessibilityIdentifier("mode-"+value.rawValue)
   .accessibilityAddTraits(mode == value ? .isSelected : [])
 }
 private func playPreview() {
  guard let url=Bundle.main.url(forResource:sound.rawValue,withExtension:"wav") else {soundPreview.stop();return}
  soundPreview.play(url:url,volume:volume)
 }
}
private struct SoundSelection:View {
 @Binding var sound:AlarmSound
 @Binding var volume:Double
 let access:MorningAccess
 let unlock:()->Void
 let preview:()->Void
 let stopPreview:()->Void
 var body:some View {
  ScrollView {
   VStack(alignment:.leading,spacing:24) {
    Text(appText("Choose a sound for your morning.")).font(.title2.weight(.semibold))
    VStack(spacing:0) {
     ForEach(AlarmSound.allCases,id:\.self) {value in
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
      Divider().overlay(MorningTheme.line)
     }
    }
    if sound != .system {
     Button(action:preview) {Label(appText("Preview sound"),systemImage:"play.fill")}.buttonStyle(MorningButtonStyle(primary:false))
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
 }
}
