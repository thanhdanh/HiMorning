import AVFoundation

final class SoundPreview:@unchecked Sendable {
 // Player creation, playback, volume and teardown share one queue off the UI thread.
 private let queue=DispatchQueue(label:"com.himorning.sound-preview",qos:.userInitiated)
 private let playsInSilentMode:Bool
 private var player:AVAudioPlayer?
 private var previousSession:AudioSessionSettings?

 init(playsInSilentMode:Bool=false) {
  self.playsInSilentMode=playsInSilentMode
 }

 func play(url:URL,volume:Double,onEnd:(@MainActor @Sendable (Bool)->Void)?=nil) {
  queue.async { [self] in
   player?.stop();player=nil
   do {
    let audio=try AVAudioPlayer(contentsOf:url)
    if playsInSilentMode,previousSession == nil {
     let session=AVAudioSession.sharedInstance()
     previousSession=AudioSessionSettings(category:session.category,mode:session.mode,options:session.categoryOptions)
     try session.setCategory(.playback,mode:.default,options:[.mixWithOthers])
     try session.setActive(true)
    }
    audio.volume=Float(volume)
    if audio.play() {
     player=audio
     queue.asyncAfter(deadline:.now()+audio.duration) { [weak self] in
      guard let self,self.player === audio else {return}
      self.finishPlayback()
      if let onEnd {DispatchQueue.main.async {onEnd(true)}}
     }
     return
    }
   } catch {
    // Reset the session after a failed activation or decode.
   }
   finishPlayback()
   if let onEnd {DispatchQueue.main.async {onEnd(false)}}
  }
 }

 func stop() {queue.async { [self] in finishPlayback()}}
 func setVolume(_ volume:Double) {queue.async { [self] in player?.volume=Float(volume)}}

 private func finishPlayback() {
  player?.stop();player=nil
  previousSession?.restore()
  previousSession=nil
 }

 deinit {
  let audio=player
  let settings=previousSession
  queue.async {audio?.stop();settings?.restore()}
 }
}

private struct AudioSessionSettings {
 let category:AVAudioSession.Category
 let mode:AVAudioSession.Mode
 let options:AVAudioSession.CategoryOptions

 func restore() {
  let session=AVAudioSession.sharedInstance()
  try? session.setActive(false,options:.notifyOthersOnDeactivation)
  try? session.setCategory(category,mode:mode,options:options)
 }
}
