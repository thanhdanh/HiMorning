import SwiftUI
import Combine
import FirebaseCore
import FirebaseAppCheck
import HiMorningCore
@main struct HiMorningApp:App {
 @StateObject private var model=PilotModel()
 var body:some Scene {WindowGroup {HomeView(model:model)}}
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
  } catch {library=nil;self.error="Không đọc được lịch đã lưu. Chưa thể thay đổi báo thức."}
 }
 func refresh() async {
  guard let library else {return}
  do {try await library.reconcile()} catch {error="Chưa kiểm tra được lịch hệ thống. Hãy kiểm tra quyền báo thức."}
  alarms=await library.all();openPending()
 }
 func add(time:AlarmTime,mode:WakeMode,sound:AlarmSound) async {
  guard let library else {return}
  do {try await library.add(SavedAlarm(time:time,mode:mode,sound:sound))} catch {error="Chưa xác nhận được lịch. Báo thức có thể vẫn tồn tại trong hệ thống; hãy kiểm tra trước khi dựa vào nó."}
  alarms=await library.all()
 }
 func toggle(_ alarm:SavedAlarm) async {
  guard let library else {return}
  do {if alarm.enabled {try await library.disable(id:alarm.id)} else {try await library.enable(id:alarm.id)}} catch {error="Chưa xác nhận được thay đổi. Hãy kiểm tra lịch hệ thống."}
  alarms=await library.all()
 }
 func remove(_ alarm:SavedAlarm) async {
  guard let library else {return}
  do {try await library.remove(id:alarm.id)} catch {error="Chưa xóa được báo thức. Lịch hệ thống có thể vẫn còn."}
  alarms=await library.all()
 }
 func openPending() {
  guard let raw=UserDefaults.standard.string(forKey:"pendingAlarmID"),let id=UUID(uuidString:raw),let alarm=alarms.first(where:{$0.id==id}) else {return}
  UserDefaults.standard.removeObject(forKey:"pendingAlarmID");rehearsal=false;selected=alarm
 }
}
extension WakeMode {
 var title:String {switch self {case .gentle:return "Nhẹ nhàng";case .balanced:return "Cân bằng";case .focused:return "Tập trung"}}
 var explanation:String {policy.reps==0 ? "Thức dậy theo nhịp của bạn" : "Gợi ý \(policy.reps) lần chống đẩy"}
}
extension AlarmSound {
 var title:String {switch self {case .system:return "Âm hệ thống";case .sunrise:return "Nắng mai";case .softChime:return "Chuông dịu"}}
}
extension ScheduleState {
 var title:String {switch self {case .pending:return "Đang xác nhận…";case .confirmed:return "Đã đặt với hệ thống";case .off:return "Đã tắt";case .needsReview:return "Cần kiểm tra lịch hệ thống"}}
}
struct HomeView:View {
 @ObservedObject var model:PilotModel
 @Environment(\.scenePhase) private var phase
 @State private var editor=false
 var body:some View {
  NavigationStack {
   ScrollView {
    VStack(alignment:.leading,spacing:24) {
     Image(systemName:"sun.max.fill").font(.system(size:42)).foregroundStyle(.orange)
     Text("Một ngày mới,\nnhẹ nhàng hơn.").font(.largeTitle.bold())
     Text("Bắt đầu từ một buổi sáng vừa sức.").foregroundStyle(.secondary)
     if model.alarms.isEmpty {ContentUnavailableView("Chưa có báo thức",systemImage:"alarm",description:Text("Đặt giờ đầu tiên cho ngày mai."))}
     ForEach(model.alarms) {alarm in
      VStack(alignment:.leading,spacing:12) {
       HStack {
        Text(String(format:"%02d:%02d",alarm.time.hour,alarm.time.minute)).font(.system(size:42,weight:.semibold,design:.rounded)).monospacedDigit()
        Spacer()
        Button(alarm.enabled ? "Tắt" : "Bật") {Task {await model.toggle(alarm)}}.buttonStyle(.bordered)
       }
       Text(alarm.mode.title+" · "+alarm.sound.title)
       Text(alarm.state.title).font(.caption).foregroundStyle(alarm.state == .needsReview ? .red : .secondary)
       HStack {
        Button("Thử nhiệm vụ") {model.rehearsal=true;model.selected=alarm}
        Spacer()
        Button("Xóa",role:.destructive) {Task {await model.remove(alarm)}}
       }.font(.subheadline)
      }.padding(20).background(Color(.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:24))
     }
     Button {editor=true} label:{Label("Thêm báo thức",systemImage:"plus").frame(maxWidth:.infinity).padding(8)}.buttonStyle(.borderedProminent).tint(.yellow).foregroundStyle(.black).accessibilityIdentifier("addAlarm")
     Text("Bạn luôn có thể dừng. Nhiệm vụ là một lời gợi ý cho buổi sáng.").font(.footnote).foregroundStyle(.secondary)
    }.padding(24)
   }.background(Color(.systemGroupedBackground)).navigationTitle("HiMorning")
   .sheet(isPresented:$editor) {AlarmEditor {time,mode,sound in Task {await model.add(time:time,mode:mode,sound:sound)}}}
   .fullScreenCover(item:$model.selected) {alarm in ChallengeView(alarm:alarm,model:model)}
   .alert("Cần kiểm tra",isPresented:Binding(get:{model.error != nil},set:{if !$0 {model.error=nil}})) {Button("Đã hiểu") {model.error=nil}} message:{Text(model.error ?? "")}
   .task {await model.refresh()}
   .onReceive(NotificationCenter.default.publisher(for:UserDefaults.didChangeNotification).receive(on:RunLoop.main)) {_ in model.openPending()}
   .onChange(of:phase) {_,value in if value == .active {Task {await model.refresh()}}}
  }
 }
}
