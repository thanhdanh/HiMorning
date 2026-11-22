import Foundation

public struct MorningLightEvaluator: Sendable {
 public enum State: Equatable, Sendable {
  case seekingLight
  case holding(progress: Double)
  case completed
 }

 public static let defaultBrightThreshold: Double = 0.58
 public static let defaultDropThreshold: Double = 0.48
 public static let defaultHoldDuration: TimeInterval = 2.0

 public let brightThreshold: Double
 public let dropThreshold: Double
 public let holdDuration: TimeInterval

 private var holdStartTimestamp: TimeInterval?
 public private(set) var state: State = .seekingLight

 public init(
  brightThreshold: Double = MorningLightEvaluator.defaultBrightThreshold,
  dropThreshold: Double = MorningLightEvaluator.defaultDropThreshold,
  holdDuration: TimeInterval = MorningLightEvaluator.defaultHoldDuration
 ) {
  self.brightThreshold = brightThreshold
  self.dropThreshold = dropThreshold
  self.holdDuration = max(0.2, holdDuration)
 }

 @discardableResult
 public mutating func process(luminance: Double, timestamp: TimeInterval) -> State {
  if state == .completed { return .completed }

  if holdStartTimestamp == nil {
   if luminance >= brightThreshold {
    holdStartTimestamp = timestamp
    state = .holding(progress: 0)
   } else {
    state = .seekingLight
   }
   return state
  }

  if luminance < dropThreshold {
   holdStartTimestamp = nil
   state = .seekingLight
   return state
  }

  let elapsed = max(0, timestamp - (holdStartTimestamp ?? timestamp))
  let progress = min(1, elapsed / holdDuration)
  if elapsed >= holdDuration {
   state = .completed
  } else {
   state = .holding(progress: progress)
  }
  return state
 }

 public mutating func reset() {
  holdStartTimestamp = nil
  state = .seekingLight
 }
}
