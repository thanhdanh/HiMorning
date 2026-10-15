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
 @Published var journal:MorningJournal?
 @Published var progressError:String?
 let scheduler=NativeAlarmScheduler()
 let cloud:(any CloudVerification)?
 private let library:AlarmLibrary?
 init() {
  if Bundle.main.url(forResource:"GoogleService-Info",withExtension:"plist") != nil {
   AppCheck.setAppCheckProviderFactory(AttestationFactory());FirebaseApp.configure();cloud=FirebaseCloud()
  } else {cloud=nil}
  do {
   let url=try FileManager.default.url(for:.applicationSupportDirectory,in:.userDomainMask,appropriateFor:nil,create:true).appendingPathComponent("HiMorning/alarms.json")
   library=try AlarmLibrary(persistence:FileAlarmPersistence(url:url),scheduler:scheduler)
  } catch {library=nil;self.error=appText("Your saved alarms could not be read. Changes are paused.")}
  do {
   let url=try FileManager.default.url(for:.applicationSupportDirectory,in:.userDomainMask,appropriateFor:nil,create:true).appendingPathComponent("HiMorning/mornings.json")
   journal=try MorningJournal(url:url)
  } catch {progressError=appText("Your progress could not be read. Your alarms are unchanged.")}
 }
 func recordMorning(id:UUID,outcome:WakeOutcome,rehearsal:Bool) {
  guard journal != nil else {return}
  do {try journal?.record(MorningEntry(id:id,outcome:outcome),rehearsal:rehearsal)}
  catch {progressError=appText("Your progress could not be saved. Your alarm is already stopped.")}
 }
 func setGoal(_ goal:Int) {
  guard subscriptions.isPro,journal != nil else {return}
  do {try journal?.setWeeklyGoal(goal);progressError=nil}
  catch {progressError=appText("Your goal could not be saved. Please try again.")}
 }
 func clearHistory() {
  do {try journal?.clear();progressError=nil}
  catch {progressError=appText("Your history could not be cleared. Please try again.")}
 }
 func refresh() async {
  guard let library else {return}
  do {try await library.reconcile()} catch {self.error=appText("Your alarms could not be checked. Please check alarm access.")}
  alarms=await library.all();openPending()
 }
 func add(time:AlarmTime,mode:WakeMode,sound:AlarmSound,challenge:ChallengeSelection) async {
  guard let library else {return}
  do {try await library.add(SavedAlarm(time:time,mode:mode,sound:sound,challenge:challenge))} catch {self.error=appText("This alarm could not be confirmed. Please check your system alarms before relying on it.")}
  alarms=await library.all()
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
}
extension AlarmSound {
 var title:String {switch self {case .system:return appText("System sound");case .sunrise:return appText("Sunrise");case .softChime:return appText("Soft chime")}}
}
extension ChallengeKind {
 var editorIdentifier:String {switch self {case .none:return "none";case .pushUps:return "pushUps";case .readAndChoose:return "readAndChoose";case .guidedRhythm:return "guidedRhythm";case .readAloud:return "readAloud"}}
 var title:String {switch self {case .none:return appText("No challenge");case .pushUps:return appText("Push-ups");case .readAndChoose:return appText("Read & Choose");case .guidedRhythm:return appText("Guided Rhythm");case .readAloud:return appText("Read Aloud")}}
 var summary:String {switch self {
  case .none:return appText("Confirm you are awake when you are ready.")
  case .pushUps:return appText("Complete a short camera-checked movement challenge.")
  case .readAndChoose:return appText("Read one short sentence and choose its meaning.")
  case .guidedRhythm:return appText("Follow a simple standing or seated rhythm on camera.")
  case .readAloud:return appText("Read the sentence aloud. 80% recognized-word match completes it.")
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
 @ObservedObject var model:PilotModel
 @Environment(\.scenePhase) private var phase
 @State private var editor=false
 @State private var progress=false
 @State private var pro=false
 @AppStorage("appLanguage") private var language="system"
 @ScaledMetric(relativeTo:.largeTitle) private var clockSize=58
 var body:some View {
  NavigationStack {
   ScrollView {
    VStack(alignment:.leading,spacing:24) {
     HStack {
      Label("HiMorning.",systemImage:"sunrise").font(.title2.bold()).labelStyle(.titleAndIcon)
      Spacer()
      Button {progress=true} label:{Image(systemName:"chart.bar").frame(width:44,height:44)}
       .accessibilityIdentifier("morningProgress").accessibilityLabel(appText("Your progress"))
      Button {pro=true} label:{Image(systemName:"sun.max").frame(width:44,height:44)}
       .accessibilityIdentifier("hiMorningPro").accessibilityLabel("HiMorning Pro")
      Menu {
       Picker(appText("Language"),selection:$language) {
        Text(appText("Use device language")).tag("system")
        Text(appText("English")).tag("en")
        Text(appText("Vietnamese")).tag("vi")
       }
      } label: {Image(systemName:"globe").frame(width:44,height:44).background(MorningTheme.soft,in:Circle())}
       .accessibilityIdentifier("appLanguage").accessibilityLabel(appText("Language"))
     }
     VStack(alignment:.leading,spacing:8) {
      Text(appText("A fresh start,\nat your pace.").replacingOccurrences(of:"\n",with:" ")).font(.title2.weight(.semibold))
      Text(appText("Start with a morning that feels right.")).font(.subheadline).foregroundStyle(MorningTheme.muted)
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
     ForEach(model.alarms) {alarm in alarmCard(alarm)}
     Button {editor=true} label:{Label(appText("Add alarm"),systemImage:"plus")}
      .buttonStyle(MorningButtonStyle()).accessibilityIdentifier("addAlarm")
      Menu {
       ForEach(ChallengeKind.allCases,id:\.self) {kind in
        Button(kind.title) {
         if let time=try? AlarmTime(hour:6,minute:30,weekdays:[]) {
          model.rehearsal=true;model.selected=SavedAlarm(time:time,mode:.balanced,challenge:ChallengeSelection(kind:kind))
         }
        }.accessibilityIdentifier("practice-"+kind.editorIdentifier)
       }
      } label: {Text(appText("Try a challenge")).frame(maxWidth:.infinity)}
       .buttonStyle(MorningButtonStyle(primary:false)).accessibilityIdentifier("practiceChallenges")
     Text(appText("You can always stop. A challenge is just a little help to start your day.")).font(.footnote).foregroundStyle(MorningTheme.muted)
    }.padding(20)
   }.background(MorningTheme.canvas.ignoresSafeArea()).foregroundStyle(MorningTheme.ink).tint(MorningTheme.accent)
   .navigationTitle("HiMorning").toolbar(.hidden,for:.navigationBar)
   .sheet(isPresented:$editor) {AlarmEditor {time,mode,sound,challenge in Task {await model.add(time:time,mode:mode,sound:sound,challenge:challenge)}}}
   .sheet(isPresented:$progress) {MorningProgressView(model:model,store:model.subscriptions)}
   .sheet(isPresented:$pro) {ProView(store:model.subscriptions)}
   .fullScreenCover(item:$model.selected) {alarm in ChallengeView(alarm:alarm,model:model)}
   .alert(appText("Please check"),isPresented:Binding(get:{model.error != nil},set:{if !$0 {model.error=nil}})) {Button(appText("Got it")) {model.error=nil}} message:{Text(model.error ?? "")}
   .task {await model.refresh()}
   .task {model.subscriptions.start();await model.subscriptions.refresh()}
   .onReceive(NotificationCenter.default.publisher(for:UserDefaults.didChangeNotification).receive(on:RunLoop.main)) {_ in model.openPending()}
   .onChange(of:phase) {_,value in if value == .active {Task {await model.refresh();await model.subscriptions.refresh()}}}
  }
 }
 private func alarmCard(_ alarm:SavedAlarm)->some View {
  VStack(alignment:.leading,spacing:14) {
   HStack {
    Text(appText("Alarm")).font(.caption.weight(.semibold))
    Spacer()
    Button(alarm.enabled ? appText("Turn off") : appText("Turn on")) {Task {await model.toggle(alarm)}}
     .buttonStyle(.plain).font(.subheadline.weight(.semibold)).padding(12).background(alarm.enabled ? Color.white.opacity(0.5) : MorningTheme.surface,in:Capsule())
   }
   Text(String(format:"%02d:%02d",alarm.time.hour,alarm.time.minute)).font(.system(size:clockSize,weight:.regular,design:.rounded)).monospacedDigit()
   Text(alarm.mode.title+" · "+alarm.sound.title).font(.subheadline)
   Text(alarm.challenge.displayTitle).font(.subheadline.weight(.medium))
   Text(alarm.state.title).font(.caption.weight(.semibold))
   Divider()
   HStack {
    Button(appText("Try a challenge")) {model.rehearsal=true;model.selected=alarm}.buttonStyle(.plain).padding(.vertical,12)
    Spacer()
    Button(appText("Delete"),role:.destructive) {Task {await model.remove(alarm)}}.buttonStyle(.plain).padding(12)
   }.font(.subheadline.weight(.medium))
  }.padding(24).foregroundStyle(alarm.enabled ? MorningTheme.onYellow : MorningTheme.ink)
   .background(alarm.enabled ? MorningTheme.hero : MorningTheme.soft,in:RoundedRectangle(cornerRadius:24))
 }
}
