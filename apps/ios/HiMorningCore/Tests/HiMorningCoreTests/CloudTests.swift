import Foundation
#if !PORTABLE_TESTS
import XCTest
@testable import HiMorningCore
#endif

final class CloudTests:XCTestCase {
 @MainActor func testCompletedChallengeRetriesDoNotStopTheAlarmAgainOrReplaceItsJournalEntry() async throws {
  let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer {try? FileManager.default.removeItem(at:root)}
  let url=root.appendingPathComponent("morning.json"),now=Date()
  var journal=try MorningJournal(url:url)
  let alarm=SavedAlarm(time:try AlarmTime(hour:6,minute:30,weekdays:[]),mode:.balanced,challenge:.readAndChoose)
  let scheduler=RestartScheduler()
  let original=ChallengeCoordinator(alarm:alarm,cloud:nil,scheduler:scheduler)
  try await original.finish(.localCompleted)
  let entry=MorningEntry(date:now,outcome:try XCTUnwrap(original.session.outcome))
  let recorded=try journal.record(entry,now:now)
  XCTAssertTrue(recorded)
  for outcome in [WakeOutcome.localCompleted,.localCompleted,.dismissed] {
   let retry=ChallengeCoordinator(alarm:alarm,cloud:nil,scheduler:scheduler,rehearsal:true)
   try await retry.finish(outcome)
   XCTAssertEqual(retry.session.outcome,outcome)
   let recorded=try journal.record(MorningEntry(date:now,outcome:try XCTUnwrap(retry.session.outcome)),rehearsal:true,now:now)
   XCTAssertFalse(recorded)
  }
  let stoppedIDs=await scheduler.stoppedIDs
  XCTAssertEqual(stoppedIDs,[alarm.id])
  let restored=try MorningJournal(url:url)
  XCTAssertEqual(restored.entries.map(\.id),[entry.id])
  XCTAssertEqual(restored.entries.map(\.outcome),[.localCompleted])
 }
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
  XCTAssertEqual(flow.session.outcome,.aiVerified)
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
 func getResult(sessionID:String,evidenceID:String) async throws ->CloudDecision {throw ChallengeError.cloudUnavailable}
 func cancel(sessionID:String) async throws {
  await withCheckedContinuation {cancellation=$0;waiting?.resume();waiting=nil}
 }
 func waitForCancellation() async {
  if cancellation != nil {return}
  await withCheckedContinuation {waiting=$0}
 }
 func releaseCancellation() {cancellation?.resume();cancellation=nil}
}

private actor RestartScheduler:AlarmScheduler {
 private(set) var stoppedIDs:[UUID]=[]
 func schedule(_ alarm:SavedAlarm) async throws {}
 func cancel(id:UUID) async throws {}
 func stop(id:UUID) async throws {stoppedIDs.append(id)}
 func scheduledIDs() async throws ->Set<UUID> {[]}
}

