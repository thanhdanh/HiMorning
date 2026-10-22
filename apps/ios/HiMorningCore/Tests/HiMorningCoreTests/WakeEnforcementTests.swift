import Foundation
#if !PORTABLE_TESTS
import XCTest
@testable import HiMorningCore
#endif

actor RingSchedulerSpy:BackupRingScheduler {
 private(set) var scheduled:[BackupRing]=[]
 private(set) var cancelled:[UUID]=[]
 private var limit:Int?
 private var cancellationFails=false
 private var uncertainSchedule=false
 func failAfterScheduling(_ value:Bool) {uncertainSchedule=value}
 func failCancellation(_ value:Bool) {cancellationFails=value}
 func failAfter(_ count:Int) {limit=count}
 func scheduleBackup(_ ring:BackupRing,for alarm:SavedAlarm) async throws {
  if let limit,scheduled.count>=limit {throw DomainError.invalidAlarmTime}
  scheduled.append(ring)
  if uncertainSchedule {throw DomainError.invalidAlarmTime}
 }
 func cancel(id:UUID) async throws {if cancellationFails {throw DomainError.invalidAlarmTime};cancelled.append(id)}
}

actor GatedRingScheduler:BackupRingScheduler {
 private(set) var scheduled:[BackupRing]=[]
 private(set) var cancelled:[UUID]=[]
 private var gate:CheckedContinuation<Void,Never>?
 private var armed=true
 var isWaiting:Bool {gate != nil}
 func open() {armed=false;gate?.resume();gate=nil}
 func scheduleBackup(_ ring:BackupRing,for alarm:SavedAlarm) async throws {
  if armed {await withCheckedContinuation {gate=$0}}
  scheduled.append(ring)
 }
 func cancel(id:UUID) async throws {cancelled.append(id)}
}

final class SaveFailingPersistence:BackupRingPersistence,@unchecked Sendable {
 private let lock=NSLock()
 private var saves=0
 private let failFrom:Int
 private let file:FileBackupRingPersistence
 init(url:URL,failFrom:Int) {file=FileBackupRingPersistence(url:url);self.failFrom=failFrom}
 func load() throws -> [BackupRing] {try file.load()}
 func save(_ rings:[BackupRing]) throws {
  lock.lock();saves+=1;let count=saves;lock.unlock()
  if count>=failFrom {throw DomainError.invalidAlarmTime}
  try file.save(rings)
 }
}

final class WakeEnforcementTests:XCTestCase {
 private var calendar:Calendar {
  var calendar=Calendar(identifier:.gregorian)
  calendar.timeZone=TimeZone(identifier:"Asia/Ho_Chi_Minh")!
  return calendar
 }
 private let base=Date(timeIntervalSince1970:1_792_000_000)
 private func alarm(_ hour:Int,_ minute:Int) throws->SavedAlarm {
  var a=SavedAlarm(time:try AlarmTime(hour:hour,minute:minute,weekdays:[]))
  a.state = .confirmed
  a.scheduledOccurrence=a.time.next(after:base,calendar:calendar)
  return a
 }
 private func occurrence(_ alarm:SavedAlarm) throws->Date {try XCTUnwrap(alarm.time.next(after:base,calendar:calendar))}
 private func live(_ alarm:SavedAlarm,_ entries:[MorningEntry]=[],at now:Date)->Date? {
  WakePlanner.liveOccurrence(of:alarm,entries:entries,now:now,calendar:calendar)
 }

 func testFireDatesAreFifteenRingsTwoMinutesApart() throws {
  let o=try occurrence(try alarm(6,30))
  let dates=WakePlanner.fireDates(for:o)
  XCTAssertEqual(dates.count,15)
  XCTAssertEqual(dates.first,o+120)
  XCTAssertEqual(dates.last,o+1800)
  XCTAssertTrue(zip(dates,dates.dropFirst()).allSatisfy {$1.timeIntervalSince($0) == 120})
 }

 func testWindowEdges() throws {
  let a=try alarm(6,30);let o=try occurrence(a)
  XCTAssertNil(live(a,at:o-1))
  XCTAssertEqual(live(a,at:o),o)
  XCTAssertEqual(live(a,at:o+1800),o)
  XCTAssertNil(live(a,at:o+1801))
 }

