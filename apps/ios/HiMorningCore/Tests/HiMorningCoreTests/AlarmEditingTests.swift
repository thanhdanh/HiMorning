import Foundation
#if !PORTABLE_TESTS
import XCTest
@testable import HiMorningCore
#endif

final class AlarmEditingTests:XCTestCase {
 func testEditingEnabledAlarmKeepsIdentityAndReschedulesItsNewSound() async throws {
  let persistence=EditingPersistence(),scheduler=EditingScheduler()
  let library=try AlarmLibrary(persistence:persistence,scheduler:scheduler)
  let original=SavedAlarm(time:try AlarmTime(hour:6,minute:30,weekdays:[2,3,4,5,6]),mode:.balanced,sound:.sunrise)
  try await library.add(original)
  let edited=SavedAlarm(id:original.id,time:try AlarmTime(hour:7,minute:15,weekdays:[1,7]),mode:.gentle,sound:.softChime,challenge:.readAloud)
  try await library.update(edited)
  let alarms=await library.all(),scheduled=await scheduler.scheduled
  XCTAssertEqual(alarms.count,1)
  XCTAssertEqual(alarms.first?.id,original.id)
  XCTAssertEqual(alarms.first?.time,edited.time)
  XCTAssertEqual(alarms.first?.sound,.softChime)
  XCTAssertEqual(alarms.first?.challenge,.readAloud)
  XCTAssertEqual(alarms.first?.state,.confirmed)
  XCTAssertEqual(scheduled.map(\.id),[original.id,original.id])
  XCTAssertEqual(scheduled.last?.sound,.softChime)
  XCTAssertEqual(try persistence.load(),alarms)
 }

 func testEditingDisabledAlarmKeepsItOffWithoutScheduling() async throws {
  let persistence=EditingPersistence(),scheduler=EditingScheduler()
  let library=try AlarmLibrary(persistence:persistence,scheduler:scheduler)
  let original=SavedAlarm(time:try AlarmTime(hour:6,minute:30,weekdays:[]),sound:.sunrise)
  try await library.add(original)
  try await library.disable(id:original.id)
  let edited=SavedAlarm(id:original.id,time:try AlarmTime(hour:8,minute:0,weekdays:[7]),sound:.softChime)
  try await library.update(edited)
  let alarms=await library.all(),scheduled=await scheduler.scheduled,ids=try await scheduler.scheduledIDs()
  XCTAssertEqual(alarms.first?.enabled,false)
  XCTAssertEqual(alarms.first?.state,.off)
  XCTAssertEqual(alarms.first?.sound,.softChime)
  XCTAssertEqual(alarms.first?.time,edited.time)
  XCTAssertEqual(scheduled.count,1)
  XCTAssertTrue(ids.isEmpty)
  XCTAssertEqual(try persistence.load(),alarms)
 }

 func testFailedEditKeepsPreviousSettingsAndCanBeRetried() async throws {
  let persistence=EditingPersistence(),scheduler=EditingScheduler()
  let library=try AlarmLibrary(persistence:persistence,scheduler:scheduler)
  let original=SavedAlarm(time:try AlarmTime(hour:6,minute:30,weekdays:[]),sound:.sunrise)
  try await library.add(original)
  let edited=SavedAlarm(id:original.id,time:original.time,sound:.softChime)
  await scheduler.failNext()
  do {try await library.update(edited);preconditionFailure("Expected schedule failure")} catch {}
  let failed=await library.all()
  XCTAssertEqual(failed.count,1)
  XCTAssertEqual(failed.first?.sound,.sunrise)
  XCTAssertEqual(failed.first?.state,.needsReview)
  XCTAssertEqual(try persistence.load(),failed)
  try await library.update(edited)
  let retried=await library.all()
  XCTAssertEqual(retried.count,1)
  XCTAssertEqual(retried.first?.sound,.softChime)
  XCTAssertEqual(retried.first?.state,.confirmed)
 }

 func testEditPersistenceFailureDoesNotRescheduleOrLoseOriginal() async throws {
  let persistence=EditingPersistence(),scheduler=EditingScheduler()
  let library=try AlarmLibrary(persistence:persistence,scheduler:scheduler)
  let original=SavedAlarm(time:try AlarmTime(hour:6,minute:30,weekdays:[]),sound:.sunrise)
  try await library.add(original)
  let before=await library.all()
  persistence.failNext()
  do {try await library.update(SavedAlarm(id:original.id,time:original.time,sound:.softChime));preconditionFailure("Expected persistence failure")} catch {}
  let after=await library.all(),scheduled=await scheduler.scheduled
  XCTAssertEqual(after,before)
  XCTAssertEqual(scheduled.count,1)
  XCTAssertEqual(try persistence.load(),before)
 }

