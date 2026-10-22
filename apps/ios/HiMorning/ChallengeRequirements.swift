import SwiftUI
import HiMorningCore

enum ChallengeRequirements {
 static func forSelection(_ selection:ChallengeSelection)->[String] {
  switch selection.kind {
  case .none:
   return [appText("Wait for the countdown to finish")]
  case .pushUps:
   return [appText("Place your phone to the side so your whole body is visible"),
    appText("Lower yourself, then push up %lld times",count:selection.repetitions ?? 5)]
  case .readAndChoose:
   return [appText("Read the sentence"),appText("Choose the closest meaning")]
  case .riddle:
   return [appText("Solve the riddle"),appText("Choose your answer")]
  case .readAloud:
   return [appText("Read the sentence aloud"),appText("Match at least 80% of the words")]
  case .waveHand:
   return [appText("Keep your hand and wrist in view"),appText("Wave side to side %lld times",count:selection.kind.localMovementTarget ?? 3)]
  case .neckRotation:
   return [appText("Keep your face in view"),appText("Turn left and right %lld times",count:selection.kind.localMovementTarget ?? 3)]
  case .jumpingJacks:
   return [appText("Keep your whole body in view"),appText("Open your arms and legs, then close them %lld times",count:selection.kind.localMovementTarget ?? 10)]
  case .stretching:
   return [appText("Keep both shoulders and elbows in view"),appText("Raise both arms, lower them, and repeat %lld times",count:selection.kind.localMovementTarget ?? 3)]
  case .guidedRhythm:
   if selection.rhythmVariant == .seated {
    return [appText("Stay seated"),appText("Lower your arms, raise them, then lower them for 3 cycles")]
   }
   return [appText("Stand sideways in view"),appText("Bend your knees gently, then stand again for 3 cycles")]
  }
 }
}

struct ChallengeRequirementsView:View {
 let selection:ChallengeSelection
 var body:some View {
  VStack(alignment:.leading,spacing:10) {
   ForEach(Array(ChallengeRequirements.forSelection(selection).enumerated()),id:\.offset) { _,requirement in
    HStack(alignment:.top,spacing:10) {
     Image(systemName:"checkmark.circle.fill").foregroundStyle(MorningTheme.accent).accessibilityHidden(true)
     Text(requirement).font(.footnote).fixedSize(horizontal:false,vertical:true)
    }
   }
  }
  .frame(maxWidth:.infinity,alignment:.leading)
  .accessibilityElement(children:.contain)
  .accessibilityIdentifier("challengeRequirements")
 }
}
