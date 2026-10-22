import Foundation
public struct BackupRing: Codable, Equatable, Sendable {
 public let id:UUID
 public let alarmID:UUID
 public let occurrence:Date
 public let fireDate:Date
 public var needsCancellation:Bool?=nil
 public var sound:AlarmSound?=nil
}
public enum WakeEnforcementPolicy {
 public static let backupInterval:TimeInterval=120
 public static let backupCount=15
 public static let window:TimeInterval=1800
 public static let selfConfirmDelay:TimeInterval=300
}
public struct UnresolvedWake: Equatable, Sendable {
 public let alarmID:UUID
 public let occurrence:Date
 public init(alarmID:UUID,occurrence:Date) {self.alarmID=alarmID;self.occurrence=occurrence}
 public var selfConfirmAvailableAt:Date {occurrence+WakeEnforcementPolicy.selfConfirmDelay}
}
public enum WakePlanner {
 public static func resolves(_ outcome:WakeOutcome)->Bool {outcome != .dismissed}
 public static func liveOccurrence(of alarm:SavedAlarm,entries:[MorningEntry],now:Date,calendar:Calendar,rings:[BackupRing]=[])->Date? {
  guard alarm.enabled,alarm.state != .pending,alarm.state != .off else {return nil}
  let occurrence:Date?
  if alarm.time.weekdays.isEmpty {
   // A clock time alone cannot identify which day a one-time alarm was scheduled.
   occurrence=alarm.scheduledOccurrence ?? rings.first {$0.alarmID==alarm.id}?.occurrence
   guard alarm.state == .confirmed || rings.contains(where:{$0.alarmID==alarm.id && $0.occurrence==occurrence && $0.needsCancellation != true}) else {return nil}
  } else {
   guard alarm.state == .confirmed else {return nil}
   occurrence=alarm.time.next(after:now-WakeEnforcementPolicy.window-1,calendar:calendar)
  }
  guard let o=occurrence,o<=now,now<=o+WakeEnforcementPolicy.window else {return nil}
  return entries.contains {$0.alarmID==alarm.id && $0.date>=o && resolves($0.outcome)} ? nil : o
 }
 public static func plannedOccurrence(of alarm:SavedAlarm,entries:[MorningEntry],now:Date,calendar:Calendar,rings:[BackupRing]=[])->Date? {
  if let live=liveOccurrence(of:alarm,entries:entries,now:now,calendar:calendar,rings:rings) {return live}
  guard alarm.enabled,alarm.state == .confirmed else {return nil}
  if alarm.time.weekdays.isEmpty {
   let occurrence=alarm.scheduledOccurrence ?? rings.first {$0.alarmID==alarm.id}?.occurrence
   return occurrence.flatMap {$0>now ? $0 : nil}
  }
  return alarm.time.next(after:now,calendar:calendar)
 }
 public static func fireDates(for occurrence:Date)->[Date] {
  (1...WakeEnforcementPolicy.backupCount).map {occurrence+Double($0)*WakeEnforcementPolicy.backupInterval}
 }
 public static func unresolvedWake(alarms:[SavedAlarm],entries:[MorningEntry],now:Date,calendar:Calendar,rings:[BackupRing]=[])->UnresolvedWake? {
  alarms.compactMap {alarm in liveOccurrence(of:alarm,entries:entries,now:now,calendar:calendar,rings:rings).map {UnresolvedWake(alarmID:alarm.id,occurrence:$0)}}.min {$0.occurrence<$1.occurrence}
 }
}
public protocol BackupRingScheduler: Sendable {
 func scheduleBackup(_ ring:BackupRing,for alarm:SavedAlarm) async throws
 func cancel(id:UUID) async throws
}
public protocol BackupRingPersistence: Sendable {
 func load() throws -> [BackupRing]
 func save(_ rings:[BackupRing]) throws
}
public struct FileBackupRingPersistence: BackupRingPersistence {
 public let url:URL
 public init(url:URL) {self.url=url}
 public func load() throws -> [BackupRing] {
  guard FileManager.default.fileExists(atPath:url.path) else {return []}
  let data=try Data(contentsOf:url)
  do {return try JSONDecoder().decode([BackupRing].self,from:data)}
  catch {
   let aside=url.deletingPathExtension().appendingPathExtension("corrupt.json")
   try? FileManager.default.removeItem(at:aside)
   try? FileManager.default.moveItem(at:url,to:aside)
   return []
  }
 }
 public func save(_ rings:[BackupRing]) throws {
  try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
  try JSONEncoder().encode(rings).write(to:url,options:.atomic)
 }
}
public struct WakePlanResult: Equatable, Sendable {
 public let scheduled:Int
 public let limited:Bool
}
public actor WakeEnforcer {
 private struct Key:Hashable {let alarmID:UUID;let occurrence:Date;let fireDate:Date;let sound:AlarmSound}
 private var stored:[BackupRing]
 private let persistence:any BackupRingPersistence
 private let scheduler:any BackupRingScheduler
 private var locked=false
 private var waiters:[CheckedContinuation<Void,Never>]=[]
 public init(persistence:any BackupRingPersistence,scheduler:any BackupRingScheduler) throws {
  self.persistence=persistence;self.scheduler=scheduler;stored=try persistence.load()
 }
 public func rings() -> [BackupRing] {stored}
 private func acquire() async {
  guard locked else {locked=true;return}
  await withCheckedContinuation {waiters.append($0)}
 }
 private func release() {
  if waiters.isEmpty {locked=false} else {waiters.removeFirst().resume()}
 }
 @discardableResult public func plan(alarms:[SavedAlarm],entries:[MorningEntry],now:Date,calendar:Calendar) async -> WakePlanResult {
  await acquire();defer {release()}
  var desired:[(alarm:SavedAlarm,key:Key)]=[]
  for alarm in alarms {
   guard let occurrence=WakePlanner.plannedOccurrence(of:alarm,entries:entries,now:now,calendar:calendar,rings:stored) else {continue}
   for fireDate in WakePlanner.fireDates(for:occurrence) where fireDate>now {desired.append((alarm,Key(alarmID:alarm.id,occurrence:occurrence,fireDate:fireDate,sound:alarm.sound)))}
  }
  desired.sort {($0.key.occurrence,$0.key.fireDate)<($1.key.occurrence,$1.key.fireDate)}
  let wanted=Set(desired.map(\.key))
  let cleanupLimited=await drop {$0.needsCancellation == true || !wanted.contains(Key(alarmID:$0.alarmID,occurrence:$0.occurrence,fireDate:$0.fireDate,sound:$0.sound ?? .system))}
  // Do not create replacements while an old or uncertain ring may still be scheduled.
  guard !cleanupLimited else {return WakePlanResult(scheduled:0,limited:true)}
  let have=Set(stored.filter {$0.needsCancellation != true}.map {Key(alarmID:$0.alarmID,occurrence:$0.occurrence,fireDate:$0.fireDate,sound:$0.sound ?? .system)})
  var scheduled=0
  for item in desired where !have.contains(item.key) {
   let ring=BackupRing(id:UUID(),alarmID:item.key.alarmID,occurrence:item.key.occurrence,fireDate:item.key.fireDate,sound:item.alarm.sound)
   stored.append(ring)
   do {try persistence.save(stored)} catch {
    stored.removeAll {$0.id==ring.id}
    return WakePlanResult(scheduled:scheduled,limited:true)
   }
   do {
    try await scheduler.scheduleBackup(ring,for:item.alarm)
    scheduled+=1
   } catch {
    // A thrown schedule can be uncertain. Keep its persisted ID until cancellation succeeds.
    if let index=stored.firstIndex(where:{$0.id==ring.id}) {stored[index].needsCancellation=true;try? persistence.save(stored)}
    _=await drop {$0.id==ring.id}
    return WakePlanResult(scheduled:scheduled,limited:true)
   }
  }
  return WakePlanResult(scheduled:scheduled,limited:cleanupLimited)
 }
 public func resolve(alarmID:UUID) async {
  await acquire();defer {release()}
  _=await drop {$0.alarmID==alarmID}
 }
 private func drop(where shouldDrop:(BackupRing)->Bool) async -> Bool {
  let dropped=stored.filter(shouldDrop)
  guard !dropped.isEmpty else {return false}
  var cancelled=Set<UUID>()
  var limited=false
  for ring in dropped {
   do {try await scheduler.cancel(id:ring.id);cancelled.insert(ring.id)}
   catch {limited=true}
  }
  let before=stored
  stored.removeAll {cancelled.contains($0.id)}
  do {try persistence.save(stored)} catch {
   // Keep the durable IDs in memory too so a later plan retries cleanup.
   stored=before;limited=true
  }
  return limited
 }
}
