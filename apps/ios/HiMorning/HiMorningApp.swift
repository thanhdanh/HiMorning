import SwiftUI
import Combine
import FirebaseCore
import FirebaseAppCheck
import HiMorningCore
import WidgetKit
import ActivityKit
@main struct HiMorningApp:App {
 @StateObject private var model=PilotModel()
 @AppStorage("appLanguage") private var language="system"
 @State private var showSplash = !ProcessInfo.processInfo.arguments.contains("--ui-testing") || ProcessInfo.processInfo.arguments.contains("--ui-splash")
 @Environment(\.accessibilityReduceMotion) private var reduceMotion
 var body:some Scene {
  WindowGroup {
   ZStack {
    HomeView(model:model)
    if showSplash {
     MorningSplashView()
      .transition(reduceMotion ? .opacity : .opacity.combined(with:.scale(scale:1.03)))
      .zIndex(1)
    }
   }
   .task {
    guard showSplash else {return}
    let keepOpen=ProcessInfo.processInfo.arguments.contains("--ui-splash-hold")
    guard !keepOpen else {return}
    try? await Task.sleep(for:.seconds(0.65))
    withAnimation(reduceMotion ? .linear(duration:0.15) : .easeOut(duration:0.35)) {
     showSplash=false
    }
   }
   .environment(\.locale,Locale(identifier:(AppLanguage(rawValue:language) ?? .system).resolved(preferredLanguages:Locale.preferredLanguages)))
  }
 }
}
enum AlarmSaveError:Error {case soundUnavailable,challengeUnavailable,trialUnavailable,trialAlarmOff}
struct ChallengeCredit:Codable,Equatable {
 let id:UUID
 let challenge:ChallengeSelection
}
#if DEBUG
struct NoopBackupScheduler:BackupRingScheduler {
 func scheduleBackup(_ ring:BackupRing,for alarm:SavedAlarm) async throws {}
 func cancel(id:UUID) async throws {}
}
#endif
@MainActor final class PilotModel:ObservableObject {
 @Published var alarms:[SavedAlarm]=[]
 @Published var hasLoadedAlarms=false
 @Published var togglingAlarms:[UUID:Bool]=[:]
 @Published var error:String?
 @Published var selected:SavedAlarm?
 @Published var rehearsal=false
 @Published var challengeAfterPractice:ChallengeSelection?
 @Published var backupWarning=false
 @Published var activeWake:UnresolvedWake?
 let subscriptions=SubscriptionStore()
 let rewardedAds=RewardedAdStore()
 private var savingAlarm=false
 private var challengeCredits:[ChallengeCredit]=[]
 private let creditDefaultsKey="rewardedChallengeCredits-v1"
 @Published var journey=JourneyStore()
 let bedtime=BedtimeAnchorStore()
 private var journeyObserver:AnyCancellable?
 lazy var preview=PreviewStore(subscriptions:subscriptions)
 private var accessObserver:AnyCancellable?
 var access:MorningAccess {preview.access}
 @Published var journal:MorningJournal?
 @Published var progressError:String?
 @Published var celebrationID:UUID?
 let scheduler=NativeAlarmScheduler()
 let cloud:(any CloudVerification)?
 private let library:AlarmLibrary?
 let enforcer:WakeEnforcer?
 private var resolvedWakes:[MorningEntry]=[]
 private var plannedRings:[BackupRing]=[]
 @Published var content:ChallengeContentStore
 private(set) var contentHistory:ContentHistory
 private let bundledContent:ChallengeContentPack
 private let refresher:ChallengeContentRefresher
 init() {
  if let data=UserDefaults.standard.data(forKey:creditDefaultsKey) {
   challengeCredits=(try? JSONDecoder().decode([ChallengeCredit].self,from:data)) ?? []
  }
  let workerEndpoint:WorkerEndpoint?
  if let configURL=Bundle.main.url(forResource:"HiMorningCloud-Info",withExtension:"plist"),let data=try? Data(contentsOf:configURL),let values=try? PropertyListDecoder().decode([String:String].self,from:data),let origin=values["WorkerURL"] {workerEndpoint=try? WorkerEndpoint(origin)}
  else {workerEndpoint=nil}
  if Bundle.main.url(forResource:"GoogleService-Info",withExtension:"plist") != nil {
   AppCheck.setAppCheckProviderFactory(AttestationFactory());FirebaseApp.configure()
   cloud=workerEndpoint.map {FirebaseCloud(endpoint:$0)}
  } else {cloud=nil}
  let support=(try? FileManager.default.url(for:.applicationSupportDirectory,in:.userDomainMask,appropriateFor:nil,create:true)) ?? FileManager.default.temporaryDirectory
  let refresher=ChallengeContentRefresher(origin:workerEndpoint?.url,directory:support)
  self.refresher=refresher
  let bundled=Bundle.main.url(forResource:"challenge-content",withExtension:"json").flatMap {try? Data(contentsOf:$0)}.flatMap {try? JSONDecoder().decode(ChallengeContentPack.self,from:$0)} ?? ChallengeContentPack(version:0,generatedAt:"",items:[])
  bundledContent=bundled
  content=ChallengeContentStore(bundled:bundled,cached:refresher.cachedPack())
  contentHistory=UserDefaults.standard.data(forKey:"contentHistory").flatMap {try? JSONDecoder().decode(ContentHistory.self,from:$0)} ?? ContentHistory()
  do {
   var url=try FileManager.default.url(for:.applicationSupportDirectory,in:.userDomainMask,appropriateFor:nil,create:true).appendingPathComponent("HiMorning/alarms.json")
   #if DEBUG
   if ProcessInfo.processInfo.arguments.contains("--ui-testing"),ProcessInfo.processInfo.arguments.contains("--ui-empty-home") {url=FileManager.default.temporaryDirectory.appendingPathComponent("himorning-empty-\(UUID().uuidString).json")}
   if ProcessInfo.processInfo.arguments.contains("--ui-testing"),ProcessInfo.processInfo.arguments.contains("--ui-disabled-alarm") || ProcessInfo.processInfo.arguments.contains("--ui-enabled-alarm") || ProcessInfo.processInfo.arguments.contains("--ui-home-alarms") {
    url=FileManager.default.temporaryDirectory.appendingPathComponent("himorning-ui-edit-alarm.json")
    var fixture=SavedAlarm(id:UUID(uuidString:"00000000-0000-0000-0000-000000000001")!,time:try AlarmTime(hour:7,minute:15,weekdays:[2,4,6]),mode:.balanced,sound:.sunrise,challenge:.guidedRhythm(variant:.seated))
    fixture.enabled=ProcessInfo.processInfo.arguments.contains("--ui-enabled-alarm");fixture.state = fixture.enabled ? .confirmed : .off
    var fixtures=[fixture]
    if ProcessInfo.processInfo.arguments.contains("--ui-home-alarms") {
     fixture=SavedAlarm(id:fixture.id,time:fixture.time,mode:.balanced,challenge:.readAndChoose);fixture.state = .confirmed
     var upcoming=SavedAlarm(id:UUID(uuidString:"00000000-0000-0000-0000-000000000002")!,time:try AlarmTime(hour:20,minute:30,weekdays:[2,4,6]),mode:.focused,challenge:.readAloud);upcoming.state = .confirmed
     var disabled=SavedAlarm(id:UUID(uuidString:"00000000-0000-0000-0000-000000000003")!,time:try AlarmTime(hour:9,minute:0,weekdays:[]));disabled.enabled=false;disabled.state = .off
     if ProcessInfo.processInfo.arguments.contains("--ui-card-layout") {
      fixture=SavedAlarm(id:fixture.id,time:fixture.time,mode:.focused,challenge:.pushUps(repetitions:50),label:"Morning routine before work")
      fixture.state = .confirmed
      upcoming=SavedAlarm(id:upcoming.id,time:try AlarmTime(hour:20,minute:30,weekdays:[]),mode:.balanced,challenge:.readAndChoose)
      upcoming.state = .needsReview
     }
     if ProcessInfo.processInfo.arguments.contains("--ui-movement-cards") {
      fixture=SavedAlarm(id:fixture.id,time:fixture.time,mode:.focused,challenge:.pushUps(repetitions:10));fixture.state = .confirmed
      upcoming=SavedAlarm(id:upcoming.id,time:upcoming.time,mode:.gentle,challenge:.none);upcoming.state = .confirmed
     }
     if ProcessInfo.processInfo.arguments.contains("--ui-card-repeat") {
      fixture=SavedAlarm(id:fixture.id,time:try AlarmTime(hour:7,minute:15,weekdays:[4]),mode:.balanced,challenge:.readAndChoose);fixture.state = .confirmed
      upcoming=SavedAlarm(id:upcoming.id,time:try AlarmTime(hour:20,minute:30,weekdays:[4,5,6]),mode:.focused,challenge:.readAloud);upcoming.state = .confirmed
      let tomorrow=Calendar.current.date(byAdding:.day,value:1,to:Calendar.current.startOfDay(for:Date()))!
      let occurrence=Calendar.current.date(bySettingHour:9,minute:0,second:0,of:tomorrow)!
      disabled=SavedAlarm(id:disabled.id,time:disabled.time,scheduledOccurrence:occurrence);disabled.state = .confirmed
     }
     if ProcessInfo.processInfo.arguments.contains("--ui-elapsed-once") {
      upcoming=SavedAlarm(id:upcoming.id,time:try AlarmTime(hour:20,minute:30,weekdays:[]),mode:.balanced,challenge:.readAndChoose,scheduledOccurrence:Date().addingTimeInterval(-60))
      upcoming.state = .confirmed
     }
     fixtures=[fixture,upcoming,disabled]
     if ProcessInfo.processInfo.arguments.contains("--ui-open-alarm") {UserDefaults.standard.set(fixture.id.uuidString,forKey:"pendingAlarmID")}
    }
    try FileAlarmPersistence(url:url).save(fixtures)
   }
   #endif
   library=try AlarmLibrary(persistence:FileAlarmPersistence(url:url),scheduler:scheduler)
  } catch {library=nil;self.error=appText("Your saved alarms could not be read. Changes are paused.")}
  do {
   var url=try FileManager.default.url(for:.applicationSupportDirectory,in:.userDomainMask,appropriateFor:nil,create:true).appendingPathComponent("HiMorning/backup-rings.json")
   #if DEBUG
   if ProcessInfo.processInfo.arguments.contains("--ui-testing") {url=FileManager.default.temporaryDirectory.appendingPathComponent("himorning-ui-backup-rings-\(UUID().uuidString).json")}
   #endif
   var backupScheduler:any BackupRingScheduler=scheduler
   #if DEBUG
   if ProcessInfo.processInfo.arguments.contains("--ui-testing") {backupScheduler=NoopBackupScheduler()}
   #endif
   enforcer=try WakeEnforcer(persistence:FileBackupRingPersistence(url:url),scheduler:backupScheduler)
  } catch {enforcer=nil;self.error=appText("Backup rings are unavailable right now. Your main alarms still work.")}
  do {
   var url=try FileManager.default.url(for:.applicationSupportDirectory,in:.userDomainMask,appropriateFor:nil,create:true).appendingPathComponent("HiMorning/mornings.json")
   #if DEBUG
   if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
    url=FileManager.default.temporaryDirectory.appendingPathComponent("morning-test-\(UUID().uuidString).json")
    if ProcessInfo.processInfo.arguments.contains("--ui-progress-read-error") {try Data("broken".utf8).write(to:url)}
   }
   #endif
   journal=try MorningJournal(url:url)
   #if DEBUG
   if ProcessInfo.processInfo.arguments.contains("--ui-testing"),ProcessInfo.processInfo.arguments.contains("--ui-progress-save-error") {
    try FileManager.default.createDirectory(at:url,withIntermediateDirectories:true)
   }
   if ProcessInfo.processInfo.arguments.contains("--ui-testing"),ProcessInfo.processInfo.arguments.contains("--ui-completed-alarm") {
    try journal?.record(MorningEntry(alarmID:UUID(uuidString:"00000000-0000-0000-0000-000000000001")!,mode:.balanced,challenge:.readAndChoose,outcome:.localCompleted))
   }
   if ProcessInfo.processInfo.arguments.contains("--ui-testing"),ProcessInfo.processInfo.arguments.contains("--ui-progress-fixture") {
    let now=Date(),calendar=Calendar.current
    let outcomes:[WakeOutcome]=[.localCompleted,.localCompleted,.selfConfirmed,.openaiVerified,.localCompleted,.localCompleted,.localCompleted]
    let modes:[WakeMode]=[.gentle,.balanced,.gentle,.focused,.balanced,.focused,.focused]
    let challenges:[ChallengeSelection]=[.readAndChoose,.readAloud,.guidedRhythm(variant:.seated),.pushUps(repetitions:5),.readAndChoose,.readAloud,.pushUps(repetitions:5)]
    for (index,outcome) in outcomes.enumerated() where index != 1 {
     if let date=calendar.date(byAdding:.day,value:index == 2 ? -6 : index-6,to:calendar.startOfDay(for:now)) {
      try journal?.record(MorningEntry(mode:index == 0 ? nil : modes[index],challenge:index == 0 ? nil : challenges[index],date:date,outcome:outcome),now:now)
     }
    }
    if let date=calendar.date(byAdding:.day,value:-2,to:calendar.startOfDay(for:now)) {
     try journal?.record(MorningEntry(mode:.gentle,date:date,outcome:.dismissed),now:now)
    }
   }
   #endif
  } catch {progressError=appText("Your progress could not be read. Your alarms are unchanged.")}
  #if DEBUG
  if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
   UserDefaults.standard.set(ProcessInfo.processInfo.arguments.contains("--ui-language-vi") ? "vi" : "en",forKey:"appLanguage")
   var period=PreviewPeriod()
   if ProcessInfo.processInfo.arguments.contains("--preview-expired") {period.start(now:Date().addingTimeInterval(-31*86_400))}
   let data=try? JSONEncoder().encode(period)
   preview=PreviewStore(subscriptions:subscriptions,load:{data},save:{_ in})
  }
  #endif
  #if DEBUG
  if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
   journey=JourneyStore(load:{nil},save:{_ in})
   if ProcessInfo.processInfo.arguments.contains("--ui-journey-fixture") {
    let now=Date(),calendar=Calendar.current
    _=journey.choose(.clearStart,access:.free,now:calendar.date(byAdding:.day,value:-45,to:now)!)
    let count=ProcessInfo.processInfo.arguments.contains("--ui-journey-complete") ? 7 : 3
    for index in 0..<count {
     let offset=ProcessInfo.processInfo.arguments.contains("--ui-journey-today") ? index-count+1 : index-count-2
     let day=calendar.date(byAdding:.day,value:offset,to:now)!
     _=journey.record(date:day,outcome:.localCompleted,rehearsal:false,now:now)
    }
   }
  }
  #endif
  journeyObserver=journey.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
  accessObserver=preview.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
 }
 func practice(_ kind:ChallengeKind) {
  guard kind != .none else {return}
  practiceMission(kind == .pushUps ? .pushUps(repetitions:kind.localMovementTarget ?? 10) : ChallengeSelection(kind:kind))
 }
 func practiceMission(_ selection:ChallengeSelection) {
  guard let time=try? AlarmTime(hour:6,minute:30,weekdays:[]) else {return}
  rehearsal=true;selected=SavedAlarm(time:time,mode:selection.kind.preferredMode,challenge:selection)
 }
 func nextPrompt(_ kind:ContentKind)->ChallengeContentItem? {
  let language=appLocale().identifier
  #if DEBUG
  let args=ProcessInfo.processInfo.arguments
  if args.contains("--ui-testing"),let index=args.firstIndex(of:"--ui-content-id"),args.indices.contains(index+1),
     let fixture=content.items(kind:kind,language:kind.promptLanguage(language)).first(where:{$0.id==args[index+1]}) {return fixture}
  #endif
  let item=content.next(kind:kind,language:language,history:&contentHistory)
  if let data=try? JSONEncoder().encode(contentHistory) {UserDefaults.standard.set(data,forKey:"contentHistory")}
  return item
 }
 func refreshContent() async {
  guard selected == nil,let fresh=await refresher.refreshIfDue() else {return}
  content=ChallengeContentStore(bundled:bundledContent,cached:fresh)
 }
 func recordMorning(id:UUID,alarm:SavedAlarm,outcome:WakeOutcome,rehearsal:Bool) {
  if !rehearsal,WakePlanner.resolves(outcome) {
   resolvedWakes.append(MorningEntry(alarmID:alarm.id,outcome:outcome))
   activeWake=nil
   Task {await enforcer?.resolve(alarmID:alarm.id);await clearExpiredChallengeTrials(completedAlarmID:alarm.id);await replanBackups()}
   if outcome != .selfConfirmed,bedtime.settings.healthSyncEnabled {
    Task {await MorningHealthSync.recordMorningWin(completedAt:Date())}
   }
  }
  guard journal != nil else {return}
  do {
   let now=Date()
   if try journal?.record(MorningEntry(id:id,alarmID:alarm.id,mode:alarm.mode,challenge:alarm.challenge,date:now,outcome:outcome),rehearsal:rehearsal) == true {
    journey.record(date:now,outcome:outcome,rehearsal:rehearsal,now:now)
   }
  }
  catch {progressError=appText("Your progress could not be saved. Your alarm is already stopped.")}
 }
 private func wakeEntries(now:Date=Date())->[MorningEntry] {
  resolvedWakes.removeAll{now.timeIntervalSince($0.date)>2*86_400}
  return (journal?.recent(days:2,now:now) ?? [])+resolvedWakes
 }
 func replanBackups() async {
  guard let enforcer else {return}
  let result=await enforcer.plan(alarms:alarms,entries:wakeEntries(),now:Date(),calendar:.current)
  backupWarning=result.limited
  plannedRings=await enforcer.rings()
 }
 func setGoal(_ goal:Int) {
  guard access.hasFullAccess,journal != nil else {return}
  do {try journal?.setWeeklyGoal(goal);progressError=nil}
  catch {progressError=appText("Your goal could not be saved. Please try again.")}
 }
 func syncWidgetSnapshot(now:Date=Date()) {
  let upcoming:(alarm:SavedAlarm,date:Date)? = alarms.filter(\.enabled).compactMap { alarm in
   guard let next = alarm.time.next(after: now, calendar: .current) else { return nil }
   return (alarm, next)
  }.min { $0.date < $1.date }

  let snapshot = MorningWidgetSnapshot(
   nextAlarmTime: upcoming?.date,
   challengeTitle: upcoming?.alarm.challenge.displayTitle,
   modeTitle: upcoming?.alarm.mode.title,
   journeyCompleted: journey.journey?.completedCount ?? 0,
   journeyTotal: 7,
   updatedAt: now
  )
  MorningWidgetStore.save(snapshot)
  WidgetCenter.shared.reloadAllTimelines()
  syncLiveActivity(upcoming: upcoming, now: now)
 }
 private func syncLiveActivity(upcoming:(alarm:SavedAlarm,date:Date)?,now:Date) {
  guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
  guard let upcoming, upcoming.date.timeIntervalSince(now) <= 12 * 3600 else {
   Task {
    for activity in Activity<MorningAlarmAttributes>.activities {
     await activity.end(nil, dismissalPolicy: .immediate)
    }
   }
   return
  }
  let state = MorningAlarmAttributes.ContentState(wakeTime: upcoming.date, completed: false)
  if let existing = Activity<MorningAlarmAttributes>.activities.first {
   Task { await existing.update(ActivityContent(state: state, staleDate: upcoming.date.addingTimeInterval(3600))) }
  } else {
   let attrs = MorningAlarmAttributes(challengeTitle: upcoming.alarm.challenge.displayTitle, modeTitle: upcoming.alarm.mode.title)
   _ = try? Activity.request(attributes: attrs, content: ActivityContent(state: state, staleDate: upcoming.date.addingTimeInterval(3600)), pushType: nil)
  }
 }
 func refresh() async {
  guard let library else {return}
  #if DEBUG
  // Presentation fixtures have no native schedules to reconcile.
  if ProcessInfo.processInfo.arguments.contains("--ui-testing"),ProcessInfo.processInfo.arguments.contains("--ui-home-alarms") {
   alarms=await library.all()
  hasLoadedAlarms=true;openPending();return
  }
  #endif
  do {try await library.reconcile()}
  catch LibraryError.busy {return}
  catch {self.error=appText("Your alarms could not be checked. Please check alarm access.")}
  alarms=await library.all()
  hasLoadedAlarms=true
  if alarms.contains(where:{$0.state == .confirmed}) {preview.start()} else {preview.refresh()}
  let assignedCreditIDs=Set(alarms.compactMap { $0.state == .confirmed ? $0.challengeTrial?.id : nil })
  if challengeCredits.contains(where:{assignedCreditIDs.contains($0.id)}) {
   challengeCredits.removeAll {assignedCreditIDs.contains($0.id)}
   persistChallengeCredits()
  }
  await clearExpiredChallengeTrials()
  await replanBackups()
  syncWidgetSnapshot()
  openPending()
  #if DEBUG
  if ProcessInfo.processInfo.arguments.contains("--ui-testing") {return}
  #endif
  if selected == nil,let wake=WakePlanner.unresolvedWake(alarms:alarms,entries:wakeEntries(),now:Date(),calendar:.current,rings:plannedRings),let alarm=alarms.first(where:{$0.id==wake.alarmID}) {
   activeWake=wake;rehearsal=false;selected=alarm
  }
 }
 func challengeCredit(for kind:ChallengeKind)->ChallengeCredit? {
  challengeCredits.first {credit in
   credit.challenge.kind == kind && !alarms.contains {$0.challengeTrial?.id == credit.id}
  }
 }
 func earnChallengeCredit(_ credit:ChallengeCredit) {
  guard challengeCredit(for:credit.challenge.kind) == nil else {return}
  challengeCredits.append(credit)
  persistChallengeCredits()
 }
 private func persistChallengeCredits() {
  if let data=try? JSONEncoder().encode(challengeCredits) {
   UserDefaults.standard.set(data,forKey:creditDefaultsKey)
  }
 }
 func save(_ alarm:SavedAlarm,credit:ChallengeCredit?=nil,removeTrial:Bool=false) async throws {
  guard !savingAlarm else {throw LibraryError.busy}
  savingAlarm=true;defer {savingAlarm=false}
  #if DEBUG
  if ProcessInfo.processInfo.arguments.contains("--ui-testing"),ProcessInfo.processInfo.arguments.contains("--ui-alarm-save-failure") {
   try await Task.sleep(for:.seconds(2));throw LibraryError.notFound
  }
  #endif
  guard let library else {throw LibraryError.notFound}
  #if DEBUG
  if ProcessInfo.processInfo.arguments.contains("--ui-testing"),ProcessInfo.processInfo.arguments.contains("--ui-sound-access-expires") {
   var period=PreviewPeriod();period.start(now:Date().addingTimeInterval(-31*86_400))
   let data=try JSONEncoder().encode(period)
   preview=PreviewStore(subscriptions:subscriptions,load:{data},save:{_ in})
  }
  #endif
  preview.refresh()
  let existing=await library.all()
  let previous=existing.first {$0.id==alarm.id}
  guard access.allows(sound:alarm.sound) else {throw AlarmSaveError.soundUnavailable}
  guard access.allows(challenge:alarm.challenge) || (alarm.challenge == previous?.challenge && alarm.mode == previous?.mode) else {throw AlarmSaveError.challengeUnavailable}
  var candidate=alarm
  let now=Date()
  let previousTrial=removeTrial ? nil : previous?.challengeTrial
  let unchangedSchedule=previous?.time == alarm.time
  if unchangedSchedule {candidate.challengeTrial=previousTrial}
  if let credit {
   guard previous?.enabled != false else {throw AlarmSaveError.trialAlarmOff}
   guard challengeCredits.contains(credit),!existing.contains(where:{$0.id != alarm.id && $0.challengeTrial?.id == credit.id}) else {throw AlarmSaveError.trialUnavailable}
   if previousTrial?.id == credit.id,unchangedSchedule,let previousTrial,previousTrial.occurrence>now {
    candidate.challengeTrial=previousTrial
   } else {
    let fixed=unchangedSchedule ? previous?.scheduledOccurrence : nil
    guard fixed.map({$0>now}) ?? true,let occurrence=fixed ?? alarm.time.next(after:now) else {
     throw AlarmSaveError.trialUnavailable
    }
    candidate.challengeTrial=AlarmChallengeTrial(id:credit.id,challenge:credit.challenge,occurrence:occurrence)
   }
  } else if !unchangedSchedule,let previousTrial,previousTrial.occurrence>now,
            let occurrence=alarm.time.next(after:now) {
   candidate.challengeTrial=AlarmChallengeTrial(id:previousTrial.id,challenge:previousTrial.challenge,occurrence:occurrence)
  }
  do {
   if previous != nil {
    try await library.update(candidate)
    if let saved=await library.all().first(where:{$0.id==alarm.id}),saved.enabled,saved.state == .needsReview {
     try await library.enable(id:saved.id)
    }
   } else {try await library.add(candidate)}
   if let credit {
    challengeCredits.removeAll {$0.id==credit.id}
    persistChallengeCredits()
   }
   alarms=await library.all()
  hasLoadedAlarms=true
   if alarms.contains(where:{$0.state == .confirmed}) {preview.start()}
   syncWidgetSnapshot()
   await replanBackups()
  } catch {alarms=await library.all();throw error}
 }
 func requestToggle(_ alarm:SavedAlarm) {
  guard togglingAlarms[alarm.id] == nil else {return}
  let targetEnabled = !(alarm.enabled && alarm.state == .confirmed)
  togglingAlarms[alarm.id]=targetEnabled
  Task {await toggle(alarm,targetEnabled:targetEnabled)}
 }
 func toggle(_ alarm:SavedAlarm,targetEnabled:Bool?=nil) async {
  guard let library else {togglingAlarms.removeValue(forKey:alarm.id);return}
  let enable=targetEnabled ?? !(alarm.enabled && alarm.state == .confirmed)
  togglingAlarms[alarm.id]=enable
  defer {togglingAlarms.removeValue(forKey:alarm.id)}
  do {if enable {try await library.enable(id:alarm.id)} else {try await library.disable(id:alarm.id)}}
  catch AlarmScheduleError.accessDenied {self.error=appText("Alarm wasn’t scheduled. Allow alarms for HiMorning in Settings.")}
  catch {self.error=appText("Alarm schedule unconfirmed") }
  alarms=await library.all()
  hasLoadedAlarms=true
  await replanBackups()
 }
 func retryTurningOff(_ alarm:SavedAlarm) async {
  guard let library else {return}
  do {try await library.disable(id:alarm.id)} catch {self.error=appText("Alarm schedule unconfirmed")}
  alarms=await library.all()
  hasLoadedAlarms=true
  await replanBackups()
 }
 func remove(_ alarm:SavedAlarm) async {
  guard let library else {return}
  do {try await library.remove(id:alarm.id)} catch {self.error=appText("This alarm could not be removed. It may still be set in the system.")}
  alarms=await library.all()
  hasLoadedAlarms=true
  await replanBackups()
 }
 private func clearExpiredChallengeTrials(completedAlarmID:UUID?=nil) async {
  guard let library,!savingAlarm else {return}
  savingAlarm=true;defer {savingAlarm=false}
  let now=Date()
  for alarm in await library.all() where !alarm.time.weekdays.isEmpty {
   guard let trial=alarm.challengeTrial,
         trial.occurrence+WakeEnforcementPolicy.window<now || (alarm.id == completedAlarmID && trial.occurrence<=now) else {continue}
   var cleared=alarm
   cleared.challengeTrial=nil
   try? await library.update(cleared)
  }
  alarms=await library.all()
  hasLoadedAlarms=true
 }
 func openPending() {
  guard let raw=UserDefaults.standard.string(forKey:"pendingAlarmID"),let id=UUID(uuidString:raw),let alarm=alarms.first(where:{$0.id==id}) else {return}
  UserDefaults.standard.removeObject(forKey:"pendingAlarmID");rehearsal=false
  activeWake=WakePlanner.liveOccurrence(of:alarm,entries:wakeEntries(),now:Date(),calendar:.current,rings:plannedRings).map {UnresolvedWake(alarmID:alarm.id,occurrence:$0)}
  if alarm.challenge.kind != .none || activeWake != nil {selected=alarm}
 }
}
extension WakeMode {
 var title:String {switch self {case .gentle:return appText("Gentle");case .balanced:return appText("Balanced");case .focused:return appText("Challenging")}}
 var icon:String {switch self {case .gentle:return "leaf.fill";case .balanced:return "sun.max.fill";case .focused:return "bolt.fill"}}
}
extension AlarmSound {
 var title:String {switch self {
  case .system:return appText("System sound")
  case .sunrise:return appText("Sunrise")
  case .softChime:return appText("Soft chime")
  case .pizzicatoDawn:return appText("Pizzicato dawn")
  case .pizzicatoSteps:return appText("Pizzicato steps")
  case .pizzicatoRise:return appText("Pizzicato rise")
  case .pizzicatoBloom:return appText("Pizzicato bloom")
  case .steelShimmer:return appText("Steel shimmer")
  case .steelBreeze:return appText("Steel breeze")
  case .steelMorning:return appText("Steel morning")
  case .steelSparkle:return appText("Steel sparkle")
  case .saxHello:return appText("Sax hello")
  case .saxStroll:return appText("Sax stroll")
  case .saxGlow:return appText("Sax glow")
  case .saxDaybreak:return appText("Sax daybreak")
  case .brightKeys:return appText("Bright keys")
  case .pixelMorning:return appText("Pixel morning")
  case .brassRise:return appText("Brass rise")
  case .glassChime:return appText("Glass chime")
  case .woodPluck:return appText("Wood pluck")
  case .softBong:return appText("Soft bell")
 }}
 static var groups:[(title:String,sounds:[AlarmSound])] {[
  (appText("Classic"),[.system,.sunrise,.softChime]),
  (appText("Plucked strings"),[.pizzicatoDawn,.pizzicatoSteps,.pizzicatoRise,.pizzicatoBloom]),
  (appText("Steel pan"),[.steelShimmer,.steelBreeze,.steelMorning,.steelSparkle]),
  (appText("Saxophone"),[.saxHello,.saxStroll,.saxGlow,.saxDaybreak]),
  (appText("Short melodies"),[.brightKeys,.pixelMorning,.brassRise]),
  (appText("Sound effects"),[.glassChime,.woodPluck,.softBong])
 ]}
}
extension ChallengeKind {
 var practiceTitle:String {
  if self == .readAloud {return title + " · " + appText("Microphone")}
  if self == .pushUps || self == .guidedRhythm || self == .morningLight || usesLocalMovement {return title + " · " + appText("Camera")}
  return title
 }
 var editorIdentifier:String {switch self {case .none:return "none";case .pushUps:return "pushUps";case .readAndChoose:return "readAndChoose";case .guidedRhythm:return "guidedRhythm";case .readAloud:return "readAloud";case .waveHand:return "waveHand";case .neckRotation:return "neckRotation";case .riddle:return "riddle";case .jumpingJacks:return "jumpingJacks";case .stretching:return "stretching";case .morningLight:return "morningLight"}}
 var title:String {switch self {case .none:return appText("No challenge");case .pushUps:return appText("Push-ups");case .readAndChoose:return appText("Read & Choose");case .guidedRhythm:return appText("Guided Rhythm");case .readAloud:return appText("Read Aloud");case .waveHand:return appText("Wave hello");case .neckRotation:return appText("Neck turns");case .riddle:return appText("Riddle");case .jumpingJacks:return appText("Jumping jacks");case .stretching:return appText("Reach up");case .morningLight:return appText("Morning light")}}
 var summary:String {switch self {
  case .none:return appText("Confirm you are awake when you are ready.")
  case .pushUps:return appText("Complete a short camera-checked movement challenge.")
  case .readAndChoose:return appText("Read one short sentence and choose its meaning.")
  case .guidedRhythm:return appText("Follow a simple standing or seated rhythm on camera.")
  case .readAloud:return appText("Read the English passage aloud and see which words match as you go.")
  case .waveHand:return appText("Hold your hand in view and wave it side to side.")
  case .neckRotation:return appText("Face the camera and turn your head left and right.")
  case .riddle:return appText("Solve a short riddle in your language.")
  case .jumpingJacks:return appText("Complete 10 gentle jumping jacks. Checked on this device.")
  case .stretching:return appText("Raise both hands above your shoulders, then lower them.")
  case .morningLight:return appText("Point your camera toward a bright window or lamp.")
 }}
 var icon:String {switch self {case .none:return "bell.badge.slash.fill";case .pushUps:return "figure.strengthtraining.traditional";case .readAndChoose:return "doc.text.magnifyingglass";case .guidedRhythm:return "figure.mind.and.body";case .readAloud:return "waveform.badge.mic";case .waveHand:return "hand.wave.fill";case .neckRotation:return "person.crop.circle.badge.checkmark";case .riddle:return "puzzlepiece.extension.fill";case .jumpingJacks:return "figure.mixed.cardio";case .stretching:return "figure.flexibility";case .morningLight:return "sun.horizon.fill"}}
}
extension ChallengeSelection {
 var displayTitle:String {
  if kind == .pushUps,let repetitions {return appText("%lld push-ups",count:repetitions)}
  if kind == .guidedRhythm {return rhythmVariant == .seated ? appText("Guided Rhythm · Seated") : appText("Guided Rhythm · Standing")}
  return kind.title
 }
}
extension ScheduleState {
 var title:String {switch self {case .pending:return appText("Checking…");case .confirmed:return appText("Alarm is set");case .off:return appText("Off");case .needsReview:return appText("Alarm schedule unconfirmed")}}
}
struct HomeView:View {
 @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
 private struct AlarmDraft:Identifiable {let id=UUID();let alarm:SavedAlarm?;var scope:AlarmEditorScope = .all;var suggestedChallenge:ChallengeSelection?}
 @ObservedObject var model:PilotModel
 @Environment(\.dynamicTypeSize) private var dynamicTypeSize
 @Environment(\.scenePhase) private var phase
 @Environment(\.accessibilityReduceMotion) private var reduceMotion
 @State private var editor:AlarmDraft?
 @State private var revealedAlarmID:UUID?
 @State private var alarmToDelete:SavedAlarm?
 @State private var progress=false
 @State private var pro=false
 @State private var choosingPurpose=false
 @State private var proAfterPurpose=false
 @State private var exploringChallenges=false
 @State private var showingBedtime=false
 @AppStorage("appLanguage") private var language="system"
 @ScaledMetric(relativeTo:.largeTitle) private var clockSize=48
 var body:some View {
  NavigationStack {
   ScrollView {
    VStack(alignment:.leading,spacing:14) {
     HStack(spacing:8) {
      Label {
       Text("HiMorning.").modifier(MorningTypography.wordmark)
        .lineLimit(1).minimumScaleFactor(0.75)
      } icon: {
       Image(systemName:"sunrise").font(.system(size:20,weight:.bold))
      }.labelStyle(.titleAndIcon)
       .fixedSize(horizontal:true,vertical:true).accessibilityLabel("Hi Morning")
      Spacer(minLength:4)
      GlassEffectContainer(spacing:8) {
      HStack(spacing:6) {
      Button {showingBedtime=true} label:{Image(systemName:"moon.stars").frame(width:44,height:44).glassEffect(.regular.interactive(),in:.circle).contentShape(Rectangle())}
       .buttonStyle(.plain)
       .accessibilityIdentifier("bedtimeAnchor").accessibilityLabel(appText("Evening & health"))
      Button {progress=true} label:{Image(systemName:"chart.bar").frame(width:44,height:44).glassEffect(.regular.interactive(),in:.circle).contentShape(Rectangle())}
       .buttonStyle(.plain)
       .accessibilityIdentifier("morningProgress").accessibilityLabel(appText("Your progress"))
      Button {pro=true} label:{Text(appText("Pro")).font(.subheadline.weight(.semibold)).frame(minWidth:44,minHeight:44).glassEffect(.regular.interactive(),in:.circle).contentShape(Rectangle())}
       .buttonStyle(.plain)
       .accessibilityIdentifier("hiMorningPro").accessibilityLabel("HiMorning Pro")
      Menu {
       Picker(appText("Language"),selection:$language) {
        Text(appText("Use device language")).tag("system")
        Text(appText("English")).tag("en")
        Text(appText("Vietnamese")).tag("vi")
       }
      } label: {Image(systemName:"globe").frame(width:44,height:44).glassEffect(.regular.interactive(),in:.circle)}
       .buttonStyle(.plain)
       .accessibilityIdentifier("appLanguage").accessibilityLabel(appText("Language"))
      }
      }
     }
     HStack(alignment:.firstTextBaseline) {
      Text(appText("Alarms")).modifier(MorningTypography.heading())
      Spacer(minLength:12)
      Text(Date(),format:.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(appLocale())).font(.caption).foregroundStyle(MorningTheme.muted)
     }
     if let error=model.progressError {
      Label(error,systemImage:"exclamationmark.triangle").font(.footnote).foregroundStyle(MorningTheme.muted).accessibilityIdentifier("homeProgressError")
     }
     TimelineView(.everyMinute) {context in
      ForEach(model.alarms.sorted {left,right in
       if left.time.hour != right.time.hour {return left.time.hour < right.time.hour}
       if left.time.minute != right.time.minute {return left.time.minute < right.time.minute}
       return left.id.uuidString < right.id.uuidString
      }) {alarm in
       SwipeableAlarmCard(id:alarm.id,revealedID:$revealedAlarmID,delete:{alarmToDelete=alarm}) {
        alarmCard(alarm,now:context.date)
       }
      }
     }
     if model.backupWarning {Text(appText("Some backup rings could not be updated. Please check your system alarms.")).font(.footnote).foregroundStyle(MorningTheme.muted)}
     Button {editor=AlarmDraft(alarm:nil)} label:{Label(appText(model.alarms.isEmpty ? "Set an alarm" : "Add alarm"),systemImage:"plus")}
      .buttonStyle(MorningButtonStyle()).accessibilityIdentifier("addAlarm")
     if !model.hasLoadedAlarms {
      ForEach(0..<2,id:\.self) { _ in
       RoundedRectangle(cornerRadius:MorningTheme.Radius.hero)
        .fill(MorningTheme.soft.opacity(0.7))
        .frame(height:92)
      }
     } else if model.alarms.isEmpty {firstMorningCard}
     Button {exploringChallenges=true} label: {
      HStack(spacing:12) {
       Image(systemName:"play.circle").font(.title3.weight(.semibold)).foregroundStyle(MorningTheme.accent)
       Text(appText("Explore challenges")).font(.body.weight(.semibold)).foregroundStyle(MorningTheme.ink)
       Spacer(minLength:8)
       Image(systemName:"chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(MorningTheme.muted)
      }
      .padding(.horizontal,18).frame(maxWidth:.infinity,minHeight:48)
      .background(MorningTheme.surface,in:RoundedRectangle(cornerRadius:MorningTheme.Radius.control))
      .overlay {RoundedRectangle(cornerRadius:MorningTheme.Radius.control).strokeBorder(MorningTheme.line)}
     }
     .buttonStyle(.plain).accessibilityIdentifier("practiceChallenges")
     MorningJourneyCard(model:model,store:model.journey,choosePurpose:{choosingPurpose=true},plan:{selection,alarm in
      let upcoming=alarm.flatMap {$0.canPrepareJourney() ? $0 : nil}
      editor=AlarmDraft(alarm:upcoming,scope:upcoming == nil ? .all:.challenge,suggestedChallenge:selection)
     })
     if !model.alarms.isEmpty || (model.journal?.completedChallengeDays(inLast:7) ?? 0)>0 {recentWinsCard}
     if let message=model.preview.message {Text(message).font(.footnote).foregroundStyle(MorningTheme.muted)}
     if model.access == .preview {
      Text(model.preview.hasStarted ? appText("%lld free days left. No automatic charge.",count:model.preview.remainingDays) : appText("Your 30 free days begin when you save your first alarm. No card needed."))
       .font(.footnote).foregroundStyle(MorningTheme.muted).accessibilityIdentifier("previewStatus")
      if (model.journal?.completedDays(inLast:30) ?? 0)>=3 {
       Button(appText("Enjoying your mornings? Explore Pro")) {pro=true}.buttonStyle(.plain).font(.subheadline)
      }
     }
    }.padding(.horizontal,20).padding(.top,20).padding(.bottom,40)
   }.background {MorningBackdrop()}.foregroundStyle(MorningTheme.ink).tint(MorningTheme.accent)
   .navigationTitle("HiMorning").toolbar(.hidden,for:.navigationBar)
   .preferredColorScheme(testingColorScheme)
   .sheet(item:$editor) {draft in AlarmEditor(alarm:draft.alarm,scope:draft.scope,suggestedChallenge:draft.suggestedChallenge,store:model.subscriptions,preview:model.preview,practiceModel:model)}
   .sheet(isPresented:$choosingPurpose,onDismiss:{if proAfterPurpose {proAfterPurpose=false;pro=true}}) {MorningPurposePicker(model:model,store:model.journey,showPro:{proAfterPurpose=true;choosingPurpose=false})}
   .sheet(isPresented:$progress) {MorningProgressView(model:model,store:model.subscriptions)}
   .sheet(isPresented:$pro) {ProView(store:model.subscriptions,preview:model.preview,ads:model.rewardedAds)}
   .sheet(isPresented:$exploringChallenges) {ExploreChallengesView {kind in model.practice(kind)}}
   .sheet(isPresented:$showingBedtime) {BedtimeAnchorView(store:model.bedtime)}
   .fullScreenCover(item:$model.selected,onDismiss:{
    if let challenge=model.challengeAfterPractice {model.challengeAfterPractice=nil;editor=AlarmDraft(alarm:nil,suggestedChallenge:challenge)}
    Task {await model.refresh()}
   }) {alarm in ChallengeView(alarm:alarm,model:model)}
   .onChange(of:model.selected) {_,value in
    if value != nil,!model.rehearsal {editor=nil;progress=false;pro=false;proAfterPurpose=false;choosingPurpose=false}
   }
   .overlay {
    if model.selected == nil,let id=model.celebrationID,!reduceMotion {
     ChallengeConfetti().id(id).ignoresSafeArea()
      .task {
       defer {if model.celebrationID==id {model.celebrationID=nil}}
       do {try await Task.sleep(for:.seconds(2))} catch {return}
      }
    }
   }
   .alert(appText("Delete alarm?"),isPresented:Binding(get:{alarmToDelete != nil},set:{if !$0 {alarmToDelete=nil}}),presenting:alarmToDelete) {alarm in
    Button(appText("Delete"),role:.destructive) {alarmToDelete=nil;Task {await model.remove(alarm)}}
     .accessibilityIdentifier("confirmDeleteAlarm")
    Button(appText("Cancel"),role:.cancel) {alarmToDelete=nil}
   } message: {_ in Text(appText("This alarm and its scheduled rings will be removed."))}
   .alert(appText("Please check"),isPresented:Binding(get:{model.error != nil},set:{visible in
    guard !visible,let shown=model.error else {return}
    DispatchQueue.main.async {if model.error==shown {model.error=nil}}
   })) {Button(appText("Got it")) {model.error=nil}} message:{Text(model.error ?? "")}
   .task {await model.refresh()}
   .task {await model.refreshContent()}
   .task {
    #if DEBUG
    guard !ProcessInfo.processInfo.arguments.contains("--ui-testing") else {return}
    #endif
    if model.rewardedAds.isConfigured {try? await model.rewardedAds.refreshConsent()}
   }
   .task {model.subscriptions.start();await model.subscriptions.refresh()}
   .onReceive(NotificationCenter.default.publisher(for:UserDefaults.didChangeNotification).receive(on:RunLoop.main)) {_ in model.openPending()}
   .onChange(of:phase) {_,value in if value == .active {Task {await model.refresh();await model.subscriptions.refresh()};Task {await model.refreshContent()}}}
   .onChange(of:reduceMotion) {_,value in if value {model.celebrationID=nil}}
  }
 }
 private var brandWordmark:some View {
  Label {
   Text("HiMorning.")
    .modifier(MorningTypography.heading(size:22,relativeTo:.title2))
    .lineLimit(1).minimumScaleFactor(0.75)
  } icon: {
   Image(systemName:"sunrise").font(.system(size:20,weight:.bold))
  }.labelStyle(.titleAndIcon)
   .fixedSize(horizontal:true,vertical:true).accessibilityLabel("Hi Morning")
 }
 @ViewBuilder private var headerActions:some View {
  GlassEffectContainer(spacing:8) {
   HStack(spacing:6) {
    Button {showingBedtime=true} label: {
     headerCircleIcon("moon.zzz")
    }.buttonStyle(.plain)
     .accessibilityIdentifier("bedtimeAnchor").accessibilityLabel(appText("Evening & health"))
    Button {progress=true} label: {
     headerCircleIcon("chart.bar")
    }.buttonStyle(.plain)
     .accessibilityIdentifier("morningProgress").accessibilityLabel(appText("Your progress"))
    Button {pro=true} label: {
     Text(appText("Pro")).font(.subheadline.weight(.semibold))
      .foregroundStyle(reduceTransparency ? MorningTheme.proInk : MorningTheme.ink)
      .padding(.horizontal,12).frame(height:44)
      .background {
       if reduceTransparency {
        Capsule().fill(MorningTheme.proGoldLight)
         .overlay {Capsule().strokeBorder(MorningTheme.proGoldEdge,lineWidth:0.75)}
       }
      }
      .glassEffect(reduceTransparency ? .identity : .regular.tint(MorningTheme.proGold.opacity(0.32)).interactive(),in:.capsule)
      .contentShape(Capsule())
    }.buttonStyle(.plain)
     .accessibilityIdentifier("hiMorningPro").accessibilityLabel("HiMorning Pro")
    Menu {
     Picker(appText("Language"),selection:$language) {
      Text(appText("Use device language")).tag("system")
      Text(appText("English")).tag("en")
      Text(appText("Vietnamese")).tag("vi")
     }
    } label: {
     headerCircleIcon("globe")
    }.buttonStyle(.plain)
     .accessibilityIdentifier("appLanguage").accessibilityLabel(appText("Language"))
   }
  }
 }
 @ViewBuilder private func headerCircleIcon(_ systemName:String)->some View {
  Image(systemName:systemName)
   .frame(width:44,height:44)
   .background {
    if reduceTransparency {
     Circle().fill(MorningTheme.surface)
      .overlay {Circle().strokeBorder(MorningTheme.line,lineWidth:1)}
    }
   }
   .glassEffect(reduceTransparency ? .identity : .regular.interactive(),in:.circle)
   .contentShape(Circle())
 }
 private var firstMorningCard:some View {
  VStack(alignment:.leading,spacing:10) {
   Text(appText("Start your morning with a small win.")).font(.title2.weight(.semibold))
    .fixedSize(horizontal:false,vertical:true).accessibilityIdentifier("firstMorningPromise")
   Text(appText("An alarm, a short challenge, a reason to get going.")).font(.subheadline)
    .fixedSize(horizontal:false,vertical:true)
   Button {model.practice(.readAndChoose)} label: {
    Label(appText("Try Read & Choose"),systemImage:"play.circle")
   }.buttonStyle(MorningButtonStyle(primary:false)).accessibilityIdentifier("quickPractice")
   Text(appText("Practice now. No camera, microphone or alarm needed.")).font(.footnote)
    .fixedSize(horizontal:false,vertical:true)
  }.padding(18).frame(maxWidth:.infinity,alignment:.leading).foregroundStyle(MorningTheme.onYellow)
   .background(MorningTheme.hero,in:RoundedRectangle(cornerRadius:24))
 }
 @ViewBuilder private var recentWinsCard:some View {
  if let journal=model.journal {
   let days=journal.completedChallengeDays(inLast:7)
   VStack(alignment:.leading,spacing:10) {
    Label(appText("Your recent wins"),systemImage:"sun.max.fill").font(.headline)
    Text(days == 0 ? appText("No challenges completed in the past 7 days.") : appText("%lld of the last 7 days with a completed challenge",count:days))
     .font(.subheadline.weight(.medium)).fixedSize(horizontal:false,vertical:true).accessibilityIdentifier("recentWinCount")
    Text(appText("Each day counts once. Practice and I’m awake do not count here."))
     .font(.footnote).foregroundStyle(MorningTheme.muted).fixedSize(horizontal:false,vertical:true)
     Button(appText("Your progress")) {progress=true}.font(.subheadline.weight(.medium))
     .frame(minHeight:44).accessibilityIdentifier("recentWinsProgress")
   }.padding(20).frame(maxWidth:.infinity,alignment:.leading).background(MorningTheme.soft,in:RoundedRectangle(cornerRadius:24))

  }
 }
 private var testingColorScheme:ColorScheme? {
  #if DEBUG
  ProcessInfo.processInfo.arguments.contains("--ui-dark-mode") ? .dark : nil
  #else
  nil
  #endif
 }
 private func alarmRepeatSummary(_ alarm:SavedAlarm,now:Date)->String {
  let days=alarm.time.weekdays
  if days.isEmpty {
   guard let occurrence=alarm.scheduledOccurrence ?? alarm.time.next(after:now,calendar:.current) else {return appText("Rings once")}
   if Calendar.current.isDate(occurrence,inSameDayAs:now) {return appText("Today · Once")}
   if let tomorrow=Calendar.current.date(byAdding:.day,value:1,to:now),Calendar.current.isDate(occurrence,inSameDayAs:tomorrow) {return appText("Tomorrow · Once")}
   return String(format:appText("Once · %@"),locale:appLocale(),occurrence.formatted(.dateTime.day().month(.abbreviated).locale(appLocale())))
  }
  if days.count == 7 {return appText("Every day")}
  if days.count == 1,let day=days.first {
   let weekly=[appText("Every Sunday"),appText("Every Monday"),appText("Every Tuesday"),appText("Every Wednesday"),appText("Every Thursday"),appText("Every Friday"),appText("Every Saturday")]
   return weekly[day-1]
  }
  let names=[appText("Sun"),appText("Mon"),appText("Tue"),appText("Wed"),appText("Thu"),appText("Fri"),appText("Sat")]
  return [2,3,4,5,6,7,1].filter {days.contains($0)}.map {names[$0-1]}.joined(separator:", ")
 }
 private func alarmCard(_ alarm:SavedAlarm,now:Date)->some View {
  let completed=model.journal?.completedToday(alarmID:alarm.id,now:now) ?? false
  let pendingTarget=model.togglingAlarms[alarm.id]
  let armed=pendingTarget ?? (alarm.enabled && alarm.state == .confirmed)
  let isEnabledVisual=pendingTarget ?? alarm.enabled
  let compactDisabled = !isEnabledVisual && alarm.state != .needsReview
  let ink=armed ? MorningTheme.onYellow : MorningTheme.ink
  let detailInk=armed ? MorningTheme.alarmDetailOnYellow : MorningTheme.muted
  let clock=Text(alarmTimeText(alarm.time))
   .font(.system(size:clockSize,weight:.medium,design:.rounded))
   .foregroundStyle(isEnabledVisual ? ink : MorningTheme.alarmClockOff)
   .monospacedDigit().lineLimit(1).minimumScaleFactor(0.6).accessibilityIdentifier("alarmTime-"+alarm.id.uuidString)
  let toggle=Toggle(appText("Alarm enabled"),isOn:Binding(get:{armed},set:{newValue in
   guard newValue != armed else {return}
   withAnimation(reduceMotion ? nil : .easeInOut(duration:0.34)) {
    model.requestToggle(alarm)
   }
  }))
   .toggleStyle(.switch).labelsHidden().fixedSize().tint(MorningTheme.alarmSwitchOn)
   .accessibilityIdentifier("toggleAlarm-"+alarm.id.uuidString)
  let repeatDays=HStack(alignment:.firstTextBaseline,spacing:5) {
   Image(systemName:alarm.time.weekdays.isEmpty ? "calendar.badge.clock" : "repeat")
    .font(.caption2.weight(.semibold)).accessibilityHidden(true)
   Text(alarmRepeatSummary(alarm,now:now)).font(.caption.weight(.medium))
    .fixedSize(horizontal:false,vertical:true).accessibilityIdentifier("alarmRepeat-"+alarm.id.uuidString)
  }.foregroundStyle(detailInk)
  let detailIn:AnyTransition = .asymmetric(
   insertion:.opacity.animation(reduceMotion ? nil : .easeOut(duration:0.26).delay(0.06)),
   removal:.opacity.animation(reduceMotion ? nil : .easeIn(duration:0.12))
  )
  let clockBlock=Button {openAlarm(alarm,scope:.schedule)} label: {
   VStack(alignment:.leading,spacing:0) {
   if !alarm.label.isEmpty {
    Text(alarm.label).font(.subheadline.weight(.medium)).lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
     .fixedSize(horizontal:false,vertical:true).foregroundStyle(compactDisabled ? detailInk : ink)
     .padding(.bottom,4)
     .accessibilityIdentifier("alarmLabel-"+alarm.id.uuidString)
   }
   clock
   if !compactDisabled && (armed || alarm.state == .confirmed) {
    repeatDays.padding(.top,6).transition(detailIn)
   }
   }.frame(maxWidth:.infinity,alignment:.leading).contentShape(Rectangle())
  }.buttonStyle(.plain)
   .accessibilityElement(children:.contain)
   .accessibilityIdentifier("editAlarmSchedule-"+alarm.id.uuidString)
  let mainLayout=dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment:.leading,spacing:16)) : AnyLayout(HStackLayout(alignment:.top,spacing:16))
  let footerLayout=dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment:.leading,spacing:8)) : AnyLayout(HStackLayout(alignment:.center,spacing:8))
  return VStack(alignment:.leading,spacing:0) {
   mainLayout {
    VStack(alignment:.leading,spacing:0) {
     if compactDisabled {
      if !alarm.label.isEmpty {
       Text(alarm.label).font(.subheadline.weight(.medium)).lineLimit(1)
        .foregroundStyle(detailInk).padding(.bottom,4)
        .accessibilityIdentifier("alarmLabel-"+alarm.id.uuidString)
      }
      clock
     } else {
      clockBlock
      Label {
       Text(alarm.sound.title).fixedSize(horizontal:false,vertical:true)
      } icon: {Image(systemName:"speaker.wave.2").accessibilityHidden(true)}
       .font(.caption.weight(.medium)).foregroundStyle(detailInk)
       .padding(.top,8)
       .accessibilityIdentifier("alarmSound-"+alarm.id.uuidString)
       .transition(detailIn)
     }
    }.frame(maxWidth:.infinity,alignment:.leading)
    if !compactDisabled {
     Button {openAlarm(alarm,scope:.challenge)} label: {
      alarmChallengeSummary(alarm,now:now,onYellow:armed).contentShape(Rectangle())
     }.buttonStyle(.plain).accessibilityIdentifier("editAlarmChallenge-"+alarm.id.uuidString)
      .transition(detailIn)
    }
   }
   if !compactDisabled {
    Rectangle().fill(ink.opacity(0.14)).frame(height:0.5).padding(.top,12).accessibilityHidden(true)
     .transition(detailIn)
   }
   footerLayout {
    alarmStatus(alarm,now:now,completed:completed,onYellow:armed,optimisticEnabled:pendingTarget).frame(maxWidth:.infinity,alignment:.leading)
    HStack(spacing:8) {
     if !compactDisabled {
      tryAlarmButton(alarm,enabled:isEnabledVisual).foregroundStyle(detailInk)
       .transition(.opacity)
     }
     if alarm.state == .needsReview {
      Button(appText(alarm.enabled ? "Retry schedule" : "Retry turning off")) {
       Task {
        if alarm.enabled {await model.toggle(alarm)}
        else {await model.retryTurningOff(alarm)}
       }
      }.font(.footnote.weight(.semibold)).frame(minHeight:44)
     } else {toggle.disabled(alarm.state == .pending)}
    }
   }.padding(.top,compactDisabled ? 8 : 12)
  }.padding(.horizontal,18).padding(.vertical,16).foregroundStyle(ink)
   .background {
    ZStack {
     RoundedRectangle(cornerRadius:MorningTheme.Radius.hero).fill(MorningTheme.surface)
     RoundedRectangle(cornerRadius:MorningTheme.Radius.hero)
      .fill(LinearGradient(colors:[MorningTheme.alarmCardHighlight,MorningTheme.yellow],startPoint:.topLeading,endPoint:.bottomTrailing))
      .opacity(armed ? 1 : 0)
    }
   }
   .clipShape(RoundedRectangle(cornerRadius:MorningTheme.Radius.hero))
   .overlay {RoundedRectangle(cornerRadius:MorningTheme.Radius.hero).strokeBorder(armed ? MorningTheme.alarmCardEdge : MorningTheme.line,lineWidth:1)}
   .contentShape(RoundedRectangle(cornerRadius:MorningTheme.Radius.hero))
   .accessibilityElement(children:.contain).accessibilityIdentifier("alarmCard-"+alarm.id.uuidString)
   .onTapGesture {openAlarm(alarm,scope:.all)}
   .contextMenu {
    Button {openAlarm(alarm,scope:.all)} label: {Label(appText("Edit alarm"),systemImage:"pencil")}
    Button(role:.destructive) {alarmToDelete=alarm} label: {Label(appText("Delete"),systemImage:"trash")}
   }
   .accessibilityAction(.default) {openAlarm(alarm,scope:.all)}
 }
 private func openAlarm(_ alarm:SavedAlarm,scope:AlarmEditorScope) {
  if revealedAlarmID == alarm.id {revealedAlarmID=nil;return}
  revealedAlarmID=nil;editor=AlarmDraft(alarm:alarm,scope:scope)
 }
 @ViewBuilder private func alarmChallengeSummary(_ alarm:SavedAlarm,now:Date,onYellow:Bool)->some View {
  let next=alarm.time.weekdays.isEmpty ? alarm.scheduledOccurrence : alarm.time.next(after:now)
  let trialPending=alarm.enabled && next.map {$0>now && $0 == alarm.challengeTrial?.occurrence} == true
  let alarm=trialPending ? model.access.effectiveAlarm(alarm,occurrence:next) : alarm
  let tint=MorningTheme.modeAccent(alarm.mode,onYellow:onYellow)
  let accessible=dynamicTypeSize.isAccessibilitySize
  let layout=accessible ? AnyLayout(HStackLayout(alignment:.center,spacing:12)) : AnyLayout(VStackLayout(alignment:.trailing,spacing:6))
  layout {
   ChallengeIcon(kind:alarm.challenge.kind,seated:alarm.challenge.rhythmVariant == .seated,size:28,animated:true)
    .foregroundStyle(tint)
    .frame(width:40,height:40)
    .background(tint.opacity(0.13),in:Circle())
   VStack(alignment:accessible ? .leading : .trailing,spacing:3) {
    Text(alarm.challenge.displayTitle).font(.subheadline.weight(.semibold)).fixedSize(horizontal:false,vertical:true)
     .accessibilityIdentifier("alarmChallenge-"+alarm.id.uuidString)
    Label(alarm.mode.title,systemImage:alarm.mode == .gentle ? "leaf.fill" : alarm.mode == .balanced ? "sun.max.fill" : "bolt.fill")
     .font(.caption.weight(.semibold)).foregroundStyle(tint).fixedSize(horizontal:false,vertical:true)
     .accessibilityLabel(String(format:appText("Challenge level: %@"),locale:appLocale(),alarm.mode.title))
     .accessibilityIdentifier("alarmMode-"+alarm.id.uuidString)
    if trialPending {
     Text(appText("Next ring only")).font(.caption2.weight(.semibold))
    }
   }.multilineTextAlignment(accessible ? .leading : .trailing)
  }.frame(width:accessible ? nil : 132,alignment:accessible ? .leading : .trailing)
   .frame(maxWidth:accessible ? .infinity : nil,alignment:accessible ? .leading : .trailing)
 }
 @ViewBuilder private func alarmStatus(_ alarm:SavedAlarm,now:Date,completed:Bool,onYellow:Bool,optimisticEnabled:Bool?=nil)->some View {
  VStack(alignment:.leading,spacing:4) {
   if let optimisticEnabled {
    if optimisticEnabled,let next=alarm.time.weekdays.isEmpty ? (alarm.scheduledOccurrence ?? alarm.time.next(after:now,calendar:.current)) : alarm.time.next(after:now),next>now {
     let day=Calendar.current.isDateInToday(next) ? appText("Today") : Calendar.current.isDateInTomorrow(next) ? appText("Tomorrow") : next.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(appLocale()))
     Text(String(format:appText("Rings at %@ · %@"),locale:appLocale(),alarmTimeText(next),day))
      .font(.caption).foregroundStyle(onYellow ? MorningTheme.alarmDetailOnYellow : MorningTheme.muted).fixedSize(horizontal:false,vertical:true)
      .accessibilityIdentifier("nextAlarm-"+alarm.id.uuidString)
    } else {
     Text(appText("Off")).font(.caption.weight(.medium)).foregroundStyle(MorningTheme.muted)
    }
   } else if alarm.state == .needsReview || alarm.state == .pending {
    Label {
     Text(alarm.state.title).accessibilityIdentifier("alarmState-"+alarm.id.uuidString)
    } icon: {
     Image(systemName:alarm.state == .needsReview ? "exclamationmark.triangle" : "clock").accessibilityHidden(true)
    }.font(.caption.weight(.semibold)).fixedSize(horizontal:false,vertical:true)
   } else if alarm.enabled,alarm.state == .confirmed,let next=alarm.time.weekdays.isEmpty ? alarm.scheduledOccurrence : alarm.time.next(after:now),next>now {
    let day=Calendar.current.isDateInToday(next) ? appText("Today") : Calendar.current.isDateInTomorrow(next) ? appText("Tomorrow") : next.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(appLocale()))
    Text(String(format:appText("Rings at %@ · %@"),locale:appLocale(),alarmTimeText(next),day))
     .font(.caption).foregroundStyle(onYellow ? MorningTheme.alarmDetailOnYellow : MorningTheme.muted).fixedSize(horizontal:false,vertical:true)
     .accessibilityIdentifier("nextAlarm-"+alarm.id.uuidString)
   } else if alarm.state == .off {
    Text(appText("Off")).font(.caption.weight(.medium)).foregroundStyle(MorningTheme.muted)
   }
   if completed {
    Label(appText("Completed today"),systemImage:"checkmark.circle.fill")
     .font(.caption.weight(.medium)).foregroundStyle(onYellow ? MorningTheme.successOnYellow : MorningTheme.success).fixedSize(horizontal:false,vertical:true)
     .accessibilityIdentifier("alarmCompleted-"+alarm.id.uuidString)
   }
  }
 }
 @ViewBuilder private func tryAlarmButton(_ alarm:SavedAlarm,enabled:Bool?=nil)->some View {
  if enabled ?? alarm.enabled,alarm.challenge.kind != .none {
   Button {revealedAlarmID=nil;model.rehearsal=true;model.selected=alarm} label: {
    Image(systemName:"play.circle").font(.system(size:22,weight:.medium))
     .frame(width:44,height:44).contentShape(Rectangle())
   }.buttonStyle(.plain).accessibilityLabel(appText("Try this challenge"))
    .accessibilityIdentifier("tryAlarm-"+alarm.id.uuidString)
  }
 }

}