 func testResolvingOutcomeEndsTheWakeButDismissedDoesNot() throws {
  let a=try alarm(6,30);let o=try occurrence(a)
  func entry(_ outcome:WakeOutcome,at date:Date)->MorningEntry {MorningEntry(alarmID:a.id,date:date,outcome:outcome)}
  XCTAssertNil(live(a,[entry(.localCompleted,at:o+60)],at:o+120))
  XCTAssertNil(live(a,[entry(.selfConfirmed,at:o+60)],at:o+120))
  XCTAssertEqual(live(a,[entry(.dismissed,at:o+60)],at:o+120),o)
  XCTAssertEqual(live(a,[entry(.localCompleted,at:o-60)],at:o+120),o)
 }

 func testInMemoryResolutionEndsWakeAndCancelsBackups() async throws {
  let a=try confirmed(6,30);let o=try occurrence(a)
  let file=tempFile();defer {try? FileManager.default.removeItem(at:file.deletingLastPathComponent())}
  let enforcer=try makeEnforcer(RingSchedulerSpy(),file:file)
  await enforcer.plan(alarms:[a],entries:[],now:o+60,calendar:calendar)
  XCTAssertNotNil(WakePlanner.unresolvedWake(alarms:[a],entries:[],now:o+60,calendar:calendar))
  let resolved=[MorningEntry(alarmID:a.id,date:o+90,outcome:.selfConfirmed)]
  XCTAssertNil(WakePlanner.unresolvedWake(alarms:[a],entries:resolved,now:o+120,calendar:calendar))
  await enforcer.resolve(alarmID:a.id)
  await enforcer.plan(alarms:[a],entries:resolved,now:o+120,calendar:calendar)
  let rings=await enforcer.rings()
  XCTAssertTrue(rings.allSatisfy {$0.occurrence != o})
 }

 func testSelfConfirmAvailableFiveMinutesAfterFirstRing() throws {
  let a=try alarm(6,30);let o=try occurrence(a)
  let wake=WakePlanner.unresolvedWake(alarms:[a],entries:[],now:o+60,calendar:calendar)
  XCTAssertEqual(wake?.selfConfirmAvailableAt,o+300)
 }

 func testOneTimeAlarmWithoutConfirmedScheduleGetsNoFutureBackups() throws {
  var a=try alarm(6,30);a.state = .needsReview
  let o=try occurrence(a)
  XCTAssertNil(WakePlanner.plannedOccurrence(of:a,entries:[],now:o+60,calendar:calendar))
  let ring=BackupRing(id:UUID(),alarmID:a.id,occurrence:o,fireDate:o+120)
  XCTAssertEqual(WakePlanner.liveOccurrence(of:a,entries:[],now:o+60,calendar:calendar,rings:[ring]),o)
  XCTAssertNil(WakePlanner.plannedOccurrence(of:a,entries:[],now:o+86_400+60,calendar:calendar))
  XCTAssertNil(WakePlanner.plannedOccurrence(of:a,entries:[],now:o+1801,calendar:calendar))
 }

 func testEarliestOverlappingWakeWins() throws {
  let first=try alarm(6,30);let second=try alarm(6,40)
  let now=try occurrence(first)+15*60
  let wake=WakePlanner.unresolvedWake(alarms:[second,first],entries:[],now:now,calendar:calendar)
  XCTAssertEqual(wake?.alarmID,first.id)
 }
 private func confirmed(_ hour:Int,_ minute:Int) throws->SavedAlarm {
  var a=try alarm(hour,minute);a.state = .confirmed
  return a
 }
 private func makeEnforcer(_ spy:RingSchedulerSpy,file:URL) throws->WakeEnforcer {
  try WakeEnforcer(persistence:FileBackupRingPersistence(url:file),scheduler:spy)
 }
 private func tempFile() -> URL {
  FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("rings.json")
 }

