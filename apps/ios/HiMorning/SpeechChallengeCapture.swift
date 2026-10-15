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

/// Streams microphone buffers to Apple's on-device analyzer. No audio is saved.
@MainActor final class SpeechChallengeCapture {
 private let target:String
 private let onUpdate:@Sendable(SpeechUpdate)->Void
 private let audioEngine=AVAudioEngine()
 private var analyzer:SpeechAnalyzer?
 private var installation:AssetInstallationRequest?
 private var inputContinuation:AsyncStream<AnalyzerInput>.Continuation?
 private var startupTask:Task<Void,Never>?
 private var analysisTask:Task<Void,Never>?
 private var resultsTask:Task<Void,Never>?
 private var timeoutTask:Task<Void,Never>?
 private var teardownTask:Task<Void,Never>?
 private var observers:[NSObjectProtocol]=[]
 private var transcript=SpeechTranscript()
 private var tapInstalled=false
 private var ownsAudioSession=false
 private var active=false
 private var started=false
 private var stopped=false
 private var generation=0

 init(target:String,onUpdate:@escaping @Sendable(SpeechUpdate)->Void) {
  self.target=target
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
  startupTask?.cancel();timeoutTask?.cancel();resultsTask?.cancel();analysisTask?.cancel()
  installation?.progress.cancel();installation=nil
  if audioEngine.isRunning {audioEngine.stop()}
  if tapInstalled {audioEngine.inputNode.removeTap(onBus:0);tapInstalled=false}
  inputContinuation?.finish();inputContinuation=nil
  for observer in observers {NotificationCenter.default.removeObserver(observer)}
  observers=[]
  if ownsAudioSession {
   try? AVAudioSession.sharedInstance().setActive(false,options:.notifyOthersOnDeactivation)
   ownsAudioSession=false
  }
  if let analyzer {
   self.analyzer=nil
   teardownTask=Task {await analyzer.cancelAndFinishNow()}
  }
 }

 func stopAndWait() async {
  stop()
  await teardownTask?.value
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
   try startAudio(format:format,analyzer:analyzer,token:token)
   guard isCurrent(token) else {return}
   observeResults()
  } catch {
   guard isCurrent(token) else {return}
   end(token:token,message:openingMicrophone
    ? "The microphone could not start. Choose another challenge."
    : "Speech support could not be prepared. Check your connection and try again.")
  }
 }

 private func startAudio(format:AVAudioFormat,analyzer:SpeechAnalyzer,token:Int) throws {
  let session=AVAudioSession.sharedInstance()
  try session.setCategory(.playAndRecord,mode:.measurement,options:[.mixWithOthers,.defaultToSpeaker])
  try session.setActive(true)
  ownsAudioSession=true
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
   catch {self?.end(token:token,message:"Speech recognition stopped. Try again or choose another challenge.")}
  }
  for (name,object) in [(AVAudioSession.interruptionNotification,session as AnyObject),(Notification.Name.AVAudioEngineConfigurationChange,audioEngine as AnyObject)] {
   observers.append(NotificationCenter.default.addObserver(forName:name,object:object,queue:nil) {[weak self] _ in
    Task {@MainActor in self?.end(token:token,message:"Speech recognition stopped. Try again or choose another challenge.")}
   })
  }
  audioEngine.prepare()
  try audioEngine.start()
  publish(token:token,message:"Listening… Read the sentence aloud.")
  guard isCurrent(token) else {return}
  timeoutTask=Task {[weak self] in
   do {try await Task.sleep(for:.seconds(20))} catch {return}
   self?.end(token:token,message:"Listening timed out. Try again or choose another challenge.")
  }
 }

 private func observe<Results:AsyncSequence & Sendable>(_ results:Results,text:@escaping(Results.Element)->String,token:Int) where Results.Element:SpeechModuleResult {
  resultsTask=Task {[weak self] in
   do {
    for try await result in results {
     guard let self,self.active,self.isCurrent(token) else {return}
     self.transcript.update(text:text(result),range:result.range,isFinal:result.isFinal)
     let score=RecognizedWordMatch.score(target:self.target,recognized:self.transcript.text)
     if score>=RecognizedWordMatch.passingScore {
      self.end(token:token,message:"Great reading. Challenge complete.",completed:true)
      return
     }
     self.publish(token:token,message:"Keep going. Match at least 80% of the words.")
    }
    self?.end(token:token,message:"Speech recognition stopped. Try again or choose another challenge.")
   } catch {self?.end(token:token,message:"Speech recognition stopped. Try again or choose another challenge.")}
  }
 }

 private func end(token:Int,message:String,completed:Bool=false) {
  guard isCurrent(token) else {return}
  publish(token:token,message:message,completed:completed,ended:true)
  stop()
 }

 private func publish(token:Int,message:String,completed:Bool=false,ended:Bool=false) {
  guard isCurrent(token) else {return}
  onUpdate(.init(transcript:transcript.text,score:RecognizedWordMatch.score(target:target,recognized:transcript.text),completed:completed,ended:ended,message:appText(message)))
 }

 private func isCurrent(_ token:Int) -> Bool {!stopped && generation == token && !Task.isCancelled}
}
