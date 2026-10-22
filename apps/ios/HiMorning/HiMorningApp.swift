import SwiftUI
import Combine
import FirebaseCore
import FirebaseAppCheck
import HiMorningCore
@main struct HiMorningApp:App {
 @StateObject private var model=PilotModel()
 @AppStorage("appLanguage") private var language="system"
 var body:some Scene {WindowGroup {HomeView(model:model).environment(\.locale,Locale(identifier:(AppLanguage(rawValue:language) ?? .system).resolved(preferredLanguages:Locale.preferredLanguages)))}}
}
enum AlarmSaveError:Error {case soundUnavailable,challengeUnavailable}
#if DEBUG
struct NoopBackupScheduler:BackupRingScheduler {
 func scheduleBackup(_ ring:BackupRing,for alarm:SavedAlarm) async throws {}
 func cancel(id:UUID) async throws {}
}
#endif
@MainActor final class PilotModel:ObservableObject {
 @Published var alarms:[SavedAlarm]=[]
 @Published var error:String?
 @Published var selected:SavedAlarm?
 @Published var rehearsal=false
 @Published var backupWarning=false
 @Published var activeWake:UnresolvedWake?
 let subscriptions=SubscriptionStore()
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
  accessObserver=preview.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
 }
 func nextPrompt(_ kind:ContentKind)->ChallengeContentItem? {
  let item=content.next(kind:kind,language:appLocale().identifier,history:&contentHistory)
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
   Task {await enforcer?.resolve(alarmID:alarm.id);await replanBackups()}
  }
  guard journal != nil else {return}
  do {try journal?.record(MorningEntry(id:id,alarmID:alarm.id,mode:alarm.mode,challenge:alarm.challenge,outcome:outcome),rehearsal:rehearsal)}
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
 func refresh() async {
  guard let library else {return}
  #if DEBUG
  // Presentation fixtures have no native schedules to reconcile.
  if ProcessInfo.processInfo.arguments.contains("--ui-testing"),ProcessInfo.processInfo.arguments.contains("--ui-home-alarms") {
   alarms=await library.all();openPending();return
  }
  #endif
  do {try await library.reconcile()}
  catch LibraryError.busy {return}
  catch {self.error=appText("Your alarms could not be checked. Please check alarm access.")}
  alarms=await library.all()
  if alarms.contains(where:{$0.state == .confirmed}) {preview.start()} else {preview.refresh()}
  await replanBackups()
  openPending()
  #if DEBUG
  if ProcessInfo.processInfo.arguments.contains("--ui-testing") {return}
  #endif
  if selected == nil,let wake=WakePlanner.unresolvedWake(alarms:alarms,entries:wakeEntries(),now:Date(),calendar:.current,rings:plannedRings),let alarm=alarms.first(where:{$0.id==wake.alarmID}) {
   activeWake=wake;rehearsal=false;selected=alarm
  }
 }
 func save(_ alarm:SavedAlarm) async throws {
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
  guard access.allows(sound:alarm.sound) else {throw AlarmSaveError.soundUnavailable}
  guard access.allows(mode:alarm.mode),access.hasFullAccess || (alarm.challenge.repetitions ?? 0)<=WakeMode.balanced.policy.reps else {throw AlarmSaveError.challengeUnavailable}
  do {
   let effective=access.effectiveAlarm(alarm)
   if await library.all().contains(where:{$0.id==alarm.id}) {try await library.update(effective)}
   else {try await library.add(effective)}
   alarms=await library.all()
   if alarms.contains(where:{$0.state == .confirmed}) {preview.start()}
   await replanBackups()
  } catch {alarms=await library.all();throw error}
 }
 func toggle(_ alarm:SavedAlarm) async {
  guard let library else {return}
  do {if alarm.enabled {try await library.disable(id:alarm.id)} else {try await library.enable(id:alarm.id)}} catch {self.error=appText("This change could not be confirmed. Please check your system alarms.")}
  alarms=await library.all()
  await replanBackups()
 }
 func remove(_ alarm:SavedAlarm) async {
  guard let library else {return}
  do {try await library.remove(id:alarm.id)} catch {self.error=appText("This alarm could not be removed. It may still be set in the system.")}
  alarms=await library.all()
  await replanBackups()
 }
 func openPending() {
  guard let raw=UserDefaults.standard.string(forKey:"pendingAlarmID"),let id=UUID(uuidString:raw),let alarm=alarms.first(where:{$0.id==id}) else {return}
  UserDefaults.standard.removeObject(forKey:"pendingAlarmID");rehearsal=false
  activeWake=WakePlanner.liveOccurrence(of:alarm,entries:wakeEntries(),now:Date(),calendar:.current,rings:plannedRings).map {UnresolvedWake(alarmID:alarm.id,occurrence:$0)}
  selected=alarm
 }
}
extension WakeMode {
 var title:String {switch self {case .gentle:return appText("Gentle");case .balanced:return appText("Balanced");case .focused:return appText("Challenging")}}
 var icon:String {switch self {case .gentle:return "leaf";case .balanced:return "circle.lefthalf.filled";case .focused:return "scope"}}
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
 }}
 static var groups:[(title:String,sounds:[AlarmSound])] {[
  (appText("Classic"),[.system,.sunrise,.softChime]),
  (appText("Plucked strings"),[.pizzicatoDawn,.pizzicatoSteps,.pizzicatoRise,.pizzicatoBloom]),
  (appText("Steel pan"),[.steelShimmer,.steelBreeze,.steelMorning,.steelSparkle]),
  (appText("Saxophone"),[.saxHello,.saxStroll,.saxGlow,.saxDaybreak])
 ]}
}
extension ChallengeKind {
 var editorIdentifier:String {switch self {case .none:return "none";case .pushUps:return "pushUps";case .readAndChoose:return "readAndChoose";case .guidedRhythm:return "guidedRhythm";case .readAloud:return "readAloud";case .waveHand:return "waveHand";case .neckRotation:return "neckRotation";case .riddle:return "riddle";case .jumpingJacks:return "jumpingJacks";case .stretching:return "stretching"}}
 var title:String {switch self {case .none:return appText("No challenge");case .pushUps:return appText("Push-ups");case .readAndChoose:return appText("Read & Choose");case .guidedRhythm:return appText("Guided Rhythm");case .readAloud:return appText("Read Aloud");case .waveHand:return appText("Wave hello");case .neckRotation:return appText("Neck turns");case .riddle:return appText("Riddle");case .jumpingJacks:return appText("Jumping jacks");case .stretching:return appText("Reach up")}}
 var summary:String {switch self {
  case .none:return appText("Confirm you are awake when you are ready.")
  case .pushUps:return appText("Complete a short camera-checked movement challenge.")
  case .readAndChoose:return appText("Read one short sentence and choose its meaning.")
  case .guidedRhythm:return appText("Follow a simple standing or seated rhythm on camera.")
  case .readAloud:return appText("Read the sentence aloud. See your score and matching words as you read.")
  case .waveHand:return appText("Hold your hand in view and wave it side to side.")
  case .neckRotation:return appText("Face the camera and turn your head left and right.")
  case .riddle:return appText("Solve a short riddle in your language.")
  case .jumpingJacks:return appText("Complete 10 gentle jumping jacks. Checked on this device.")
  case .stretching:return appText("Raise both hands above your shoulders, then lower them.")
 }}
 var icon:String {switch self {case .none:return "hand.tap";case .pushUps:return "figure.strengthtraining.traditional";case .readAndChoose:return "text.book.closed";case .guidedRhythm:return "figure.cooldown";case .readAloud:return "waveform";case .waveHand:return "hand.wave";case .neckRotation:return "person.crop.circle";case .riddle:return "lightbulb";case .jumpingJacks:return "figure.jumping";case .stretching:return "figure.cooldown"}}
}
extension ChallengeSelection {
 var displayTitle:String {
  if kind == .pushUps,let repetitions {return appText("%lld push-ups",count:repetitions)}
  if kind == .guidedRhythm {return rhythmVariant == .seated ? appText("Guided Rhythm · Seated") : appText("Guided Rhythm · Standing")}
  return kind.title
 }
}
extension ScheduleState {
 var title:String {switch self {case .pending:return appText("Checking…");case .confirmed:return appText("Alarm is set");case .off:return appText("Off");case .needsReview:return appText("Check system alarms")}}
}
struct HomeView:View {
 @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
 private struct AlarmDraft:Identifiable {let id=UUID();let alarm:SavedAlarm?}
 @ObservedObject var model:PilotModel
 @Environment(\.dynamicTypeSize) private var dynamicTypeSize
 @Environment(\.scenePhase) private var phase
 @Environment(\.accessibilityReduceMotion) private var reduceMotion
 @State private var editor:AlarmDraft?
 @State private var revealedAlarmID:UUID?
 @State private var alarmToDelete:SavedAlarm?
 @State private var progress=false
 @State private var pro=false
 @AppStorage("appLanguage") private var language="system"
 @ScaledMetric(relativeTo:.largeTitle) private var clockSize=48
 var body:some View {
  NavigationStack {
   ScrollView {
    VStack(alignment:.leading,spacing:16) {
     HStack(spacing:12) {
      Label("HiMorning.",systemImage:"sunrise").font(.system(size:20,weight:.bold)).labelStyle(.titleAndIcon)
       .fixedSize(horizontal:false,vertical:true).accessibilityLabel("Hi Morning")
      Spacer()
      GlassEffectContainer(spacing:12) {
      HStack(spacing:8) {
      Button {progress=true} label:{Image(systemName:"chart.bar").frame(width:44,height:44).glassEffect(.regular.interactive(),in:.circle).contentShape(Rectangle())}
       .buttonStyle(.plain)
       .accessibilityIdentifier("morningProgress").accessibilityLabel(appText("Your progress"))
      Button {pro=true} label:{Image(systemName:"sun.max").frame(width:44,height:44).glassEffect(.regular.interactive(),in:.circle).contentShape(Rectangle())}
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
      Text(appText("Alarms")).font(.title2.weight(.semibold))
      Spacer(minLength:12)
      Text(Date(),format:.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(appLocale())).font(.caption).foregroundStyle(MorningTheme.muted)
     }
     if model.alarms.isEmpty {
      HStack(spacing:16) {
       VStack(alignment:.leading,spacing:10) {
        Text(appText("No alarms yet")).font(.title3.weight(.semibold))
        Text(appText("Set your first alarm for tomorrow.")).font(.subheadline)
       }
       Spacer(minLength:0)
       MorningSun(size:88)
      }.padding(24).frame(maxWidth:.infinity,minHeight:180).foregroundStyle(MorningTheme.onYellow)
       .background(MorningTheme.hero,in:RoundedRectangle(cornerRadius:24))
     }
     if let error=model.progressError {
      Label(error,systemImage:"exclamationmark.triangle").font(.footnote).foregroundStyle(MorningTheme.muted).accessibilityIdentifier("homeProgressError")
     }
     TimelineView(.everyMinute) {_ in
      ForEach(model.alarms) {alarm in
       SwipeableAlarmCard(id:alarm.id,revealedID:$revealedAlarmID,delete:{alarmToDelete=alarm}) {
        alarmCard(alarm,now:Date())
       }
      }
     }
     if model.backupWarning {Text(appText("Some backup rings could not be updated. Please check your system alarms.")).font(.footnote).foregroundStyle(MorningTheme.muted)}
     Button {editor=AlarmDraft(alarm:nil)} label:{Label(appText("Add alarm"),systemImage:"plus")}
      .buttonStyle(MorningButtonStyle()).accessibilityIdentifier("addAlarm")
      Menu {
       ForEach(ChallengeKind.allCases,id:\.self) {kind in
        Button(kind.title) {
         if let time=try? AlarmTime(hour:6,minute:30,weekdays:[]) {
          let mode=kind.preferredMode
          model.rehearsal=true;model.selected=SavedAlarm(time:time,mode:mode,challenge:kind == .none ? .none : kind == .pushUps ? .pushUps(repetitions:kind.localMovementTarget ?? 10) : ChallengeSelection(kind:kind))
         }
        }.accessibilityIdentifier("practice-"+kind.editorIdentifier)
       }
      } label: {Text(appText("Explore challenges")).frame(maxWidth:.infinity)}
       .buttonStyle(MorningButtonStyle(primary:false)).accessibilityIdentifier("practiceChallenges")
     if let message=model.preview.message {Text(message).font(.footnote).foregroundStyle(MorningTheme.muted)}
     if model.access == .preview {
      Text(model.preview.hasStarted ? appText("%lld free days left. No automatic charge.",count:model.preview.remainingDays) : appText("Your 30 free days begin when you save your first alarm. No card needed."))
       .font(.footnote).foregroundStyle(MorningTheme.muted).accessibilityIdentifier("previewStatus")
      if (model.journal?.completedDays(inLast:30) ?? 0)>=3 {
       Button(appText("Enjoying your mornings? Explore Pro")) {pro=true}.buttonStyle(.plain).font(.subheadline)
      }
     }
    }.padding(20)
   }.background(MorningTheme.canvas.ignoresSafeArea()).foregroundStyle(MorningTheme.ink).tint(MorningTheme.accent)
   .navigationTitle("HiMorning").toolbar(.hidden,for:.navigationBar)
   .preferredColorScheme(testingColorScheme)
   .sheet(item:$editor) {draft in AlarmEditor(alarm:draft.alarm,store:model.subscriptions,preview:model.preview,practiceModel:model,save:model.save)}
   .sheet(isPresented:$progress) {MorningProgressView(model:model,store:model.subscriptions)}
   .sheet(isPresented:$pro) {ProView(store:model.subscriptions,preview:model.preview)}
   .fullScreenCover(item:$model.selected,onDismiss:{Task {await model.refresh()}}) {alarm in ChallengeView(alarm:alarm,model:model)}
   .onChange(of:model.selected) {_,value in
    if value != nil,!model.rehearsal {editor=nil;progress=false;pro=false}
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
   .task {model.subscriptions.start();await model.subscriptions.refresh()}
   .onReceive(NotificationCenter.default.publisher(for:UserDefaults.didChangeNotification).receive(on:RunLoop.main)) {_ in model.openPending()}
   .onChange(of:phase) {_,value in if value == .active {Task {await model.refresh();await model.subscriptions.refresh()};Task {await model.refreshContent()}}}
   .onChange(of:reduceMotion) {_,value in if value {model.celebrationID=nil}}
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
  let time=String(format:"%02d:%02d",alarm.time.hour%12 == 0 ? 12 : alarm.time.hour%12,alarm.time.minute)
  let period=alarm.time.hour<12 ? "AM" : "PM"
  let clock=HStack(alignment:.firstTextBaseline,spacing:5) {
   Text(time).font(.system(size:clockSize,weight:.medium,design:.rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
    .accessibilityLabel(time+" "+period).accessibilityIdentifier("alarmTime-"+alarm.id.uuidString)
   Text(verbatim:period).font(.caption.weight(.semibold)).accessibilityHidden(true)
  }
  let toggle=Toggle(appText(alarm.enabled ? "Turn off" : "Turn on"),isOn:Binding(get:{alarm.enabled},set:{_ in Task {await model.toggle(alarm)}}))
   .labelsHidden().fixedSize().tint(alarm.enabled ? MorningTheme.successOnYellow : MorningTheme.success).accessibilityIdentifier("toggleAlarm-"+alarm.id.uuidString)
  let repeatDays=HStack(alignment:.firstTextBaseline,spacing:5) {
   Image(systemName:alarm.time.weekdays.isEmpty ? "calendar.badge.clock" : "repeat")
    .font(.caption2.weight(.semibold)).accessibilityHidden(true)
   Text(alarmRepeatSummary(alarm,now:now)).font(.caption.weight(.medium))
    .fixedSize(horizontal:false,vertical:true).accessibilityIdentifier("alarmRepeat-"+alarm.id.uuidString)
  }.foregroundStyle(MorningTheme.onYellow.opacity(0.8))
  let clockBlock=VStack(alignment:.leading,spacing:6) {
   if !alarm.label.isEmpty {
    Text(alarm.label).font(.subheadline.weight(.medium)).lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
     .fixedSize(horizontal:false,vertical:true).accessibilityIdentifier("alarmLabel-"+alarm.id.uuidString)
   }
   clock
   if alarm.enabled {repeatDays}
   else {Text(appText("Off")).font(.caption.weight(.medium))}
  }
  let mainLayout=dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment:.leading,spacing:16)) : AnyLayout(HStackLayout(alignment:.top,spacing:16))
  let footerLayout=dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment:.leading,spacing:8)) : AnyLayout(HStackLayout(alignment:.center,spacing:8))
  return VStack(alignment:.leading,spacing:12) {
   if alarm.enabled,alarm.challenge.kind != .none {
    mainLayout {
     clockBlock.frame(maxWidth:.infinity,alignment:.leading)
     alarmChallengeSummary(alarm)
    }
    Rectangle().fill(MorningTheme.onYellow.opacity(0.12)).frame(height:0.5).accessibilityHidden(true)
    footerLayout {
     alarmStatus(alarm,now:now,completed:completed).frame(maxWidth:.infinity,alignment:.leading)
     HStack(spacing:8) {tryAlarmButton(alarm);toggle}
    }
   } else {
    HStack(alignment:.top,spacing:16) {
     VStack(alignment:.leading,spacing:6) {
      clockBlock
      alarmStatus(alarm,now:now,completed:completed)
     }.frame(maxWidth:.infinity,alignment:.leading)
     toggle
    }
   }
  }.padding(18).foregroundStyle(alarm.enabled ? MorningTheme.onYellow : MorningTheme.muted)
   .background {alarmCardBackground(alarm)}
   .overlay {RoundedRectangle(cornerRadius:26).strokeBorder(alarm.enabled ? MorningTheme.onYellow.opacity(0.08) : MorningTheme.line,lineWidth:1)}
   .contentShape(RoundedRectangle(cornerRadius:26))
   .accessibilityElement(children:.contain).accessibilityIdentifier("alarmCard-"+alarm.id.uuidString)
   .onTapGesture {if revealedAlarmID == alarm.id {revealedAlarmID=nil} else {revealedAlarmID=nil;editor=AlarmDraft(alarm:alarm)}}
   .accessibilityAction(.default) {editor=AlarmDraft(alarm:alarm)}
 }
 private func alarmCardBackground(_ alarm:SavedAlarm)->some View {
  ZStack(alignment:.topTrailing) {
   alarm.enabled ? MorningTheme.alarmCard : MorningTheme.soft
   if alarm.enabled,alarm.challenge.kind != .none,!reduceTransparency {
    let tint:Color=switch alarm.mode {
    case .gentle:Color(red:0.20,green:0.60,blue:0.44)
    case .balanced:Color(red:0.58,green:0.42,blue:0.76)
    case .focused:Color(red:0.91,green:0.31,blue:0.16)
    }
    Canvas {context,size in
     let center=CGPoint(x:size.width,y:0)
     for (index,radius) in [160.0,120,80,40].enumerated() {
      let circle=Path(ellipseIn:CGRect(x:center.x-radius,y:center.y-radius,width:radius*2,height:radius*2))
      context.fill(circle,with:.color(tint.opacity(0.04+Double(index)*0.01)))
     }
    }.blur(radius:1.5)
   }
  }.clipShape(RoundedRectangle(cornerRadius:26)).accessibilityHidden(true)
 }
 @ViewBuilder private func alarmChallengeSummary(_ alarm:SavedAlarm)->some View {
  let accessible=dynamicTypeSize.isAccessibilitySize
  let layout=accessible ? AnyLayout(HStackLayout(alignment:.center,spacing:12)) : AnyLayout(VStackLayout(alignment:.trailing,spacing:6))
  layout {
   Group {
    if alarm.challenge.kind.hasMovementIllustration {
     MovementIllustration(selection:alarm.challenge)
    } else {
     Image(systemName:alarm.challenge.kind.icon).font(.system(size:21,weight:.medium))
      .frame(maxWidth:.infinity,maxHeight:.infinity)
      .background(MorningTheme.onYellow.opacity(0.05),in:Circle()).accessibilityHidden(true)
    }
   }.frame(width:44,height:44)
   VStack(alignment:accessible ? .leading : .trailing,spacing:3) {
    Text(alarm.challenge.displayTitle).font(.subheadline.weight(.semibold)).fixedSize(horizontal:false,vertical:true)
     .accessibilityIdentifier("alarmChallenge-"+alarm.id.uuidString)
    Text(alarm.mode.title).font(.caption).foregroundStyle(MorningTheme.onYellow.opacity(0.7)).fixedSize(horizontal:false,vertical:true)
     .accessibilityLabel(String(format:appText("Challenge level: %@"),locale:appLocale(),alarm.mode.title))
     .accessibilityIdentifier("alarmMode-"+alarm.id.uuidString)
   }.multilineTextAlignment(accessible ? .leading : .trailing)
  }.frame(width:accessible ? nil : 132,alignment:accessible ? .leading : .trailing)
   .frame(maxWidth:accessible ? .infinity : nil,alignment:accessible ? .leading : .trailing)
 }
 @ViewBuilder private func alarmStatus(_ alarm:SavedAlarm,now:Date,completed:Bool)->some View {
  VStack(alignment:.leading,spacing:4) {
   if alarm.state == .needsReview || alarm.state == .pending {
    Label {
     Text(alarm.state.title).accessibilityIdentifier("alarmState-"+alarm.id.uuidString)
    } icon: {
     Image(systemName:alarm.state == .needsReview ? "exclamationmark.triangle" : "clock").accessibilityHidden(true)
    }.font(.caption.weight(.semibold)).fixedSize(horizontal:false,vertical:true)
   } else if alarm.enabled,alarm.state == .confirmed,let next=alarm.time.next(after:now) {
    Text(String(format:appText("Next: %@"),locale:appLocale(),next.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(appLocale()))))
     .font(.caption).foregroundStyle(MorningTheme.onYellow.opacity(0.7)).fixedSize(horizontal:false,vertical:true)
     .accessibilityIdentifier("nextAlarm-"+alarm.id.uuidString)
   }
   if completed {
    Label(appText("Completed today"),systemImage:"checkmark.circle.fill")
     .font(.caption.weight(.medium)).foregroundStyle(alarm.enabled ? MorningTheme.successOnYellow : MorningTheme.success).fixedSize(horizontal:false,vertical:true)
     .accessibilityIdentifier("alarmCompleted-"+alarm.id.uuidString)
   }
  }
 }
 @ViewBuilder private func tryAlarmButton(_ alarm:SavedAlarm)->some View {
  if alarm.enabled,alarm.challenge.kind != .none {
   Button {revealedAlarmID=nil;model.rehearsal=true;model.selected=alarm} label: {
    Image(systemName:"play.circle").font(.system(size:22,weight:.medium))
     .foregroundStyle(MorningTheme.onYellow.opacity(0.8))
     .frame(width:44,height:44).contentShape(Rectangle())
   }.buttonStyle(.plain).accessibilityLabel(appText("Try this challenge"))
    .accessibilityIdentifier("tryAlarm-"+alarm.id.uuidString)
  }
 }

}
