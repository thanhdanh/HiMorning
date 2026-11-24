import SwiftUI
import UIKit
import HiMorningCore

// Match the original design/styles.css palette, including dark surfaces.
enum MorningTheme {
 static let canvas=color(0xFFFCF6,0x171612)
 static let surface=color(0xFFFFFF,0x25231D)
 static let soft=color(0xF4F1E9,0x312E26)
 static let ink=color(0x29251D,0xF8F4EA)
 static let muted=color(0x6D675B,0xC2BBAE)
 static let line=color(0xDDD7CA,0x4D493E)
 static let error=color(0xBA3B34,0xFF8A80)
 static let yellow=Color(red:245/255,green:200/255,blue:66/255)
 static let alarmCardHighlight=color(0xFBE693,0xFBE693)
 static let alarmCardEdge=color(0xE1B73B,0xE1B73B)
 static let alarmSwitchOn=color(0x355E47,0x355E47)
 static let alarmClockOff=color(0x6D675B,0xA8A093)
 static let alarmDetailOnYellow=color(0x5D471D,0x5D471D)
 static let successOnYellow=color(0x36563C,0x36563C)
 static let hero=Color(red:248/255,green:217/255,blue:96/255)
 static let onYellow=Color(red:41/255,green:37/255,blue:29/255)
 static let accent=color(0x805E08,0xF5C842)
 enum Radius {
  static let hero:CGFloat=24
  static let card:CGFloat=18
  static let control:CGFloat=16
 }
 static let success=color(0x44634A,0xBDD6BF)
 static let correctWord=color(0x126B36,0x7FE5A2)
 static let proGoldLight=color(0xFFF2CF,0xFFEAC0)
 static let proGold=color(0xECCA82,0xDBB167)
 static let proGoldEdge=color(0xC09A50,0xB38C48)
 static let proInk=color(0x4E3516,0x4E3516)
 static let proSurface=color(0xFBF4E5,0x363025)
 static let proOutline=color(0xDDC9A1,0x736043)
 static func modeAccent(_ mode:WakeMode,onYellow:Bool=false)->Color {
  switch mode {
  case .gentle:return onYellow ? color(0x34543E,0x34543E) : color(0x41644C,0x8EBB99)
  case .balanced:return onYellow ? color(0x534366,0x534366) : color(0x64547B,0xBFAFD4)
  case .focused:return onYellow ? color(0x794419,0x794419) : color(0x89501F,0xE8AE6E)
  }
 }
 private static func color(_ light:UInt32,_ dark:UInt32)->Color {
  Color(uiColor:UIColor { traits in
   let hex=traits.userInterfaceStyle == .dark ? dark : light
   return UIColor(red:CGFloat((hex>>16)&255)/255,green:CGFloat((hex>>8)&255)/255,blue:CGFloat(hex&255)/255,alpha:1)
  })
 }
}
struct ProLockBadge:View {
 var compact=false
 var body:some View {
  HStack(spacing:5) {
   Image(systemName:"lock.fill").font(.caption2.weight(.semibold)).imageScale(.small)
   Text(appText("Pro")).font(.caption2.weight(.bold)).tracking(0.45)
  }
   .padding(.horizontal,compact ? 7 : 9).padding(.vertical,compact ? 3 : 4)
   .foregroundStyle(MorningTheme.proInk)
   .background(LinearGradient(colors:[MorningTheme.proGoldLight,MorningTheme.proGold],startPoint:.topLeading,endPoint:.bottomTrailing),in:Capsule())
   .overlay {Capsule().strokeBorder(MorningTheme.proGoldEdge,lineWidth:0.75)}
   .accessibilityElement(children:.ignore)
   .accessibilityLabel(appText("Requires Pro"))
 }
}
struct MorningButtonStyle:ButtonStyle {
 var primary=true
 @Environment(\.isEnabled) private var enabled
 func makeBody(configuration:Configuration)->some View {
  let bg:Color = !enabled ? MorningTheme.soft : (primary ? MorningTheme.yellow : MorningTheme.surface)
  let fg:Color = !enabled ? MorningTheme.muted : (primary ? MorningTheme.onYellow : MorningTheme.ink)
  let border:Color = !enabled ? MorningTheme.line : (primary ? .clear : MorningTheme.line)
  configuration.label.font(.body.weight(.semibold)).multilineTextAlignment(.center)
   .padding(.horizontal,16).padding(.vertical,13).frame(maxWidth:.infinity,minHeight:48)
   .foregroundStyle(fg)
   .background(bg,in:RoundedRectangle(cornerRadius:MorningTheme.Radius.control))
   .overlay {RoundedRectangle(cornerRadius:MorningTheme.Radius.control).strokeBorder(border)}
   .opacity(configuration.isPressed && enabled ? 0.88 : 1)
   .scaleEffect(configuration.isPressed && enabled ? 0.985 : 1)
 }
}
struct MorningBackdrop:View {
 @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
 @Environment(\.colorScheme) private var colorScheme
 var body:some View {
  ZStack {
   MorningTheme.canvas
   if !reduceTransparency {
    RadialGradient(
     colors:[MorningTheme.yellow.opacity(colorScheme == .dark ? 0.12 : 0.16),.clear],
     center:.topTrailing,
     startRadius:12,
     endRadius:420
    )
   }
  }.ignoresSafeArea()
 }
}
struct MorningSun:View {
 var size:CGFloat=140
 var showRays=true
 var body:some View {
  ZStack {
   if showRays {
    ForEach(0..<12,id:\.self) {ray in
     Capsule().fill(MorningTheme.accent).frame(width:2,height:12).offset(y:-62).rotationEffect(.degrees(Double(ray)*30))
    }
   }
   Circle().fill(MorningTheme.yellow).frame(width:90,height:90)
   HStack(spacing:24) {Circle().frame(width:4,height:4);Circle().frame(width:4,height:4)}.foregroundStyle(MorningTheme.onYellow).offset(y:-4)
   Path {path in path.move(to:CGPoint(x:59,y:76));path.addQuadCurve(to:CGPoint(x:81,y:76),control:CGPoint(x:70,y:91))}
    .stroke(MorningTheme.onYellow,style:StrokeStyle(lineWidth:2.5,lineCap:.round))
  }.frame(width:140,height:140).scaleEffect(size/140).frame(width:size,height:size).accessibilityHidden(true)
 }
}
