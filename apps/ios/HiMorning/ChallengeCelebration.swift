import SwiftUI

struct ChallengeCelebrationView:View {
 var body:some View {
  VStack(spacing:12) {
   ChallengeSuccessGraphic()
   Text(appText("Hooray!"))
    .font(.system(.largeTitle,design:.rounded).bold())
    .accessibilityAddTraits(.isHeader)
   Text(appText("Challenge complete!"))
    .font(.title3.weight(.semibold))
   Text(appText("Tap Back to home when you’re ready."))
    .font(.body).foregroundStyle(MorningTheme.muted)
  }
  .multilineTextAlignment(.center)
  .fixedSize(horizontal:false,vertical:true)
  .frame(maxWidth:.infinity)
  .accessibilityElement(children:.contain)
  .accessibilityIdentifier("challengeCelebration")
 }
}

private struct ChallengeSuccessGraphic:View {
 @Environment(\.accessibilityReduceMotion) private var reduceMotion
 @State private var expanded=false
 var body:some View {
  ZStack {
   if !reduceMotion {
    ForEach(0..<16,id:\.self) {index in
     Capsule()
      .fill(index.isMultiple(of:3) ? MorningTheme.success : MorningTheme.yellow)
      .frame(width:4,height:index.isMultiple(of:2) ? 12 : 7)
      .offset(y:expanded ? -72 : -46)
      .rotationEffect(.degrees(Double(index)*22.5))
      .opacity(expanded ? 0 : 1)
    }
   }
   Circle().fill(MorningTheme.yellow).frame(width:88,height:88)
   Image(systemName:"checkmark")
    .font(.system(size:38,weight:.bold)).foregroundStyle(MorningTheme.onYellow)
  }
  .frame(height:160)
  .frame(maxWidth:.infinity)
  .accessibilityHidden(true)
  .allowsHitTesting(false)
  .onAppear {
   guard !reduceMotion,!expanded else {return}
   withAnimation(.easeOut(duration:1.7)) {expanded=true}
  }
 }
}
