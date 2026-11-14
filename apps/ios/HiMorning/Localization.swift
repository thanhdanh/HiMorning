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

func alarmTimeText(_ date:Date)->String {
 date.formatted(.dateTime.hour().minute())
}

func alarmTimeText(_ time:AlarmTime)->String {
 let date=Calendar.current.date(from:DateComponents(hour:time.hour,minute:time.minute))
 return date.map {alarmTimeText($0)} ?? String(format:"%02d:%02d",time.hour,time.minute)
}

func morningCountText(_ count:Int)->String {appText(count == 1 ? "%lld morning" : "%lld mornings",count:count)}
