import Foundation
public struct WorkerEndpoint:Sendable {
 public let url:URL
 public init(_ origin:String) throws {
  guard let parts=URLComponents(string:origin),parts.scheme=="https",let host=parts.host,host.hasSuffix(".workers.dev"),parts.user==nil,parts.password==nil,parts.port==nil,parts.query==nil,parts.fragment==nil,parts.path.isEmpty || parts.path=="/",let url=parts.url else {throw ChallengeError.cloudUnavailable}
  self.url=url
 }
}
public enum RemoteDemo {
 public static func frames(from data:Data,target:Int) throws ->[EvidenceFrame] {
  struct Fixture:Decodable {let frames:[SubmissionFrame]}
  guard (1...ChallengeSelection.maximumPushUps).contains(target) else {throw ChallengeError.insufficientEvidence}
  let fixture=try JSONDecoder().decode(Fixture.self,from:data)
  guard [25,100,ChallengeSelection.maximumPushUps*5].contains(fixture.frames.count),fixture.frames.count>=target*5 else {throw ChallengeError.insufficientEvidence}
  var buffer=EvidenceBuffer()
  for (index,frame) in fixture.frames.enumerated() {
   guard frame.id=="f\(index)",frame.timestampMs==index*300,let jpeg=Data(base64Encoded:frame.jpegBase64),buffer.append(jpeg,timestampMs:frame.timestampMs) else {throw ChallengeError.insufficientEvidence}
  }
  return Array(buffer.frames.prefix(target*5))
 }
}
