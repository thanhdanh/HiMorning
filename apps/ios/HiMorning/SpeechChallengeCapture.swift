import AVFoundation
import Speech
import HiMorningCore

struct SpeechUpdate:Sendable {
 let transcript:String
 let score:Double
 let completed:Bool
 let ended:Bool
 let message:String
}

/// Streams microphone buffers directly to Apple's on-device recognizer. No audio is saved.
final class SpeechChallengeCapture:NSObject,@unchecked Sendable {
 private let target:String
 private let onUpdate:@Sendable(SpeechUpdate)->Void
 private let queue=DispatchQueue(label:"com.himorning.speech",qos:.userInitiated)
 private let lock=NSLock()
 private let audioEngine=AVAudioEngine()
 private var recognitionTask:SFSpeechRecognitionTask?
 private var recognitionRequest:SFSpeechAudioBufferRecognitionRequest?
 private var tapInstalled=false
 private var active=false
 private var generation=0
 private var stopped=false
 private var timeoutWorkItem:DispatchWorkItem?
 private var interruptionObserver:NSObjectProtocol?

 init(target:String,onUpdate:@escaping @Sendable(SpeechUpdate)->Void) {
  self.target=target
  self.onUpdate=onUpdate
  super.init()
 }

 func start() async {
  guard let token=beginStartup() else {return}
  let speechStatus=await requestSpeechPermission()
  guard isCurrent(token) else {return}
  let microphoneGranted=await requestMicrophonePermission()
  guard isCurrent(token) else {return}
  guard speechStatus == .authorized,microphoneGranted else {
   publish(transcript:"",score:0,completed:false,ended:true,message:appText("Speech and microphone access are needed for this challenge."))
   return
  }
  guard let recognizer=SFSpeechRecognizer(locale:Locale(identifier:"en-US")),recognizer.isAvailable,recognizer.supportsOnDeviceRecognition else {
   publish(transcript:"",score:0,completed:false,ended:true,message:appText("On-device speech recognition is not available. Choose another challenge."))
   return
  }
  queue.async { [weak self] in self?.startAudio(token:token) }
 }

 func stop() {
  stopPermanently()
  queue.async { [self] in stopAudio() }
 }

 private func startAudio(token:Int) {
  guard isCurrent(token) else {return}
  stopAudio()
  guard let recognizer=SFSpeechRecognizer(locale:Locale(identifier:"en-US")),recognizer.isAvailable,recognizer.supportsOnDeviceRecognition else {
   publish(transcript:"",score:0,completed:false,ended:true,message:appText("On-device speech recognition is not available. Choose another challenge."))
   return
  }
  do {
   let audioSession=AVAudioSession.sharedInstance()
   try audioSession.setCategory(.record,mode:.measurement,options:[.duckOthers])
   try audioSession.setActive(true,options:.notifyOthersOnDeactivation)
   let input=audioEngine.inputNode
   let format=input.outputFormat(forBus:0)
   guard format.sampleRate>0,format.channelCount>0 else {throw SpeechCaptureError.invalidAudioFormat}
   let request=SFSpeechAudioBufferRecognitionRequest()
   request.requiresOnDeviceRecognition=true
   request.shouldReportPartialResults=true
   request.taskHint = .confirmation
   input.installTap(onBus:0,bufferSize:1_024,format:format) {buffer,_ in request.append(buffer)}
   tapInstalled=true
   recognitionRequest=request
   active=true
   recognitionTask=recognizer.recognitionTask(with:request) { [weak self] result,error in
    self?.queue.async {self?.handle(result:result,error:error,token:token)}
   }
   interruptionObserver=NotificationCenter.default.addObserver(forName:AVAudioSession.interruptionNotification,object:audioSession,queue:nil) { [weak self] _ in
    self?.queue.async {self?.endForInterruption(token:token)}
   }
   let timeout=DispatchWorkItem { [weak self] in self?.endForTimeout(token:token) }
   timeoutWorkItem=timeout
   queue.asyncAfter(deadline:.now()+20,execute:timeout)
   audioEngine.prepare()
   try audioEngine.start()
   publish(transcript:"",score:0,completed:false,ended:false,message:appText("Listening… Read the sentence aloud."))
  } catch {
   stopAudio()
   publish(transcript:"",score:0,completed:false,ended:true,message:appText("The microphone could not start. Choose another challenge."))
  }
 }

 private func handle(result:SFSpeechRecognitionResult?,error:Error?,token:Int) {
  guard active,isCurrent(token) else {return}
  if let result {
   let transcript=result.bestTranscription.formattedString
   let score=RecognizedWordMatch.score(target:target,recognized:transcript)
   let completed=score>=RecognizedWordMatch.passingScore
   publish(
    transcript:transcript,
    score:score,
    completed:completed,
    ended:completed,
    message:appText(completed ? "Great reading. Challenge complete." : "Keep going. Match at least 80% of the words.")
   )
   if completed {
    invalidateStartup()
    stopAudio()
    return
   }
   if result.isFinal {
    stopAudio()
    publish(transcript:transcript,score:score,completed:false,ended:true,message:appText("Speech recognition stopped. Try again or choose another challenge."))
   }
  } else if error != nil {
   stopAudio()
   publish(transcript:"",score:0,completed:false,ended:true,message:appText("Speech recognition stopped. Try again or choose another challenge."))
  }
 }

 private func endForTimeout(token:Int) {
  guard active,isCurrent(token) else {return}
  stopAudio()
  publish(transcript:"",score:0,completed:false,ended:true,message:appText("Listening timed out. Try again or choose another challenge."))
 }

 private func endForInterruption(token:Int) {
  guard active,isCurrent(token) else {return}
  stopAudio()
  publish(transcript:"",score:0,completed:false,ended:true,message:appText("Speech recognition stopped. Try again or choose another challenge."))
 }

 private func stopAudio() {
  active=false
  if audioEngine.isRunning {audioEngine.stop()}
  if tapInstalled {audioEngine.inputNode.removeTap(onBus:0);tapInstalled=false}
  recognitionRequest?.endAudio()
  recognitionTask?.cancel()
  recognitionRequest=nil
  recognitionTask=nil
  timeoutWorkItem?.cancel()
  timeoutWorkItem=nil
  if let interruptionObserver {NotificationCenter.default.removeObserver(interruptionObserver);self.interruptionObserver=nil}
  try? AVAudioSession.sharedInstance().setActive(false,options:.notifyOthersOnDeactivation)
 }

 private func publish(transcript:String,score:Double,completed:Bool,ended:Bool,message:String) {
  onUpdate(.init(transcript:transcript,score:score,completed:completed,ended:ended,message:message))
 }

 private func beginStartup() -> Int? {
  lock.lock();defer {lock.unlock()}
  guard !stopped else {return nil}
  generation+=1
  return generation
 }

 private func stopPermanently() {
  lock.lock();stopped=true;generation+=1;lock.unlock()
 }

 private func invalidateStartup() {
  lock.lock();generation+=1;lock.unlock()
 }

 private func isCurrent(_ token:Int) -> Bool {
  lock.lock();defer {lock.unlock()}
  return token == generation
 }

 private func requestSpeechPermission() async -> SFSpeechRecognizerAuthorizationStatus {
  await withCheckedContinuation {continuation in
   SFSpeechRecognizer.requestAuthorization {continuation.resume(returning:$0)}
  }
 }

 private func requestMicrophonePermission() async -> Bool {
  await withCheckedContinuation {continuation in
   AVAudioApplication.requestRecordPermission {continuation.resume(returning:$0)}
  }
 }
}

private enum SpeechCaptureError:Error {case invalidAudioFormat}
