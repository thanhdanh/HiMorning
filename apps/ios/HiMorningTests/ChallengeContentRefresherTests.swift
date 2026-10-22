import XCTest
@testable import HiMorning
import HiMorningCore

final class ContentStubProtocol:URLProtocol {
 nonisolated(unsafe) static var handler:((URLRequest) throws -> (HTTPURLResponse,Data))?
 nonisolated(unsafe) static var requests:[URLRequest]=[]
 override class func canInit(with request:URLRequest)->Bool {true}
 override class func canonicalRequest(for request:URLRequest)->URLRequest {request}
 override func startLoading() {
  Self.requests.append(request)
  do {
   let (response,data)=try Self.handler!(request)
   client?.urlProtocol(self,didReceive:response,cacheStoragePolicy:.notAllowed)
   client?.urlProtocol(self,didLoad:data)
   client?.urlProtocolDidFinishLoading(self)
  } catch {client?.urlProtocol(self,didFailWithError:error)}
 }
 override func stopLoading() {}
}

final class ChallengeContentRefresherTests:XCTestCase {
 private let origin=URL(string:"https://himorning.example.workers.dev")!
 private var directory:URL!
 private var defaults:UserDefaults!
 private var suite:String!
 private var clock:Date!

 override func setUpWithError() throws {
  directory=FileManager.default.temporaryDirectory.appendingPathComponent("content-refresher-\(UUID().uuidString)")
  try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
  suite="content-refresher-\(UUID().uuidString)"
  defaults=UserDefaults(suiteName:suite)
  clock=Date(timeIntervalSince1970:1_800_000_000)
  ContentStubProtocol.handler=nil
  ContentStubProtocol.requests=[]
 }

 override func tearDownWithError() throws {
  try? FileManager.default.removeItem(at:directory)
  defaults.removePersistentDomain(forName:suite)
 }

 private func refresher()->ChallengeContentRefresher {
  let configuration=URLSessionConfiguration.ephemeral
  configuration.protocolClasses=[ContentStubProtocol.self]
  let current=clock!
  return ChallengeContentRefresher(origin:origin,directory:directory,defaults:defaults,session:URLSession(configuration:configuration),now:{current})
 }

 private func readAloud(_ id:String)->ChallengeContentItem {
  ChallengeContentItem(id:id,kind:.readAloud,language:"en",text:"Every quiet morning gives me a small chance to begin again with patience, care, and a little more courage than yesterday.",choices:nil,answerIndex:nil,source:"test",license:"original",attribution:nil)
 }

 private func pack(version:Int,items:[ChallengeContentItem]? = nil)throws->Data {
  try JSONEncoder().encode(ChallengeContentPack(version:version,generatedAt:"2026-10-18T00:00:00.000Z",items:items ?? [readAloud("a")]))
 }

 private func respond(_ status:Int,_ body:Data=Data(),etag:String?=nil)->(URLRequest) throws->(HTTPURLResponse,Data) {
  {request in
   var headers:[String:String]=[:]
   if let etag {headers["ETag"]=etag}
   return (HTTPURLResponse(url:request.url!,statusCode:status,httpVersion:nil,headerFields:headers)!,body)
  }
 }

 func testFreshPackIsCachedWithETag() async throws {
  ContentStubProtocol.handler=respond(200,try pack(version:5),etag:"\"v5\"")
  let target=refresher()
  let fresh=await target.refreshIfDue()
  XCTAssertEqual(fresh?.version,5)
  XCTAssertEqual(target.cachedPack()?.version,5)
  XCTAssertEqual(defaults.string(forKey:"contentETag"),"\"v5\"")
  XCTAssertEqual(defaults.object(forKey:"contentLastRefresh") as? Date,clock)
  let request=try XCTUnwrap(ContentStubProtocol.requests.first)
  XCTAssertEqual(request.url?.path,"/content/v1/challenge-content.json")
  XCTAssertEqual(request.timeoutInterval,10)
  XCTAssertNil(request.value(forHTTPHeaderField:"If-None-Match"))
 }

