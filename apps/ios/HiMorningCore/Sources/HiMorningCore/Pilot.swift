import Foundation
public enum AlarmSound: String, Codable, CaseIterable, Sendable {
 case system,sunrise,softChime
 case pizzicatoDawn,pizzicatoSteps,pizzicatoRise,pizzicatoBloom
 case steelShimmer,steelBreeze,steelMorning,steelSparkle
 case saxHello,saxStroll,saxGlow,saxDaybreak
 case brightKeys,pixelMorning,brassRise
 case glassChime,woodPluck,softBong
}
public enum ScheduleState: String, Codable, Sendable {case pending,confirmed,off,needsReview}
public struct AlarmChallengeTrial: Codable, Equatable, Sendable {
 public let id:UUID
 public let challenge:ChallengeSelection
 public let occurrence:Date

 public init(id:UUID,challenge:ChallengeSelection,occurrence:Date) {
  self.id=id;self.challenge=challenge;self.occurrence=occurrence
 }
}

public struct SavedAlarm: Codable, Equatable, Identifiable, Sendable {
 public let id:UUID
 public let time:AlarmTime
 public let mode:WakeMode
 public let sound:AlarmSound
 public let challenge:ChallengeSelection
 public var enabled:Bool
 public var state:ScheduleState
 public var label:String
 public var scheduledOccurrence:Date?
 public var challengeTrial:AlarmChallengeTrial?
 public init(id:UUID=UUID(),time:AlarmTime,mode:WakeMode = .gentle,sound:AlarmSound = .system,challenge:ChallengeSelection?=nil,label:String="",scheduledOccurrence:Date?=nil) {
  self.id=id;self.time=time;self.mode=mode;self.sound=sound;self.challenge=challenge ?? .legacyDefault(for:mode);self.label=label.trimmingCharacters(in:.whitespacesAndNewlines);self.scheduledOccurrence=scheduledOccurrence;enabled=true;state = .pending
 }
 private enum CodingKeys:String,CodingKey {case id,time,mode,sound,challenge,enabled,state,label,scheduledOccurrence,challengeTrial}
 public init(from decoder:Decoder) throws {
  let values=try decoder.container(keyedBy:CodingKeys.self)
  id=try values.decode(UUID.self,forKey:.id)
  time=try values.decode(AlarmTime.self,forKey:.time)
  mode=try values.decode(WakeMode.self,forKey:.mode)
  sound=try values.decode(AlarmSound.self,forKey:.sound)
  if let saved=try values.decodeIfPresent(ChallengeSelection.self,forKey:.challenge) {challenge=saved}
  else {
   // Alarms predating explicit challenges retain their original mode target.
   switch mode {case .gentle:challenge = .none;case .balanced:challenge = .pushUps(repetitions:3);case .focused:challenge = .pushUps(repetitions:5)}
  }
  enabled=try values.decode(Bool.self,forKey:.enabled)
  state=try values.decode(ScheduleState.self,forKey:.state)
  label=(try values.decodeIfPresent(String.self,forKey:.label) ?? "").trimmingCharacters(in:.whitespacesAndNewlines)
  scheduledOccurrence=try values.decodeIfPresent(Date.self,forKey:.scheduledOccurrence)
  challengeTrial=try values.decodeIfPresent(AlarmChallengeTrial.self,forKey:.challengeTrial)
 }
 public var hasChallengeIntent:Bool {challenge.kind != .none || challengeTrial != nil}
 public func hasChallenge(at occurrence:Date)->Bool {
  challenge.kind != .none || challengeTrial?.occurrence == occurrence
 }
}
public enum AlarmScheduleError: Error {case accessDenied}

public protocol AlarmScheduler: Sendable {
 func authorizeScheduling() async throws
 func schedule(_ alarm:SavedAlarm) async throws
 func cancel(id:UUID) async throws
 func stop(id:UUID) async throws
 func scheduledIDs() async throws -> Set<UUID>
}
public extension AlarmScheduler {
 func authorizeScheduling() async throws {}
}

