import Foundation
public enum CloudConsent {
 public static let modal="2026-10-15"
 public static let demo="2026-10-15-free-demo"
}
public struct CloudSession: Codable, Sendable {
 public let sessionID:String;public let nonce:String;public let expiresAt:Double
 public init(sessionID:String,nonce:String,expiresAt:Double) {self.sessionID=sessionID;self.nonce=nonce;self.expiresAt=expiresAt}
}
public struct CloudDecision: Codable, Sendable {
 public let status:String;public let decisionID:String;public let verifiedRepCount:Int?
 public init(status:String,decisionID:String,verifiedRepCount:Int?) {self.status=status;self.decisionID=decisionID;self.verifiedRepCount=verifiedRepCount}
}
public struct SubmissionFrame: Codable, Sendable {public let id:String;public let timestampMs:Int;public let jpegBase64:String}
public struct VerificationSubmission: Codable, Sendable {
 public let sessionID:String;public let nonce:String;public let evidenceID:String;public let consentVersion:String
 public let frames:[SubmissionFrame]
 public init(session:CloudSession,evidenceID:UUID,frames:[EvidenceFrame],consentVersion:String=CloudConsent.modal) {
  sessionID=session.sessionID;nonce=session.nonce;self.evidenceID=evidenceID.uuidString.lowercased();self.consentVersion=consentVersion
  self.frames=frames.enumerated().map {SubmissionFrame(id:"f\($0.offset)",timestampMs:$0.element.timestampMs,jpegBase64:$0.element.jpeg.base64EncodedString())}
 }
}
public protocol CloudVerification: Sendable {
 var isDemoOnly:Bool {get}
 var consentVersion:String {get}
 func create(target:Int,requestID:UUID) async throws -> CloudSession
 func verify(_ request:VerificationSubmission) async throws -> CloudDecision
 func getResult(sessionID:String,evidenceID:String) async throws ->CloudDecision
 func cancel(sessionID:String) async throws
}
public extension CloudVerification {
 var isDemoOnly:Bool {false}
 var consentVersion:String {CloudConsent.modal}
}
public enum ChallengeError: Error {case consentRequired,cloudUnavailable,expired,insufficientEvidence,alreadySubmitted,unsupportedOutcome}
@MainActor public final class ChallengeCoordinator {
 public private(set) var session:WakeSession
 public private(set) var lastDecision:CloudDecision?
 private let alarm:SavedAlarm
 private let cloud:(any CloudVerification)?
 private let scheduler:any AlarmScheduler
 private let rehearsal:Bool
 private var cloudSession:CloudSession?
 private var consent=false
 private var submitted=false
 private var starting=false
 private var verificationTask:Task<CloudDecision,Error>?
 private let sleep:@Sendable(UInt64) async throws ->Void
 private let clock:()->TimeInterval
 public init(alarm:SavedAlarm,cloud:(any CloudVerification)?,scheduler:any AlarmScheduler,rehearsal:Bool=false,sleep:@escaping @Sendable(UInt64) async throws ->Void={try await Task.sleep(nanoseconds:$0)},clock:@escaping ()->TimeInterval={ProcessInfo.processInfo.systemUptime}) {
  self.alarm=alarm;self.cloud=cloud;self.scheduler=scheduler;self.rehearsal=rehearsal;self.sleep=sleep;self.clock=clock;session=WakeSession(mode:alarm.mode)
 }
 public func startCloud(consent:Bool) async throws {
  guard consent else {throw ChallengeError.consentRequired}
  guard let cloud,alarm.challenge.kind == .pushUps,let target=alarm.challenge.repetitions else {throw ChallengeError.cloudUnavailable}
  if let existing=cloudSession {
   guard existing.expiresAt>Date().timeIntervalSince1970*1000 else {throw ChallengeError.expired}
   return
  }
  guard !starting,!submitted,session.outcome == nil else {throw ChallengeError.alreadySubmitted}
  starting=true;defer {starting=false}
  let generation=session.generation
  let created=try await cloud.create(target:target,requestID:UUID())
  guard session.outcome == nil,session.generation==generation else {try? await cloud.cancel(sessionID:created.sessionID);return}
  self.consent=true;cloudSession=created
 }
 public func submit(_ frames:[EvidenceFrame]) async throws -> Bool {
  guard consent else {throw ChallengeError.consentRequired}
  guard let cloud,let remote=cloudSession else {throw ChallengeError.cloudUnavailable}
  guard remote.expiresAt>Date().timeIntervalSince1970*1000 else {throw ChallengeError.expired}
  guard !submitted else {throw ChallengeError.alreadySubmitted}
  guard let target=alarm.challenge.repetitions,frames.count>=target*5,frames.count<=ChallengeSelection.maximumPushUps*5 else {throw ChallengeError.insufficientEvidence}
  var evidence=EvidenceBuffer()
  for frame in frames {guard evidence.append(frame.jpeg,timestampMs:frame.timestampMs) else {throw ChallengeError.insufficientEvidence}}
  submitted=true
  let generation=session.beginVerification()
  let request=VerificationSubmission(session:remote,evidenceID:UUID(),frames:frames,consentVersion:cloud.consentVersion)
  let task=Task { @MainActor in
   let deadline=self.clock()+180
   var decision=try await cloud.verify(request)
   var delay=2.0
   while decision.status=="pending" {
    try Task.checkCancellation()
    guard self.consent,self.session.outcome == nil,self.session.generation==generation else {throw CancellationError()}
    self.lastDecision=decision
    let remaining=deadline-self.clock()
    guard remaining>0 else {try? await cloud.cancel(sessionID:remote.sessionID);throw ChallengeError.cloudUnavailable}
    try await self.sleep(UInt64(min(delay,remaining)*1_000_000_000))
    try Task.checkCancellation()
    guard self.clock()<deadline else {try? await cloud.cancel(sessionID:remote.sessionID);throw ChallengeError.cloudUnavailable}
    decision=try await cloud.getResult(sessionID:remote.sessionID,evidenceID:request.evidenceID)
    delay=delay<8 ? delay*2:10
   }
   return decision
  }
  verificationTask=task
  defer {if session.generation==generation {verificationTask=nil}}
  let decision:CloudDecision
  do {decision=try await task.value} catch is CancellationError {return false}
  guard consent,session.outcome == nil,session.generation==generation else {return false}
  lastDecision=decision
  guard !cloud.isDemoOnly,decision.status=="verified",!decision.decisionID.isEmpty,decision.verifiedRepCount==target else {return false}
  if !rehearsal {try await scheduler.stop(id:alarm.id)}
  return session.applyVerified(generation:generation)
 }
 public func suspend() async {
  verificationTask?.cancel();verificationTask=nil
  consent=false;session.interruptVerification()
  let remote=cloudSession
  cloudSession=nil
  if let remote {try? await cloud?.cancel(sessionID:remote.sessionID)}
 }
 public func finish(_ outcome:WakeOutcome) async throws {
  switch outcome {
  case .dismissed:session.stop()
  case .selfConfirmed:session.selfConfirm()
  case .localCompleted:
   guard [.readAndChoose,.guidedRhythm,.readAloud].contains(alarm.challenge.kind) else {throw ChallengeError.unsupportedOutcome}
   _ = session.completeLocally()
  case .openaiVerified,.aiVerified:throw ChallengeError.unsupportedOutcome
  }
  consent=false
  verificationTask?.cancel();verificationTask=nil
  // Native stop always precedes network cleanup.
  var stopError:Error?
  if !rehearsal {do {try await scheduler.stop(id:alarm.id)} catch {stopError=error}}
  if let remote=cloudSession {try? await cloud?.cancel(sessionID:remote.sessionID)}
  cloudSession=nil
  if let stopError {throw stopError}
 }
}
