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
    DatePicker("Giờ thức dậy",selection:$time,displayedComponents:.hourAndMinute).datePickerStyle(.wheel).environment(\.locale,Locale(identifier:"vi_VN"))
    Section("Nhịp buổi sáng") {
     Picker("Chế độ",selection:$mode) {ForEach(WakeMode.allCases,id:\.self) {Text($0.title).tag($0)}}
     Text(mode.explanation).font(.footnote)
     Text("Bạn luôn có thể chọn tự xác nhận hoặc dừng.").font(.footnote).foregroundStyle(.secondary)
    }
    Section("Lặp lại") {
     ForEach(Array(["CN","T2","T3","T4","T5","T6","T7"].enumerated()),id:\.offset) {i,name in Toggle(name,isOn:Binding(get:{days.contains(i+1)},set:{if $0 {days.insert(i+1)} else {days.remove(i+1)}}))}
     Text(days.isEmpty ? "Chỉ reo một lần" : "Theo giờ địa phương của điện thoại").font(.footnote)
    }
    Section("Âm thanh") {
     Picker("Âm báo",selection:$sound) {ForEach(AlarmSound.allCases,id:\.self) {Text($0.title).tag($0)}}
     if sound != .system {
      Button("Nghe thử") {preview()}
      Slider(value:$volume,in:0...0.7).accessibilityLabel("Âm lượng nghe thử").onChange(of:volume) {_,value in player?.volume=Float(value)}
     }
     Text("Thanh âm lượng chỉ dùng khi nghe thử. Âm báo dùng âm lượng hệ thống; hãy kiểm tra trên điện thoại.").font(.footnote).foregroundStyle(.secondary)
    }
   }.navigationTitle("Báo thức mới")
   .toolbar {ToolbarItem(placement:.cancellationAction) {Button("Hủy") {player?.stop();dismiss()}};ToolbarItem(placement:.confirmationAction) {Button("Lưu") {let c=Calendar.current.dateComponents([.hour,.minute],from:time);if let value=try? AlarmTime(hour:c.hour ?? 6,minute:c.minute ?? 30,weekdays:days) {save(value,mode,sound);player?.stop();dismiss()}}}}
   .onDisappear {player?.stop()}
  }
 }
 private func preview() {
  player?.stop()
  guard let url=Bundle.main.url(forResource:sound.rawValue,withExtension:"wav"),let audio=try? AVAudioPlayer(contentsOf:url) else {return}
  player=audio;audio.volume=Float(volume);audio.play()
 }
}
