import AVFoundation

final class SoundPreview:@unchecked Sendable {
 // Player creation, playback, volume and teardown share one queue off the UI thread.
 private let queue=DispatchQueue(label:"com.himorning.sound-preview",qos:.userInitiated)
 private var player:AVAudioPlayer?
 func play(url:URL,volume:Double,onEnd:(@MainActor @Sendable ()->Void)?=nil) {
  queue.async { [self] in
   player?.stop();player=nil
   if let audio=try? AVAudioPlayer(contentsOf:url) {
    audio.volume=Float(volume)
    if audio.play() {
     player=audio
     if let onEnd {
      queue.asyncAfter(deadline:.now()+audio.duration) {
       DispatchQueue.main.async(execute:onEnd)
      }
     }
     return
    }
   }
   if let onEnd {DispatchQueue.main.async(execute:onEnd)}
  }
 }
 func stop() {queue.async { [self] in player?.stop();player=nil}}
 func setVolume(_ volume:Double) {queue.async { [self] in player?.volume=Float(volume)}}
 deinit {
  let audio=player
  queue.async {audio?.stop()}
 }
}