public protocol AlarmPersistence: Sendable {
 func load() throws -> [SavedAlarm]
 func save(_ alarms:[SavedAlarm]) throws
}
public struct FileAlarmPersistence: AlarmPersistence {
 public let url:URL
 public init(url:URL) {self.url=url}
 public func load() throws -> [SavedAlarm] {
  guard FileManager.default.fileExists(atPath:url.path) else {return []}
  return try JSONDecoder().decode([SavedAlarm].self,from:Data(contentsOf:url))
 }
 public func save(_ alarms:[SavedAlarm]) throws {
  try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
  try JSONEncoder().encode(alarms).write(to:url,options:.atomic)
 }
}
public enum LibraryError: Error {case busy,duplicate,notFound}
public actor AlarmLibrary {
 private var alarms:[SavedAlarm]
 private let persistence:any AlarmPersistence
 private let scheduler:any AlarmScheduler
 private var busy=false
 public init(persistence:any AlarmPersistence,scheduler:any AlarmScheduler) throws {
  self.persistence=persistence;self.scheduler=scheduler;alarms=try persistence.load()
 }
 public func all() -> [SavedAlarm] {alarms}
 public func add(_ alarm:SavedAlarm) async throws {
  guard !busy else {throw LibraryError.busy}
  guard !alarms.contains(where:{$0.id==alarm.id}) else {throw LibraryError.duplicate}
  busy=true;defer {busy=false}
  try await scheduler.authorizeScheduling()
  var pending=alarm;pending.state = .pending;pending.enabled=true;pending.scheduledOccurrence=pending.time.weekdays.isEmpty ? pending.time.next(after:Date(),calendar:.current) : nil
  let before=alarms;alarms.append(pending)
  do {try persistence.save(alarms)} catch {alarms=before;throw error}
  do {
   try await scheduler.schedule(pending)
   alarms[alarms.count-1].state = .confirmed
   try persistence.save(alarms)
  } catch {
   alarms[alarms.count-1].state = .needsReview
   try? persistence.save(alarms)
   throw error
  }
 }
 public func update(_ alarm:SavedAlarm) async throws {
  guard !busy else {throw LibraryError.busy}
  guard let index=alarms.firstIndex(where:{$0.id==alarm.id}) else {throw LibraryError.notFound}
  busy=true;defer {busy=false}
  let previous=alarms[index]
  let nativeScheduleChanged=alarm.time != previous.time || alarm.sound != previous.sound || alarm.hasChallengeIntent != previous.hasChallengeIntent
  if previous.enabled,nativeScheduleChanged {try await scheduler.authorizeScheduling()}
  var replacement=alarm;replacement.enabled=previous.enabled;replacement.state=previous.state
  if nativeScheduleChanged {
   replacement.state=previous.enabled ? .pending : previous.state == .off ? .off : .needsReview
   let now=Date()
   let previousFutureRing=previous.scheduledOccurrence.flatMap {$0>now ? $0 : nil}
   if replacement.time.weekdays.isEmpty {
    replacement.scheduledOccurrence=(replacement.time == previous.time ? previousFutureRing : nil)
     ?? replacement.time.next(after:now,calendar:.current)
   } else {
    replacement.scheduledOccurrence=nil
   }
  } else {
   replacement.scheduledOccurrence=previous.scheduledOccurrence
  }
  alarms[index]=replacement
  do {try persistence.save(alarms)} catch {alarms[index]=previous;throw error}
  guard replacement.enabled,nativeScheduleChanged else {return}
  do {try await scheduler.cancel(id:previous.id)} catch {
   alarms[index]=previous;alarms[index].state = .needsReview
   try? persistence.save(alarms)
   throw error
  }
  do {try await scheduler.schedule(replacement)} catch {
   // AlarmKit cannot replace an existing ID; recover its old schedule after a failed edit.
   try? await scheduler.cancel(id:previous.id)
   try? await scheduler.schedule(previous)
   alarms[index]=previous;alarms[index].state = .needsReview
   try? persistence.save(alarms)
   throw error
  }
  alarms[index].state = .confirmed
  do {try persistence.save(alarms)} catch {
   alarms[index].state = .needsReview;try? persistence.save(alarms)
   throw error
  }
 }
 public func enable(id:UUID) async throws {
  guard !busy else {throw LibraryError.busy}
  guard let index=alarms.firstIndex(where:{$0.id==id}) else {throw LibraryError.notFound}
  busy=true;defer {busy=false}
  try await scheduler.authorizeScheduling()
  let before=alarms;alarms[index].enabled=true;alarms[index].state = .pending;alarms[index].scheduledOccurrence=alarms[index].time.weekdays.isEmpty ? alarms[index].time.next(after:Date(),calendar:.current) : nil
  do {try persistence.save(alarms)} catch {alarms=before;throw error}
  do {
   if before[index].state == .needsReview,try await scheduler.scheduledIDs().contains(id) {
    try await scheduler.cancel(id:id)
   }
   try await scheduler.schedule(alarms[index])
   alarms[index].state = .confirmed
   try persistence.save(alarms)
  }
  catch {alarms[index].state = .needsReview;try? persistence.save(alarms);throw error}
 }
 public func remove(id:UUID) async throws {
  try await disable(id:id)
  guard !busy else {throw LibraryError.busy}
  let before=alarms;alarms.removeAll(where:{$0.id==id})
  do {try persistence.save(alarms)} catch {alarms=before;throw error}
 }
 public func disable(id:UUID) async throws {
  guard !busy else {throw LibraryError.busy}
  guard let index=alarms.firstIndex(where:{$0.id==id}) else {throw LibraryError.notFound}
  busy=true;defer {busy=false}
  let before=alarms;alarms[index].enabled=false;alarms[index].state = .pending
  do {try persistence.save(alarms)} catch {alarms=before;throw error}
  do {try await scheduler.cancel(id:id);alarms[index].state = .off;try persistence.save(alarms)}
  catch {alarms[index].state = .needsReview;try? persistence.save(alarms);throw error}
 }
 public func reconcile() async throws {
  guard !busy else {throw LibraryError.busy}
  busy=true;defer {busy=false}
  let ids=try await scheduler.scheduledIDs()
  let previous=alarms
  for i in alarms.indices {
   if alarms[i].enabled {
    if ids.contains(alarms[i].id) {alarms[i].state = .confirmed}
    else if !alarms[i].hasChallengeIntent,alarms[i].state == .confirmed,
            alarms[i].time.weekdays.isEmpty,let occurrence=alarms[i].scheduledOccurrence,occurrence<=Date() {
     alarms[i].enabled=false;alarms[i].state = .off
    } else {alarms[i].state = .needsReview}
   }
   else {alarms[i].state=ids.contains(alarms[i].id) ? .needsReview : .off}
  }
  do {try persistence.save(alarms)} catch {alarms=previous;throw error}
 }
}
// Five selected phases per complete cycle; no video archive and no partial-cycle upload.
public struct CycleCapture: Sendable {
 private enum Phase:Sendable {case top,descending,bottom,ascending,end}
 private var phase:Phase = .top
 private var cycle:[EvidenceFrame]=[]
 private var buffer=EvidenceBuffer()
 private let target:Int
 public private(set) var completedReps=0
 public var frames:[EvidenceFrame] {buffer.frames}
 public var ready:Bool {completedReps>=target}
 public init(target:Int) {self.target=min(ChallengeSelection.maximumPushUps,max(1,target))}
 public mutating func interrupt() {phase = .top;cycle.removeAll(keepingCapacity:false)}
 public mutating func clear() {interrupt();completedReps=0;buffer.clear()}
 public mutating func observe(angle:Double,visible:Bool,jpeg:Data,timestampMs:Int) {
  guard !ready else {return}
  guard visible,angle.isFinite,(0...180).contains(angle),!jpeg.isEmpty,jpeg.count<=50000,(0...EvidenceBuffer.maximumDurationMs).contains(timestampMs) else {interrupt();return}
  if let last=cycle.last, timestampMs-last.timestampMs<120 {return}
  let matches:Bool
  switch phase {
  case .top:matches=angle>=160
  case .descending:matches=(100...150).contains(angle)
  case .bottom:matches=angle<=90
  case .ascending:matches=(100...150).contains(angle)
  case .end:matches=angle>=160
  }
  guard matches else {return}
  cycle.append(EvidenceFrame(jpeg:jpeg,timestampMs:timestampMs))
  switch phase {
  case .top:phase = .descending
  case .descending:phase = .bottom
  case .bottom:phase = .ascending
  case .ascending:phase = .end
  case .end:
   var candidate=buffer
   for frame in cycle {guard candidate.append(frame.jpeg,timestampMs:frame.timestampMs) else {interrupt();return}}
   buffer=candidate;completedReps+=1;interrupt()
  }
 }
}
