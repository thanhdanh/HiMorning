import Foundation

public struct OneEuroFilter:Sendable {
 private let minCutoff:Double
 private let beta:Double
 private let derivativeCutoff:Double
 private var value:Double?
 private var derivative=0.0
 private var lastRaw=0.0
 private var lastTimestampMs:Int?

 public init(minCutoff:Double,beta:Double,derivativeCutoff:Double=1.0) {
  self.minCutoff=minCutoff;self.beta=beta;self.derivativeCutoff=derivativeCutoff
 }

 public mutating func reset() {value=nil;derivative=0;lastRaw=0;lastTimestampMs=nil}

 public mutating func filter(_ sample:Double,timestampMs:Int)->Double {
  guard sample.isFinite else {reset();return .nan}
  guard let previous=value,let last=lastTimestampMs else {
   value=sample;lastRaw=sample;derivative=0;lastTimestampMs=timestampMs;return sample
  }
  guard timestampMs>last else {return previous}
  let dt=Double(timestampMs-last)/1_000
  derivative+=Self.alpha(cutoff:derivativeCutoff,dt:dt)*((sample-lastRaw)/dt-derivative)
  let smoothed=previous+Self.alpha(cutoff:minCutoff+beta*abs(derivative),dt:dt)*(sample-previous)
  value=smoothed;lastRaw=sample;lastTimestampMs=timestampMs
  return smoothed
 }

 private static func alpha(cutoff:Double,dt:Double)->Double {1/(1+1/(2 * .pi * cutoff)/dt)}
}

public enum CameraLightingStatus:String,Equatable,Sendable {
 case lowLight = "low_light"
 case goodLight = "good_light"
 case overexposed
}

/// Shared camera lighting & gravity roll-compensation math ported from go-tall
/// so dim 6:00 AM bedrooms and tilted nightstand phones stay reliable.
public enum CameraConditionMath {
 public static let lowLightThreshold=0.20
 public static let overexposedThreshold=0.90

 public static func classifyLuma(_ meanLuma:Double)->CameraLightingStatus {
  guard meanLuma.isFinite else {return .goodLight}
  if meanLuma < lowLightThreshold {return .lowLight}
  if meanLuma > overexposedThreshold {return .overexposed}
  return .goodLight
 }

 /// Converts iOS CMDeviceMotion gravity (upright portrait = (0, -1, 0)) into lateral roll degrees.
 public static func iosRollDegrees(gx:Double,gy:Double)->Double {
  guard gx.isFinite,gy.isFinite,abs(gy)>0.05 else {return 0}
  let deg=atan2(gx,-gy)*180.0 / .pi
  return max(-35.0,min(35.0,(deg*10.0).rounded()/10.0))
 }

 /// Rotates a normalized [0..1] point in isotropic metric space by -rollDeg around center.
 public static func derotateNormalizedPoint(x:Double,y:Double,rollDeg:Double,aspectRatio:Double)->(x:Double,y:Double) {
  guard rollDeg.isFinite,abs(rollDeg)>=0.5,aspectRatio.isFinite,aspectRatio>0 else {return (x,y)}
  let clamped=max(-35.0,min(35.0,rollDeg))
  let rad = -clamped * .pi / 180.0
  let cosR=cos(rad),sinR=sin(rad)
  let cx=0.5*aspectRatio,cy=0.5
  let mx=x*aspectRatio-cx,my=y-cy
  let rx=mx*cosR-my*sinR+cx
  let ry=mx*sinR+my*cosR+cy
  return (rx/aspectRatio,ry)
 }
}
