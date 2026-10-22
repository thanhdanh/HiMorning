import SwiftUI
import UIKit
import HiMorningCore

enum AlarmComposerPalette {
 static func symbol(for kind:ChallengeKind)->String {
  switch kind {
  case .none:return "sun.max.fill"
  case .jumpingJacks:return "figure.highintensity.intervaltraining"
  default:return kind.icon
  }
 }
 static func color(for kind:ChallengeKind)->Color {
  switch kind {
  case .none:return MorningTheme.accent
  case .pushUps,.jumpingJacks:return color(0xBF472E,0xFF9166)
  case .readAndChoose,.readAloud,.riddle:return color(0x6652AD,0xBDA6FF)
  case .guidedRhythm,.waveHand,.neckRotation,.stretching:return color(0x1F7A70,0x66D4BA)
  }
 }
 private static func color(_ light:UInt32,_ dark:UInt32)->Color {
  Color(uiColor:UIColor {traits in
   let hex=traits.userInterfaceStyle == .dark ? dark : light
   return UIColor(red:CGFloat((hex>>16)&255)/255,green:CGFloat((hex>>8)&255)/255,blue:CGFloat(hex&255)/255,alpha:1)
  })
 }
}

struct AlarmComposerBackdrop:View {
 @Environment(\.composerReduceTransparency) private var reduceTransparency
 let tint:Color
 var body:some View {
  ZStack(alignment:.topTrailing) {
   MorningTheme.canvas
   if !reduceTransparency {
    Ellipse().fill(MorningTheme.yellow.opacity(0.24)).frame(width:320,height:370).blur(radius:65).offset(x:120,y:-160)
    Ellipse().fill(tint.opacity(0.14)).frame(width:270,height:420).blur(radius:70).offset(x:-210,y:180)
   }
  }.ignoresSafeArea().accessibilityHidden(true)
 }
}

struct AlarmComposerEmblem:View {
 @Environment(\.composerReduceMotion) private var reduceMotion
 let symbol:String
 let tint:Color
 var body:some View {
  ZStack {
   Circle().fill(tint.opacity(0.1)).frame(width:108,height:108)
   Circle().strokeBorder(tint.opacity(0.2),lineWidth:1).frame(width:96,height:96)
   Circle().fill(tint.opacity(0.1)).frame(width:78,height:78)
   Image(systemName:symbol).font(.system(size:44,weight:.medium)).foregroundStyle(tint)
    .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
   Image(systemName:"sparkle").font(.system(size:18)).offset(x:42,y:-46)
   Image(systemName:"sparkle").font(.system(size:10)).offset(x:-42,y:39)
   Circle().fill(tint.opacity(0.5)).frame(width:5,height:5).offset(x:-42,y:-42)
  }.foregroundStyle(tint)
 }
}

private struct AlarmComposerGlass:ViewModifier {
 @Environment(\.composerReduceTransparency) private var reduceTransparency
 let tint:Color
 let cornerRadius:CGFloat
 let interactive:Bool
 func body(content:Content)->some View {
  if reduceTransparency {
   content.background(MorningTheme.surface,in:RoundedRectangle(cornerRadius:cornerRadius))
    .overlay {RoundedRectangle(cornerRadius:cornerRadius).strokeBorder(MorningTheme.line)}
  } else {
   content.glassEffect(.regular.tint(tint).interactive(interactive),in:.rect(cornerRadius:cornerRadius))
  }
 }
}

extension View {
 func composerGlass(tint:Color,cornerRadius:CGFloat,interactive:Bool=false)->some View {
  modifier(AlarmComposerGlass(tint:tint,cornerRadius:cornerRadius,interactive:interactive))
 }
}

struct AlarmComposerPressStyle:ButtonStyle {
 @Environment(\.composerReduceMotion) private var reduceMotion
 func makeBody(configuration:Configuration)->some View {
  configuration.label.scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
   .opacity(configuration.isPressed ? 0.85 : 1)
   .animation(reduceMotion ? nil : .spring(response:0.25,dampingFraction:0.7),value:configuration.isPressed)
 }
}

private struct ComposerReduceMotionKey:EnvironmentKey {static let defaultValue=false}
private struct ComposerReduceTransparencyKey:EnvironmentKey {static let defaultValue=false}
extension EnvironmentValues {
 var composerReduceMotion:Bool {
  get {self[ComposerReduceMotionKey.self]}
  set {self[ComposerReduceMotionKey.self]=newValue}
 }
 var composerReduceTransparency:Bool {
  get {self[ComposerReduceTransparencyKey.self]}
  set {self[ComposerReduceTransparencyKey.self]=newValue}
 }
}
