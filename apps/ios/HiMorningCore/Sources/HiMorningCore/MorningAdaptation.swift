import Foundation

public enum MorningAdaptationAction: String, Codable, Equatable, Sendable {
 case stepDownToInclinePushUps = "step_down_to_incline_push_ups"
 case stepDownToSquats = "step_down_to_squats"
 case stepUpReps = "step_up_reps"
 case keepSteady = "keep_steady"
}

public struct MorningAdaptationRecommendation: Equatable, Sendable {
 public let action: MorningAdaptationAction
 public let suggestedRepetitions: Int?
 public let consecutiveStruggles: Int
 public let consecutiveFastWins: Int

 public init(
  action: MorningAdaptationAction,
  suggestedRepetitions: Int? = nil,
  consecutiveStruggles: Int = 0,
  consecutiveFastWins: Int = 0
 ) {
  self.action = action
  self.suggestedRepetitions = suggestedRepetitions
  self.consecutiveStruggles = consecutiveStruggles
  self.consecutiveFastWins = consecutiveFastWins
 }
}

/// 100% offline deterministic habit adaptation engine.
/// Detects morning push-up friction (2+ consecutive self-confirmed/dismissed mornings)
/// and steady mastery (5+ fast completions <= 25s) without any network call.
public enum MorningAdaptationEngine {
 public static let struggleThreshold = 2
 public static let fastWinThreshold = 5
 public static let fastCompletionMaxSec = 25
 public static let maxRepetitions = 50

 public static func evaluate(
  entries: [MorningEntry],
  currentSelection: ChallengeSelection? = nil
 ) -> MorningAdaptationRecommendation {
  let ordered = entries.sorted { $0.date > $1.date }
  let pushUpEntries = ordered.filter { $0.challenge?.kind == .pushUps }

  var consecutivePushUpStruggles = 0
  for entry in pushUpEntries {
   if entry.outcome == .selfConfirmed || entry.outcome == .dismissed {
    consecutivePushUpStruggles += 1
   } else {
    break
   }
  }

  if consecutivePushUpStruggles >= struggleThreshold {
   let currentVariant = currentSelection?.pushUpVariant
    ?? pushUpEntries.first?.challenge?.pushUpVariant
    ?? .standard
   if currentVariant == .standard {
    return MorningAdaptationRecommendation(
     action: .stepDownToInclinePushUps,
     suggestedRepetitions: min(currentSelection?.repetitions ?? 10, 10),
     consecutiveStruggles: consecutivePushUpStruggles
    )
   }
   return MorningAdaptationRecommendation(
    action: .stepDownToSquats,
    suggestedRepetitions: 10,
    consecutiveStruggles: consecutivePushUpStruggles
   )
  }

  let movementKinds: Set<ChallengeKind> = [.pushUps, .squats, .jumpingJacks]
  let movementEntries = ordered.filter { entry in
   guard let kind = entry.challenge?.kind else { return false }
   return movementKinds.contains(kind)
  }

  var consecutiveFastWins = 0
  for entry in movementEntries {
   let succeeded = entry.outcome == .localCompleted || entry.outcome == .aiVerified || entry.outcome == .openaiVerified
   guard succeeded, let duration = entry.completionDurationSec, duration > 0, duration <= fastCompletionMaxSec else {
    break
   }
   consecutiveFastWins += 1
  }

  if consecutiveFastWins >= fastWinThreshold {
   let baseReps = currentSelection?.repetitions ?? movementEntries.first?.challenge?.repetitions ?? 10
   let nextReps = min(maxRepetitions, baseReps + 2)
   if nextReps > baseReps {
    return MorningAdaptationRecommendation(
     action: .stepUpReps,
     suggestedRepetitions: nextReps,
     consecutiveFastWins: consecutiveFastWins
    )
   }
  }

  return MorningAdaptationRecommendation(
   action: .keepSteady,
   consecutiveStruggles: consecutivePushUpStruggles,
   consecutiveFastWins: consecutiveFastWins
  )
 }
}
