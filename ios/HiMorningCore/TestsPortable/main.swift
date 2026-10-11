import Foundation
// Portable assertions for Command Line Tools hosts without XCTest.
func XCTAssertTrue(_ value: @autoclosure () -> Bool) { precondition(value()) }
func XCTAssertFalse(_ value: @autoclosure () -> Bool) { precondition(!value()) }
func XCTAssertEqual<T: Equatable>(_ a: T, _ b: T) { precondition(a == b, "Expected \(a) == \(b)") }
func XCTAssertNil<T>(_ value: T?) { precondition(value == nil) }
func XCTAssertGreaterThan<T: Comparable>(_ a: T, _ b: T) { precondition(a > b) }
func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T) { do { _ = try expression(); preconditionFailure("Expected error") } catch {} }
func XCTAssertNoThrow<T>(_ expression: @autoclosure () throws -> T) { do { _ = try expression() } catch { preconditionFailure("Unexpected error: \(error)") } }
final class CoreTests {
 func testPresetsAreGentleAndBounded() {
  XCTAssertEqual(WakeMode.gentle.policy.snoozes, 2)
  XCTAssertEqual(WakeMode.gentle.policy.reps, 0)
  XCTAssertEqual(WakeMode.balanced.policy.reps, 3)
  XCTAssertEqual(WakeMode.focused.policy.reps, 5)
  XCTAssertEqual(WakeMode.focused.policy.snoozes, 0)
 }
 func testAlarmValidation() throws {
  XCTAssertThrowsError(try AlarmTime(hour:24,minute:0,weekdays:[]))
  XCTAssertThrowsError(try AlarmTime(hour:6,minute:60,weekdays:[]))
  XCTAssertThrowsError(try AlarmTime(hour:6,minute:30,weekdays:[0]))
  XCTAssertNoThrow(try AlarmTime(hour:6,minute:30,weekdays:[2,3,4,5,6]))
 }
 func testNextWeekdayInVietnamAndOneTimeTomorrow() throws {
  var calendar=Calendar(identifier:.gregorian); calendar.timeZone=TimeZone(identifier:"Asia/Ho_Chi_Minh")!
  let now=ISO8601DateFormatter().date(from:"2026-10-11T22:15:00+07:00")!
  let next=try AlarmTime(hour:6,minute:30,weekdays:[2,3,4,5,6]).next(after:now,calendar:calendar)
  XCTAssertEqual(calendar.component(.weekday,from:next!),2)
  XCTAssertEqual(calendar.component(.hour,from:next!),6)
  let tomorrow=try AlarmTime(hour:6,minute:30,weekdays:[]).next(after:now,calendar:calendar)!
  XCTAssertEqual(calendar.component(.day,from:tomorrow),12)
 }
 func testSpringDSTDoesNotCreatePastAlarm() throws {
  var calendar=Calendar(identifier:.gregorian); calendar.timeZone=TimeZone(identifier:"America/New_York")!
  let now=ISO8601DateFormatter().date(from:"2026-03-08T00:00:00-05:00")!
  let next=try AlarmTime(hour:2,minute:30,weekdays:[]).next(after:now,calendar:calendar)!
  XCTAssertGreaterThan(next,now)
  XCTAssertEqual(calendar.component(.day,from:next),8)
 }
 func testStopInvalidatesPendingResponseAndDoesNotCountAsSuccess() {
  var flow=WakeSession(mode:.balanced)
  let generation=flow.beginVerification()
  flow.stop()
  XCTAssertFalse(flow.applyVerified(generation:generation))
  XCTAssertEqual(flow.outcome,.dismissed)
 }
 func testLocalCountNeverCompletesCloudChallengeAndDuplicateResultCannotApply() {
  var flow=WakeSession(mode:.balanced)
  flow.recordLocalRep(); XCTAssertNil(flow.outcome)
  let generation=flow.beginVerification()
  XCTAssertTrue(flow.applyVerified(generation:generation))
  XCTAssertFalse(flow.applyVerified(generation:generation))
  XCTAssertEqual(flow.outcome,.openaiVerified)
 }
 func testFallbackAndSnoozeRemainExplicit() {
  var flow=WakeSession(mode:.gentle)
  XCTAssertTrue(flow.snooze());XCTAssertTrue(flow.snooze());XCTAssertFalse(flow.snooze())
  flow.selfConfirm();XCTAssertEqual(flow.outcome,.selfConfirmed)
  var focused=WakeSession(mode:.focused);XCTAssertFalse(focused.snooze())
 }
 func testInterruptedRepResetsButRetainsCompletedReps() {
  var counter=RepCounter()
  XCTAssertFalse(counter.observe(angle:165,visible:true))
  XCTAssertFalse(counter.observe(angle:80,visible:true))
  XCTAssertFalse(counter.observe(angle:165,visible:false))
  XCTAssertFalse(counter.observe(angle:165,visible:true))
  XCTAssertEqual(counter.count,0)
  XCTAssertFalse(counter.observe(angle:80,visible:true))
  XCTAssertTrue(counter.observe(angle:165,visible:true))
  XCTAssertEqual(counter.count,1)
  counter.interrupt();XCTAssertEqual(counter.count,1)
 }
 func testNoiseDoesNotCountAndBufferNeverExceedsCap() {
  var counter=RepCounter()
  for angle in [Double.nan,140,100,150,120] { XCTAssertFalse(counter.observe(angle:angle,visible:true)) }
  XCTAssertEqual(counter.count,0)
  var evidence=EvidenceBuffer(maxFrames:2,maxBytes:6)
  XCTAssertTrue(evidence.append(Data([1,2,3]),timestampMs:0))
  XCTAssertFalse(evidence.append(Data([1]),timestampMs:0))
  XCTAssertTrue(evidence.append(Data([4,5,6]),timestampMs:300))
  XCTAssertFalse(evidence.append(Data([7]),timestampMs:600))
  XCTAssertEqual(evidence.frames.count,2)
  evidence.clear();XCTAssertTrue(evidence.frames.isEmpty)
 }
}

