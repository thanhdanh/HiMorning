import Foundation
import FirebaseCore
import FirebaseAppCheck
@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseFunctions
import HiMorningCore
final class AttestationFactory:NSObject,AppCheckProviderFactory {
 func createProvider(with app:FirebaseApp) -> AppCheckProvider? {
  #if DEBUG
  if app.options.projectID=="himorning-staging-0109" {return AppCheckDebugProvider(app:app)}
  #endif
  return AppAttestProvider(app:app)
 }
}
actor FirebaseCloud:CloudVerification {
 private let functions=Functions.functions(region:"asia-southeast1")
 private let endpoint:URL
 nonisolated let isDemoOnly=true
 nonisolated var consentVersion:String {CloudConsent.demo}
 init(endpoint:WorkerEndpoint){self.endpoint=endpoint.url}
 private func call<T:Decodable>(_ name:String,_ data:[String:Any],as type:T.Type) async throws -> T {
  if Auth.auth().currentUser == nil {_ = try await Auth.auth().signInAnonymously()}
  let callable=functions.httpsCallable(endpoint.appendingPathComponent(name));callable.timeoutInterval=30
  let response=try await callable.call(data)
  return try JSONDecoder().decode(type,from:JSONSerialization.data(withJSONObject:response.data))
 }
 func create(target:Int,requestID:UUID) async throws -> CloudSession {
  try await call("createVerificationSession",["requestID":requestID.uuidString.lowercased(),"challenge":"pushup","target":target,"consentVersion":consentVersion],as:CloudSession.self)
 }
 func verify(_ request:VerificationSubmission) async throws -> CloudDecision {
  let data=try JSONSerialization.jsonObject(with:JSONEncoder().encode(request)) as! [String:Any]
  return try await call("verifyChallenge",data,as:CloudDecision.self)
 }
 func getResult(sessionID:String,evidenceID:String) async throws ->CloudDecision {
  try await call("getVerificationResult",["sessionID":sessionID,"evidenceID":evidenceID],as:CloudDecision.self)
 }
 func cancel(sessionID:String) async throws {
  struct Cancelled:Decodable {let status:String}
  _ = try await call("cancelVerificationSession",["sessionID":sessionID],as:Cancelled.self)
 }
}
