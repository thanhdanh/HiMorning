import SwiftUI
import UIKit

// Match the original design/styles.css palette, including dark surfaces.
enum MorningTheme {
 static let canvas=color(0xFFFCF6,0x201F1A)
 static let surface=color(0xFFFFFF,0x2C2A24)
 static let soft=color(0xF4F1E9,0x353229)
 static let ink=color(0x29251D,0xF8F4EA)
 static let muted=color(0x756F63,0xC2BBAE)
 static let line=color(0xE9E5DC,0x49463D)
 static let yellow=Color(red:245/255,green:200/255,blue:66/255)
 static let hero=Color(red:248/255,green:217/255,blue:96/255)
 static let onYellow=Color(red:41/255,green:37/255,blue:29/255)
 static let accent=color(0x967211,0xF5C842)
 static let success=color(0x44634A,0xBDD6BF)
 static let successOnYellow=Color(red:68/255,green:99/255,blue:74/255)
 static let correctWord=color(0x126B36,0x7FE5A2)
 private static func color(_ light:UInt32,_ dark:UInt32)->Color {
  Color(uiColor:UIColor { traits in
   let hex=traits.userInterfaceStyle == .dark ? dark : light
   return UIColor(red:CGFloat((hex>>16)&255)/255,green:CGFloat((hex>>8)&255)/255,blue:CGFloat(hex&255)/255,alpha:1)
  })
 }
}
struct MorningButtonStyle:ButtonStyle {
 var primary=true
 @Environment(\.isEnabled) private var enabled
 func makeBody(configuration:Configuration)->some View {
  configuration.label.font(.body.weight(.semibold)).multilineTextAlignment(.center)
   .padding(.horizontal,16).padding(.vertical,13).frame(maxWidth:.infinity,minHeight:48)
   .foregroundStyle(primary ? MorningTheme.onYellow : MorningTheme.ink)
   .background(primary ? MorningTheme.yellow : MorningTheme.surface,in:RoundedRectangle(cornerRadius:16))
   .overlay {RoundedRectangle(cornerRadius:16).strokeBorder(primary ? .clear : MorningTheme.line)}
   .opacity(!enabled ? 0.5 : configuration.isPressed ? 0.85 : 1)
 }
}
struct MorningSun:View {
 var size:CGFloat=140
 var body:some View {
  ZStack {
   ForEach(0..<12,id:\.self) {ray in
    Capsule().fill(MorningTheme.accent).frame(width:2,height:12).offset(y:-62).rotationEffect(.degrees(Double(ray)*30))
   }
   Circle().fill(MorningTheme.yellow).frame(width:90,height:90)
   HStack(spacing:24) {Circle().frame(width:4,height:4);Circle().frame(width:4,height:4)}.foregroundStyle(MorningTheme.onYellow).offset(y:-4)
   Path {path in path.move(to:CGPoint(x:59,y:76));path.addQuadCurve(to:CGPoint(x:81,y:76),control:CGPoint(x:70,y:91))}
    .stroke(MorningTheme.onYellow,style:StrokeStyle(lineWidth:2.5,lineCap:.round))
  }.frame(width:140,height:140).scaleEffect(size/140).frame(width:size,height:size).accessibilityHidden(true)
 }
}
