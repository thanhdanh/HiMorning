import SwiftUI
import HiMorningCore

struct ExploreChallengesView: View {
 let onSelect: (ChallengeKind) -> Void
 @Environment(\.dismiss) private var dismiss

 private struct Category: Identifiable {
  let id: String
  let titleKey: String
  let kinds: [ChallengeKind]
 }

 private var categories: [Category] {
  [
   Category(id: "no-camera", titleKey: "Camera-free", kinds: [.readAndChoose, .riddle, .readAloud, .none]),
   Category(id: "gentle-camera", titleKey: "Gentle & close framing", kinds: [.morningLight, .waveHand, .neckRotation]),
   Category(id: "active-movement", titleKey: "Active movement", kinds: [.pushUps, .jumpingJacks, .stretching])
  ]
 }

 private func badgeKey(for kind: ChallengeKind) -> String {
  switch kind {
  case .none, .readAndChoose, .riddle: return "No camera"
  case .readAloud: return "Voice"
  case .morningLight: return "Window light"
  case .waveHand, .neckRotation: return "Close camera"
  case .pushUps, .jumpingJacks, .stretching: return "Whole body"
  case .guidedRhythm: return "Camera"
  }
 }

 var body: some View {
  NavigationStack {
   ScrollView {
    VStack(alignment: .leading, spacing: 24) {
     Text(appText("Practice any challenge now without changing your alarms or progress."))
      .font(.subheadline)
      .foregroundStyle(MorningTheme.muted)

     ForEach(categories) { category in
      VStack(alignment: .leading, spacing: 12) {
       Text(appText(category.titleKey))
        .font(.headline)
       VStack(spacing: 10) {
        ForEach(category.kinds, id: \.self) { kind in
         Button {
          dismiss()
          onSelect(kind)
         } label: {
          HStack(alignment: .top, spacing: 14) {
           let tint = MorningTheme.modeAccent(kind.preferredMode)
           ChallengeIcon(kind: kind, size: 24, animated: true)
            .foregroundStyle(tint)
            .frame(width: 28, height: 28)
            .padding(8)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

           VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
             Text(kind.title)
              .font(.headline)
              .foregroundStyle(MorningTheme.ink)
             Spacer(minLength: 4)
             Text(appText(badgeKey(for: kind)))
              .font(.caption2.weight(.semibold))
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(MorningTheme.soft, in: Capsule())
              .foregroundStyle(MorningTheme.muted)
            }
            Text(kind.summary)
             .font(.footnote)
             .foregroundStyle(MorningTheme.muted)
             .multilineTextAlignment(.leading)
             .fixedSize(horizontal: false, vertical: true)
           }
          }
          .padding(14)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(MorningTheme.surface, in: RoundedRectangle(cornerRadius: 18))
          .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(MorningTheme.line))
         }
         .buttonStyle(.plain)
         .accessibilityIdentifier("practice-" + kind.editorIdentifier)
        }
       }
      }
     }
    }
    .padding(20)
   }
   .background(MorningTheme.canvas.ignoresSafeArea())
   .foregroundStyle(MorningTheme.ink)
   .navigationTitle(appText("Explore challenges"))
   .navigationBarTitleDisplayMode(.inline)
   .toolbar {
    ToolbarItem(placement: .cancellationAction) {
     Button(appText("Close")) { dismiss() }
      .accessibilityIdentifier("closeExploreChallenges")
    }
   }
  }
  .tint(MorningTheme.accent)
 }
}
