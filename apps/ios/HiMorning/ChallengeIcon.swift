import SwiftUI
import HiMorningCore

struct ChallengeIcon:View {
 let kind:ChallengeKind
 var seated=false
 var size:CGFloat=24
 var animated=false

 private enum Artwork {
  case asset(String)
  case symbol(String)
 }

 private var artwork:Artwork {
  switch kind {
  case .none:return .symbol("sun.max.fill")
  case .pushUps:return .asset("ChallengePushUps")
  case .readAndChoose:return .symbol("doc.text.magnifyingglass")
  case .guidedRhythm:return .asset(seated ? "ChallengeRhythmSeated" : "ChallengeRhythmStanding")
  case .readAloud:return .symbol("waveform.badge.mic")
  case .waveHand:return .asset("ChallengeWaveHand")
  case .neckRotation:return .asset("ChallengeNeckRotation")
  case .riddle:return .symbol("puzzlepiece.extension.fill")
  case .jumpingJacks:return .asset("ChallengeJumpingJacks")
  case .stretching:return .asset("ChallengeStretching")
  case .morningLight:return .symbol("sun.horizon.fill")
  }
 }

 var image:Image {
  switch artwork {
  case let .asset(name):return Image(name).renderingMode(.template)
  case let .symbol(name):return Image(systemName:name)
  }
 }

 var body:some View {
  Group {
   if animated && kind.hasMovementIllustration {
    MovementIllustration(selection:.init(kind:kind,rhythmVariant:seated ? .seated : .standing),icon:true)
   } else {
    switch artwork {
    case .asset:image.resizable().scaledToFit()
    case .symbol:image.symbolRenderingMode(.hierarchical).font(.system(size:size,weight:.medium))
    }
   }
  }.frame(width:size,height:size).accessibilityHidden(true)
 }
}
