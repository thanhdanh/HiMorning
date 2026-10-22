import AVFoundation
import Combine

@MainActor final class SpokenExample:NSObject,ObservableObject,AVSpeechSynthesizerDelegate {
 @Published private(set) var isSpeaking=false
 private let synthesizer:AVSpeechSynthesizer
 private let voiceOverride:(()->AVSpeechSynthesisVoice?)?
 private var currentUtterance:ObjectIdentifier?

 init(synthesizer:AVSpeechSynthesizer=AVSpeechSynthesizer(),voice:(()->AVSpeechSynthesisVoice?)?=nil) {
  self.synthesizer=synthesizer;self.voiceOverride=voice
  super.init()
  synthesizer.usesApplicationAudioSession=false
  synthesizer.delegate=self
 }

 @discardableResult func play(_ text:String,language:String="en")->Bool {
  guard !isSpeaking,!text.isEmpty,let voice=voiceOverride.map({$0()}) ?? Self.preferredVoice(language:language) else {return false}
  let utterance=AVSpeechUtterance(string:text)
  utterance.voice=voice
  utterance.rate=AVSpeechUtteranceDefaultSpeechRate*0.9
  currentUtterance=ObjectIdentifier(utterance)
  isSpeaking=true
  synthesizer.speak(utterance)
  return true
 }

 nonisolated static func preferredVoice(language:String="en")->AVSpeechSynthesisVoice? {
  let home=language == "vi" ? "vi-VN" : "en-US"
  return AVSpeechSynthesisVoice.speechVoices().filter {$0.language.hasPrefix(language+"-")}
   .sorted {left,right in
    if left.quality != right.quality {return left.quality.rawValue>right.quality.rawValue}
    return left.language == home && right.language != home
   }.first
   ?? AVSpeechSynthesisVoice(language:home)
 }

 func stop() {
  guard isSpeaking else {return}
  if !synthesizer.stopSpeaking(at:.immediate) {currentUtterance=nil;isSpeaking=false}
 }

 nonisolated func speechSynthesizer(_ synthesizer:AVSpeechSynthesizer,didFinish utterance:AVSpeechUtterance) {ended(utterance)}
 nonisolated func speechSynthesizer(_ synthesizer:AVSpeechSynthesizer,didCancel utterance:AVSpeechUtterance) {ended(utterance)}

 private nonisolated func ended(_ utterance:AVSpeechUtterance) {
  let identifier=ObjectIdentifier(utterance)
  Task {@MainActor [weak self] in
   guard let self,currentUtterance == identifier else {return}
   currentUtterance=nil;isSpeaking=false
  }
 }
}
