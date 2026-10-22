import SwiftUI
import HiMorningCore

extension ChallengeKind {
 var hasMovementIllustration:Bool {
  switch self {
  case .pushUps,.waveHand,.neckRotation,.jumpingJacks,.stretching,.guidedRhythm:return true
  default:return false
  }
 }
}

/// The illustration and its caption describe the same camera framing.
/// These are presentation hints; capture counters keep their own evidence requirements.
enum MovementCameraFraming {
 case hand,face,upperBody,wholeBodyFront,wholeBodySide
 var caption:String {
  switch self {
  case .hand:return "Front view · Hand"
  case .face:return "Front view · Face"
  case .upperBody:return "Front view · Upper body"
  case .wholeBodyFront:return "Front view · Whole body"
  case .wholeBodySide:return "Side view · Whole body"
  }
 }
 var artboard:CGRect {
  switch self {
  case .hand:return CGRect(x:30,y:20,width:60,height:66)
  case .face:return CGRect(x:38,y:5,width:44,height:40)
  case .upperBody:return CGRect(x:15,y:0,width:90,height:64)
  case .wholeBodyFront,.wholeBodySide:return CGRect(x:0,y:0,width:120,height:100)
  }
 }
}

extension ChallengeSelection {
 var movementCameraFraming:MovementCameraFraming {
  switch kind {
  case .waveHand:return .hand
  case .neckRotation:return .face
  case .stretching:return .upperBody
  case .guidedRhythm:return rhythmVariant == .seated ? .upperBody : .wholeBodySide
  case .pushUps:return .wholeBodySide
  default:return .wholeBodyFront
  }
 }
}

/// One vector vocabulary for alarm cards and instructional motion. No camera data is used.
struct MovementIllustration:View {
 let selection:ChallengeSelection
 var animated=true
 var paused=false
 @Environment(\.scenePhase) private var scene
 @Environment(\.accessibilityReduceMotion) private var reduceMotion
 @State private var visible=false
 @State private var elapsed:TimeInterval=0
 @State private var resumedAt=Date()
 private var motionReduced:Bool {
  #if DEBUG
  reduceMotion || ProcessInfo.processInfo.arguments.contains("--ui-reduce-motion")
  #else
  reduceMotion
  #endif
 }
 private var running:Bool {animated && visible && !paused && !motionReduced && scene == .active}
 static func loopDuration(for selection:ChallengeSelection)->TimeInterval {
  switch selection.kind {
  case .waveHand:return 1.1
  case .jumpingJacks:return 1.4
  case .pushUps:return 2.6
  case .neckRotation:return 3.6
  case .stretching:return 2.8
  case .guidedRhythm:return selection.rhythmVariant == .seated ? 2.6 : 2.8
  default:return 2.4
  }
 }
 var body:some View {
  GeometryReader { geometry in
   let diameter=min(geometry.size.width,geometry.size.height)*0.9
   TimelineView(.animation(minimumInterval:1.0/30,paused:!running)) { context in
    let seconds=elapsed+(running ? max(0,context.date.timeIntervalSince(resumedAt)) : 0)
    MovementFigure(selection:selection,phase:animated && !motionReduced ? seconds / Self.loopDuration(for:selection) : 0.22)
     .fill(.black).padding(diameter*0.05)
   }
   .frame(width:diameter,height:diameter)
   .background(.white.opacity(0.08),in:Circle())
   .clipShape(Circle())
   .overlay {Circle().strokeBorder(.black.opacity(0.22),lineWidth:0.8)}
   .frame(maxWidth:.infinity,maxHeight:.infinity)
  }
  .onChange(of:running) {old,new in
   if old {elapsed += max(0,Date().timeIntervalSince(resumedAt))}
   if new {resumedAt=Date()}
  }
  .onAppear {resumedAt=Date();visible=true}
  .onDisappear {visible=false}
  .accessibilityHidden(true)
 }
}

