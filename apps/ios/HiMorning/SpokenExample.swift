import AVFoundation
import Combine

@MainActor final class SpokenExample:NSObject,ObservableObject,AVSpeechSynthesizerDelegate {
 @Published private(set) var isSpeaking=false
 private let synthesizer:AVSpeechSynthesizer
 private let voice:()->AVSpeechSynthesisVoice?
 private var currentUtterance:ObjectIdentifier?

 init(synthesizer:AVSpeechSynthesizer=AVSpeechSynthesizer(),voice:@escaping ()->AVSpeechSynthesisVoice? = {AVSpeechSynthesisVoice(language:"en-US")}) {
  self.synthesizer=synthesizer;self.voice=voice
  super.init()
  synthesizer.usesApplicationAudioSession=false
  synthesizer.delegate=self
 }

 @discardableResult func play(_ text:String)->Bool {
  guard !isSpeaking,!text.isEmpty,let voice=voice() else {return false}
  let utterance=AVSpeechUtterance(string:text)
  utterance.voice=voice
  currentUtterance=ObjectIdentifier(utterance)
  isSpeaking=true
  synthesizer.speak(utterance)
  return true
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
