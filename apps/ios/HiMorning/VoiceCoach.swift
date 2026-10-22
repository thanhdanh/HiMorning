import AVFoundation
import AudioToolbox

@MainActor final class VoiceCoach {
 private let say:(String)->Void
 private let tick:()->Void
 private let isSpeaking:()->Bool
 private let synthesizer=AVSpeechSynthesizer()
 private var lastHint:String?
 private var lastSpeechAt:Date?
 private var pendingHint:String?
 private var pendingSince:Date?
 private var lastProgressAt:Date?
 private var stopped=false

 init(languageCode:String=appLocale().identifier,say:((String)->Void)?=nil,tick:(()->Void)?=nil,isSpeaking:(()->Bool)?=nil) {
  let synthesizer=self.synthesizer
  if let say {self.say=say}
  else {
   let language=languageCode.hasPrefix("vi") ? "vi-VN":"en-US"
   let preferred=AVSpeechSynthesisVoice(language:language)
   let best=AVSpeechSynthesisVoice.speechVoices().filter {
    $0.language==language && !$0.voiceTraits.contains(.isNoveltyVoice) && !$0.voiceTraits.contains(.isPersonalVoice)
   }.max {$0.quality.rawValue<$1.quality.rawValue}
   let voice=(best?.quality.rawValue ?? 0)>(preferred?.quality.rawValue ?? 0) ? best:preferred
   self.say={text in synthesizer.speak(Self.utterance(text,voice:voice))}
  }
  self.tick=tick ?? {AudioServicesPlaySystemSound(1057)}
  self.isSpeaking=isSpeaking ?? {synthesizer.isSpeaking}
 }

 static func utterance(_ text:String,voice:AVSpeechSynthesisVoice?=nil)->AVSpeechUtterance {
  let utterance=AVSpeechUtterance(string:text)
  utterance.voice=voice
  utterance.rate=AVSpeechUtteranceDefaultSpeechRate*0.85
  utterance.preUtteranceDelay=0.15
  utterance.postUtteranceDelay=0.35
  return utterance
 }

 func speak(_ text:String,at now:Date = .now) {
  stopped=false;pendingHint=nil;pendingSince=nil
  lastHint=text;lastSpeechAt=now;say(text)
 }

 // Camera frames refresh the candidate. Brief tracking flicker stays visual;
 // it cannot interrupt speech or build an audio queue.
 func hint(_ text:String,at now:Date = .now) {
  guard !stopped else {return}
  guard text != lastHint else {pendingHint=nil;pendingSince=nil;return}
  if pendingHint != text {pendingHint=text;pendingSince=now;return}
  guard let since=pendingSince,now.timeIntervalSince(since)>=2,
        lastSpeechAt.map({now.timeIntervalSince($0)>=15}) ?? true,
        lastProgressAt.map({now.timeIntervalSince($0)>=10}) ?? true,
        !isSpeaking() else {return}
  lastHint=text;lastSpeechAt=now;pendingHint=nil;pendingSince=nil;say(text)
 }

 func rep(_ count:Int,spoken:Bool=true,at now:Date = .now) {
  guard !stopped else {return}
  tick();lastProgressAt=now;pendingHint=nil;pendingSince=nil
  guard spoken,count>0,count.isMultiple(of:5),!isSpeaking(),
        lastSpeechAt.map({now.timeIntervalSince($0)>=6}) ?? true else {return}
  lastSpeechAt=now;say("\(count)")
 }

 func stop() {
  stopped=true;pendingHint=nil;pendingSince=nil
  synthesizer.stopSpeaking(at:.immediate)
 }
}
