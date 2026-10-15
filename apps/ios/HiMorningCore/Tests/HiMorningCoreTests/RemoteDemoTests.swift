import Foundation
#if !PORTABLE_TESTS
import XCTest
@testable import HiMorningCore
#endif
final class RemoteDemoTests:XCTestCase {
 func testEndpointRejectsUntrustedURLs() throws {
  XCTAssertEqual(try WorkerEndpoint("https://demo.account.workers.dev").url.host,"demo.account.workers.dev")
  for value in ["http://demo.account.workers.dev","https://attacker.test","https://demo.workers.dev/extra","https://user:secret@demo.workers.dev","https://demo.workers.dev?token=secret","https://demo.workers.dev:8443"] {XCTAssertThrowsError(try WorkerEndpoint(value))}
 }
 func testGeneratedFramesShareTheServerFixtureAndBounds() throws {
  #if PORTABLE_TESTS
  let root=URL(fileURLWithPath:CommandLine.arguments[1])
  #else
  let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("shared/contracts/v1")
  #endif
  let data=try Data(contentsOf:root.appendingPathComponent("free-demo-frames.json"))
  let wire=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("free-demo-wire.json"))) as! [String:Any]
  let session=try JSONDecoder().decode(CloudSession.self,from:JSONSerialization.data(withJSONObject:wire["CreateResponse"]!))
  let submission=wire["SubmitRequest"] as! [String:Any]
  let encoded=VerificationSubmission(session:session,evidenceID:UUID(uuidString:submission["evidenceID"] as! String)!,frames:try RemoteDemo.frames(from:data,target:1),consentVersion:CloudConsent.demo)
  XCTAssertEqual(try JSONSerialization.jsonObject(with:JSONEncoder().encode(encoded)) as! NSDictionary,submission as NSDictionary)
  for target in [1,3,5,10,20,50] {
   let frames=try RemoteDemo.frames(from:data,target:target)
   XCTAssertEqual(frames.count,target*5);XCTAssertTrue(frames.allSatisfy{$0.jpeg.count<=50000})
  }
  let object=try JSONSerialization.jsonObject(with:data) as! [String:Any]
  let original=object["frames"] as! [[String:Any]]
  let legacy=try JSONSerialization.data(withJSONObject:["frames":Array(original.prefix(25))])
  XCTAssertEqual(try RemoteDemo.frames(from:legacy,target:5).count,25)
  XCTAssertThrowsError(try RemoteDemo.frames(from:legacy,target:10))
  let previous=try JSONSerialization.data(withJSONObject:["frames":Array(original.prefix(100))])
  XCTAssertEqual(try RemoteDemo.frames(from:previous,target:20).count,100)
  XCTAssertThrowsError(try RemoteDemo.frames(from:previous,target:50))
  var corrupt=original
  corrupt[corrupt.count-1]["id"]="invalid"
  XCTAssertThrowsError(try RemoteDemo.frames(from:JSONSerialization.data(withJSONObject:["frames":corrupt]),target:1))
  XCTAssertThrowsError(try RemoteDemo.frames(from:data,target:51))
  XCTAssertThrowsError(try RemoteDemo.frames(from:Data("{}".utf8),target:1))
 }
 @MainActor func testDemoCannotStopAnAlarmOrRecordVerifiedEvenWithAMaliciousSuccess() async throws {
  let cloud=DemoCloud(),scheduler=DemoScheduler()
  let flow=ChallengeCoordinator(alarm:SavedAlarm(time:try AlarmTime(hour:6,minute:30,weekdays:[]),mode:.balanced,challenge:.pushUps(repetitions:3)),cloud:cloud,scheduler:scheduler)
  try await flow.startCloud(consent:true)
  let applied=try await flow.submit((0..<15).map{EvidenceFrame(jpeg:Data([UInt8($0)]),timestampMs:$0*300)})
  XCTAssertFalse(applied);XCTAssertNil(flow.session.outcome)
  let stops=await scheduler.stops,version=await cloud.version
  XCTAssertEqual(stops,0);XCTAssertEqual(version,CloudConsent.demo)
 }
}
private actor DemoCloud:CloudVerification {
 nonisolated var isDemoOnly:Bool {true}
 nonisolated var consentVersion:String {CloudConsent.demo}
 private(set) var version:String?
 func create(target:Int,requestID:UUID) async throws ->CloudSession {CloudSession(sessionID:String(repeating:"a",count:64),nonce:UUID().uuidString,expiresAt:Date().addingTimeInterval(600).timeIntervalSince1970*1000)}
 func verify(_ request:VerificationSubmission) async throws ->CloudDecision {version=request.consentVersion;return CloudDecision(status:"verified",decisionID:"malicious",verifiedRepCount:3)}
 func getResult(sessionID:String,evidenceID:String) async throws ->CloudDecision {throw ChallengeError.cloudUnavailable}
 func cancel(sessionID:String) async throws {}
}
private actor DemoScheduler:AlarmScheduler {
 private(set) var stops=0
 func schedule(_ alarm:SavedAlarm) async throws {}
 func cancel(id:UUID) async throws {}
 func stop(id:UUID) async throws {stops+=1}
 func scheduledIDs() async throws ->Set<UUID> {[]}
}
