import AVFoundation
import Speech
import HiMorningCore

struct SpeechUpdate:Sendable {
 let transcript:String
 let progress:Double
 let completed:Bool
 let ended:Bool
 let finishing:Bool
 let message:String
}

private actor SpeechAudioSession {
 static let shared=SpeechAudioSession()
 private var owner:UUID?
 func activate(owner:UUID) throws {
  try Task.checkCancellation()
  let session=AVAudioSession.sharedInstance()
  try session.setCategory(.playAndRecord,mode:.measurement,options:[.mixWithOthers,.defaultToSpeaker])
  try session.setActive(true)
  self.owner=owner
 }
 func deactivate(owner:UUID) {
  guard self.owner == owner else {return}
  try? AVAudioSession.sharedInstance().setActive(false,options:.notifyOthersOnDeactivation)
  self.owner=nil
 }
}

/// Streams microphone buffers to Apple's on-device analyzer. No audio is saved.
@MainActor final class SpeechChallengeCapture {
 private var reading:ReadAloudAttempt
 private let onUpdate:@Sendable(SpeechUpdate)->Void
 private let audioEngine=AVAudioEngine()
 private let audioSessionID=UUID()
 private var analyzer:SpeechAnalyzer?
 private var installation:AssetInstallationRequest?
 private var inputContinuation:AsyncStream<AnalyzerInput>.Continuation?
 private var startupTask:Task<Void,Never>?
 private var analysisTask:Task<Void,Never>?
 private var resultsTask:Task<Void,Never>?
 private var timeoutTask:Task<Void,Never>?
 private var idleTask:Task<Void,Never>?
 private var finishTask:Task<Void,Never>?
 private var finalizationTimeoutTask:Task<Void,Never>?
 private var teardownTask:Task<Void,Never>?
 private var observers:[NSObjectProtocol]=[]
 private var transcript=SpeechTranscript()
 private var tapInstalled=false
 private var active=false
 private var started=false
 private var stopped=false
 private var finishing=false
 private var generation=0

 init(target:String,onUpdate:@escaping @Sendable(SpeechUpdate)->Void) {
  reading=ReadAloudAttempt(target:target)
  self.onUpdate=onUpdate
 }

 func start() async {
  guard !started,!stopped,!Task.isCancelled else {return}
  started=true
  let token=generation
  let startup=Task {await prepareAndStart(token:token)}
  startupTask=startup
  await withTaskCancellationHandler(operation:{await startup.value},onCancel:{
   Task {@MainActor [weak self] in self?.stop()}
  })
 }

 func stop() {
  guard !stopped else {return}
  stopped=true;generation+=1;active=false
  reading.stop()
  startupTask?.cancel();timeoutTask?.cancel();idleTask?.cancel();finishTask?.cancel();finalizationTimeoutTask?.cancel();resultsTask?.cancel();analysisTask?.cancel()
  installation?.progress.cancel();installation=nil
  closeInput()
  for observer in observers {NotificationCenter.default.removeObserver(observer)}
  observers=[]
  let analyzer=self.analyzer;self.analyzer=nil
  let audioSessionID=audioSessionID
  teardownTask=Task {
   await SpeechAudioSession.shared.deactivate(owner:audioSessionID)
   if let analyzer {await analyzer.cancelAndFinishNow()}
  }
 }

 func stopAndWait() async {
  stop()
  await startupTask?.value
  await teardownTask?.value
 }

 func finishReading() {
  guard active,!finishing,isCurrent(generation),let analyzer else {return}
  let token=generation
  finishing=true
  closeInput()
  publish(token:token,message:"Finishing your reading…")
  timeoutTask?.cancel();idleTask?.cancel()
  finalizationTimeoutTask=Task {[weak self] in
   do {try await Task.sleep(for:.seconds(6))} catch {return}
   self?.completeReading(token:token)
  }
  finishTask=Task {[weak self] in
   do {
    try await analyzer.finalizeAndFinishThroughEndOfInput()
    await self?.resultsTask?.value
   } catch {}
   self?.completeReading(token:token)
  }
 }

 private func closeInput() {
  if audioEngine.isRunning {audioEngine.stop()}
  if tapInstalled {audioEngine.inputNode.removeTap(onBus:0);tapInstalled=false}
  inputContinuation?.finish();inputContinuation=nil
 }

