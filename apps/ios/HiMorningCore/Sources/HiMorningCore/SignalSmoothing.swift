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