 func testPlanSchedulesFifteenRingsForNextConfirmedOccurrence() async throws {
  let file=tempFile();defer {try? FileManager.default.removeItem(at:file.deletingLastPathComponent())}
  let spy=RingSchedulerSpy();let enforcer=try makeEnforcer(spy,file:file)
  let result=await enforcer.plan(alarms:[try confirmed(6,30)],entries:[],now:base,calendar:calendar)
  XCTAssertEqual(result,WakePlanResult(scheduled:15,limited:false))
  let scheduled=await spy.scheduled.count;XCTAssertEqual(scheduled,15)
  let rings=await enforcer.rings();XCTAssertEqual(rings.count,15)
 }

 func testSystemDismissalAndRestartKeepOneTimeWakeAndBackupRingsUnresolved() async throws {
  let file=tempFile();defer {try? FileManager.default.removeItem(at:file.deletingLastPathComponent())}
  let spy=RingSchedulerSpy();let enforcer=try makeEnforcer(spy,file:file)
  var a=try confirmed(6,30);let o=try occurrence(a)
  await enforcer.plan(alarms:[a],entries:[],now:o-60,calendar:calendar)
  let before=await enforcer.rings()
  // Reconciliation no longer sees the one-time native alarm after a system Stop.
  a.state = .needsReview
  let entries=[MorningEntry(alarmID:a.id,date:o+10,outcome:.dismissed)]
  let restarted=try makeEnforcer(spy,file:file)
  let result=await restarted.plan(alarms:[a],entries:entries,now:o+60,calendar:calendar)
  XCTAssertEqual(result,WakePlanResult(scheduled:0,limited:false))
  let remaining=await restarted.rings()
  XCTAssertEqual(remaining,before)
  XCTAssertEqual(remaining.first?.fireDate,o+120)
  XCTAssertEqual(WakePlanner.unresolvedWake(alarms:[a],entries:entries,now:o+60,calendar:calendar,rings:remaining)?.alarmID,a.id)
  let cancelled=await spy.cancelled;XCTAssertTrue(cancelled.isEmpty)
  await restarted.resolve(alarmID:a.id)
  let after=await restarted.rings();XCTAssertTrue(after.isEmpty)
 }
 func testPlanIsIdempotentAcrossRestart() async throws {
  let file=tempFile();defer {try? FileManager.default.removeItem(at:file.deletingLastPathComponent())}
  let spy=RingSchedulerSpy();let alarms=[try confirmed(6,30)]
  try await makeEnforcer(spy,file:file).plan(alarms:alarms,entries:[],now:base,calendar:calendar)
  let restarted=try makeEnforcer(spy,file:file)
  let result=await restarted.plan(alarms:alarms,entries:[],now:base,calendar:calendar)
  XCTAssertEqual(result,WakePlanResult(scheduled:0,limited:false))
  let scheduled=await spy.scheduled.count;XCTAssertEqual(scheduled,15)
 }

 func testDisablingAlarmCancelsItsRings() async throws {
  let file=tempFile();defer {try? FileManager.default.removeItem(at:file.deletingLastPathComponent())}
  let spy=RingSchedulerSpy();let enforcer=try makeEnforcer(spy,file:file)
  var a=try confirmed(6,30)
  await enforcer.plan(alarms:[a],entries:[],now:base,calendar:calendar)
  a.enabled=false
  await enforcer.plan(alarms:[a],entries:[],now:base,calendar:calendar)
  let cancelled=await spy.cancelled.count;XCTAssertEqual(cancelled,15)
  let rings=await enforcer.rings();XCTAssertTrue(rings.isEmpty)
 }

 func testResolveCancelsOnlyThatAlarmsRings() async throws {
  let file=tempFile();defer {try? FileManager.default.removeItem(at:file.deletingLastPathComponent())}
  let spy=RingSchedulerSpy();let enforcer=try makeEnforcer(spy,file:file)
  let a=try confirmed(6,30);let b=try confirmed(6,40)
  await enforcer.plan(alarms:[a,b],entries:[],now:base,calendar:calendar)
  await enforcer.resolve(alarmID:a.id)
  let scheduled=await spy.scheduled;let cancelled=await spy.cancelled
  XCTAssertEqual(Set(cancelled),Set(scheduled.filter {$0.alarmID == a.id}.map(\.id)))
  XCTAssertEqual(cancelled.count,15)
  let rings=await enforcer.rings()
  XCTAssertEqual(rings.count,15);XCTAssertTrue(rings.allSatisfy {$0.alarmID == b.id})
 }

