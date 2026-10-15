import SwiftUI

struct ChallengeCelebrationView:View {
 var body:some View {
  VStack(spacing:12) {
   ZStack {
    Circle().fill(MorningTheme.yellow).frame(width:88,height:88)
    Image(systemName:"checkmark")
     .font(.system(size:38,weight:.bold)).foregroundStyle(MorningTheme.onYellow)
   }.frame(height:160).accessibilityHidden(true)
   Text(appText("Hooray!"))
    .font(.system(.largeTitle,design:.rounded).bold())
    .accessibilityAddTraits(.isHeader)
   Text(appText("Challenge complete!"))
    .font(.title3.weight(.semibold))
   Text(appText("Try again, or head home when you’re ready."))
    .font(.body).foregroundStyle(MorningTheme.muted)
  }
  .multilineTextAlignment(.center)
  .fixedSize(horizontal:false,vertical:true)
  .frame(maxWidth:.infinity)
  .accessibilityElement(children:.contain)
  .accessibilityIdentifier("challengeCelebration")
 }
}

struct ChallengeConfetti:View {
 @State private var started=Date()
 @State private var ended=false
 var body:some View {
  TimelineView(.animation(minimumInterval:1.0/30,paused:ended)) {timeline in
   Canvas {context,size in
    let elapsed=timeline.date.timeIntervalSince(started)
    guard elapsed>=0,elapsed<3 else {return}
    let colors:[Color]=[MorningTheme.yellow,MorningTheme.success,.pink,.orange,.teal]
    for index in 0..<90 {
     let time=elapsed-Double(index % 8)*0.025
     guard time>=0 else {continue}
     let angle=Double(index)*2.3999632297
     let speed=120+Double(index % 9)*28
     var particle=context
     particle.opacity=min(1,(3-elapsed)*2)
     particle.translateBy(x:size.width/2+cos(angle)*speed*time,y:size.height*0.38+sin(angle)*speed*time+180*time*time)
     particle.rotate(by:.radians(angle+time*Double(index % 5+2)))
     particle.fill(Path(CGRect(x:-4,y:-6,width:8,height:index.isMultiple(of:2) ? 12:7)),with:.color(colors[index % colors.count]))
    }
   }
  }
  .accessibilityHidden(true)
  .allowsHitTesting(false)
  .task {
   started=Date()
   do {try await Task.sleep(for:.seconds(3))} catch {return}
   ended=true
  }
 }
}
