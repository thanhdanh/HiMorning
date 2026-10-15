import Combine
import Foundation
import Security
import HiMorningCore

@MainActor final class PreviewStore:ObservableObject {
 @Published private(set) var access:MorningAccess = .free
 @Published private(set) var message:String?
 private var period=PreviewPeriod()
 private var healthy=true
 private var paid:MorningAccess = .free
 private let save:(Data)throws->Void
 private let now:()->Date
 private var observer:AnyCancellable?
 private var expiry:Task<Void,Never>?
 var hasStarted:Bool {period.startedAt != nil}
 var remainingDays:Int {hasStarted ? period.remainingDays(now:now()) : 30}
 init(subscriptions:SubscriptionStore,load:()throws->Data? = {try PreviewKeychain.load()},
      save:@escaping(Data)throws->Void = {try PreviewKeychain.save($0)},now:@escaping()->Date = {Date()}) {
  self.save=save;self.now=now
  do {if let data=try load() {period=try JSONDecoder().decode(PreviewPeriod.self,from:data)}}
  catch {healthy=false;message=appText("Your free preview could not be checked. Basic alarms are available.")}
  observer=subscriptions.$access.sink { [weak self] access in
   self?.paid=access;self?.refresh()
  }
 }
 func start() {
  guard healthy,!hasStarted else {refresh();return}
  period.start(now:now());refresh()
 }
 func refresh() {
  expiry?.cancel();expiry=nil
  if healthy,hasStarted {
   period.observe(now:now())
   do {try save(JSONEncoder().encode(period))}
   catch {healthy=false;message=appText("Your free preview could not be saved. Basic alarms are available.")}
  }
  access=paid == .pro ? .pro : (healthy ? (hasStarted ? period.access(now:now()) : .preview) : .free)
  if access == .preview,let end=period.expiresAt {
   let effectiveNow=max(now(),period.lastSeenAt ?? now())
   let seconds=max(0,end.timeIntervalSince(effectiveNow))
   expiry=Task { [weak self] in
    do {try await Task.sleep(for:.seconds(seconds))} catch {return}
    self?.refresh()
   }
  }
 }
 deinit {expiry?.cancel()}
}

enum PreviewKeychain {
 private static func query(service:String)->[String:Any] {
  [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:"period-v1"]
 }
 static func load(service:String="com.himorning.preview") throws ->Data? {
  var request=query(service:service)
  request[kSecReturnData as String]=true;request[kSecMatchLimit as String]=kSecMatchLimitOne
  var result:CFTypeRef?
  let status=SecItemCopyMatching(request as CFDictionary,&result)
  if status == errSecItemNotFound {return nil}
  guard status == errSecSuccess,let data=result as? Data else {throw Failure.status(status)}
  return data
 }
 static func save(_ data:Data,service:String="com.himorning.preview") throws {
  let status=SecItemUpdate(query(service:service) as CFDictionary,[kSecValueData as String:data] as CFDictionary)
  if status == errSecItemNotFound {
   var item=query(service:service);item[kSecValueData as String]=data
   item[kSecAttrAccessible as String]=kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
   let added=SecItemAdd(item as CFDictionary,nil)
   guard added == errSecSuccess else {throw Failure.status(added)}
  } else if status != errSecSuccess {throw Failure.status(status)}
 }
 private enum Failure:Error {case status(OSStatus)}
}
