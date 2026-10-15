import AppKit
import Foundation

let resources=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("apps/ios/Resources")
let iconSet=resources.appendingPathComponent("Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at:iconSet,withIntermediateDirectories:true)

func color(_ hex:UInt32)->NSColor {
 NSColor(srgbRed:CGFloat((hex>>16)&255)/255,green:CGFloat((hex>>8)&255)/255,blue:CGFloat(hex&255)/255,alpha:1)
}
let canvas=CGContext(data:nil,width:1024,height:1024,bitsPerComponent:8,bytesPerRow:4096,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
canvas.setFillColor(color(0xFFFCF6).cgColor)
canvas.fill(CGRect(x:0,y:0,width:1024,height:1024))
canvas.setStrokeColor(color(0x967211).cgColor)
canvas.setLineWidth(15)
canvas.setLineCap(.round)
for ray in 0..<12 {
 let angle=Double(ray)*Double.pi/6
 let path=CGMutablePath()
 path.move(to:NSPoint(x:512+315*sin(angle),y:512+315*cos(angle)))
 path.addLine(to:NSPoint(x:512+370*sin(angle),y:512+370*cos(angle)))
 canvas.addPath(path)
 canvas.strokePath()
}
canvas.setFillColor(color(0xF5C842).cgColor)
canvas.fillEllipse(in:CGRect(x:282,y:282,width:460,height:460))
canvas.setFillColor(color(0x29251D).cgColor)
for x in [440,564] {canvas.fillEllipse(in:CGRect(x:x,y:522,width:20,height:20))}
let smile=CGMutablePath()
smile.move(to:NSPoint(x:456,y:468))
smile.addCurve(to:NSPoint(x:568,y:468),control1:NSPoint(x:493,y:417),control2:NSPoint(x:531,y:417))
canvas.setLineWidth(13)
canvas.setStrokeColor(color(0x29251D).cgColor)
canvas.addPath(smile)
canvas.strokePath()
let bitmap=NSBitmapImageRep(cgImage:canvas.makeImage()!)
try bitmap.representation(using:.png,properties:[:])!.write(to:iconSet.appendingPathComponent("AppIcon.png"))
let iconContents="""
{"images":[{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}

"""
try Data(iconContents.utf8).write(to:iconSet.appendingPathComponent("Contents.json"))
try Data("{\"info\":{\"author\":\"xcode\",\"version\":1}}\n".utf8).write(to:iconSet.deletingLastPathComponent().appendingPathComponent("Contents.json"))

extension Data {
 mutating func appendLE<T:FixedWidthInteger>(_ value:T) {
  var little=value.littleEndian
  Swift.withUnsafeBytes(of:&little) {append(contentsOf:$0)}
 }
}
func sound(_ name:String,duration:Double,notes:[(Double,Double,Double)],bell:Bool) throws {
 let sampleRate=22_050
 var samples=[Double](repeating:0,count:Int(duration*Double(sampleRate)))
 let partials:[(Double,Double,Double)]=bell
  ? [(1,1,1.25),(2.002,0.16,0.75),(3.98,0.035,0.4),(5.43,0.018,0.25)]
  : [(1,1,1.5),(2.001,0.26,0.95),(3.004,0.1,0.6),(4.01,0.045,0.4)]
 for (start,frequency,level) in notes {
  let first=Int(start*Double(sampleRate))
  for frame in first..<samples.count {
   let t=Double(frame-first)/Double(sampleRate)
   let attack=1-exp(-t/0.025)
   let tone=partials.reduce(0.0) {value,partial in
    value+partial.1*exp(-t/partial.2)*sin(2*Double.pi*frequency*partial.0*t)
   }
   samples[frame]+=level*attack*tone
  }
 }
 for frame in samples.indices {
  let remaining=Double(samples.count-1-frame)/Double(sampleRate)
  if remaining<0.8 {samples[frame]*=pow(sin(remaining/0.8*Double.pi/2),2)}
 }
 let scale=0.44/samples.map(abs).max()!
 let pcm=samples.map {Int16(($0*scale*Double(Int16.max)).rounded())}
 precondition(pcm.count>=sampleRate*7 && pcm.count<sampleRate*30)
 precondition(pcm.first==0 && pcm.last==0)
 precondition(pcm.map {abs(Int($0))}.max()!<16_400)
 var wav=Data("RIFF".utf8)
 wav.appendLE(UInt32(36+pcm.count*2));wav.append(Data("WAVEfmt ".utf8))
 wav.appendLE(UInt32(16));wav.appendLE(UInt16(1));wav.appendLE(UInt16(1))
 wav.appendLE(UInt32(sampleRate));wav.appendLE(UInt32(sampleRate*2))
 wav.appendLE(UInt16(2));wav.appendLE(UInt16(16));wav.append(Data("data".utf8))
 wav.appendLE(UInt32(pcm.count*2))
 for sample in pcm {wav.appendLE(sample)}
 try wav.write(to:resources.appendingPathComponent(name+".wav"))
 print("\(name): \(duration)s, mono PCM 22.05 kHz, peak 0.44")
}
try sound("sunrise",duration:9.4,notes:[(0.2,220,0.72),(1.55,277.1826,0.62),(2.9,329.6276,0.7),(4.55,440,0.53),(6.3,329.6276,0.45)],bell:false)
try sound("softChime",duration:8.2,notes:[(0.2,523.2511,0.7),(1.55,659.2551,0.52),(3.1,783.9909,0.48),(4.8,659.2551,0.4)],bell:true)
let decoded=NSBitmapImageRep(data:try Data(contentsOf:iconSet.appendingPathComponent("AppIcon.png")))!
precondition(decoded.pixelsWide==1024 && decoded.pixelsHigh==1024 && !decoded.hasAlpha)
precondition(decoded.colorAt(x:0,y:0)!.usingColorSpace(.deviceRGB)!.redComponent>0.98)
precondition(decoded.colorAt(x:512,y:512) != decoded.colorAt(x:0,y:0))
print("AppIcon: opaque 1024×1024 PNG")
