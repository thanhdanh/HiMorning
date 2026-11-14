import CoreText
import SwiftUI

enum MorningTypography {
 static func heading(size:CGFloat=22,relativeTo style:Font.TextStyle = .title2)->some ViewModifier {
  QuicksandStyle(size:size,relativeTo:style,bold:false)
 }

 static var wordmark:some ViewModifier {
  QuicksandStyle(size:20,relativeTo:.title3,bold:true)
 }
}

private struct QuicksandStyle:ViewModifier {
 @ScaledMetric private var size:CGFloat
 let bold:Bool

 init(size:CGFloat,relativeTo style:Font.TextStyle,bold:Bool) {
  _size=ScaledMetric(wrappedValue:size,relativeTo:style)
  self.bold=bold
 }

 func body(content:Content)->some View {
  content.font(QuicksandFont.font(size:size,bold:bold))
 }
}

private enum QuicksandFont {
 private static let weightAxis=NSNumber(value:0x77676874) // OpenType 'wght'

 private static let descriptor:CTFontDescriptor? = {
  guard let url=Bundle.main.url(forResource:"Quicksand",withExtension:"ttf"),
        let descriptors=CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] else {return nil}
  CTFontManagerRegisterFontsForURL(url as CFURL,.process,nil)
  return descriptors.first
 }()

 static func font(size:CGFloat,bold:Bool)->Font {
  guard let descriptor else {return .system(size:size,weight:bold ? .bold:.semibold)}
  let variant=CTFontDescriptorCreateCopyWithVariation(descriptor,weightAxis,bold ? 700:600)
  return Font(CTFontCreateWithFontDescriptor(variant,size,nil))
 }
}
