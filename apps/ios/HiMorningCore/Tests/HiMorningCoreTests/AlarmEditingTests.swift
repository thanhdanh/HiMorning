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
  await scheduler.expectSchedule(original)
  try await library.add(original)
  let edited=SavedAlarm(id:original.id,time:try AlarmTime(hour:7,minute:15,weekdays:[1,7]),mode:.gentle,sound:.softChime,challenge:.readAloud)
  await scheduler.expectSchedule(edited)
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
  let events=await scheduler.events,cancelled=await scheduler.cancelled
  XCTAssertEqual(events,["schedule:sunrise","cancel","schedule:softChime"])
  XCTAssertEqual(cancelled,[original.id])
  XCTAssertEqual(try persistence.load(),alarms)
 }

 func testEditingEnabledChallengePersistsWithoutNativeScheduling() async throws {
  let persistence=EditingPersistence(),scheduler=EditingScheduler()
  var original=SavedAlarm(time:try AlarmTime(hour:6,minute:30,weekdays:[2,3,4,5,6]),mode:.balanced,sound:.sunrise)
  original.state = .confirmed
  try persistence.save([original])
  let library=try AlarmLibrary(persistence:persistence,scheduler:scheduler)
  var edited=SavedAlarm(id:original.id,time:original.time,mode:original.mode,sound:original.sound,challenge:.readAloud)
  edited.enabled=false;edited.state = .off
  try await library.update(edited)
  edited.enabled=true;edited.state = .confirmed
  let alarms=await library.all(),attempts=await scheduler.attempts
  XCTAssertEqual(alarms,[edited])
  XCTAssertTrue(attempts.isEmpty)
  let cancelled=await scheduler.cancelled
  XCTAssertTrue(cancelled.isEmpty)
  XCTAssertEqual(try persistence.load(),alarms)
  let restarted=try AlarmLibrary(persistence:persistence,scheduler:scheduler)
  let restored=await restarted.all()
  XCTAssertEqual(restored,alarms)
 }

 func testEditingChallengeParametersPersistsWithoutNativeScheduling() async throws {
  let selections:[(ChallengeSelection,ChallengeSelection)]=[
   (.pushUps(repetitions:3),.pushUps(repetitions:5)),
   (.guidedRhythm(variant:.standing),.guidedRhythm(variant:.seated))
  ]
  for (previous,updated) in selections {
   let persistence=EditingPersistence(),scheduler=EditingScheduler()
   var original=SavedAlarm(time:try AlarmTime(hour:6,minute:30,weekdays:[]),sound:.sunrise,challenge:previous)
   original.state = .confirmed
   try persistence.save([original])
   let library=try AlarmLibrary(persistence:persistence,scheduler:scheduler)
   var edited=SavedAlarm(id:original.id,time:original.time,mode:original.mode,sound:original.sound,challenge:updated)
   try await library.update(edited)
   edited.state = .confirmed
   let alarms=await library.all(),attempts=await scheduler.attempts
   XCTAssertEqual(alarms,[edited])
   XCTAssertTrue(attempts.isEmpty)
  let cancelled=await scheduler.cancelled
  XCTAssertTrue(cancelled.isEmpty)
   XCTAssertEqual(try persistence.load(),alarms)
  }
 }

 func testEditingModeKeepsExplicitChallengeWithoutNativeScheduling() async throws {
  let persistence=EditingPersistence(),scheduler=EditingScheduler()
  var original=SavedAlarm(time:try AlarmTime(hour:6,minute:30,weekdays:[]),mode:.gentle,sound:.sunrise,challenge:.readAloud)
  original.state = .confirmed
  try persistence.save([original])
  let library=try AlarmLibrary(persistence:persistence,scheduler:scheduler)
  var edited=SavedAlarm(id:original.id,time:original.time,mode:.focused,sound:original.sound,challenge:original.challenge)
  try await library.update(edited)
  edited.state = .confirmed
  let alarms=await library.all(),attempts=await scheduler.attempts
  XCTAssertEqual(alarms,[edited])
  XCTAssertTrue(attempts.isEmpty)
  let cancelled=await scheduler.cancelled
  XCTAssertTrue(cancelled.isEmpty)
  XCTAssertEqual(try persistence.load(),alarms)
 }

 func testSavingUnchangedAlarmDoesNotTouchNativeSchedule() async throws {
  let persistence=EditingPersistence(),scheduler=EditingScheduler()
  var original=SavedAlarm(time:try AlarmTime(hour:6,minute:30,weekdays:[]),mode:.balanced,sound:.sunrise)
  original.state = .confirmed
  try persistence.save([original])
  let library=try AlarmLibrary(persistence:persistence,scheduler:scheduler)
  try await library.update(SavedAlarm(id:original.id,time:original.time,mode:original.mode,sound:original.sound,challenge:original.challenge))
  let alarms=await library.all(),attempts=await scheduler.attempts
  XCTAssertEqual(alarms,[original])
  XCTAssertTrue(attempts.isEmpty)
  let cancelled=await scheduler.cancelled
  XCTAssertTrue(cancelled.isEmpty)
  XCTAssertEqual(try persistence.load(),alarms)
 }

 func testEditingChallengePreservesUncertainNativeState() async throws {
  for state in [ScheduleState.needsReview,.pending] {
   let persistence=EditingPersistence(),scheduler=EditingScheduler()
   var original=SavedAlarm(time:try AlarmTime(hour:6,minute:30,weekdays:[]),mode:.balanced,sound:.sunrise)
   original.state=state
   try persistence.save([original])
   let library=try AlarmLibrary(persistence:persistence,scheduler:scheduler)
   var edited=SavedAlarm(id:original.id,time:original.time,mode:original.mode,sound:original.sound,challenge:.readAloud)
   try await library.update(edited)
   edited.state=state
   let alarms=await library.all(),attempts=await scheduler.attempts
   XCTAssertEqual(alarms,[edited])
   XCTAssertTrue(attempts.isEmpty)
  let cancelled=await scheduler.cancelled
  XCTAssertTrue(cancelled.isEmpty)
   XCTAssertEqual(try persistence.load(),alarms)
  }
 }

 func testChallengeEditPersistenceFailureRollsBackWithoutNativeScheduling() async throws {
  let persistence=EditingPersistence(),scheduler=EditingScheduler()
  var original=SavedAlarm(time:try AlarmTime(hour:6,minute:30,weekdays:[]),mode:.balanced,sound:.sunrise)
  original.state = .confirmed
  try persistence.save([original])
  let library=try AlarmLibrary(persistence:persistence,scheduler:scheduler)
  let edited=SavedAlarm(id:original.id,time:original.time,mode:original.mode,sound:original.sound,challenge:.readAloud)
  persistence.failNext()
  do {try await library.update(edited);preconditionFailure("Expected persistence failure")} catch {}
  let alarms=await library.all(),attempts=await scheduler.attempts
  XCTAssertEqual(alarms,[original])
  XCTAssertTrue(attempts.isEmpty)
  let cancelled=await scheduler.cancelled
  XCTAssertTrue(cancelled.isEmpty)
  XCTAssertEqual(try persistence.load(),alarms)
 }

 func testEditingOnlyTimeStillReschedulesNativeAlarm() async throws {
  let persistence=EditingPersistence(),scheduler=EditingScheduler()
  let library=try AlarmLibrary(persistence:persistence,scheduler:scheduler)
  let original=SavedAlarm(time:try AlarmTime(hour:6,minute:30,weekdays:[]),sound:.sunrise,challenge:.readAloud)
  await scheduler.expectSchedule(original)
  try await library.add(original)
  let edited=SavedAlarm(id:original.id,time:try AlarmTime(hour:7,minute:15,weekdays:[2,3,4,5,6]),mode:original.mode,sound:original.sound,challenge:original.challenge)
  await scheduler.expectSchedule(edited)
  try await library.update(edited)
  let alarms=await library.all(),scheduled=await scheduler.scheduled
  XCTAssertEqual(alarms.first?.state,.confirmed)
  XCTAssertEqual(alarms.first?.time,edited.time)
  XCTAssertEqual(scheduled.map(\.time),[original.time,edited.time])
  XCTAssertEqual(try persistence.load(),alarms)
 }

 func testEditingDisabledAlarmKeepsItOffWithoutScheduling() async throws {
  let persistence=EditingPersistence(),scheduler=EditingScheduler()
  let library=try AlarmLibrary(persistence:persistence,scheduler:scheduler)
  let original=SavedAlarm(time:try AlarmTime(hour:6,minute:30,weekdays:[]),sound:.sunrise)
  await scheduler.expectSchedule(original)
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
  let cancelled=await scheduler.cancelled
  XCTAssertEqual(cancelled,[original.id])
  XCTAssertTrue(ids.isEmpty)
  XCTAssertEqual(try persistence.load(),alarms)
 }

 func testFailedEditKeepsPreviousSettingsAndCanBeRetried() async throws {
  let persistence=EditingPersistence(),scheduler=EditingScheduler()
  let library=try AlarmLibrary(persistence:persistence,scheduler:scheduler)
  let original=SavedAlarm(time:try AlarmTime(hour:6,minute:30,weekdays:[]),sound:.sunrise)
  await scheduler.expectSchedule(original)
  try await library.add(original)
  let edited=SavedAlarm(id:original.id,time:original.time,sound:.softChime)
  await scheduler.expectSchedule(edited)
  await scheduler.failNext()
  var restored=original;restored.state = .confirmed
  await scheduler.expectSchedule(restored)
  do {try await library.update(edited);preconditionFailure("Expected schedule failure")} catch {}
  let failed=await library.all()
  XCTAssertEqual(failed.count,1)
  XCTAssertEqual(failed.first?.sound,.sunrise)
  XCTAssertEqual(failed.first?.state,.needsReview)
  XCTAssertEqual(try persistence.load(),failed)
  let restoredEvents=await scheduler.events,restoredIDs=try await scheduler.scheduledIDs()
  XCTAssertEqual(restoredEvents,["schedule:sunrise","cancel","schedule:softChime","cancel","schedule:sunrise"])
  XCTAssertEqual(restoredIDs,[original.id])
  await scheduler.expectSchedule(edited)
  try await library.update(edited)
  let retried=await library.all()
  XCTAssertEqual(retried.count,1)
  XCTAssertEqual(retried.first?.sound,.softChime)
  XCTAssertEqual(retried.first?.state,.confirmed)
 }

 func testCancellationFailureKeepsWorkingAlarmAndDoesNotTryReplacement() async throws {
  let persistence=EditingPersistence(),scheduler=EditingScheduler()
  let library=try AlarmLibrary(persistence:persistence,scheduler:scheduler)
  let original=SavedAlarm(time:try AlarmTime(hour:6,minute:30,weekdays:[]),sound:.sunrise)
  await scheduler.expectSchedule(original);try await library.add(original)
  await scheduler.failCancellation()
  do {try await library.update(SavedAlarm(id:original.id,time:original.time,sound:.softChime));preconditionFailure("Expected cancellation failure")} catch {}
  let alarms=await library.all(),events=await scheduler.events,ids=try await scheduler.scheduledIDs()
  XCTAssertEqual(alarms.first?.sound,.sunrise);XCTAssertEqual(alarms.first?.state,.needsReview)
  XCTAssertEqual(events,["schedule:sunrise","cancel"]);XCTAssertEqual(ids,[original.id])
  XCTAssertEqual(try persistence.load(),alarms)
 }

 func testReplacementAndRestoreFailurePreservesPreviousSettingsForReview() async throws {
  let persistence=EditingPersistence(),scheduler=EditingScheduler()
  let library=try AlarmLibrary(persistence:persistence,scheduler:scheduler)
  let original=SavedAlarm(time:try AlarmTime(hour:6,minute:30,weekdays:[]),sound:.sunrise)
  await scheduler.expectSchedule(original);try await library.add(original)
  let edited=SavedAlarm(id:original.id,time:original.time,sound:.softChime)
  var restored=original;restored.state = .confirmed
  await scheduler.expectSchedule(edited);await scheduler.expectSchedule(restored)
  await scheduler.failNext(count:2)
  do {try await library.update(edited);preconditionFailure("Expected scheduling failure")} catch {}
  let alarms=await library.all(),events=await scheduler.events,ids=try await scheduler.scheduledIDs()
  XCTAssertEqual(alarms.first?.sound,.sunrise);XCTAssertEqual(alarms.first?.state,.needsReview)
  XCTAssertEqual(events,["schedule:sunrise","cancel","schedule:softChime","cancel","schedule:sunrise"])
  XCTAssertTrue(ids.isEmpty);XCTAssertEqual(try persistence.load(),alarms)
 }

 func testEditPersistenceFailureDoesNotRescheduleOrLoseOriginal() async throws {
  let persistence=EditingPersistence(),scheduler=EditingScheduler()
  let library=try AlarmLibrary(persistence:persistence,scheduler:scheduler)
  let original=SavedAlarm(time:try AlarmTime(hour:6,minute:30,weekdays:[]),sound:.sunrise)
  await scheduler.expectSchedule(original)
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
  await scheduler.expectSchedule(original)
  try await library.add(original)
  let edited=SavedAlarm(id:original.id,time:original.time,sound:.softChime)
  await scheduler.expectSchedule(edited)
  persistence.failAfter(saves:1)
  do {try await library.update(edited);preconditionFailure("Expected persistence failure")} catch {}
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

private enum EditingSchedulerError:Error {case unexpectedSchedule}

private actor EditingScheduler:AlarmScheduler {
 var scheduled:[SavedAlarm]=[]
 var attempts:[SavedAlarm]=[]
 var events:[String]=[]
 var cancelled:[UUID]=[]
 private var expected:[SavedAlarm]=[]
 private var ids:Set<UUID>=[]
 private var failures=0
 private var cancellationFails=false
 func expectSchedule(_ alarm:SavedAlarm) {expected.append(alarm)}
 func failNext(count:Int=1) {failures=count}
 func failCancellation() {cancellationFails=true}
 func schedule(_ alarm:SavedAlarm) async throws {
  attempts.append(alarm);events.append("schedule:\(alarm.sound.rawValue)")
  guard !expected.isEmpty,expected.removeFirst() == alarm else {throw EditingSchedulerError.unexpectedSchedule}
  if failures>0 {failures-=1;throw DomainError.invalidAlarmTime}
  guard !ids.contains(alarm.id) else {throw EditingSchedulerError.unexpectedSchedule}
  scheduled.append(alarm);ids.insert(alarm.id)
 }
 func cancel(id:UUID) async throws {events.append("cancel");cancelled.append(id);if cancellationFails {cancellationFails=false;throw DomainError.invalidAlarmTime};ids.remove(id)}
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
