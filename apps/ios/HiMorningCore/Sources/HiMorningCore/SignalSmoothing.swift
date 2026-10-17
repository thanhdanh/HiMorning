import Foundation

/// Time-aware exponential moving average for a scalar signal that arrives on
/// camera-frame timestamps (e.g. face yaw, joint offsets).
///
/// Smoothing strength adapts to the actual frame delta, so behaviour stays
/// consistent across frame rates. A "half-life" is the time it takes the output
/// to move halfway toward a new input; smaller values are more responsive,
/// larger values are smoother but linger longer.
public struct ExpMovingAverage: Sendable {
 /// Time in milliseconds for the output to close half the distance to a new sample.
 public let halfLifeMs: Int
 private var value: Double?
 private var lastTimestampMs: Int?

 public init(halfLifeMs: Int) {
  self.halfLifeMs = max(1, halfLifeMs)
 }

 public mutating func reset() { value = nil; lastTimestampMs = nil }

 /// Feeds one sample and returns the smoothed value. A non-finite sample resets
 /// the filter; the caller decides whether that maps to a tracking loss.
 @discardableResult public mutating func smooth(_ sample: Double, timestampMs: Int) -> Double {
  guard sample.isFinite else { reset(); return .nan }
  defer { lastTimestampMs = timestampMs }
  guard let previous = value, let last = lastTimestampMs, timestampMs >= last else {
   value = sample; return sample
  }
  let dt = max(0, timestampMs - last)
  // alpha closes 1 - 0.5^(dt / halfLife) toward the sample each step.
  let alpha = 1 - exp(-Double(dt) * log(2.0) / Double(halfLifeMs))
  let smoothed = previous + alpha * (sample - previous)
  value = smoothed
  return smoothed
 }
}