 func testNotModifiedKeepsCacheAndAdvancesClock() async throws {
  ContentStubProtocol.handler=respond(200,try pack(version:5),etag:"\"v5\"")
  _=await refresher().refreshIfDue()
  clock=clock.addingTimeInterval(25*3_600)
  ContentStubProtocol.handler=respond(304)
  let target=refresher()
  let result=await target.refreshIfDue()
  XCTAssertNil(result)
  XCTAssertEqual(ContentStubProtocol.requests.last?.value(forHTTPHeaderField:"If-None-Match"),"\"v5\"")
  XCTAssertEqual(target.cachedPack()?.version,5)
  XCTAssertEqual(defaults.object(forKey:"contentLastRefresh") as? Date,clock)
 }

 func testFailedFetchDoesNotAdvanceRefreshClock() async throws {
  let before=clock!
  defaults.set(before.addingTimeInterval(-25*3_600),forKey:"contentLastRefresh")
  let stale=before.addingTimeInterval(-25*3_600)
  ContentStubProtocol.handler=respond(500)
  let serverError=await refresher().refreshIfDue()
  XCTAssertNil(serverError)
  XCTAssertEqual(defaults.object(forKey:"contentLastRefresh") as? Date,stale)
  ContentStubProtocol.handler={_ in throw URLError(.timedOut)}
  let timedOut=await refresher().refreshIfDue()
  XCTAssertNil(timedOut)
  XCTAssertEqual(defaults.object(forKey:"contentLastRefresh") as? Date,stale)
  XCTAssertEqual(ContentStubProtocol.requests.count,2)
 }

 func testNotDueWithinTwentyFourHoursMakesNoRequest() async throws {
  defaults.set(clock.addingTimeInterval(-23*3_600),forKey:"contentLastRefresh")
  ContentStubProtocol.handler=respond(200,try pack(version:9),etag:"\"v9\"")
  let result=await refresher().refreshIfDue()
  XCTAssertNil(result)
  XCTAssertTrue(ContentStubProtocol.requests.isEmpty)
 }

 func testInvalidPayloadIsNotCached() async throws {
  ContentStubProtocol.handler=respond(200,Data("{\"version\":".utf8),etag:"\"v7\"")
  let target=refresher()
  let garbage=await target.refreshIfDue()
  XCTAssertNil(garbage)
  XCTAssertNil(target.cachedPack())
  XCTAssertNil(defaults.string(forKey:"contentETag"))
  let empty=ChallengeContentItem(id:"",kind:.readAloud,language:"en",text:"",choices:nil,answerIndex:nil,source:"",license:"",attribution:nil)
  ContentStubProtocol.handler=respond(200,try pack(version:7,items:[empty]),etag:"\"v7\"")
  let unusable=await refresher().refreshIfDue()
  XCTAssertNil(unusable)
  XCTAssertNil(target.cachedPack())
  XCTAssertNil(defaults.string(forKey:"contentETag"))
  XCTAssertNil(defaults.object(forKey:"contentLastRefresh"))
  ContentStubProtocol.handler=respond(200,try pack(version:8),etag:"\"v8\"")
  let corrected=await target.refreshIfDue()
  XCTAssertEqual(corrected?.version,8)
  XCTAssertEqual(ContentStubProtocol.requests.count,3)
 }

 func testSameVersionIsNotReturnedAndKeepsETag() async throws {
  ContentStubProtocol.handler=respond(200,try pack(version:5),etag:"\"v5\"")
  _=await refresher().refreshIfDue()
  clock=clock.addingTimeInterval(25*3_600)
  ContentStubProtocol.handler=respond(200,try pack(version:5),etag:"\"other\"")
  let target=refresher()
  let result=await target.refreshIfDue()
  XCTAssertNil(result)
  XCTAssertEqual(defaults.string(forKey:"contentETag"),"\"v5\"")
  XCTAssertEqual(target.cachedPack()?.version,5)
 }
}
