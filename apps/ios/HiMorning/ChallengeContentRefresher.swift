import Foundation
import HiMorningCore

final class ChallengeContentRefresher:Sendable {
 static let interval:TimeInterval=24*3_600
 private static let etagKey="contentETag"
 private static let lastRefreshKey="contentLastRefresh"
 private let endpoint:URL?
 private let cacheURL:URL
 private let defaults:UserDefaults
 private let session:URLSession
 private let now:@Sendable ()->Date

 init(origin:URL?,directory:URL,defaults:UserDefaults = .standard,session:URLSession = .shared,now:@escaping @Sendable ()->Date = Date.init) {
  endpoint=origin?.appendingPathComponent("content/v1/challenge-content.json")
  cacheURL=directory.appendingPathComponent("challenge-content.json")
  self.defaults=defaults;self.session=session;self.now=now
 }

 func cachedPack()->ChallengeContentPack? {
  guard let data=try? Data(contentsOf:cacheURL) else {return nil}
  return try? JSONDecoder().decode(ChallengeContentPack.self,from:data)
 }

 func refreshIfDue() async->ChallengeContentPack? {
  guard let endpoint else {return nil}
  let current=now()
  if let last=defaults.object(forKey:Self.lastRefreshKey) as? Date,current.timeIntervalSince(last)<Self.interval,last<=current {return nil}
  let cached=cachedPack()
  var request=URLRequest(url:endpoint,timeoutInterval:10)
  if cached != nil,let etag=defaults.string(forKey:Self.etagKey) {request.setValue(etag,forHTTPHeaderField:"If-None-Match")}
  guard let (data,response)=try? await session.data(for:request),let http=response as? HTTPURLResponse else {return nil}
  switch http.statusCode {
  case 304:
   defaults.set(current,forKey:Self.lastRefreshKey)
   return nil
  case 200:
   guard let pack=try? JSONDecoder().decode(ChallengeContentPack.self,from:data),
         !ChallengeContentStore.validItems(pack).isEmpty,
         pack.version>(cached?.version ?? 0),
         (try? FileManager.default.createDirectory(at:cacheURL.deletingLastPathComponent(),withIntermediateDirectories:true)) != nil,
         (try? data.write(to:cacheURL,options:.atomic)) != nil else {return nil}
   defaults.set(current,forKey:Self.lastRefreshKey)
   if let etag=http.value(forHTTPHeaderField:"ETag") {defaults.set(etag,forKey:Self.etagKey)} else {defaults.removeObject(forKey:Self.etagKey)}
   return pack
  default:
   return nil
  }
 }
}