 private func prepareAndStart(token:Int) async {
  publish(token:token,message:"Preparing on-device speech…")
  guard isCurrent(token) else {return}
  var openingMicrophone=false
  do {
   let locale=Locale(identifier:"en-US")
   let module:any SpeechModule
   let observeResults:()->Void
   if SpeechTranscriber.isAvailable,let supported=await SpeechTranscriber.supportedLocale(equivalentTo:locale) {
    guard isCurrent(token) else {return}
    let transcriber=SpeechTranscriber(locale:supported,preset:.progressiveTranscription)
    module=transcriber
    observeResults={self.observe(transcriber.results,text:{String($0.text.characters)},token:token)}
   } else if let supported=await DictationTranscriber.supportedLocale(equivalentTo:locale) {
    guard isCurrent(token) else {return}
    let transcriber=DictationTranscriber(locale:supported,preset:.progressiveShortDictation)
    module=transcriber
    observeResults={self.observe(transcriber.results,text:{String($0.text.characters)},token:token)}
   } else {
    end(token:token,message:"On-device speech recognition is not available. Choose another challenge.")
    return
   }
   guard isCurrent(token) else {return}
   if let request=try await AssetInventory.assetInstallationRequest(supporting:[module]) {
    guard isCurrent(token) else {return}
    installation=request
    publish(token:token,message:"Downloading speech support… You can stop at any time.")
    guard isCurrent(token) else {return}
    try await request.downloadAndInstall()
    guard isCurrent(token) else {return}
    installation=nil
   }
   guard isCurrent(token) else {return}
   guard let format=await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith:[module]) else {
    end(token:token,message:"On-device speech recognition is not available. Choose another challenge.")
    return
   }
   guard isCurrent(token) else {return}
   let analyzer=SpeechAnalyzer(modules:[module])
   self.analyzer=analyzer
   try await analyzer.prepareToAnalyze(in:format)
   guard isCurrent(token) else {return}
   let granted=await AVAudioApplication.requestRecordPermission()
   guard isCurrent(token) else {return}
   guard granted else {
    end(token:token,message:"Microphone access is needed for this challenge.")
    return
   }
   openingMicrophone=true
   try await startAudio(format:format,analyzer:analyzer,token:token)
   guard isCurrent(token) else {return}
   observeResults()
  } catch {
   guard isCurrent(token) else {return}
   end(token:token,message:openingMicrophone
    ? "The microphone could not start. Choose another challenge."
    : "Speech support could not be prepared. Check your connection and try again.")
  }
 }

 private func startAudio(format:AVAudioFormat,analyzer:SpeechAnalyzer,token:Int) async throws {
  let session=AVAudioSession.sharedInstance()
  try await SpeechAudioSession.shared.activate(owner:audioSessionID)
  guard isCurrent(token) else {
   await SpeechAudioSession.shared.deactivate(owner:audioSessionID)
   return
  }
  let input=audioEngine.inputNode
  let converter=try SpeechBufferConverter(inputFormat:input.outputFormat(forBus:0),outputFormat:format)
  let (stream,continuation)=AsyncStream<AnalyzerInput>.makeStream()
  inputContinuation=continuation
  input.installTap(onBus:0,bufferSize:1_024,format:input.outputFormat(forBus:0)) {[weak self] buffer,_ in
   do {
    if let output=try converter.convert(buffer) {continuation.yield(AnalyzerInput(buffer:output))}
   } catch {
    Task {@MainActor in self?.end(token:token,message:"Speech recognition stopped. Try again or choose another challenge.")}
   }
  }
  tapInstalled=true
  active=true
  analysisTask=Task {[weak self] in
   do {try await analyzer.start(inputSequence:stream)}
   catch {
    guard let self,self.isCurrent(token) else {return}
    if self.finishing {self.completeReading(token:token)}
    else {self.end(token:token,message:"Speech recognition stopped. Try again or choose another challenge.")}
   }
  }
  for (name,object) in [(AVAudioSession.interruptionNotification,session as AnyObject),(Notification.Name.AVAudioEngineConfigurationChange,audioEngine as AnyObject)] {
   observers.append(NotificationCenter.default.addObserver(forName:name,object:object,queue:nil) {[weak self] _ in
    Task {@MainActor in
     guard let self,!self.finishing else {return}
     self.end(token:token,message:"Speech recognition stopped. Try again or choose another challenge.")
    }
   })
  }
  audioEngine.prepare()
  try audioEngine.start()
  publish(token:token,message:"Listening… Read the sentence aloud.")
  guard isCurrent(token) else {return}
  timeoutTask=Task {[weak self] in
   guard let duration=self?.reading.listeningDuration else {return}
   do {try await Task.sleep(for:.seconds(duration))} catch {return}
   self?.finishReading()
  }
 }

 private func observe<Results:AsyncSequence & Sendable>(_ results:Results,text:@escaping(Results.Element)->String,token:Int) where Results.Element:SpeechModuleResult {
  resultsTask=Task {[weak self] in
   do {
    for try await result in results {
     guard let self,self.active,self.isCurrent(token) else {return}
     self.transcript.update(text:text(result),range:result.range,isFinal:result.isFinal)
     self.reading.observe(self.transcript.text)
     self.idleTask?.cancel()
     if self.finishing {continue}
     if self.reading.hasEnoughSpeech {
      self.idleTask=Task {[weak self] in
       do {try await Task.sleep(for:.seconds(1.8))} catch {return}
       self?.finishReading()
      }
     }
     self.publish(token:token,message:"Keep reading. Tap Finish reading when you are done.")
    }
    self?.completeReading(token:token)
   } catch {
    guard let self,self.isCurrent(token) else {return}
    if self.finishing {self.completeReading(token:token)}
    else {self.end(token:token,message:"Speech recognition stopped. Try again or choose another challenge.")}
   }
  }
 }

 private func completeReading(token:Int) {
  guard isCurrent(token) else {return}
  let completed=reading.finish()
  let message=completed ? "Reading recorded. Challenge complete." : reading.progress == 0
   ? "No speech was recognized. Try again and speak near the microphone."
   : "Only part of the reading was recorded. Read the whole sentence and try again."
  end(token:token,message:message,completed:completed)
 }

 private func end(token:Int,message:String,completed:Bool=false) {
  guard isCurrent(token) else {return}
  publish(token:token,message:message,completed:completed,ended:true)
  stop()
 }

 private func publish(token:Int,message:String,completed:Bool=false,ended:Bool=false) {
  guard isCurrent(token) else {return}
  onUpdate(.init(transcript:transcript.text,progress:reading.progress,completed:completed,ended:ended,finishing:finishing,message:appText(message)))
 }

 private func isCurrent(_ token:Int) -> Bool {!stopped && generation == token && !Task.isCancelled}
}