 func testLiveWakeKeepsRemainingRingsOnly() async throws {
  let file=tempFile();defer {try? FileManager.default.removeItem(at:file.deletingLastPathComponent())}
  let spy=RingSchedulerSpy();let enforcer=try makeEnforcer(spy,file:file)
  let a=try confirmed(6,30);let o=try occurrence(a)
  await enforcer.plan(alarms:[a],entries:[],now:o-60,calendar:calendar)
  await enforcer.plan(alarms:[a],entries:[],now:o+300,calendar:calendar)
  let rings=await enforcer.rings();XCTAssertEqual(rings.count,13)
  XCTAssertTrue(rings.allSatisfy {$0.fireDate>o+300})
  let scheduled=await spy.scheduled.count;XCTAssertEqual(scheduled,15)
 }

 func testScheduleFailureKeepsEarlierRingsAndReportsLimited() async throws {
  let file=tempFile();defer {try? FileManager.default.removeItem(at:file.deletingLastPathComponent())}
  let spy=RingSchedulerSpy();await spy.failAfter(20)
  let enforcer=try makeEnforcer(spy,file:file)
  let a=try confirmed(6,30);let b=try confirmed(6,40)
  let earlier=try occurrence(a)<=(try occurrence(b)) ? a : b
  let result=await enforcer.plan(alarms:[a,b],entries:[],now:base,calendar:calendar)
  XCTAssertEqual(result,WakePlanResult(scheduled:20,limited:true))
  let rings=await enforcer.rings()
  XCTAssertEqual(rings.count,20)
  XCTAssertEqual(rings.filter {$0.alarmID == earlier.id}.count,15)
  let stored=try FileBackupRingPersistence(url:file).load();XCTAssertEqual(stored.count,20)
 }
 func testCompletedOneTimeAlarmDoesNotPlanTomorrowEvenBeforeReconcile() throws {
  let a=try confirmed(6,30);let o=try occurrence(a)
  let entries=[MorningEntry(alarmID:a.id,date:o+30,outcome:.localCompleted)]
  XCTAssertNil(WakePlanner.plannedOccurrence(of:a,entries:entries,now:o+60,calendar:calendar))
  XCTAssertNil(WakePlanner.liveOccurrence(of:a,entries:[],now:o+86_400+60,calendar:calendar))
 }

 func testUnscheduledAndUnanchoredOneTimeAlarmsDoNotInventWake() throws {
  var a=try alarm(6,30);let o=try occurrence(a)
  a.scheduledOccurrence=nil
  XCTAssertNil(WakePlanner.liveOccurrence(of:a,entries:[],now:o+60,calendar:calendar))
  XCTAssertNil(WakePlanner.plannedOccurrence(of:a,entries:[],now:o-60,calendar:calendar))
  a.scheduledOccurrence=o;a.state = .pending
  XCTAssertNil(WakePlanner.liveOccurrence(of:a,entries:[],now:o+60,calendar:calendar))
 }

 func testChangingSoundReplacesBackupRingsAtTheSameOccurrence() async throws {
  let file=tempFile();defer {try? FileManager.default.removeItem(at:file.deletingLastPathComponent())}
  let spy=RingSchedulerSpy();let enforcer=try makeEnforcer(spy,file:file)
  let a=try confirmed(6,30)
  await enforcer.plan(alarms:[a],entries:[],now:base,calendar:calendar)
  var edited=SavedAlarm(id:a.id,time:a.time,sound:.sunrise,scheduledOccurrence:a.scheduledOccurrence);edited.state = .confirmed
  let changed=await enforcer.plan(alarms:[edited],entries:[],now:base,calendar:calendar)
  XCTAssertEqual(changed.scheduled,15)
  let cancelled=await spy.cancelled;XCTAssertEqual(cancelled.count,15)
  let rings=await enforcer.rings();XCTAssertEqual(rings.count,15)
  XCTAssertTrue(rings.allSatisfy {$0.sound == .sunrise})
 }

