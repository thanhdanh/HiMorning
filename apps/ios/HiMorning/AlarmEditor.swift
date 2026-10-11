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
 @State private var player:AVAudioPlayer?
 let save:(AlarmTime,WakeMode,AlarmSound)->Void
 var body:some View {
  NavigationStack {
   Form {
    DatePicker(appText("Wake-up time"),selection:$time,displayedComponents:.hourAndMinute).datePickerStyle(.wheel)
    Section(appText("Your morning")) {
     Picker(appText("Mode"),selection:$mode) {ForEach(WakeMode.allCases,id:\.self) {Text($0.title).tag($0)}}
     Text(mode.explanation).font(.footnote)
     Text(appText("You can always confirm you are awake or stop.")).font(.footnote).foregroundStyle(.secondary)
    }
    Section(appText("Repeat")) {
     ForEach(Array([appText("Sun"),appText("Mon"),appText("Tue"),appText("Wed"),appText("Thu"),appText("Fri"),appText("Sat")].enumerated()),id:\.offset) {i,name in Toggle(name,isOn:Binding(get:{days.contains(i+1)},set:{if $0 {days.insert(i+1)} else {days.remove(i+1)}}))}
     Text(days.isEmpty ? appText("Rings once") : appText("Uses your phone’s local time")).font(.footnote)
    }
    Section(appText("Sound")) {
     Picker(appText("Alarm sound"),selection:$sound) {ForEach(AlarmSound.allCases,id:\.self) {Text($0.title).tag($0)}}
     if sound != .system {
      Button(appText("Preview sound")) {preview()}
      Slider(value:$volume,in:0...0.7).accessibilityLabel(appText("Preview volume")).onChange(of:volume) {_,value in player?.volume=Float(value)}
     }
     Text(appText("This slider changes the preview only. The alarm uses system volume. Please check it on your phone.")).font(.footnote).foregroundStyle(.secondary)
    }
   }.navigationTitle(appText("New alarm"))
   .toolbar {ToolbarItem(placement:.cancellationAction) {Button(appText("Cancel")) {player?.stop();dismiss()}};ToolbarItem(placement:.confirmationAction) {Button(appText("Save")) {let c=Calendar.current.dateComponents([.hour,.minute],from:time);if let value=try? AlarmTime(hour:c.hour ?? 6,minute:c.minute ?? 30,weekdays:days) {save(value,mode,sound);player?.stop();dismiss()}}}}
   .onDisappear {player?.stop()}
  }
 }
 private func preview() {
  player?.stop()
  guard let url=Bundle.main.url(forResource:sound.rawValue,withExtension:"wav"),let audio=try? AVAudioPlayer(contentsOf:url) else {return}
  player=audio;audio.volume=Float(volume);audio.play()
 }
}
