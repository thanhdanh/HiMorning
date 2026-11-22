import AVFoundation
import Combine

@MainActor final class SpokenExample:NSObject,ObservableObject,AVSpeechSynthesizerDelegate {
 @Published private(set) var isSpeaking=false
 private let synthesizer:AVSpeechSynthesizer
 private let voiceOverride:(()->AVSpeechSynthesisVoice?)?
 private let useNeuralClips:Bool
 private let neural=NeuralVoicePlayer()
 private var currentUtterance:ObjectIdentifier?

 init(synthesizer:AVSpeechSynthesizer=AVSpeechSynthesizer(),voice:(()->AVSpeechSynthesisVoice?)?=nil) {
  self.synthesizer=synthesizer
  self.voiceOverride=voice
  self.useNeuralClips=(type(of:synthesizer) == AVSpeechSynthesizer.self && voice == nil)
  super.init()
  synthesizer.usesApplicationAudioSession=false
  synthesizer.delegate=self
 }

 @discardableResult func play(_ text:String,language:String="en")->Bool {
  guard !isSpeaking,!text.isEmpty else {return false}
  if useNeuralClips,neural.play(language:language,text:text,onFinish:{[weak self] in
   self?.isSpeaking=false
  }) {
   isSpeaking=true
   return true
  }
  guard let voice=voiceOverride.map({$0()}) ?? Self.preferredVoice(language:language) else {return false}
  let utterance=AVSpeechUtterance(string:text)
  utterance.voice=voice
  utterance.rate=AVSpeechUtteranceDefaultSpeechRate*0.9
  utterance.pitchMultiplier=1.03
  currentUtterance=ObjectIdentifier(utterance)
  isSpeaking=true
  synthesizer.speak(utterance)
  return true
 }

 nonisolated static func preferredVoice(language:String="en")->AVSpeechSynthesisVoice? {
  NeuralVoicePlayer.naturalSystemVoice(language:language)
 }

 func stop() {
  guard isSpeaking else {return}
  if neural.isPlaying {
   neural.stop()
   isSpeaking=false
   return
  }
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