 func testUncertainScheduleKeepsItsIDUntilCancellationCanBeRetried() async throws {
  let file=tempFile();defer {try? FileManager.default.removeItem(at:file.deletingLastPathComponent())}
  let spy=RingSchedulerSpy();await spy.failAfterScheduling(true);await spy.failCancellation(true)
  let enforcer=try makeEnforcer(spy,file:file)
  let result=await enforcer.plan(alarms:[try confirmed(6,30)],entries:[],now:base,calendar:calendar)
  XCTAssertTrue(result.limited)
  let retained=await enforcer.rings()
  XCTAssertEqual(retained.count,1);XCTAssertEqual(retained.first?.needsCancellation,true)
  XCTAssertEqual(try FileBackupRingPersistence(url:file).load(),retained)
  let repeated=await enforcer.plan(alarms:[try confirmed(6,30)],entries:[],now:base,calendar:calendar)
  XCTAssertTrue(repeated.limited)
  let scheduled=await spy.scheduled;XCTAssertEqual(scheduled.count,1)
  await spy.failCancellation(false)
  let restarted=try makeEnforcer(spy,file:file)
  let cleaned=await restarted.plan(alarms:[],entries:[],now:base,calendar:calendar)
  XCTAssertFalse(cleaned.limited)
  let remaining=await restarted.rings();XCTAssertTrue(remaining.isEmpty)
 }

 func testFailedCancellationRemainsDurableAndRetriesAfterRestart() async throws {
  let file=tempFile();defer {try? FileManager.default.removeItem(at:file.deletingLastPathComponent())}
  let spy=RingSchedulerSpy();let enforcer=try makeEnforcer(spy,file:file)
  let a=try confirmed(6,30)
  await enforcer.plan(alarms:[a],entries:[],now:base,calendar:calendar)
  await spy.failCancellation(true)
  await enforcer.resolve(alarmID:a.id)
  let retained=await enforcer.rings();XCTAssertEqual(retained.count,15)
  XCTAssertEqual(try FileBackupRingPersistence(url:file).load().count,15)
  let blocked=await enforcer.plan(alarms:[],entries:[],now:base,calendar:calendar)
  XCTAssertTrue(blocked.limited)
  await spy.failCancellation(false)
  let restarted=try makeEnforcer(spy,file:file)
  let retried=await restarted.plan(alarms:[],entries:[],now:base,calendar:calendar)
  XCTAssertFalse(retried.limited)
  let remaining=await restarted.rings();XCTAssertTrue(remaining.isEmpty)
 }

 private func waitUntilBlocked(_ spy:GatedRingScheduler) async throws {
  for _ in 0..<2000 {
   if await spy.isWaiting {return}
   try await Task.sleep(nanoseconds:1_000_000)
  }
  XCTAssertTrue(false)
 }

 func testResolveDuringPlanLeavesNoRingsForThatAlarm() async throws {
  let file=tempFile();defer {try? FileManager.default.removeItem(at:file.deletingLastPathComponent())}
  let spy=GatedRingScheduler();let enforcer=try WakeEnforcer(persistence:FileBackupRingPersistence(url:file),scheduler:spy)
  let a=try confirmed(6,30);let now=base;let cal=calendar
  let planning=Task {await enforcer.plan(alarms:[a],entries:[],now:now,calendar:cal)}
  try await waitUntilBlocked(spy)
  let resolving=Task {await enforcer.resolve(alarmID:a.id)}
  try await Task.sleep(nanoseconds:20_000_000)
  await spy.open()
  _=await planning.value;await resolving.value
  let rings=await enforcer.rings();XCTAssertTrue(rings.isEmpty)
  let scheduled=await spy.scheduled;let cancelled=await spy.cancelled
  XCTAssertEqual(Set(cancelled),Set(scheduled.map(\.id)))
  let stored=try FileBackupRingPersistence(url:file).load();XCTAssertTrue(stored.isEmpty)
 }

