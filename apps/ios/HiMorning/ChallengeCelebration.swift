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
  TimelineView(.animation(minimumInterval:1.0/60,paused:ended)) {timeline in
   Canvas {context,size in
    let elapsed=timeline.date.timeIntervalSince(started)
    guard !ended,elapsed>=0,elapsed<2 else {return}
    let colors:[Color]=[MorningTheme.yellow,.pink,.orange,.teal,.mint,.indigo]
    for index in 0..<210 {
     // Stable variation keeps trajectories continuous between frames.
     let seed=Double(index)+1
     let random=abs(sin(seed*127.1)*43758.5453).truncatingRemainder(dividingBy:1)
     let variation=abs(sin(seed*311.7)*9643.239).truncatingRemainder(dividingBy:1)
     let time=elapsed-Double(index % 3)*0.045
     guard time>=0 else {continue}
     let cannon=index % 3
     let origin=cannon == 0 ? 0.12 : cannon == 1 ? 0.88 : 0.5
     let direction=cannon == 0 ? -0.95 : cannon == 1 ? -2.19 : -Double.pi/2
     let angle=direction+(random-0.5)*1.7
     let speed=440+variation*570
     let drag=1.7+random*1.4
     let travel=(1-exp(-drag*time))/drag
     let flutter=sin(time*(9+variation*9)+seed)*time*9
     var particle=context
     particle.opacity=min(1,max(0,(2-elapsed)/0.45))
     particle.translateBy(x:size.width*origin+cos(angle)*speed*travel+flutter,
                          y:size.height*0.68+sin(angle)*speed*travel+1100/drag*(time-travel))
     particle.rotate(by:.radians(seed+time*(5+random*11)))
     particle.scaleBy(x:0.6+variation*0.7,y:max(0.12,abs(cos(seed+time*(8+variation*7)))))
     let rect=CGRect(x:-4,y:-6,width:8,height:index.isMultiple(of:3) ? 8 : 12)
     let shape=index.isMultiple(of:4) ? Path(ellipseIn:rect) : Path(roundedRect:rect,cornerRadius:1)
     particle.fill(shape,with:.color(colors[index % colors.count]))
    }
   }
  }
  .accessibilityHidden(true)
  .allowsHitTesting(false)
  .task {
   started=Date()
   do {try await Task.sleep(for:.seconds(2))} catch {return}
   ended=true
  }
 }
}
