import AVFoundation

/// Used only by the serial audio tap; each output owns its samples beyond the tap callback.
final class SpeechBufferConverter:@unchecked Sendable {
 private let converter:AVAudioConverter

 init(inputFormat:AVAudioFormat,outputFormat:AVAudioFormat) throws {
  guard inputFormat.sampleRate>0,outputFormat.sampleRate>0,
        inputFormat.channelCount>0,outputFormat.channelCount>0,
        let converter=AVAudioConverter(from:inputFormat,to:outputFormat) else {throw ConversionError.invalidFormat}
  self.converter=converter
  converter.primeMethod = .none
 }

 func convert(_ input:AVAudioPCMBuffer) throws -> AVAudioPCMBuffer? {
  guard input.format == converter.inputFormat else {throw ConversionError.invalidFormat}
  guard input.frameLength>0 else {return nil}
  let frames=AVAudioFrameCount(ceil(Double(input.frameLength)*converter.outputFormat.sampleRate/input.format.sampleRate))
  guard let output=AVAudioPCMBuffer(pcmFormat:converter.outputFormat,frameCapacity:frames) else {throw ConversionError.invalidFormat}
  var supplied=false
  var error:NSError?
  let status=converter.convert(to:output,error:&error) {_,status in
   guard !supplied else {status.pointee = .noDataNow;return nil}
   supplied=true;status.pointee = .haveData
   return input
  }
  if let error {throw error}
  guard status != .error else {throw ConversionError.failed}
  return output.frameLength>0 ? output : nil
 }

 private enum ConversionError:Error {case invalidFormat,failed}
}