private actor PollingCloud:CloudVerification {
 var submissions=0
 var polls=0
 var cancellations=0
 var evidenceID:String?
 let pendingPolls:Int
 init(pendingPolls:Int=4){self.pendingPolls=pendingPolls}
 func create(target:Int,requestID:UUID) async throws ->CloudSession {CloudSession(sessionID:String(repeating:"a",count:64),nonce:UUID().uuidString,expiresAt:Date().addingTimeInterval(600).timeIntervalSince1970*1000)}
 func verify(_ request:VerificationSubmission) async throws ->CloudDecision {submissions+=1;evidenceID=request.evidenceID;return CloudDecision(status:"pending",decisionID:"decision",verifiedRepCount:nil)}
 func getResult(sessionID:String,evidenceID:String) async throws ->CloudDecision {
  XCTAssertEqual(self.evidenceID,evidenceID);polls+=1
  return CloudDecision(status:polls<=pendingPolls ? "pending":"verified",decisionID:"decision",verifiedRepCount:3)
 }
 func cancel(sessionID:String) async throws {cancellations+=1}
}
private actor PollDelays {
 var values:[UInt64]=[]
 func record(_ value:UInt64){values.append(value)}
}
private actor PausedPoll {
 var began=false
 func sleep(_ value:UInt64) async throws {began=true;try await Task.sleep(nanoseconds:60_000_000_000)}
 func waitUntilSleeping() async {while !began {await Task.yield()}}
}
extension CloudTests {
 @MainActor func testColdStartPollsWithoutResubmittingAndRecordsNeutralSuccess() async throws {
  let cloud=PollingCloud(),delays=PollDelays()
  let alarm=SavedAlarm(time:try AlarmTime(hour:6,minute:30,weekdays:[]),mode:.balanced)
  let flow=ChallengeCoordinator(alarm:alarm,cloud:cloud,scheduler:RestartScheduler(),rehearsal:true,sleep:{await delays.record($0)})
  try await flow.startCloud(consent:true)
  let applied=try await flow.submit((0..<15).map{EvidenceFrame(jpeg:Data([UInt8($0+1)]),timestampMs:$0*300)})
  XCTAssertTrue(applied);XCTAssertEqual(flow.session.outcome,.aiVerified)
  let submissions=await cloud.submissions,polls=await cloud.polls,recorded=await delays.values
  XCTAssertEqual(submissions,1);XCTAssertEqual(polls,5);XCTAssertEqual(recorded,[2,4,8,10,10].map{UInt64($0)*1_000_000_000})
 }
 @MainActor func testStopCancelsSleepingPollWithoutWaitingForItsNextInterval() async throws {
  let cloud=PollingCloud(),pause=PausedPoll()
  let alarm=SavedAlarm(time:try AlarmTime(hour:6,minute:30,weekdays:[]),mode:.balanced)
  let flow=ChallengeCoordinator(alarm:alarm,cloud:cloud,scheduler:RestartScheduler(),rehearsal:true,sleep:{try await pause.sleep($0)})
  try await flow.startCloud(consent:true)
  let task=Task{try await flow.submit((0..<15).map{EvidenceFrame(jpeg:Data([UInt8($0+1)]),timestampMs:$0*300)})}
  await pause.waitUntilSleeping();try await flow.finish(.dismissed)
  let applied=try await task.value,polls=await cloud.polls,cancellations=await cloud.cancellations
  XCTAssertFalse(applied);XCTAssertEqual(polls,0);XCTAssertEqual(cancellations,1);XCTAssertEqual(flow.session.outcome,.dismissed)
 }
 @MainActor func testPollingDeadlineCancelsRemoteJobAndNeverMarksSuccess() async throws {
  let cloud=PollingCloud()
  let alarm=SavedAlarm(time:try AlarmTime(hour:6,minute:30,weekdays:[]),mode:.balanced)
  var times:[TimeInterval]=[0,181]
  let flow=ChallengeCoordinator(alarm:alarm,cloud:cloud,scheduler:RestartScheduler(),rehearsal:true,sleep:{_ in},clock:{times.removeFirst()})
  try await flow.startCloud(consent:true)
  do{_=try await flow.submit((0..<15).map{EvidenceFrame(jpeg:Data([UInt8($0+1)]),timestampMs:$0*300)});preconditionFailure("Expected deadline")}catch{}
  let polls=await cloud.polls,cancellations=await cloud.cancellations
  XCTAssertEqual(polls,0);XCTAssertEqual(cancellations,1);XCTAssertNil(flow.session.outcome)
 }
 func testBothHistoricalAndNewVerifiedOutcomesDecodeWithoutMigration() throws {
  XCTAssertEqual(try JSONDecoder().decode(WakeOutcome.self,from:Data("\"openai_verified\"".utf8)),.openaiVerified)
  XCTAssertEqual(try JSONDecoder().decode(WakeOutcome.self,from:Data("\"ai_verified\"".utf8)),.aiVerified)
 }
}
