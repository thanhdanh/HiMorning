import Foundation

public enum AppLanguage:String,CaseIterable,Sendable {
 case system
 case english = "en"
 case vietnamese = "vi"

 public func resolved(preferredLanguages:[String])->String {
  if self != .system {return rawValue}
  for identifier in preferredLanguages {
   let language=identifier.lowercased().split(whereSeparator:{$0 == "-" || $0 == "_"}).first
   if language == "en" || language == "vi" {return String(language!)}
  }
  return "en"
 }
}