/// A shared, fixed-proportion silhouette with a tapered torso
/// and articulated limbs. Side profiles match a phone facing the exercise.
struct MovementFigure:Shape {
 let selection:ChallengeSelection
 let phase:Double
 func path(in rect:CGRect)->Path {
  let cycle=phase.truncatingRemainder(dividingBy:1)
  let outward=selection.kind == .pushUps || selection.kind == .guidedRhythm ? 0.56 : 0.5
  let progress=cycle<outward ? cycle/outward : (1-cycle)/(1-outward)
  let amount=progress*progress*(3-2*progress)
  var figure=Path()
  func p(_ x:Double,_ y:Double)->CGPoint {CGPoint(x:x,y:y)}
  func line(_ points:[CGPoint],_ width:CGFloat) {
   var path=Path();path.addLines(points)
   figure=figure.union(path.strokedPath(.init(lineWidth:width,lineCap:.round,lineJoin:.round)))
  }
  func limb(_ start:CGPoint,_ elbow:CGPoint,_ finish:CGPoint,_ width:CGFloat=5) {
   line([start,elbow],width);line([elbow,finish],width*0.88)
  }
  func head(_ center:CGPoint,look:Double?=nil) {
   var oval=Path(ellipseIn:CGRect(x:center.x-5.25,y:center.y-6.25,width:10.5,height:12.5))
   if let look {
    for side in [-1.0,1.0] {
     let eye=CGRect(x:center.x+side*1.8+look*1.5-0.65,y:center.y-1.5,width:1.3,height:1.3)
     oval=oval.subtracting(Path(ellipseIn:eye))
    }
   }
   figure=figure.union(oval)
  }
  func end(_ start:CGPoint,_ angle:Double,_ length:Double,_ side:Double=1)->CGPoint {
   p(start.x+side*sin(angle)*length,start.y+cos(angle)*length)
  }
  func joint(_ start:CGPoint,_ finish:CGPoint,_ first:Double,_ second:Double)->CGPoint {
   let dx=finish.x-start.x,dy=finish.y-start.y
   let distance=max(0.001,hypot(dx,dy))
   let along=(first*first-second*second+distance*distance)/(2*distance)
   let height=sqrt(max(0,first*first-along*along))
   return p(start.x+dx/distance*along+dy/distance*height,start.y+dy/distance*along-dx/distance*height)
  }
  func frontBody(raised:Double,spread:Double=0,seated:Bool=false,upperBody:Bool=false) {
   let lift=seated ? 0 : -sin(amount * .pi)
   func q(_ x:Double,_ y:Double)->CGPoint {p(x,y+lift)}
   if seated {
    line([q(76,37),q(76,58),q(44,58)],2)
   }
   head(q(60,18))
   line([q(60,23),q(60,27)],4)
   var torso=Path()
   torso.move(to:q(48,27));torso.addQuadCurve(to:q(72,27),control:q(60,25))
   torso.addQuadCurve(to:q(68,43),control:q(71,36))
   torso.addQuadCurve(to:q(69,53),control:q(68,48))
   torso.addQuadCurve(to:q(51,53),control:q(60,56))
   torso.addQuadCurve(to:q(52,43),control:q(52,48))
   torso.addQuadCurve(to:q(48,27),control:q(49,36));torso.closeSubpath()
   figure=figure.union(torso)
   for side in [-1.0,1.0] {
    let shoulder=q(60+11.5*side,28)
    let armAngle=0.1+2.25*raised
    let elbow=end(shoulder,armAngle,16,side)
    limb(shoulder,elbow,end(elbow,armAngle+0.08*raised,15,side))
    if upperBody {continue}
    let hip=q(60+4.5*side,52),legAngle=0.06+0.44*spread
    let knee=end(hip,legAngle,20,side),ankle=end(knee,legAngle,21,side)
    limb(hip,knee,ankle,6)
    line([ankle,p(ankle.x+4*side,ankle.y+1)],4)
   }
  }
  func sideTorso(_ shoulder:CGPoint,_ hip:CGPoint) {
   let dx=hip.x-shoulder.x,dy=hip.y-shoulder.y,length=hypot(dx,dy)
   let nx = -dy/length,ny=dx/length
   func offset(_ point:CGPoint,_ width:Double)->CGPoint {p(point.x+nx*width,point.y+ny*width)}
   var torso=Path();torso.move(to:offset(shoulder,6))
   torso.addQuadCurve(to:offset(hip,5),control:offset(p(shoulder.x+dx*0.45,shoulder.y+dy*0.45),5.5))
   torso.addLine(to:offset(hip,-5))
   torso.addQuadCurve(to:offset(shoulder,-6),control:offset(p(shoulder.x+dx*0.45,shoulder.y+dy*0.45),-4.5))
   torso.closeSubpath();figure=figure.union(torso)
  }
  switch selection.kind {
  case .pushUps:
   let angle=0.53-0.34*amount
   let ankle=p(103,87),shoulder=p(103-69*cos(angle),87-69*sin(angle))
   let hip=p(shoulder.x+28*cos(angle),shoulder.y+28*sin(angle))
   let neck=p(shoulder.x-4*cos(angle),shoulder.y-4*sin(angle))
   let rearShoulder=p(shoulder.x+2,shoulder.y-1),rearWrist=p(43,86)
   limb(rearShoulder,joint(rearShoulder,rearWrist,18,18),rearWrist,3.8)
   limb(p(hip.x+1,hip.y-1),p(hip.x+22*cos(angle),hip.y+22*sin(angle)-2),p(104,84),4.2)
   line([neck,shoulder],4);head(p(neck.x-6*cos(angle),neck.y-6*sin(angle)))
   sideTorso(shoulder,hip)
   limb(hip,p(hip.x+21*cos(angle),hip.y+21*sin(angle)),ankle,6)
   line([ankle,p(108,87)],4)
   let wrist=p(36,87)
   limb(shoulder,joint(shoulder,wrist,18,18),wrist)
   line([wrist,p(40,88)],3)
  case .jumpingJacks:frontBody(raised:amount,spread:amount)
  case .stretching:frontBody(raised:amount,upperBody:true)
  case .waveHand:
   // The wave counter observes the hand and wrist, without requiring a body pose.
   var hand=Path(roundedRect:CGRect(x:49,y:44,width:24,height:26),cornerRadius:8)
   func finger(_ points:[CGPoint],_ width:CGFloat) {
    var stroke=Path();stroke.addLines(points)
    hand=hand.union(stroke.strokedPath(.init(lineWidth:width,lineCap:.round,lineJoin:.round)))
   }
   finger([p(53,49),p(52,36)],5.5)
   finger([p(59,46),p(59,30)],5.5)
   finger([p(65,47),p(66,33)],5.5)
   finger([p(70,51),p(73,40)],5)
   finger([p(54,60),p(44,50)],6)
   finger([p(60,66),p(60,76)],12)
   let sway=sin(cycle*2 * .pi)
   figure=hand.applying(CGAffineTransform(translationX:-60,y:-78)
    .concatenating(CGAffineTransform(rotationAngle:sway*0.22))
    .concatenating(CGAffineTransform(translationX:60+sway*4,y:78)))
  case .neckRotation:
   let look=sin(cycle*2 * .pi)
   head(p(60+look,19),look:look)
   line([p(60,24),p(60,27)],4)
   var shoulders=Path()
   shoulders.move(to:p(46,40));shoulders.addQuadCurve(to:p(52,30),control:p(46,33))
   shoulders.addQuadCurve(to:p(60,27),control:p(57,29))
   shoulders.addQuadCurve(to:p(68,30),control:p(63,29))
   shoulders.addQuadCurve(to:p(74,40),control:p(74,33));shoulders.closeSubpath()
   figure=figure.union(shoulders)
   line([p(43,11),p(40,15),p(43,19)],1.5)
   line([p(77,11),p(80,15),p(77,19)],1.5)
  case .guidedRhythm:
   if selection.rhythmVariant == .seated {frontBody(raised:amount,seated:true,upperBody:true)}
   else {
    let hip=p(63-15*amount,52+15*amount),ankle=p(65,89)
    let lean=0.05+0.4*amount
    let shoulder=p(hip.x-25*sin(lean),hip.y-25*cos(lean))
    let rearHip=p(hip.x-2,hip.y-1),rearAnkle=p(60,87)
    limb(rearHip,joint(rearHip,rearAnkle,18,20),rearAnkle,4)
    let neck=p(shoulder.x-4*sin(lean),shoulder.y-4*cos(lean))
    line([neck,shoulder],4);head(p(neck.x-6*sin(lean),neck.y-6*cos(lean)))
    sideTorso(shoulder,hip)
    limb(hip,joint(hip,ankle,18,20),ankle,6)
    line([ankle,p(71,90)],4)
    let elbow=end(shoulder,0.3+0.85*amount,16)
    limb(shoulder,elbow,end(elbow,0.5+1.4*amount,15))
   }
  default:break
  }
  let source=selection.movementCameraFraming.artboard
  let scale=min(rect.width/source.width,rect.height/source.height)
  return figure.applying(CGAffineTransform(scaleX:scale,y:scale).concatenating(CGAffineTransform(translationX:rect.midX-source.midX*scale,y:rect.midY-source.midY*scale)))
 }
}

