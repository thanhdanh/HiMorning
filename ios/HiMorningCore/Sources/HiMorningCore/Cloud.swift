import Foundation
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
 public init(session:CloudSession,evidenceID:UUID,frames:[EvidenceFrame]) {
  sessionID=session.sessionID;nonce=session.nonce;self.evidenceID=evidenceID.uuidString.lowercased();consentVersion="2026-10-11"
  self.frames=frames.enumerated().map {SubmissionFrame(id:"f\($0.offset)",timestampMs:$0.element.timestampMs,jpegBase64:$0.element.jpeg.base64EncodedString())}
 }
}
public protocol CloudVerification: Sendable {
 func create(target:Int,requestID:UUID) async throws -> CloudSession
 func verify(_ request:VerificationSubmission) async throws -> CloudDecision
 func cancel(sessionID:String) async throws
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
 public init(alarm:SavedAlarm,cloud:(any CloudVerification)?,scheduler:any AlarmScheduler,rehearsal:Bool=false) {
  self.alarm=alarm;self.cloud=cloud;self.scheduler=scheduler;self.rehearsal=rehearsal;session=WakeSession(mode:alarm.mode)
 }
 public func startCloud(consent:Bool) async throws {
  guard consent else {throw ChallengeError.consentRequired}
  guard let cloud,alarm.mode.policy.reps>0 else {throw ChallengeError.cloudUnavailable}
  let generation=session.generation
  let created=try await cloud.create(target:alarm.mode.policy.reps,requestID:UUID())
  guard session.outcome == nil,session.generation==generation else {try? await cloud.cancel(sessionID:created.sessionID);return}
  self.consent=true;cloudSession=created
 }
 public func submit(_ frames:[EvidenceFrame]) async throws -> Bool {
  guard consent else {throw ChallengeError.consentRequired}
  guard let cloud,let remote=cloudSession else {throw ChallengeError.cloudUnavailable}
  guard remote.expiresAt>Date().timeIntervalSince1970*1000 else {throw ChallengeError.expired}
  guard !submitted else {throw ChallengeError.alreadySubmitted}
  guard frames.count>=alarm.mode.policy.reps*5,frames.count<=25 else {throw ChallengeError.insufficientEvidence}
  submitted=true
  let generation=session.beginVerification()
  let decision=try await cloud.verify(VerificationSubmission(session:remote,evidenceID:UUID(),frames:frames))
  guard consent,session.outcome == nil,session.generation==generation else {return false}
  lastDecision=decision
  guard decision.status=="verified",!decision.decisionID.isEmpty,decision.verifiedRepCount==alarm.mode.policy.reps else {return false}
  if !rehearsal {try await scheduler.stop(id:alarm.id)}
  return session.applyVerified(generation:generation)
 }
 public func finish(_ outcome:WakeOutcome) async throws {
  switch outcome {case .dismissed:session.stop();case .selfConfirmed:session.selfConfirm();case .openaiVerified:throw ChallengeError.unsupportedOutcome}
  consent=false
  // Native stop always precedes network cleanup.
  var stopError:Error?
  if !rehearsal {do {try await scheduler.stop(id:alarm.id)} catch {stopError=error}}
  if let remote=cloudSession {try? await cloud?.cancel(sessionID:remote.sessionID)}
  cloudSession=nil
  if let stopError {throw stopError}
 }
}
