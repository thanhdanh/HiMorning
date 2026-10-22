import Foundation
#if !PORTABLE_TESTS
import XCTest
@testable import HiMorningCore
#endif

final class PushUpTests:XCTestCase {
 private func cycle(_ counter:inout PushUpCounter,start:Int=0,body:Double=175,incline:Double=10) {
  for (index,angle) in [165.0,120,80,120,165].enumerated() {
   counter.observe(elbowAngle:angle,bodyAngle:body,incline:incline,visible:true,timestampMs:start+index*300)
  }
 }
 func testCompleteCyclesCountOnceWithoutImages() {
  var counter=PushUpCounter(target:2)
  cycle(&counter);XCTAssertEqual(counter.completedReps,1);XCTAssertFalse(counter.ready)
  cycle(&counter,start:1500);XCTAssertTrue(counter.ready)
  cycle(&counter,start:3000);XCTAssertEqual(counter.completedReps,2)
 }
 func testStandingBentBodyOcclusionAndStaleFramesCannotComplete() {
  for (body,incline) in [(175.0,90.0),(100.0,10.0),(Double.nan,10.0),(175.0,Double.infinity)] {
   var counter=PushUpCounter(target:1);cycle(&counter,body:body,incline:incline);XCTAssertFalse(counter.ready)
  }
  var counter=PushUpCounter(target:1)
  for (time,angle,visible) in [(0,165.0,true),(300,120.0,true),(600,80.0,false),(900,120.0,true),(1200,165.0,true)] {
   counter.observe(elbowAngle:angle,bodyAngle:175,incline:10,visible:visible,timestampMs:time)
  }
  XCTAssertFalse(counter.ready)
  counter.interrupt()
  for (time,angle) in [(0,165.0),(300,120.0),(2000,80.0),(2300,120.0),(2600,165.0)] {
   counter.observe(elbowAngle:angle,bodyAngle:175,incline:10,visible:true,timestampMs:time)
  }
  XCTAssertFalse(counter.ready)
  counter.interrupt()
  for (index,angle) in [165.0,120,80,120,165].enumerated() {
   counter.observe(elbowAngle:angle,bodyAngle:175,incline:10,visible:true,timestampMs:index*120)
  }
  XCTAssertFalse(counter.ready)
 }
 private func feed(_ counter:inout PushUpCounter,_ samples:[(Int,Double,Bool)]) {
  for (time,angle,visible) in samples {
   counter.observe(elbowAngle:angle,bodyAngle:175,incline:10,visible:visible,timestampMs:time)
  }
 }
 func testFastDescentWithoutMiddleBandSamplesCounts() {
  var counter=PushUpCounter(target:1)
  feed(&counter,[(0,165,true),(400,80,true),(900,165,true)])
  XCTAssertEqual(counter.completedReps,1)
 }
 func testBriefOcclusionKeepsTheRep() {
  var counter=PushUpCounter(target:1)
  feed(&counter,[(0,165,true),(300,80,true),(500,0,false),(900,165,true)])
  XCTAssertEqual(counter.completedReps,1)
 }
 func testLongOcclusionResets() {
  var counter=PushUpCounter(target:1)
  feed(&counter,[(0,165,true),(300,80,true),(400,0,false),(1100,0,false),(1200,165,true)])
  XCTAssertEqual(counter.completedReps,0)
 }
 func testResumeAfterLongOcclusionWithoutHiddenSamplesResets() {
  var counter=PushUpCounter(target:1)
  feed(&counter,[(0,165,true),(300,80,true),(400,0,false),(1100,165,true)])
  XCTAssertEqual(counter.completedReps,0)
 }
 @MainActor func testLocalCameraCompletionNeedsTheTargetAndNeverCallsCloud() async throws {
  let scheduler=PushUpScheduler()
  let alarm=SavedAlarm(time:try AlarmTime(hour:7,minute:0,weekdays:[]),challenge:.pushUps(repetitions:2))
  let flow=ChallengeCoordinator(alarm:alarm,cloud:nil,scheduler:scheduler)
  var counter=PushUpCounter(target:2);cycle(&counter)
  do {_=try await flow.completePushUps(counter);preconditionFailure("Partial movement must not complete")} catch {}
  let before=await scheduler.stops
  XCTAssertNil(flow.session.outcome);XCTAssertEqual(before,0)
  cycle(&counter,start:1500)
  let applied=try await flow.completePushUps(counter)
  XCTAssertTrue(applied);XCTAssertEqual(flow.session.outcome,.localCompleted)
  let duplicate=try await flow.completePushUps(counter),stops=await scheduler.stops
  XCTAssertFalse(duplicate);XCTAssertEqual(stops,1)
  let practice=ChallengeCoordinator(alarm:alarm,cloud:nil,scheduler:scheduler,rehearsal:true)
  let practiced=try await practice.completePushUps(counter),practiceStops=await scheduler.stops
  XCTAssertTrue(practiced);XCTAssertEqual(practiceStops,1)
  let stopped=ChallengeCoordinator(alarm:alarm,cloud:nil,scheduler:scheduler)
  try await stopped.finish(.dismissed)
  let late=try await stopped.completePushUps(counter)
  XCTAssertFalse(late);XCTAssertEqual(stopped.session.outcome,.dismissed)
  let wrong=ChallengeCoordinator(alarm:SavedAlarm(time:alarm.time,challenge:.readAndChoose),cloud:nil,scheduler:scheduler)
  do {_=try await wrong.completePushUps(counter);preconditionFailure("Wrong challenge must reject camera completion")} catch {}
 }
 @MainActor func testStopWinsWhileCameraCompletionIsWaitingForTheAlarm() async throws {
  let scheduler=PushUpStopGate()
  let alarm=SavedAlarm(time:try AlarmTime(hour:7,minute:0,weekdays:[]),challenge:.pushUps(repetitions:1))
  let flow=ChallengeCoordinator(alarm:alarm,cloud:nil,scheduler:scheduler)
  var counter=PushUpCounter(target:1);cycle(&counter)
  let proof=counter
  let pending=Task {try await flow.completePushUps(proof)}
  await scheduler.waitForStop()
  let duplicate=try await flow.completePushUps(proof)
  XCTAssertFalse(duplicate)
  try await flow.finish(.dismissed)
  await scheduler.release()
  let applied=try await pending.value
  XCTAssertFalse(applied);XCTAssertEqual(flow.session.outcome,.dismissed)
 }
 @MainActor func testFailedNativeStopCannotRecordCameraSuccess() async throws {
  let alarm=SavedAlarm(time:try AlarmTime(hour:7,minute:0,weekdays:[]),challenge:.pushUps(repetitions:1))
  let flow=ChallengeCoordinator(alarm:alarm,cloud:nil,scheduler:FailingPushUpScheduler())
  var counter=PushUpCounter(target:1);cycle(&counter)
  do {_=try await flow.completePushUps(counter);preconditionFailure("Failed native stop must not complete")} catch {}
  XCTAssertNil(flow.session.outcome)
 }
}
private actor PushUpStopGate:AlarmScheduler {
 private var reply:CheckedContinuation<Void,Never>?
 private var stops=0
 func schedule(_ alarm:SavedAlarm) async throws {}
 func cancel(id:UUID) async throws {}
 func scheduledIDs() async throws ->Set<UUID> {[]}
 func stop(id:UUID) async throws {stops+=1;if stops == 1 {await withCheckedContinuation {reply=$0}}}
 func waitForStop() async {while reply == nil {await Task.yield()}}
 func release() {reply?.resume();reply=nil}
}
private struct FailingPushUpScheduler:AlarmScheduler {
 func schedule(_ alarm:SavedAlarm) async throws {}
 func cancel(id:UUID) async throws {}
 func scheduledIDs() async throws ->Set<UUID> {[]}
 func stop(id:UUID) async throws {throw ChallengeError.cloudUnavailable}
}
private actor PushUpScheduler:AlarmScheduler {
 private(set) var stops=0
 func schedule(_ alarm:SavedAlarm) async throws {}
 func cancel(id:UUID) async throws {}
 func scheduledIDs() async throws ->Set<UUID> {[]}
 func stop(id:UUID) async throws {stops+=1}
}
