import AVFoundation
import CryptoKit
import Foundation

/// Plays pre-generated Microsoft Edge Neural TTS (.m4a AAC) clips bundled in the app
/// (`vi-VN-HoaiMyNeural` for Vietnamese, `en-US-AvaNeural` for English), and provides
/// a natural-prosody `AVSpeechSynthesisVoice` selector when falling back to system TTS.
@MainActor final class NeuralVoicePlayer:NSObject,AVAudioPlayerDelegate {
 private var player:AVAudioPlayer?
 private var onFinish:(()->Void)?

 var isPlaying:Bool {player?.isPlaying == true}

 static func clipResourceName(language:String,text:String)->String {
  let lang=language.hasPrefix("vi") ? "vi" : "en"
  let trimmed=text.trimmingCharacters(in:.whitespacesAndNewlines)
  let digest=SHA256.hash(data:Data("\(lang):\(trimmed)".utf8))
  let hex=digest.prefix(8).map {String(format:"%02x",$0)}.joined()
  return "voice_\(lang)_\(hex)"
 }

 static func bundledClipURL(language:String,text:String,bundle:Bundle = .main)->URL? {
  let name=clipResourceName(language:language,text:text)
  return bundle.url(forResource:name,withExtension:"m4a",subdirectory:"Voice")
   ?? bundle.url(forResource:name,withExtension:"m4a")
 }

 @discardableResult func play(language:String,text:String,onFinish:(()->Void)?=nil)->Bool {
  guard let url=Self.bundledClipURL(language:language,text:text) else {return false}
  do {
   stop()
   let audio=try AVAudioPlayer(contentsOf:url)
   audio.delegate=self
   audio.prepareToPlay()
   player=audio
   self.onFinish=onFinish
   if audio.play() {return true}
   player=nil;self.onFinish=nil
   return false
  } catch {
   player=nil;self.onFinish=nil
   return false
  }
 }

 func stop() {
  player?.stop()
  player=nil
  onFinish=nil
 }

 nonisolated func audioPlayerDidFinishPlaying(_ player:AVAudioPlayer,successfully flag:Bool) {
  Task {@MainActor [weak self] in
   guard let self,self.player === player else {return}
   self.player=nil
   let callback=self.onFinish
   self.onFinish=nil
   callback?()
  }
 }

 nonisolated static func naturalSystemVoice(language:String)->AVSpeechSynthesisVoice? {
  let prefix=language.hasPrefix("vi") ? "vi" : "en"
  let home=prefix == "vi" ? "vi-VN" : "en-US"
  let candidates=AVSpeechSynthesisVoice.speechVoices().filter {voice in
   guard voice.language.hasPrefix(prefix+"-") else {return false}
   guard !voice.voiceTraits.contains(.isNoveltyVoice),!voice.voiceTraits.contains(.isPersonalVoice) else {return false}
   let id=voice.identifier.lowercased()
   return !id.contains("eloquence") && !id.contains("compact")
  }
  let pool=candidates.isEmpty ? AVSpeechSynthesisVoice.speechVoices().filter {
   $0.language.hasPrefix(prefix+"-") && !$0.voiceTraits.contains(.isNoveltyVoice) && !$0.voiceTraits.contains(.isPersonalVoice)
  } : candidates
  return pool.sorted {left,right in
   if left.quality != right.quality {return left.quality.rawValue>right.quality.rawValue}
   let leftSiri=left.identifier.lowercased().contains("siri")
   let rightSiri=right.identifier.lowercased().contains("siri")
   if leftSiri != rightSiri {return leftSiri}
   return left.language == home && right.language != home
  }.first ?? AVSpeechSynthesisVoice(language:home)
 }
}
