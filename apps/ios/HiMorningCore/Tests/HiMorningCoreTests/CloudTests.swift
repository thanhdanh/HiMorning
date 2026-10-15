import Foundation
#if !PORTABLE_TESTS
import XCTest
@testable import HiMorningCore
#endif

final class CloudTests:XCTestCase {
 @MainActor func testRestartDuringCancellationKeepsTheNewSessionAndConsent() async throws {
  let cloud=RestartCloud()
  let alarm=SavedAlarm(time:try AlarmTime(hour:6,minute:30,weekdays:[]),mode:.balanced)
  let flow=ChallengeCoordinator(alarm:alarm,cloud:cloud,scheduler:RestartScheduler(),rehearsal:true)
  try await flow.startCloud(consent:true)
  let suspension=Task {await flow.suspend()}
  await cloud.waitForCancellation()
  try await flow.startCloud(consent:true)
  await cloud.releaseCancellation()
  await suspension.value
  let evidence=(0..<15).map {EvidenceFrame(jpeg:Data([UInt8($0+1)]),timestampMs:$0*300)}
  let applied=try await flow.submit(evidence)
  let creates=await cloud.creates
  XCTAssertTrue(applied)
  XCTAssertEqual(creates,2)
  XCTAssertEqual(flow.session.outcome,.openaiVerified)
 }
}

private actor RestartCloud:CloudVerification {
 private(set) var creates=0
 private var cancellation:CheckedContinuation<Void,Never>?
 private var waiting:CheckedContinuation<Void,Never>?
 func create(target:Int,requestID:UUID) async throws ->CloudSession {
  creates+=1
  return CloudSession(sessionID:String(format:"%064d",creates),nonce:UUID().uuidString,expiresAt:Date().addingTimeInterval(120).timeIntervalSince1970*1000)
 }
 func verify(_ request:VerificationSubmission) async throws ->CloudDecision {
  CloudDecision(status:"verified",decisionID:UUID().uuidString,verifiedRepCount:3)
 }
 func cancel(sessionID:String) async throws {
  await withCheckedContinuation {cancellation=$0;waiting?.resume();waiting=nil}
 }
 func waitForCancellation() async {
  if cancellation != nil {return}
  await withCheckedContinuation {waiting=$0}
 }
 func releaseCancellation() {cancellation?.resume();cancellation=nil}
}

private struct RestartScheduler:AlarmScheduler {
 func schedule(_ alarm:SavedAlarm) async throws {}
 func cancel(id:UUID) async throws {}
 func stop(id:UUID) async throws {}
 func scheduledIDs() async throws ->Set<UUID> {[]}
}