struct MovementGuide:View {
 let selection:ChallengeSelection
 var compact=false
 @State private var paused=false
 @Environment(\.accessibilityReduceMotion) private var reduceMotion
 private var motionReduced:Bool {
  #if DEBUG
  reduceMotion || ProcessInfo.processInfo.arguments.contains("--ui-reduce-motion")
  #else
  reduceMotion
  #endif
 }
 private var instruction:String {
  switch selection.kind {
  case .pushUps:return "Lower, then push up"
  case .waveHand:return "Wave side to side"
  case .neckRotation:return "Turn left, then right"
  case .jumpingJacks:return "Open, then close"
  case .stretching:return "Arms up, then down"
  case .guidedRhythm:return selection.rhythmVariant == .seated ? "Seated · Arms up, then down" : "Bend, then stand"
  default:return ""
  }
 }
 var body:some View {
  HStack(spacing:12) {
   MovementIllustration(selection:selection,animated:true,paused:paused)
    .frame(width:compact ? 68 : 100,height:compact ? 64 : 88)
   VStack(alignment:.leading,spacing:6) {
    Text(appText(motionReduced ? "Movement guide" : "Follow the movement")).font(.caption.weight(.semibold))
    Text(appText(instruction)).font(compact ? .footnote.weight(.medium) : .headline).fixedSize(horizontal:false,vertical:true)
     .accessibilityIdentifier("movementGuideInstruction")
    Text(appText(selection.movementCameraFraming.caption)).font(.caption).foregroundStyle(MorningTheme.onYellow.opacity(0.7)).fixedSize(horizontal:false,vertical:true)
     .accessibilityIdentifier("movementCameraFraming")
   }.frame(maxWidth:.infinity,alignment:.leading)
   if !motionReduced {
    Button {paused.toggle()} label: {
     Image(systemName:paused ? "play.fill" : "pause.fill").font(.system(size:13,weight:.semibold))
      .frame(width:44,height:44).contentShape(Rectangle())
    }.buttonStyle(.plain).accessibilityLabel(appText(paused ? "Play movement guide" : "Pause movement guide"))
     .accessibilityIdentifier("toggleMovementGuide")
   }
  }.padding(compact ? 10 : 14).foregroundStyle(MorningTheme.onYellow)
   .background(MorningTheme.hero.opacity(0.55),in:RoundedRectangle(cornerRadius:22))
   .overlay {RoundedRectangle(cornerRadius:22).strokeBorder(MorningTheme.onYellow.opacity(0.12),lineWidth:1)}
   .accessibilityElement(children:.contain).accessibilityIdentifier("movementGuide")
 }
}
