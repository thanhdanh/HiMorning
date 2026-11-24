import SwiftUI

struct MorningSplashView:View {
 @Environment(\.accessibilityReduceMotion) private var reduceMotion
 @State private var entered=false
 @State private var raySpin:Double=0

 var body:some View {
  ZStack {
   MorningTheme.canvas.ignoresSafeArea()
   RadialGradient(
    colors:[MorningTheme.yellow.opacity(entered ? 0.34 : 0.08),MorningTheme.yellow.opacity(0.08),.clear],
    center:.center,
    startRadius:8,
    endRadius:entered ? 240 : 90
   )
   .ignoresSafeArea()

   VStack(spacing:20) {
    ZStack {
     ForEach(0..<12,id:\.self) { index in
      Capsule()
       .fill(MorningTheme.accent.opacity(0.45))
       .frame(width:2.5,height:10)
       .offset(y:-66)
       .rotationEffect(.degrees(Double(index)*30 + raySpin))
     }
     .opacity(entered ? 1 : 0)

     MorningSun(size:104,showRays:false)
      .scaleEffect(entered ? 1 : 0.72)
      .offset(y:entered ? 0 : 28)
    }

    VStack(spacing:8) {
     Text("HiMorning.")
      .modifier(MorningTypography.heading(size:32,relativeTo:.largeTitle))
      .fontWeight(.bold)
      .foregroundStyle(MorningTheme.ink)
     Text(appText("A fresh start,\nat your pace."))
      .font(.subheadline.weight(.medium))
      .foregroundStyle(MorningTheme.muted)
      .multilineTextAlignment(.center)
    }
    .opacity(entered ? 1 : 0)
    .offset(y:entered ? 0 : 12)
   }
  }
  .onAppear {
   if reduceMotion {
    entered=true
   } else {
    withAnimation(.spring(response:0.65,dampingFraction:0.78)) {entered=true}
    withAnimation(.linear(duration:8).repeatForever(autoreverses:false)) {raySpin=360}
   }
  }
  .accessibilityElement(children:.combine)
  .accessibilityIdentifier("morningSplash")
 }
}
