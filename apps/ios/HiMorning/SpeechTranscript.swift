import Foundation
import CoreMedia

struct SpeechTranscript {
 private var finalized=""
 private var volatile=""
 private var finalEnd=CMTime.zero

 var text:String {[finalized,volatile].filter {!$0.isEmpty}.joined(separator:" ")}

 mutating func update(text:String,range:CMTimeRange,isFinal:Bool) {
  guard range.end>finalEnd else {return}
  let text=text.trimmingCharacters(in:.whitespacesAndNewlines)
  if isFinal {
   finalized=[finalized,text].filter {!$0.isEmpty}.joined(separator:" ")
   volatile=""
   finalEnd=range.end
  } else {volatile=text}
 }
}
