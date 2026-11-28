import XCTest
@testable import HiMorningCore

final class SquatAndAdaptationTests: XCTestCase {
 func testSquatCounterCountsCleanRepsAndRejectsShallowMotion() {
  var counter = SquatCounter(target: 10)
  XCTAssertEqual(counter.observe(kneeAngle: 170, visible: true, timestampMs: 0), 0)
  XCTAssertEqual(counter.observe(kneeAngle: 132, visible: true, timestampMs: 400), 0)
  XCTAssertEqual(counter.observe(kneeAngle: 130, visible: true, timestampMs: 1_000), 0)
  XCTAssertEqual(counter.formCue, .goLower)
  XCTAssertEqual(counter.observe(kneeAngle: 170, visible: true, timestampMs: 1_400), 0)

  XCTAssertEqual(counter.observe(kneeAngle: 170, visible: true, timestampMs: 2_000), 0)
  XCTAssertEqual(counter.observe(kneeAngle: 104, visible: true, timestampMs: 2_450), 0)
  XCTAssertGreaterThan(counter.romProgress, 0.9)
  XCTAssertEqual(counter.observe(kneeAngle: 168, visible: true, timestampMs: 2_950), 1)
 }

 func testInclinePushUpAcceptsElevatedInclineAndTracksROM() {
  var counter = PushUpCounter(target: 10, variant: .inclineOrKnee)
  counter.observe(elbowAngle: 160, bodyAngle: 142, incline: 58, visible: true, timestampMs: 0)
  XCTAssertEqual(counter.completedReps, 0)
  counter.observe(elbowAngle: 100, bodyAngle: 142, incline: 58, visible: true, timestampMs: 400)
  XCTAssertGreaterThan(counter.romProgress, 0.9)
  counter.observe(elbowAngle: 158, bodyAngle: 142, incline: 58, visible: true, timestampMs: 950)
  XCTAssertEqual(counter.completedReps, 1)
 }

 func testCameraConditionMathClassifiesLumaAndDerotatesRoll() {
  XCTAssertEqual(CameraConditionMath.classifyLuma(0.14), .lowLight)
  XCTAssertEqual(CameraConditionMath.classifyLuma(0.52), .goodLight)
  XCTAssertEqual(CameraConditionMath.classifyLuma(0.94), .overexposed)

  let roll = CameraConditionMath.iosRollDegrees(gx: 0.3, gy: -0.95)
  XCTAssertGreaterThan(roll, 15)
  XCTAssertLessThan(roll, 20)

  let center = CameraConditionMath.derotateNormalizedPoint(x: 0.5, y: 0.5, rollDeg: 20, aspectRatio: 0.75)
  XCTAssertEqual(center.x, 0.5, accuracy: 0.001)
  XCTAssertEqual(center.y, 0.5, accuracy: 0.001)
 }

 func testMorningAdaptationStepsDownAndStepsUpOffline() {
  let now = Date()
  let standardSelection = ChallengeSelection.pushUps(repetitions: 10, variant: .standard)
  let friction: [MorningEntry] = [
   MorningEntry(mode: .focused, challenge: standardSelection, date: now, outcome: .selfConfirmed),
   MorningEntry(mode: .focused, challenge: standardSelection, date: now.addingTimeInterval(-86_400), outcome: .dismissed),
  ]

  let inclineRec = MorningAdaptationEngine.evaluate(entries: friction, currentSelection: standardSelection)
  XCTAssertEqual(inclineRec.action, .stepDownToInclinePushUps)
  XCTAssertEqual(inclineRec.consecutiveStruggles, 2)

  let inclineSelection = ChallengeSelection.pushUps(repetitions: 10, variant: .inclineOrKnee)
  let squatRec = MorningAdaptationEngine.evaluate(entries: friction, currentSelection: inclineSelection)
  XCTAssertEqual(squatRec.action, .stepDownToSquats)

  let fastWins: [MorningEntry] = (0..<5).map { day in
   MorningEntry(
    mode: .focused,
    challenge: standardSelection,
    date: now.addingTimeInterval(Double(-day) * 86_400),
    outcome: .localCompleted,
    completionDurationSec: 19,
    avgRomScore: 0.91
   )
  }
  let stepUpRec = MorningAdaptationEngine.evaluate(entries: fastWins, currentSelection: standardSelection)
  XCTAssertEqual(stepUpRec.action, .stepUpReps)
  XCTAssertEqual(stepUpRec.suggestedRepetitions, 12)
  XCTAssertEqual(stepUpRec.consecutiveFastWins, 5)
 }

 func testMorningEntryRemainsBackwardCompatibleWhenOptionalMetricsOmitted() throws {
  let legacyJSON = """
  {"id":"00000000-0000-0000-0000-000000000009","date":1000,"outcome":"local_completed"}
  """
  let decoded = try JSONDecoder().decode(MorningEntry.self, from: Data(legacyJSON.utf8))
  XCTAssertNil(decoded.completionDurationSec)
  XCTAssertNil(decoded.avgRomScore)
 }
}
