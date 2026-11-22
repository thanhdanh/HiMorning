import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct MorningWinCardView: View {
 let challengeTitle: String
 let completedAt: Date
 let journeyStep: Int?
 let journeyTotal: Int

 var body: some View {
  VStack(alignment: .leading, spacing: 18) {
   HStack(alignment: .center, spacing: 12) {
    MorningSun(size: 46)
    VStack(alignment: .leading, spacing: 2) {
     Text("HiMorning.")
      .font(.headline.weight(.bold))
     Text(appText("Morning win"))
      .font(.caption.weight(.medium))
      .opacity(0.75)
    }
    Spacer(minLength: 8)
    Text(completedAt, format: .dateTime.hour().minute().locale(appLocale()))
     .font(.title3.weight(.bold))
     .monospacedDigit()
   }

   Text(challengeTitle)
    .font(.system(.title, design: .rounded).weight(.bold))
    .fixedSize(horizontal: false, vertical: true)

   if let journeyStep {
    Text(String(format: appText("Morning %lld of %lld"), journeyStep, journeyTotal))
     .font(.subheadline.weight(.semibold))
     .padding(.horizontal, 12)
     .padding(.vertical, 6)
     .background(MorningTheme.surface.opacity(0.65), in: Capsule())
   }

   Divider().overlay(MorningTheme.onYellow.opacity(0.15))

   HStack {
    Text(completedAt, format: .dateTime.weekday(.wide).month(.abbreviated).day().locale(appLocale()))
     .font(.caption)
     .opacity(0.8)
    Spacer(minLength: 8)
    Text(appText("Checked privately on iPhone"))
     .font(.caption2.weight(.medium))
     .opacity(0.7)
   }
  }
  .padding(24)
  .frame(maxWidth: .infinity, alignment: .leading)
  .foregroundStyle(MorningTheme.onYellow)
  .background(MorningTheme.hero, in: RoundedRectangle(cornerRadius: 28))
  .overlay(
   RoundedRectangle(cornerRadius: 28)
    .strokeBorder(MorningTheme.onYellow.opacity(0.08), lineWidth: 1)
  )
  .padding(16)
  .background(MorningTheme.canvas)
 }
}

struct MorningWinShareImage: Transferable {
 let pngData: Data

 static var transferRepresentation: some TransferRepresentation {
  DataRepresentation(exportedContentType: .png) { item in
   item.pngData
  }
 }
}

struct MorningWinShareButton: View {
 let challengeTitle: String
 let completedAt: Date
 let journeyStep: Int?
 let journeyTotal: Int

 @State private var shareImage: MorningWinShareImage?

 var body: some View {
  Group {
   if let shareImage {
    ShareLink(
     item: shareImage,
     preview: SharePreview(
      appText("Morning win"),
      image: Image(uiImage: UIImage(data: shareImage.pngData) ?? UIImage())
     )
    ) {
     Label(appText("Share morning win"), systemImage: "square.and.arrow.up")
    }
    .buttonStyle(MorningButtonStyle(primary: false))
    .accessibilityIdentifier("shareMorningWin")
   }
  }
  .task(id: "\(challengeTitle)-\(journeyStep ?? -1)") {
   let renderer = ImageRenderer(
    content: MorningWinCardView(
     challengeTitle: challengeTitle,
     completedAt: completedAt,
     journeyStep: journeyStep,
     journeyTotal: journeyTotal
    ).frame(width: 380)
   )
   renderer.scale = 3.0
   if let uiImage = renderer.uiImage, let data = uiImage.pngData() {
    shareImage = MorningWinShareImage(pngData: data)
   }
  }
 }
}