 func testConcurrentPlansDoNotDuplicateRings() async throws {
  let file=tempFile();defer {try? FileManager.default.removeItem(at:file.deletingLastPathComponent())}
  let spy=GatedRingScheduler();let enforcer=try WakeEnforcer(persistence:FileBackupRingPersistence(url:file),scheduler:spy)
  let a=try confirmed(6,30);let now=base;let cal=calendar
  let first=Task {await enforcer.plan(alarms:[a],entries:[],now:now,calendar:cal)}
  try await waitUntilBlocked(spy)
  let second=Task {await enforcer.plan(alarms:[a],entries:[],now:now,calendar:cal)}
  try await Task.sleep(nanoseconds:20_000_000)
  await spy.open()
  _=await first.value;_=await second.value
  let scheduled=await spy.scheduled.count;XCTAssertEqual(scheduled,15)
  let rings=await enforcer.rings();XCTAssertEqual(rings.count,15)
 }

 func testCorruptRingFileIsMovedAsideAndEnforcementContinues() async throws {
  let file=tempFile();defer {try? FileManager.default.removeItem(at:file.deletingLastPathComponent())}
  try FileManager.default.createDirectory(at:file.deletingLastPathComponent(),withIntermediateDirectories:true)
  try Data("not json".utf8).write(to:file)
  let spy=RingSchedulerSpy();let enforcer=try makeEnforcer(spy,file:file)
  let before=await enforcer.rings();XCTAssertTrue(before.isEmpty)
  let aside=file.deletingLastPathComponent().appendingPathComponent("rings.corrupt.json")
  XCTAssertTrue(FileManager.default.fileExists(atPath:aside.path))
  let result=await enforcer.plan(alarms:[try confirmed(6,30)],entries:[],now:base,calendar:calendar)
  XCTAssertEqual(result,WakePlanResult(scheduled:15,limited:false))
  let stored=try FileBackupRingPersistence(url:file).load();XCTAssertEqual(stored.count,15)
 }

 func testSaveFailureBeforeSchedulingLeavesNothingScheduledOrStored() async throws {
  let file=tempFile();defer {try? FileManager.default.removeItem(at:file.deletingLastPathComponent())}
  let spy=RingSchedulerSpy()
  let enforcer=try WakeEnforcer(persistence:SaveFailingPersistence(url:file,failFrom:1),scheduler:spy)
  let result=await enforcer.plan(alarms:[try confirmed(6,30)],entries:[],now:base,calendar:calendar)
  XCTAssertEqual(result,WakePlanResult(scheduled:0,limited:true))
  let scheduled=await spy.scheduled.count;XCTAssertEqual(scheduled,0)
  let rings=await enforcer.rings();XCTAssertTrue(rings.isEmpty)
 }

 func testScheduleFailureLeavesStoredEqualToScheduled() async throws {
  let file=tempFile();defer {try? FileManager.default.removeItem(at:file.deletingLastPathComponent())}
  let spy=RingSchedulerSpy();await spy.failAfter(3)
  let enforcer=try makeEnforcer(spy,file:file)
  let result=await enforcer.plan(alarms:[try confirmed(6,30)],entries:[],now:base,calendar:calendar)
  XCTAssertEqual(result,WakePlanResult(scheduled:3,limited:true))
  let scheduled=await spy.scheduled.map(\.id);let rings=await enforcer.rings().map(\.id)
  let stored=try FileBackupRingPersistence(url:file).load().map(\.id)
  XCTAssertEqual(Set(rings),Set(scheduled));XCTAssertEqual(Set(stored),Set(scheduled))
  XCTAssertEqual(stored.count,3)
 }

 func testLaterSaveFailureDoesNotOrphanTheRingThatWasNotPersisted() async throws {
  let file=tempFile();defer {try? FileManager.default.removeItem(at:file.deletingLastPathComponent())}
  let spy=RingSchedulerSpy()
  let enforcer=try WakeEnforcer(persistence:SaveFailingPersistence(url:file,failFrom:4),scheduler:spy)
  let result=await enforcer.plan(alarms:[try confirmed(6,30)],entries:[],now:base,calendar:calendar)
  XCTAssertEqual(result,WakePlanResult(scheduled:3,limited:true))
  let scheduled=await spy.scheduled.map(\.id);let rings=await enforcer.rings().map(\.id)
  XCTAssertEqual(Set(rings),Set(scheduled));XCTAssertEqual(scheduled.count,3)
 }
}
