import SwiftUI

struct BedtimeAnchorView: View {
 @ObservedObject var store: BedtimeAnchorStore
 @Environment(\.dismiss) private var dismiss

 private var bedtimeBinding: Binding<Date> {
  Binding(
   get: { store.settings.bedtimeDate },
   set: { date in
    let components = Calendar.current.dateComponents([.hour, .minute], from: date)
    store.update {
     $0.bedtimeHour = components.hour ?? 22
     $0.bedtimeMinute = components.minute ?? 30
    }
   }
  )
 }

 private var enabledBinding: Binding<Bool> {
  Binding(
   get: { store.settings.enabled },
   set: { value in store.update { $0.enabled = value } }
  )
 }

 private var leadMinutesBinding: Binding<Int> {
  Binding(
   get: { store.settings.windDownMinutes },
   set: { value in store.update { $0.windDownMinutes = value } }
  )
 }

 private var sunriseRampBinding: Binding<Bool> {
  Binding(
   get: { store.settings.sunriseRampEnabled },
   set: { value in store.update { $0.sunriseRampEnabled = value } }
  )
 }

 private var healthBinding: Binding<Bool> {
  Binding(
   get: { store.settings.healthSyncEnabled },
   set: { enabled in
    if enabled {
     Task {
      let granted = await MorningHealthSync.requestAuthorization()
      await MainActor.run {
       store.update { $0.healthSyncEnabled = granted }
      }
     }
    } else {
     store.update { $0.healthSyncEnabled = false }
    }
   }
  )
 }

 var body: some View {
  NavigationStack {
   ScrollView {
    VStack(alignment: .leading, spacing: 20) {
     VStack(alignment: .leading, spacing: 14) {
      Toggle(isOn: enabledBinding) {
       VStack(alignment: .leading, spacing: 4) {
        Text(appText("Bedtime anchor")).font(.headline)
        Text(appText("A calm evening reminder before your target sleep time."))
         .font(.footnote).foregroundStyle(MorningTheme.muted)
       }
      }
      .tint(MorningTheme.yellow)
      .accessibilityIdentifier("bedtimeAnchorToggle")

      if store.settings.enabled {
       DatePicker(appText("Target bedtime"), selection: bedtimeBinding, displayedComponents: .hourAndMinute)
        .datePickerStyle(.compact)
       Picker(appText("Remind before bed"), selection: leadMinutesBinding) {
        Text(appText("15 min")).tag(15)
        Text(appText("30 min")).tag(30)
        Text(appText("45 min")).tag(45)
       }
       .pickerStyle(.segmented)
      }

      if let status = store.statusMessage {
       Text(status).font(.footnote).foregroundStyle(MorningTheme.muted)
      }
     }
     .padding(18)
     .background(MorningTheme.surface, in: RoundedRectangle(cornerRadius: 20))
     .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(MorningTheme.line))

     VStack(alignment: .leading, spacing: 14) {
      Toggle(isOn: sunriseRampBinding) {
       VStack(alignment: .leading, spacing: 4) {
        Text(appText("Gradual sunrise ramp")).font(.headline)
        Text(appText("Start sound previews gently instead of jumping to full volume."))
         .font(.footnote).foregroundStyle(MorningTheme.muted)
       }
      }
      .tint(MorningTheme.yellow)

      if MorningHealthSync.isAvailable {
       Divider().overlay(MorningTheme.line)
       Toggle(isOn: healthBinding) {
        VStack(alignment: .leading, spacing: 4) {
         Text(appText("Apple Health mindful check-ins")).font(.headline)
         Text(appText("Your morning wins stay on this device and sync to Apple Health only when you enable this."))
          .font(.footnote).foregroundStyle(MorningTheme.muted)
        }
       }
       .tint(MorningTheme.yellow)
      }
     }
     .padding(18)
     .background(MorningTheme.surface, in: RoundedRectangle(cornerRadius: 20))
     .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(MorningTheme.line))
    }
    .padding(20)
   }
   .background(MorningTheme.canvas.ignoresSafeArea())
   .foregroundStyle(MorningTheme.ink)
   .navigationTitle(appText("Evening & health"))
   .navigationBarTitleDisplayMode(.inline)
   .toolbar {
    ToolbarItem(placement: .cancellationAction) {
     Button(appText("Close")) { dismiss() }
      .accessibilityIdentifier("closeBedtimeAnchor")
    }
   }
  }
  .tint(MorningTheme.accent)
 }
}
