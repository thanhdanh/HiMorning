import AVFoundation
import AudioToolbox

@MainActor final class VoiceCoach {
 private let say: (String) -> Void
 private let tick: () -> Void
 private var lastHint: String?
 private var lastHintAt: Date?
 private let synthesizer = AVSpeechSynthesizer()

 init(languageCode: String = appLocale().identifier, say: ((String) -> Void)? = nil, tick: (() -> Void)? = nil) {
  let synthesizer = self.synthesizer
  let voice = AVSpeechSynthesisVoice(language: languageCode.hasPrefix("vi") ? "vi-VN" : "en-US")
  self.say = say ?? { text in
   synthesizer.stopSpeaking(at: .word)
   let utterance = AVSpeechUtterance(string: text)
   utterance.voice = voice
   synthesizer.speak(utterance)
  }
  self.tick = tick ?? { AudioServicesPlaySystemSound(1057) }
 }

 func speak(_ text: String, at now: Date = .now) {
  lastHint = text; lastHintAt = now
  say(text)
 }

 func hint(_ text: String, at now: Date = .now) {
  guard text != lastHint, lastHintAt.map({ now.timeIntervalSince($0) >= 3 }) ?? true else { return }
  lastHint = text; lastHintAt = now
  say(text)
 }

 func rep(_ count: Int, spoken: Bool = true) {
  tick()
  if spoken { say("\(count)") }
 }

 func stop() { synthesizer.stopSpeaking(at: .immediate) }
}