actor FakeScheduler: AlarmScheduler {
 var ids:Set<UUID>=[]
 var shouldFail=false
 var stops=0
 func schedule(_ alarm:SavedAlarm) async throws { if shouldFail {throw DomainError.invalidAlarmTime};ids.insert(alarm.id) }
 func cancel(id:UUID) async throws {ids.remove(id)}
 func stop(id:UUID) async throws {stops+=1}
 func scheduledIDs() async throws -> Set<UUID> {ids}
 func failNext() {shouldFail=true}
}
func testNativeLibrary() async throws {
 let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
 defer {try? FileManager.default.removeItem(at:dir)}
 try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
 let persistence=FileAlarmPersistence(url:dir.appendingPathComponent("alarms.json"))
 let scheduler=FakeScheduler()
 let library=try AlarmLibrary(persistence:persistence,scheduler:scheduler)
 let alarm=SavedAlarm(time:try AlarmTime(hour:6,minute:30,weekdays:[2,3,4,5,6]),mode:.gentle,sound:.sunrise)
 try await library.add(alarm)
 let saved=await library.all();XCTAssertEqual(saved.first?.state,.confirmed)
 let restarted=try AlarmLibrary(persistence:persistence,scheduler:scheduler)
 let restored=await restarted.all();XCTAssertEqual(restored.first?.id,alarm.id)
 try await library.disable(id:alarm.id)
 let disabled=await library.all();XCTAssertEqual(disabled.first?.state,.off)
 try await library.enable(id:alarm.id)
 let enabled=await library.all();XCTAssertEqual(enabled.first?.state,.confirmed)
 try await library.remove(id:alarm.id)
 let removed=await library.all();XCTAssertTrue(removed.isEmpty)
 await scheduler.failNext()
 do {try await library.add(SavedAlarm(time:alarm.time,mode:.balanced,sound:.system));preconditionFailure("Expected schedule failure")} catch {}
 let failed=await library.all();XCTAssertEqual(failed.last?.state,.needsReview)
 try await library.reconcile()
}
func testCaptureSelectsCompleteCyclesAndDiscardsInterruptedEvidence() {
 var capture=CycleCapture(target:1)
 for (i,angle) in [165.0,120,80,120,165].enumerated() {capture.observe(angle:angle,visible:true,jpeg:Data([UInt8(i+1)]),timestampMs:i*300)}
 XCTAssertEqual(capture.completedReps,1);XCTAssertEqual(capture.frames.count,5);XCTAssertTrue(capture.ready)
 capture.observe(angle:165,visible:true,jpeg:Data([10]),timestampMs:1800)
 XCTAssertEqual(capture.frames.count,5)
 capture.clear();XCTAssertTrue(capture.frames.isEmpty)
 var interrupted=CycleCapture(target:1)
 interrupted.observe(angle:165,visible:true,jpeg:Data([1]),timestampMs:0)
 interrupted.observe(angle:120,visible:true,jpeg:Data([2]),timestampMs:300)
 interrupted.observe(angle:80,visible:false,jpeg:Data([3]),timestampMs:600)
 interrupted.observe(angle:165,visible:true,jpeg:Data([4]),timestampMs:900)
 XCTAssertEqual(interrupted.completedReps,0);XCTAssertTrue(interrupted.frames.isEmpty)
 var oversize=EvidenceBuffer()
 XCTAssertFalse(oversize.append(Data(repeating:1,count:50001),timestampMs:0))
}
func testPersistedTimeCannotBypassValidation() {
 XCTAssertThrowsError(try JSONDecoder().decode(AlarmTime.self,from:Data(#"{"hour":24,"minute":30,"weekdays":[]}"#.utf8)))
}
actor FakeCloud: CloudVerification {
 var continuation:CheckedContinuation<CloudDecision,Error>?
 var started:CheckedContinuation<Void,Never>?
 var cancelled=false
 var creates=0
 func create(target:Int,requestID:UUID) async throws -> CloudSession {creates+=1;return CloudSession(sessionID:String(repeating:"a",count:64),nonce:UUID().uuidString,expiresAt:Date().addingTimeInterval(120).timeIntervalSince1970*1000)}
 func verify(_ request:VerificationSubmission) async throws -> CloudDecision {
  return try await withCheckedThrowingContinuation {continuation=$0;started?.resume();started=nil}
 }
 func waitStarted() async {if continuation != nil {return};await withCheckedContinuation {started=$0}}
 func cancel(sessionID:String) async throws {cancelled=true}
 func release() {continuation?.resume(returning:CloudDecision(status:"verified",decisionID:UUID().uuidString,verifiedRepCount:3));continuation=nil}
}
@MainActor func testCloudStopRaceAndConsent() async throws {
 let cloud=FakeCloud();let scheduler=FakeScheduler()
 let alarm=SavedAlarm(time:try AlarmTime(hour:6,minute:30,weekdays:[]),mode:.balanced)
 let flow=ChallengeCoordinator(alarm:alarm,cloud:cloud,scheduler:scheduler)
 do {try await flow.startCloud(consent:false);preconditionFailure("Consent required")} catch {}
 try await flow.startCloud(consent:true)
 try await flow.startCloud(consent:true)
 let creates=await cloud.creates;XCTAssertEqual(creates,1)
 let evidence=(0..<15).map {EvidenceFrame(jpeg:Data([UInt8($0+1)]),timestampMs:$0*300)}
 let pending=Task {try await flow.submit(evidence)}
 await cloud.waitStarted()
 try await flow.finish(.dismissed)
 await cloud.release()
 let applied=try await pending.value
 XCTAssertFalse(applied);XCTAssertEqual(flow.session.outcome,.dismissed)
 let cancelled=await cloud.cancelled;XCTAssertTrue(cancelled)
 let suspendedCloud=FakeCloud()
 let suspended=ChallengeCoordinator(alarm:alarm,cloud:suspendedCloud,scheduler:scheduler)
 try await suspended.startCloud(consent:true)
 let before=await scheduler.stops
 await suspended.suspend()
 let after=await scheduler.stops
 XCTAssertEqual(before,after);XCTAssertNil(suspended.session.outcome)
 let noCloud=ChallengeCoordinator(alarm:alarm,cloud:nil,scheduler:scheduler)
 do {try await noCloud.startCloud(consent:true);preconditionFailure("Missing backend")} catch {}
 try await noCloud.finish(.selfConfirmed);XCTAssertEqual(noCloud.session.outcome,.selfConfirmed)
}

let suite = CoreTests()
suite.testPresetsAreGentleAndBounded()
try suite.testAlarmValidation()
try suite.testNextWeekdayInVietnamAndOneTimeTomorrow()
try suite.testSpringDSTDoesNotCreatePastAlarm()
suite.testStopInvalidatesPendingResponseAndDoesNotCountAsSuccess()
suite.testLocalCountNeverCompletesCloudChallengeAndDuplicateResultCannotApply()
suite.testFallbackAndSnoozeRemainExplicit()
suite.testInterruptedRepResetsButRetainsCompletedReps()
suite.testNoiseDoesNotCountAndBufferNeverExceedsCap()
try await testNativeLibrary()
testCaptureSelectsCompleteCyclesAndDiscardsInterruptedEvidence()
testPersistedTimeCannotBypassValidation()
try await testCloudStopRaceAndConsent()
print("PASS: 13 portable Swift domain and integration journeys")
