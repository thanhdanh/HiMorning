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
@MainActor final class PilotModel:ObservableObject {
 @Published var alarms:[SavedAlarm]=[]
 @Published var error:String?
 @Published var selected:SavedAlarm?
 @Published var rehearsal=false
 let subscriptions=SubscriptionStore()
 lazy var preview=PreviewStore(subscriptions:subscriptions)
 private var accessObserver:AnyCancellable?
 var access:MorningAccess {preview.access}
 @Published var journal:MorningJournal?
 @Published var progressError:String?
 let scheduler=NativeAlarmScheduler()
 let cloud:(any CloudVerification)?
 private let library:AlarmLibrary?
 init() {
  if Bundle.main.url(forResource:"GoogleService-Info",withExtension:"plist") != nil {
   AppCheck.setAppCheckProviderFactory(AttestationFactory());FirebaseApp.configure()
   if let configURL=Bundle.main.url(forResource:"HiMorningCloud-Info",withExtension:"plist") {
    if let data=try? Data(contentsOf:configURL),let values=try? PropertyListDecoder().decode([String:String].self,from:data),let origin=values["WorkerURL"],let endpoint=try? WorkerEndpoint(origin) {cloud=FirebaseCloud(endpoint:endpoint)}
    else {cloud=nil}
   } else {cloud=nil}
  } else {cloud=nil}
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
     fixtures=[fixture,upcoming,disabled]
     if ProcessInfo.processInfo.arguments.contains("--ui-open-alarm") {UserDefaults.standard.set(fixture.id.uuidString,forKey:"pendingAlarmID")}
    }
    try FileAlarmPersistence(url:url).save(fixtures)
   }
   #endif
   library=try AlarmLibrary(persistence:FileAlarmPersistence(url:url),scheduler:scheduler)
  } catch {library=nil;self.error=appText("Your saved alarms could not be read. Changes are paused.")}
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
 func recordMorning(id:UUID,alarm:SavedAlarm,outcome:WakeOutcome,rehearsal:Bool) {
  guard journal != nil else {return}
  do {try journal?.record(MorningEntry(id:id,alarmID:alarm.id,mode:alarm.mode,challenge:alarm.challenge,outcome:outcome),rehearsal:rehearsal)}
  catch {progressError=appText("Your progress could not be saved. Your alarm is already stopped.")}
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
  openPending()
 }
 func save(_ alarm:SavedAlarm) async throws {
  #if DEBUG
  if ProcessInfo.processInfo.arguments.contains("--ui-testing"),ProcessInfo.processInfo.arguments.contains("--ui-alarm-save-failure") {
   try await Task.sleep(for:.seconds(2));throw LibraryError.notFound
  }
  #endif
  guard let library else {throw LibraryError.notFound}
  preview.refresh()
  do {
   let effective=access.effectiveAlarm(alarm)
   if await library.all().contains(where:{$0.id==alarm.id}) {try await library.update(effective)}
   else {try await library.add(effective)}
   alarms=await library.all()
   if alarms.contains(where:{$0.state == .confirmed}) {preview.start()}
  } catch {alarms=await library.all();throw error}
 }
 func toggle(_ alarm:SavedAlarm) async {
  guard let library else {return}
  do {if alarm.enabled {try await library.disable(id:alarm.id)} else {try await library.enable(id:alarm.id)}} catch {self.error=appText("This change could not be confirmed. Please check your system alarms.")}
  alarms=await library.all()
 }
 func remove(_ alarm:SavedAlarm) async {
  guard let library else {return}
  do {try await library.remove(id:alarm.id)} catch {self.error=appText("This alarm could not be removed. It may still be set in the system.")}
  alarms=await library.all()
 }
 func openPending() {
  guard let raw=UserDefaults.standard.string(forKey:"pendingAlarmID"),let id=UUID(uuidString:raw),let alarm=alarms.first(where:{$0.id==id}) else {return}
  UserDefaults.standard.removeObject(forKey:"pendingAlarmID");rehearsal=false;selected=alarm
 }
}
extension WakeMode {
 var title:String {switch self {case .gentle:return appText("Gentle");case .balanced:return appText("Balanced");case .focused:return appText("Focused")}}
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
 var editorIdentifier:String {switch self {case .none:return "none";case .pushUps:return "pushUps";case .readAndChoose:return "readAndChoose";case .guidedRhythm:return "guidedRhythm";case .readAloud:return "readAloud"}}
 var title:String {switch self {case .none:return appText("No challenge");case .pushUps:return appText("Push-ups");case .readAndChoose:return appText("Read & Choose");case .guidedRhythm:return appText("Guided Rhythm");case .readAloud:return appText("Read Aloud")}}
 var summary:String {switch self {
  case .none:return appText("Confirm you are awake when you are ready.")
  case .pushUps:return appText("Complete a short camera-checked movement challenge.")
  case .readAndChoose:return appText("Read one short sentence and choose its meaning.")
  case .guidedRhythm:return appText("Follow a simple standing or seated rhythm on camera.")
  case .readAloud:return appText("Read the English sentence aloud. See your score and matching words as you read.")
 }}
 var icon:String {switch self {case .none:return "hand.tap";case .pushUps:return "figure.strengthtraining.traditional";case .readAndChoose:return "text.book.closed";case .guidedRhythm:return "figure.cooldown";case .readAloud:return "waveform"}}
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
 private struct AlarmDraft:Identifiable {let id=UUID();let alarm:SavedAlarm?}
 @ObservedObject var model:PilotModel
 @Environment(\.scenePhase) private var phase
 @State private var editor:AlarmDraft?
 @State private var progress=false
 @State private var pro=false
 @AppStorage("appLanguage") private var language="system"
 @ScaledMetric(relativeTo:.largeTitle) private var clockSize=46
 var body:some View {
  NavigationStack {
   ScrollView {
    VStack(alignment:.leading,spacing:16) {
     HStack(spacing:12) {
      Label("HiMorning.",systemImage:"sunrise").font(.title3.bold()).labelStyle(.titleAndIcon)
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
      ForEach(model.alarms) {alarm in alarmCard(alarm,now:Date())}
     }
     Button {editor=AlarmDraft(alarm:nil)} label:{Label(appText("Add alarm"),systemImage:"plus")}
      .buttonStyle(MorningButtonStyle()).accessibilityIdentifier("addAlarm")
      Menu {
       ForEach(ChallengeKind.allCases,id:\.self) {kind in
        Button(kind.title) {
         if let time=try? AlarmTime(hour:6,minute:30,weekdays:[]) {
          model.rehearsal=true;model.selected=SavedAlarm(time:time,mode:.balanced,challenge:ChallengeSelection(kind:kind))
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
   .sheet(item:$editor) {draft in AlarmEditor(alarm:draft.alarm,store:model.subscriptions,preview:model.preview,save:model.save)}
   .sheet(isPresented:$progress) {MorningProgressView(model:model,store:model.subscriptions)}
   .sheet(isPresented:$pro) {ProView(store:model.subscriptions,preview:model.preview)}
   .fullScreenCover(item:$model.selected,onDismiss:{Task {await model.refresh()}}) {alarm in ChallengeView(alarm:alarm,model:model)}
   .alert(appText("Please check"),isPresented:Binding(get:{model.error != nil},set:{visible in
    guard !visible,let shown=model.error else {return}
    DispatchQueue.main.async {if model.error==shown {model.error=nil}}
   })) {Button(appText("Got it")) {model.error=nil}} message:{Text(model.error ?? "")}
   .task {await model.refresh()}
   .task {model.subscriptions.start();await model.subscriptions.refresh()}
   .onReceive(NotificationCenter.default.publisher(for:UserDefaults.didChangeNotification).receive(on:RunLoop.main)) {_ in model.openPending()}
   .onChange(of:phase) {_,value in if value == .active {Task {await model.refresh();await model.subscriptions.refresh()}}}
  }
 }
 private func alarmCard(_ alarm:SavedAlarm,now:Date)->some View {
  let completed=model.journal?.completedToday(alarmID:alarm.id,now:now) ?? false
  let time=String(format:"%02d:%02d",alarm.time.hour%12 == 0 ? 12 : alarm.time.hour%12,alarm.time.minute)
  let period=alarm.time.hour<12 ? "AM" : "PM"
  return VStack(alignment:.leading,spacing:10) {
   HStack(spacing:12) {
    VStack(alignment:.leading,spacing:4) {
     HStack(spacing:8) {
      if alarm.enabled {
       HStack(alignment:.firstTextBaseline,spacing:6) {
        Text(time).font(.system(size:clockSize,weight:.medium,design:.rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
         .accessibilityLabel(time+" "+period).accessibilityIdentifier("alarmTime-"+alarm.id.uuidString)
        Text(verbatim:period).font(.caption.weight(.semibold)).accessibilityHidden(true)
       }
      } else {
       Button {editor=AlarmDraft(alarm:alarm)} label: {
       HStack(alignment:.firstTextBaseline,spacing:6) {
        Text(time).font(.system(size:clockSize*0.7,weight:.regular,design:.rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
        Text(verbatim:period).font(.caption.weight(.medium))
       }.frame(minHeight:44).contentShape(Rectangle())
      }.buttonStyle(.plain).accessibilityLabel(appText("Edit")+" "+time+" "+period).accessibilityIdentifier("editAlarm-"+alarm.id.uuidString)
      }
      if completed,!alarm.enabled {
       Image(systemName:"checkmark.circle.fill").foregroundStyle(MorningTheme.success).accessibilityLabel(appText("Completed today")).accessibilityIdentifier("alarmCompleted-"+alarm.id.uuidString)
      }
     }
     if !alarm.enabled {Text(appText("Off")).font(.caption.weight(.medium)).foregroundStyle(MorningTheme.ink)}
     else if alarm.state == .confirmed,let next=alarm.time.next(after:now) {
      Text(String(format:appText("Next: %@"),locale:appLocale(),next.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(appLocale()))))
       .font(.caption).foregroundStyle(MorningTheme.onYellow.opacity(0.75)).accessibilityIdentifier("nextAlarm-"+alarm.id.uuidString)
     }
    }
    Spacer()
    Toggle(appText(alarm.enabled ? "Turn off" : "Turn on"),isOn:Binding(get:{alarm.enabled},set:{_ in Task {await model.toggle(alarm)}}))
     .labelsHidden().tint(alarm.enabled ? MorningTheme.successOnYellow : MorningTheme.success).accessibilityIdentifier("toggleAlarm-"+alarm.id.uuidString)
    if !alarm.enabled {
    Button(role:.destructive) {Task {await model.remove(alarm)}} label: {Image(systemName:"trash").frame(width:44,height:44).contentShape(Rectangle())}
     .buttonStyle(.plain).accessibilityLabel(appText("Delete")).accessibilityIdentifier("deleteAlarm-"+alarm.id.uuidString)
    }
   }
   if alarm.enabled {
    Label(alarm.challenge.displayTitle,systemImage:alarm.challenge.kind.icon).font(.subheadline.weight(.semibold)).accessibilityIdentifier("alarmChallenge-"+alarm.id.uuidString)
    HStack(alignment:.top,spacing:12) {
     Label(alarm.mode.title,systemImage:alarm.mode.icon).font(.caption.weight(.medium)).foregroundStyle(MorningTheme.onYellow.opacity(0.75))
      .accessibilityIdentifier("alarmMode-"+alarm.id.uuidString)
     Spacer(minLength:8)
     if completed {
      Label(appText("Completed today"),systemImage:"checkmark.circle.fill").font(.caption.weight(.medium)).foregroundStyle(MorningTheme.successOnYellow).accessibilityIdentifier("alarmCompleted-"+alarm.id.uuidString)
     }
    }
   }
   if alarm.state == .needsReview || alarm.state == .pending {
    Label(alarm.state.title,systemImage:alarm.state == .needsReview ? "exclamationmark.triangle" : "clock")
     .font(.caption.weight(.semibold)).accessibilityIdentifier("alarmState-"+alarm.id.uuidString)
   }
   if alarm.enabled {
    Divider().overlay(MorningTheme.onYellow.opacity(0.15))
    HStack {
     Button {editor=AlarmDraft(alarm:alarm)} label:{Text(appText("Edit")).frame(minWidth:44,minHeight:44).contentShape(Rectangle())}
      .accessibilityIdentifier("editAlarm-"+alarm.id.uuidString)
     Spacer(minLength:8)
     Button {model.rehearsal=true;model.selected=alarm} label:{Text(appText("Try")).frame(minWidth:44,minHeight:44).contentShape(Rectangle())}
      .accessibilityLabel(appText("Try this challenge"))
     Spacer(minLength:8)
     Button(role:.destructive) {Task {await model.remove(alarm)}} label:{Text(appText("Delete")).frame(minWidth:44,minHeight:44).contentShape(Rectangle())}
      .accessibilityIdentifier("deleteAlarm-"+alarm.id.uuidString)
    }.buttonStyle(.plain).font(.footnote.weight(.medium)).foregroundStyle(MorningTheme.onYellow.opacity(0.75))
   }
  }.padding(alarm.enabled ? 18 : 16).foregroundStyle(alarm.enabled ? MorningTheme.onYellow : MorningTheme.muted)
   .background(alarm.enabled ? MorningTheme.hero : MorningTheme.soft,in:RoundedRectangle(cornerRadius:22))
   .overlay {RoundedRectangle(cornerRadius:22).strokeBorder(alarm.enabled ? (completed ? MorningTheme.successOnYellow.opacity(0.35) : MorningTheme.onYellow.opacity(0.12)) : MorningTheme.line,lineWidth:1)}
 }
}
