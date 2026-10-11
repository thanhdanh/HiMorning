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
 }
 func refresh() async {
  guard let library else {return}
  do {try await library.reconcile()} catch {self.error=appText("Your alarms could not be checked. Please check alarm access.")}
  alarms=await library.all();openPending()
 }
 func add(time:AlarmTime,mode:WakeMode,sound:AlarmSound) async {
  guard let library else {return}
  do {try await library.add(SavedAlarm(time:time,mode:mode,sound:sound))} catch {self.error=appText("This alarm could not be confirmed. Please check your system alarms before relying on it.")}
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
 var explanation:String {policy.reps==0 ? appText("Wake up at your own pace") : appText("Try %lld push-ups",count:policy.reps)}
}
extension AlarmSound {
 var title:String {switch self {case .system:return appText("System sound");case .sunrise:return appText("Sunrise");case .softChime:return appText("Soft chime")}}
}
extension ScheduleState {
 var title:String {switch self {case .pending:return appText("Checking…");case .confirmed:return appText("Alarm is set");case .off:return appText("Off");case .needsReview:return appText("Check system alarms")}}
}
struct HomeView:View {
 @ObservedObject var model:PilotModel
 @Environment(\.scenePhase) private var phase
 @State private var editor=false
 @AppStorage("appLanguage") private var language="system"
 var body:some View {
  NavigationStack {
   ScrollView {
    VStack(alignment:.leading,spacing:24) {
     Image(systemName:"sun.max.fill").font(.system(size:42)).foregroundStyle(.orange)
     Text(appText("A fresh start,\nat your pace.")).font(.largeTitle.bold())
     Text(appText("Start with a morning that feels right.")).foregroundStyle(.secondary)
     if model.alarms.isEmpty {ContentUnavailableView(appText("No alarms yet"),systemImage:"alarm",description:Text(appText("Set your first alarm for tomorrow.")))}
     ForEach(model.alarms) {alarm in
      VStack(alignment:.leading,spacing:12) {
       HStack {
        Text(String(format:"%02d:%02d",alarm.time.hour,alarm.time.minute)).font(.system(size:42,weight:.semibold,design:.rounded)).monospacedDigit()
        Spacer()
        Button(alarm.enabled ? appText("Turn off") : appText("Turn on")) {Task {await model.toggle(alarm)}}.buttonStyle(.bordered)
       }
       Text(alarm.mode.title+" · "+alarm.sound.title)
       Text(alarm.state.title).font(.caption).foregroundStyle(alarm.state == .needsReview ? .red : .secondary)
       HStack {
        Button(appText("Try a challenge")) {model.rehearsal=true;model.selected=alarm}
        Spacer()
        Button(appText("Delete"),role:.destructive) {Task {await model.remove(alarm)}}
       }.font(.subheadline)
      }.padding(20).background(Color(.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:24))
     }
     Button {editor=true} label:{Label(appText("Add alarm"),systemImage:"plus").frame(maxWidth:.infinity).padding(8)}.buttonStyle(.borderedProminent).tint(.yellow).foregroundStyle(.black).accessibilityIdentifier("addAlarm")
     Text(appText("You can always stop. A challenge is just a little help to start your day.")).font(.footnote).foregroundStyle(.secondary)
    }.padding(24)
   }.background(Color(.systemGroupedBackground)).navigationTitle("HiMorning")
   .toolbar {ToolbarItem(placement:.topBarTrailing) {
    Picker(selection:$language) {
     Text(appText("Use device language")).tag("system")
     Text(appText("English")).tag("en")
     Text(appText("Vietnamese")).tag("vi")
    } label: {Label(appText("Language"),systemImage:"globe")}
    .pickerStyle(.menu).accessibilityIdentifier("appLanguage").accessibilityLabel(appText("Language"))
   }}
   .sheet(isPresented:$editor) {AlarmEditor {time,mode,sound in Task {await model.add(time:time,mode:mode,sound:sound)}}}
   .fullScreenCover(item:$model.selected) {alarm in ChallengeView(alarm:alarm,model:model)}
   .alert(appText("Please check"),isPresented:Binding(get:{model.error != nil},set:{if !$0 {model.error=nil}})) {Button(appText("Got it")) {model.error=nil}} message:{Text(model.error ?? "")}
   .task {await model.refresh()}
   .onReceive(NotificationCenter.default.publisher(for:UserDefaults.didChangeNotification).receive(on:RunLoop.main)) {_ in model.openPending()}
   .onChange(of:phase) {_,value in if value == .active {Task {await model.refresh()}}}
  }
 }
}
