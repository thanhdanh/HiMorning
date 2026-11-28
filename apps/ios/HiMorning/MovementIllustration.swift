import SwiftUI
import AVFoundation
import UIKit
import HiMorningCore

extension ChallengeKind {
 var hasMovementIllustration:Bool {
  switch self {
  case .pushUps,.squats,.waveHand,.neckRotation,.jumpingJacks,.stretching,.guidedRhythm:return true
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
}

extension ChallengeSelection {
 var movementCameraFraming:MovementCameraFraming {
  switch kind {
  case .waveHand:return .hand
  case .neckRotation:return .face
  case .stretching:return .upperBody
  case .guidedRhythm:return rhythmVariant == .seated ? .upperBody : .wholeBodySide
  case .pushUps,.squats:return .wholeBodySide
  default:return .wholeBodyFront
  }
 }
}

struct StudioMotionAsset {
 let key:String
 let phase1CueKey:String
 let phase2CueKey:String
 let focusJoint:(xPct:CGFloat,yPct:CGFloat)

 var videoURL:URL? {
  Bundle.main.url(forResource:"motion_\(key)",withExtension:"mp4",subdirectory:"Motion")
   ?? Bundle.main.url(forResource:"motion_\(key)",withExtension:"mp4")
 }

 var posterURL:URL? {
  Bundle.main.url(forResource:"motion_\(key)_poster",withExtension:"jpg",subdirectory:"Motion")
   ?? Bundle.main.url(forResource:"motion_\(key)_poster",withExtension:"jpg")
 }

 var posterImage:UIImage? {
  posterURL.flatMap {UIImage(contentsOfFile:$0.path)}
 }

 static func forSelection(_ selection:ChallengeSelection)->StudioMotionAsset? {
  switch selection.kind {
  case .pushUps:
   return StudioMotionAsset(key:"push_ups",phase1CueKey:"High plank",phase2CueKey:"Lower 90°",focusJoint:(0.64,0.626))
  case .squats:
   return StudioMotionAsset(key:"rhythm_standing",phase1CueKey:"Stand tall",phase2CueKey:"Bend knees",focusJoint:(0.518,0.692))
  case .waveHand:
   return StudioMotionAsset(key:"wave_hand",phase1CueKey:"Wave left",phase2CueKey:"Wave right",focusJoint:(0.257,0.478))
  case .neckRotation:
   return StudioMotionAsset(key:"neck_rotation",phase1CueKey:"Turn left",phase2CueKey:"Turn right",focusJoint:(0.504,0.558))
  case .jumpingJacks:
   return StudioMotionAsset(key:"jumping_jacks",phase1CueKey:"Feet together",phase2CueKey:"Jump open",focusJoint:(0.653,0.112))
  case .stretching:
   return StudioMotionAsset(key:"stretching",phase1CueKey:"Arms down",phase2CueKey:"Reach high",focusJoint:(0.607,0.307))
  case .guidedRhythm:
   if selection.rhythmVariant == .seated {
    return StudioMotionAsset(key:"rhythm_seated",phase1CueKey:"Arms down",phase2CueKey:"Lift both arms",focusJoint:(0.609,0.26))
   }
   return StudioMotionAsset(key:"rhythm_standing",phase1CueKey:"Stand tall",phase2CueKey:"Bend knees",focusJoint:(0.518,0.692))
  default:
   return nil
  }
 }
}

/// Hardware-accelerated seamless looping studio MP4 player (modeled after go-tall).
private struct StudioLoopVideoView:UIViewRepresentable {
 let url:URL
 let playing:Bool
 let rate:Float
 let onPhaseChange:(Int)->Void

 final class PlayerContainerView:UIView {
  override class var layerClass:AnyClass {AVPlayerLayer.self}
  var playerLayer:AVPlayerLayer {layer as! AVPlayerLayer}
  var queuePlayer:AVQueuePlayer?
  var looper:AVPlayerLooper?
  var timeObserver:Any?
  var loadedURL:URL?
  var lastPhase:Int=1

  override init(frame:CGRect) {
   super.init(frame:frame)
   backgroundColor=UIColor(red:17/255,green:22/255,blue:31/255,alpha:1)
   playerLayer.videoGravity = .resizeAspectFill
  }
  required init?(coder:NSCoder) {super.init(coder:coder)}

  func configure(url:URL,playing:Bool,rate:Float,onPhaseChange:@escaping (Int)->Void) {
   if loadedURL != url {
    teardown()
    loadedURL=url
    let item=AVPlayerItem(url:url)
    let player=AVQueuePlayer(playerItem:item)
    player.isMuted=true
    player.actionAtItemEnd = .none
    player.automaticallyWaitsToMinimizeStalling=false
    looper=AVPlayerLooper(player:player,templateItem:item)
    queuePlayer=player
    playerLayer.player=player
    let interval=CMTime(seconds:0.15,preferredTimescale:600)
    timeObserver=player.addPeriodicTimeObserver(forInterval:interval,queue:.main) { [weak self] time in
     guard let self else {return}
     let seconds=CMTimeGetSeconds(time)
     guard seconds.isFinite else {return}
     let phase=seconds >= 2.3 ? 2 : 1
     if phase != self.lastPhase {
      self.lastPhase=phase
      onPhaseChange(phase)
     }
    }
   }
   guard let player=queuePlayer else {return}
   if playing {
    if player.rate != rate {player.playImmediately(atRate:rate)}
   } else if player.rate != 0 {
    player.pause()
   }
  }

  func teardown() {
   if let observer=timeObserver,let player=queuePlayer {
    player.removeTimeObserver(observer)
   }
   timeObserver=nil
   queuePlayer?.pause()
   looper?.disableLooping()
   looper=nil
   queuePlayer=nil
   playerLayer.player=nil
   loadedURL=nil
  }

  deinit {teardown()}
 }

 func makeUIView(context:Context)->PlayerContainerView {
  let view=PlayerContainerView()
  view.configure(url:url,playing:playing,rate:rate,onPhaseChange:onPhaseChange)
  return view
 }

 func updateUIView(_ uiView:PlayerContainerView,context:Context) {
  uiView.configure(url:url,playing:playing,rate:rate,onPhaseChange:onPhaseChange)
 }

 static func dismantleUIView(_ uiView:PlayerContainerView,coordinator:()) {
  uiView.teardown()
 }
}

/// Shows the studio biomechanical motion guide without using camera data.
struct MovementIllustration:View {
 let selection:ChallengeSelection
 var animated=true
 var paused=false
 var slowTempo=false
 var onPhaseChange:(Int)->Void={_ in}
 @Environment(\.scenePhase) private var scene
 @Environment(\.accessibilityReduceMotion) private var reduceMotion
 @State private var visible=false
 @State private var sonarPulse=false

 private var motionReduced:Bool {
  #if DEBUG
  reduceMotion || ProcessInfo.processInfo.arguments.contains("--ui-reduce-motion")
  #else
  reduceMotion
  #endif
 }

 private var running:Bool {animated && visible && !paused && !motionReduced && scene == .active}

 var body:some View {
  let asset=StudioMotionAsset.forSelection(selection)
  ZStack {
   Color(red:17/255,green:22/255,blue:31/255)
   if let poster=asset?.posterImage {
    Image(uiImage:poster)
     .resizable()
     .scaledToFill()
     .frame(maxWidth:.infinity,maxHeight:.infinity)
     .clipped()
   }
   if let videoURL=asset?.videoURL,running {
    StudioLoopVideoView(url:videoURL,playing:true,rate:slowTempo ? 0.7 : 1.0,onPhaseChange:onPhaseChange)
     .frame(maxWidth:.infinity,maxHeight:.infinity)
   } else if let asset {
    GeometryReader { proxy in
     Circle()
      .stroke(Color(red:52/255,green:211/255,blue:153/255),lineWidth:2)
      .background(Circle().fill(Color(red:52/255,green:211/255,blue:153/255).opacity(0.18)))
      .frame(width:30,height:30)
      .scaleEffect(motionReduced ? 1.0 : (sonarPulse ? 1.45 : 0.9))
      .opacity(motionReduced ? 0.85 : (sonarPulse ? 0.18 : 0.75))
      .position(x:proxy.size.width*asset.focusJoint.xPct,y:proxy.size.height*asset.focusJoint.yPct)
    }
    .allowsHitTesting(false)
   }
  }
  .clipped()
  .onAppear {
   visible=true
   if !motionReduced {
    withAnimation(.easeInOut(duration:0.95).repeatForever(autoreverses:true)) {sonarPulse=true}
   }
  }
  .onDisappear {visible=false}
  .accessibilityHidden(true)
 }
}

/// Unobstructed 16:9 Studio Motion Stage + non-occluding top HUD (modeled after go-tall).
struct MovementGuide:View {
 let selection:ChallengeSelection
 let mode:WakeMode
 var compact=false
 var showInstructions=true
 @State private var paused=false
 @State private var slowTempo=false
 @State private var activePhase=1
 @Environment(\.accessibilityReduceMotion) private var reduceMotion

 private static let studioBg=Color(red:17/255,green:22/255,blue:31/255)
 private static let biomechEmerald=Color(red:52/255,green:211/255,blue:153/255)
 private static let biomechEmeraldText=Color(red:110/255,green:231/255,blue:183/255)
 private static let tempoGold=Color(red:232/255,green:201/255,blue:122/255)

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
  let asset=StudioMotionAsset.forSelection(selection)
  let cueKey=asset.map { (motionReduced || paused || activePhase == 2) ? $0.phase2CueKey : $0.phase1CueKey } ?? instruction
  let stepBadge=(motionReduced || paused || activePhase == 2) ? "2/2" : "1/2"

  if compact {
   compactLayout(tint:tint)
  } else {
   VStack(alignment:.leading,spacing:12) {
    ZStack(alignment:.top) {
     MovementIllustration(selection:selection,animated:true,paused:paused,slowTempo:slowTempo) { phase in
      activePhase=phase
     }
     .aspectRatio(16.0/9.0,contentMode:.fit)
     .frame(maxWidth:.infinity)
     .background(Self.studioBg)
     .clipShape(RoundedRectangle(cornerRadius:18))
     .overlay {RoundedRectangle(cornerRadius:18).strokeBorder(Color.white.opacity(0.14),lineWidth:1)}

     // Slim non-occluding top corner HUD (leaves center & bottom 100% unobstructed)
     HStack(spacing:6) {
      HStack(spacing:6) {
       Text(stepBadge)
        .font(.system(size:11,weight:.bold)).monospacedDigit()
        .foregroundStyle(Color(red:244/255,green:244/255,blue:240/255))
       Circle().fill(Self.biomechEmerald).frame(width:4,height:4)
       Text(appText(cueKey))
        .font(.system(size:11,weight:.bold))
        .foregroundStyle(Self.biomechEmeraldText)
        .lineLimit(1)
      }
      .padding(.horizontal,10).padding(.vertical,5)
      .background(Color(red:11/255,green:13/255,blue:18/255).opacity(0.80),in:Capsule())
      .overlay {Capsule().strokeBorder(Self.biomechEmerald.opacity(0.42),lineWidth:1)}
      .accessibilityHidden(true)

      Spacer(minLength:4)

      if !motionReduced {
       HStack(spacing:6) {
        Button {slowTempo.toggle()} label: {
         Text(appText(slowTempo ? "Slow 0.7x" : "Speed 1x"))
          .font(.system(size:11,weight:.bold))
          .foregroundStyle(slowTempo ? Self.tempoGold : Color(red:228/255,green:228/255,blue:231/255))
          .padding(.horizontal,10).padding(.vertical,5)
          .background(slowTempo ? Self.tempoGold.opacity(0.20) : Color(red:11/255,green:13/255,blue:18/255).opacity(0.82),in:Capsule())
          .overlay {Capsule().strokeBorder(slowTempo ? Self.tempoGold : Color.white.opacity(0.20),lineWidth:1)}
          .frame(minHeight:44)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(appText(slowTempo ? "Slow 0.7x speed, tap for normal speed" : "Normal 1x speed, tap for slow 0.7x"))
        .accessibilityIdentifier("toggleMovementTempo")

        Button {paused.toggle()} label: {
         Image(systemName:paused ? "play.fill" : "pause.fill")
          .font(.system(size:12,weight:.semibold))
          .foregroundStyle(.white)
          .frame(width:30,height:30)
          .background(Color(red:11/255,green:13/255,blue:18/255).opacity(0.82),in:Circle())
          .overlay {Circle().strokeBorder(Color.white.opacity(0.20),lineWidth:1)}
          .frame(width:44,height:44)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(appText(paused ? "Play movement guide" : "Pause movement guide"))
        .accessibilityIdentifier("toggleMovementGuide")
       }
      }
     }
     .padding(.horizontal,8).padding(.top,4)
    }

    HStack(alignment:.center,spacing:10) {
     VStack(alignment:.leading,spacing:4) {
      if showInstructions {
       Text(appText(motionReduced ? "Movement guide" : "Follow the movement"))
        .font(.caption.weight(.semibold)).foregroundStyle(tint)
       Text(appText(instruction))
        .font(.headline).fixedSize(horizontal:false,vertical:true)
        .accessibilityIdentifier("movementGuideInstruction")
      } else {
       Label(appText("challenge_info_camera_required"),systemImage:"camera")
        .font(.subheadline.weight(.semibold)).foregroundStyle(tint)
        .fixedSize(horizontal:false,vertical:true)
        .accessibilityIdentifier("challengeInfoCamera")
      }
      Text(appText(selection.movementCameraFraming.caption))
       .font(.caption).foregroundStyle(MorningTheme.muted)
       .fixedSize(horizontal:false,vertical:true)
       .accessibilityIdentifier("movementCameraFraming")
     }
     .frame(maxWidth:.infinity,alignment:.leading)
    }
    .padding(.horizontal,4)
   }
   .padding(12)
   .foregroundStyle(MorningTheme.ink)
   .background(MorningTheme.surface,in:RoundedRectangle(cornerRadius:22))
   .overlay {RoundedRectangle(cornerRadius:22).strokeBorder(MorningTheme.line,lineWidth:1)}
   .accessibilityElement(children:.contain)
   .accessibilityIdentifier("movementGuide")
  }
 }

 private func compactLayout(tint:Color)->some View {
  HStack(spacing:12) {
   MovementIllustration(selection:selection,animated:true,paused:paused,slowTempo:slowTempo)
    .frame(width:112,height:63)
    .background(Self.studioBg)
    .clipShape(RoundedRectangle(cornerRadius:12))
    .overlay {RoundedRectangle(cornerRadius:12).strokeBorder(Color.white.opacity(0.14),lineWidth:1)}
   VStack(alignment:.leading,spacing:4) {
    if showInstructions {
     Text(appText(motionReduced ? "Movement guide" : "Follow the movement")).font(.caption2.weight(.semibold)).foregroundStyle(tint)
     Text(appText(instruction)).font(.footnote.weight(.semibold)).fixedSize(horizontal:false,vertical:true)
      .accessibilityIdentifier("movementGuideInstruction")
    } else {
     Label(appText("challenge_info_camera_required"),systemImage:"camera")
      .font(.subheadline.weight(.semibold)).foregroundStyle(tint)
      .fixedSize(horizontal:false,vertical:true)
      .accessibilityIdentifier("challengeInfoCamera")
    }
    Text(appText(selection.movementCameraFraming.caption)).font(.caption2).foregroundStyle(MorningTheme.muted).fixedSize(horizontal:false,vertical:true)
     .accessibilityIdentifier("movementCameraFraming")
   }.frame(maxWidth:.infinity,alignment:.leading)
   if !motionReduced {
    Button {paused.toggle()} label: {
     Image(systemName:paused ? "play.fill" : "pause.fill").font(.system(size:13,weight:.semibold))
      .frame(width:44,height:44).contentShape(Rectangle())
    }.buttonStyle(.plain).accessibilityLabel(appText(paused ? "Play movement guide" : "Pause movement guide"))
     .accessibilityIdentifier("toggleMovementGuide")
   }
  }.padding(10).foregroundStyle(MorningTheme.ink)
   .background(MorningTheme.surface,in:RoundedRectangle(cornerRadius:20))
   .overlay {RoundedRectangle(cornerRadius:20).strokeBorder(MorningTheme.line,lineWidth:1)}
   .accessibilityElement(children:.contain).accessibilityIdentifier("movementGuide")
 }
}
