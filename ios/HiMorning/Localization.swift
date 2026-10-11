import Foundation
import HiMorningCore

func appLocale()->Locale {
 let preference=AppLanguage(rawValue:UserDefaults.standard.string(forKey:"appLanguage") ?? "system") ?? .system
 return Locale(identifier:preference.resolved(preferredLanguages:Locale.preferredLanguages))
}

func appText(_ key:String,count:Int?=nil)->String {
 let locale=appLocale()
 let bundle=Bundle.main.path(forResource:locale.identifier,ofType:"lproj").flatMap(Bundle.init(path:)) ?? .main
 let value=NSLocalizedString(key,bundle:bundle,value:key,comment:"")
 if let count {return String(format:value,locale:locale,Int64(count))}
 return value
}
