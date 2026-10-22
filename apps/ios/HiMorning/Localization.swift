import Foundation
import HiMorningCore

func appLocale()->Locale {
 let preference=AppLanguage(rawValue:UserDefaults.standard.string(forKey:"appLanguage") ?? "system") ?? .system
 return Locale(identifier:preference.resolved(preferredLanguages:Locale.preferredLanguages))
}

func appText(_ key:String,count:Int?=nil)->String {
 let locale=appLocale()
 let value=localizedValue(key,identifier:locale.identifier)
 if let count {return String(format:value,locale:locale,Int64(count))}
 return value
}

func appText(_ key:String,language:String)->String {localizedValue(key,identifier:language)}

private func localizedValue(_ key:String,identifier:String)->String {
 let bundle=Bundle.main.path(forResource:identifier,ofType:"lproj").flatMap {Bundle(path:$0)} ?? .main
 return NSLocalizedString(key,bundle:bundle,value:key,comment:"")
}

func morningCountText(_ count:Int)->String {appText(count == 1 ? "%lld morning" : "%lld mornings",count:count)}