 func testPersistenceFailureAfterReschedulingKeepsNewSettingsForReview() async throws {
  let persistence=EditingPersistence(),scheduler=EditingScheduler()
  let library=try AlarmLibrary(persistence:persistence,scheduler:scheduler)
  let original=SavedAlarm(time:try AlarmTime(hour:6,minute:30,weekdays:[]),sound:.sunrise)
  try await library.add(original)
  persistence.failAfter(saves:1)
  do {try await library.update(SavedAlarm(id:original.id,time:original.time,sound:.softChime));preconditionFailure("Expected persistence failure")} catch {}
  let alarms=await library.all(),scheduled=await scheduler.scheduled
  XCTAssertEqual(alarms.first?.sound,.softChime)
  XCTAssertEqual(alarms.first?.state,.needsReview)
  XCTAssertEqual(scheduled.last?.sound,.softChime)
  XCTAssertEqual(try persistence.load(),alarms)
 }

 func testEditingUncertainDisabledAlarmDoesNotFalselyConfirmItIsOff() async throws {
  let persistence=EditingPersistence(),scheduler=EditingScheduler()
  var original=SavedAlarm(time:try AlarmTime(hour:6,minute:30,weekdays:[]),sound:.sunrise)
  original.enabled=false;original.state = .needsReview
  try persistence.save([original])
  let library=try AlarmLibrary(persistence:persistence,scheduler:scheduler)
  try await library.update(SavedAlarm(id:original.id,time:original.time,sound:.softChime))
  let alarms=await library.all(),scheduled=await scheduler.scheduled
  XCTAssertEqual(alarms.first?.enabled,false)
  XCTAssertEqual(alarms.first?.state,.needsReview)
  XCTAssertTrue(scheduled.isEmpty)
 }

 func testConcurrentReconcileReportsBusyWhileOriginalCheckFinishesNormally() async throws {
  let scheduler=BlockingReconcileScheduler(),persistence=EditingPersistence()
  let library=try AlarmLibrary(persistence:persistence,scheduler:scheduler)
  let first=Task {try await library.reconcile()}
  await scheduler.waitUntilChecking()
  do {try await library.reconcile();preconditionFailure("Expected in-flight check to report busy")}
  catch LibraryError.busy {}
  await scheduler.finishChecking()
  try await first.value
  let alarms=await library.all()
  XCTAssertTrue(alarms.isEmpty)
  XCTAssertEqual(try persistence.load(),alarms)
 }
}

private actor BlockingReconcileScheduler:AlarmScheduler {
 private var checking=false
 private var started:CheckedContinuation<Void,Never>?
 private var finish:CheckedContinuation<Set<UUID>,Never>?
 func schedule(_ alarm:SavedAlarm) async throws {}
 func cancel(id:UUID) async throws {}
 func stop(id:UUID) async throws {}
 func scheduledIDs() async throws ->Set<UUID> {
  await withCheckedContinuation {finish=$0;checking=true;started?.resume();started=nil}
 }
 func waitUntilChecking() async {if checking {return};await withCheckedContinuation {started=$0}}
 func finishChecking() {finish?.resume(returning:[]);finish=nil}
}

private actor EditingScheduler:AlarmScheduler {
 var scheduled:[SavedAlarm]=[]
 private var ids:Set<UUID>=[]
 private var fail=false
 func failNext() {fail=true}
 func schedule(_ alarm:SavedAlarm) async throws {
  if fail {fail=false;throw DomainError.invalidAlarmTime}
  scheduled.append(alarm);ids.insert(alarm.id)
 }
 func cancel(id:UUID) async throws {ids.remove(id)}
 func stop(id:UUID) async throws {}
 func scheduledIDs() async throws ->Set<UUID> {ids}
}

private final class EditingPersistence:AlarmPersistence,@unchecked Sendable {
 private let lock=NSLock()
 private var alarms:[SavedAlarm]=[]
 private var savesUntilFailure:Int?
 func failNext() {failAfter(saves:0)}
 func failAfter(saves:Int) {lock.lock();defer {lock.unlock()};savesUntilFailure=saves}
 func load() throws ->[SavedAlarm] {lock.lock();defer {lock.unlock()};return alarms}
 func save(_ alarms:[SavedAlarm]) throws {
  lock.lock();defer {lock.unlock()}
  if let remaining=savesUntilFailure {
   if remaining == 0 {savesUntilFailure=nil;throw DomainError.invalidAlarmTime}
   savesUntilFailure=remaining-1
  }
  self.alarms=alarms
 }
}
