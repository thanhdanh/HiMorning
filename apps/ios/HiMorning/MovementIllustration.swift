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
  case .hand:return CGRect(x:15,y:10,width:90,height:84)
  case .face:return CGRect(x:34,y:2,width:52,height:50)
  case .upperBody:return CGRect(x:10,y:-6,width:100,height:76)
  case .wholeBodyFront:return CGRect(x:0,y:-7,width:120,height:107)
  case .wholeBodySide:return CGRect(x:0,y:0,width:120,height:100)
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

/// Shows the instructional motion without using camera data.
struct MovementIllustration:View {
 let selection:ChallengeSelection
 var animated=true
 var paused=false
 var icon=false
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
   let diameter=min(geometry.size.width,geometry.size.height)
   TimelineView(.animation(minimumInterval:icon ? 1.0/24 : 1.0/30,paused:!running)) { context in
    let seconds=elapsed+(running ? max(0,context.date.timeIntervalSince(resumedAt)) : 0)
    MovementFigure(selection:selection,phase:animated && !motionReduced ? seconds / Self.loopDuration(for:selection) : 0.22,icon:icon)
     .fill(.foreground).padding(diameter*(icon ? 0.025 : 0.10))
   }
   .frame(width:diameter,height:diameter)
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
 var icon=false
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
  func limb(_ start:CGPoint,_ elbow:CGPoint,_ finish:CGPoint,_ width:CGFloat=7) {
   line([start,elbow],width);line([elbow,finish],width*0.86)
  }
  func head(_ center:CGPoint) {
   figure=figure.union(Path(ellipseIn:CGRect(x:center.x-6.3,y:center.y-6.3,width:12.6,height:12.6)))
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
  func frontBody(raised:Double,spread:Double=0,upperBody:Bool=false) {
   let flight=sin(cycle*2 * .pi)
   let lift=selection.kind == .jumpingJacks ? -7*flight*flight : 0
   func q(_ x:Double,_ y:Double)->CGPoint {p(x,y+lift)}
   head(q(60,16))
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
    let armAngle=0.14+2.44*raised
    let elbow=end(shoulder,armAngle,16,side)
    limb(shoulder,elbow,end(elbow,armAngle+0.08*raised,15,side))
    if upperBody {continue}
    let hip=q(60+4.5*side,52),legAngle=0.06+0.44*spread
    let knee=end(hip,legAngle,20,side),ankle=end(knee,legAngle,21,side)
    limb(hip,knee,ankle,8)
    line([ankle,p(ankle.x+4*side,ankle.y+1)],5)
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
  func seatedReach() {
   let shoulder=p(49,38),hip=p(46,62)
   line([p(31,49),p(31,69),p(61,69)],4)
   line([p(35,69),p(35,90)],4)
   line([p(58,69),p(58,90)],4)

   limb(p(46,61),p(66,63),p(66,86),6)
   line([p(66,86),p(73,86)],4.5)
   limb(hip,p(75,66),p(75,91),8)
   line([p(75,91),p(84,91)],5)
   sideTorso(shoulder,hip)
   head(p(51,26))

   // Both arms lift from the shoulder while the hips and feet stay planted.
   let angle=0.20+2.87*amount
   let farShoulder=p(54,37),nearShoulder=p(47,39)
   let farElbow=end(farShoulder,angle,16),nearElbow=end(nearShoulder,angle,15)
   limb(farShoulder,farElbow,end(farElbow,angle+0.32,15),5.5)
   limb(nearShoulder,nearElbow,end(nearElbow,angle-0.20,16),7)
  }
  switch selection.kind {
  case .pushUps:
   let angle=0.48-0.37*amount
   let ankle=p(103,87),shoulder=p(103-69*cos(angle),87-69*sin(angle))
   let hip=p(shoulder.x+28*cos(angle),shoulder.y+28*sin(angle))
   let neck=p(shoulder.x-4*cos(angle),shoulder.y-4*sin(angle))
   let rearShoulder=p(shoulder.x+2,shoulder.y-1),rearWrist=p(43,86)
   limb(rearShoulder,joint(rearShoulder,rearWrist,18,18),rearWrist,5)
   limb(p(hip.x+1,hip.y-1),p(hip.x+22*cos(angle),hip.y+22*sin(angle)-2),p(104,84),5)
   head(p(neck.x-7*cos(angle),neck.y-7*sin(angle)-3))
   sideTorso(shoulder,hip)
   limb(hip,p(hip.x+21*cos(angle),hip.y+21*sin(angle)),ankle,8)
   line([ankle,p(107,87)],5)
   let wrist=p(36,87)
   limb(shoulder,joint(shoulder,wrist,18,18),wrist)
   line([wrist,p(40,88)],4)
  case .jumpingJacks:frontBody(raised:amount,spread:amount)
  case .stretching:frontBody(raised:amount,upperBody:true)
  case .waveHand:
   // The wave counter observes the hand and wrist, without requiring a body pose.
   var hand=Path { palm in
    palm.move(to:p(52,79))
    palm.addQuadCurve(to:p(48,66),control:p(54,72))
    palm.addQuadCurve(to:p(45,52),control:p(43,60))
    palm.addQuadCurve(to:p(57,43),control:p(46,44))
    palm.addQuadCurve(to:p(76,53),control:p(71,43))
    palm.addQuadCurve(to:p(71,69),control:p(79,60))
    palm.addQuadCurve(to:p(68,79),control:p(68,74))
    palm.closeSubpath()
   }
   func digit(from base:CGPoint,via joint:CGPoint,to tip:CGPoint,width:CGFloat) {
    var curve=Path();curve.move(to:base);curve.addQuadCurve(to:tip,control:joint)
    hand=hand.union(curve.strokedPath(.init(lineWidth:width,lineCap:.round)))
   }
   digit(from:p(50,51),via:p(46,40),to:p(43,27),width:7.0)
   digit(from:p(57,48),via:p(55,36),to:p(55,20),width:7.5)
   digit(from:p(64,49),via:p(66,37),to:p(67,24),width:7.0)
   digit(from:p(71,53),via:p(76,43),to:p(78,34),width:6.5)
   digit(from:p(51,64),via:p(44,55),to:p(33,49),width:9.0)
   let sway=sin(cycle*2 * .pi)*0.24
   figure=hand.applying(CGAffineTransform(translationX:-60,y:-78)
    .concatenating(CGAffineTransform(rotationAngle:sway))
    .concatenating(CGAffineTransform(translationX:60,y:78)))
  case .neckRotation:
   let look=sin(cycle*2 * .pi)
   let faceX=60+look*1.8,faceY=18.0
   let faceWidth=11-2.8*abs(look)
   var face=Path(ellipseIn:CGRect(x:faceX-faceWidth,y:faceY-11.5,width:faceWidth*2,height:23))
   for side in [-1.0,1.0] {
    let farSide=max(0,side*look)
    let earWidth=3.0-0.8*farSide
    let earX=faceX+side*(faceWidth-0.65-1.15*farSide)
    let ear=CGRect(x:earX-earWidth/2,y:faceY-1.8,width:earWidth,height:4.4-0.8*farSide)
    face=face.union(Path(ellipseIn:ear))
   }
   let nose=Path { profile in
    profile.move(to:p(faceX+look*6.4,faceY-3.8))
    profile.addQuadCurve(to:p(faceX+look*11.6,faceY+1.6),control:p(faceX+look*9.2,faceY-0.6))
    profile.addQuadCurve(to:p(faceX+look*7.1,faceY+3.6),control:p(faceX+look*12,faceY+3.2))
    profile.closeSubpath()
   }
   face=face.union(nose)
   for side in [-1.0,1.0] {
    let eyeWidth=3.4*max(0,1-max(0,-side*look)*1.18)
    let eyeX=faceX+look*5.5+side*4*(1-0.53*abs(look))
    face=face.subtracting(Path(ellipseIn:CGRect(x:eyeX-eyeWidth/2,y:faceY-3.7,width:eyeWidth,height:3.2)))
   }
   figure=figure.union(face)
   var shoulders=Path()
   shoulders.move(to:p(46,40));shoulders.addQuadCurve(to:p(52,30),control:p(46,33))
   shoulders.addQuadCurve(to:p(60,27),control:p(57,29))
   shoulders.addQuadCurve(to:p(68,30),control:p(63,29))
   shoulders.addQuadCurve(to:p(74,40),control:p(74,33));shoulders.closeSubpath()
   figure=figure.union(shoulders)
   line([p(50,45),p(70,45)],2.5)
   line([p(53,42),p(49,45),p(53,48)],2.5)
   line([p(67,42),p(71,45),p(67,48)],2.5)
  case .guidedRhythm:
   if selection.rhythmVariant == .seated {seatedReach()}
   else {
    let hip=p(59-9*amount,52+9*amount),ankle=p(60,89)
    let lean=0.06+0.31*amount
    let shoulder=p(hip.x+25*sin(lean),hip.y-25*cos(lean))
    let rearHip=p(hip.x-2,hip.y-1),rearAnkle=p(60,87)
    limb(rearHip,joint(rearHip,rearAnkle,18,20),rearAnkle,4)
    head(p(shoulder.x+11*sin(lean),shoulder.y-11*cos(lean)))
    sideTorso(shoulder,hip)
    limb(hip,joint(hip,ankle,18,20),ankle,6)
    line([ankle,p(71,90)],4)
    let elbow=end(shoulder,0.19+0.83*amount,15)
    limb(shoulder,elbow,end(elbow,0.32+0.96*amount,14))
   }
  default:break
  }
  let source=switch (icon,selection.kind) {
  case (true,.pushUps):CGRect(x:15,y:35,width:98,height:60)
  case (true,.jumpingJacks):CGRect(x:19,y:-7,width:82,height:106)
  case (_,.guidedRhythm) where selection.rhythmVariant == .seated:CGRect(x:22,y:0,width:74,height:98)
  case (true,.guidedRhythm):CGRect(x:36,y:7,width:53,height:90)
  default:selection.movementCameraFraming.artboard
  }
  let scale=min(rect.width/source.width,rect.height/source.height)
  return figure.applying(CGAffineTransform(scaleX:scale,y:scale).concatenating(CGAffineTransform(translationX:rect.midX-source.midX*scale,y:rect.midY-source.midY*scale)))
 }
}

struct MovementGuide:View {
 let selection:ChallengeSelection
 let mode:WakeMode
 var compact=false
 var showInstructions=true
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
  let tint=MorningTheme.modeAccent(mode)
  return HStack(spacing:12) {
   MovementIllustration(selection:selection,animated:true,paused:paused)
    .frame(width:compact ? 68 : 100,height:compact ? 64 : 88)
    .foregroundStyle(tint)
    .background(tint.opacity(0.13),in:Circle())
   VStack(alignment:.leading,spacing:6) {
    if showInstructions {
     Text(appText(motionReduced ? "Movement guide" : "Follow the movement")).font(.caption.weight(.semibold))
     Text(appText(instruction)).font(compact ? .footnote.weight(.medium) : .headline).fixedSize(horizontal:false,vertical:true)
      .accessibilityIdentifier("movementGuideInstruction")
    } else {
     Label(appText("challenge_info_camera_required"),systemImage:"camera")
      .font(.subheadline.weight(.semibold)).foregroundStyle(tint)
      .fixedSize(horizontal:false,vertical:true)
      .accessibilityIdentifier("challengeInfoCamera")
    }
    Text(appText(selection.movementCameraFraming.caption)).font(.caption).foregroundStyle(MorningTheme.muted).fixedSize(horizontal:false,vertical:true)
     .accessibilityIdentifier("movementCameraFraming")
   }.frame(maxWidth:.infinity,alignment:.leading)
   if !motionReduced {
    Button {paused.toggle()} label: {
     Image(systemName:paused ? "play.fill" : "pause.fill").font(.system(size:13,weight:.semibold))
      .frame(width:44,height:44).contentShape(Rectangle())
    }.buttonStyle(.plain).accessibilityLabel(appText(paused ? "Play movement guide" : "Pause movement guide"))
     .accessibilityIdentifier("toggleMovementGuide")
   }
  }.padding(compact ? 10 : 14).foregroundStyle(MorningTheme.ink)
   .background(MorningTheme.surface,in:RoundedRectangle(cornerRadius:22))
   .overlay {RoundedRectangle(cornerRadius:22).strokeBorder(MorningTheme.line,lineWidth:1)}
   .accessibilityElement(children:.contain).accessibilityIdentifier("movementGuide")
 }
}
