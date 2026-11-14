import SwiftUI
import HiMorningCore

enum ChallengeRequirements {
 static func forSelection(_ selection:ChallengeSelection)->[String] {
  switch selection.kind {
  case .none:
   return [appText("Stop the alarm with one tap")]
  case .pushUps:
   return [appText("Place your phone to the side so your whole body is visible"),
    appText("Lower yourself, then push up %lld times",count:selection.repetitions ?? 5)]
  case .readAndChoose:
   return [appText("Read the prompt and pick the correct answer.")]
  case .riddle:
   return [appText("Solve the riddle"),appText("Choose the correct answer")]
  case .readAloud:
   return [appText("Read the English passage aloud"),appText("Match at least 80% of the words")]
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

struct ChallengeCheckingGuide:View {
 let selection:ChallengeSelection
 var body:some View {
  VStack(alignment:.leading,spacing:8) {
   Text(appText(selection.checkingGuide)).font(.subheadline).fixedSize(horizontal:false,vertical:true)
    .accessibilityIdentifier("challengeCheckingGuide")
   if selection.kind.hasMovementIllustration {
    Label(appText("challenge_guide_camera"),systemImage:"camera")
     .font(.footnote).foregroundStyle(MorningTheme.muted)
   } else if selection.kind == .readAloud {
    Label(appText("Uses the microphone"),systemImage:"mic")
     .font(.footnote).foregroundStyle(MorningTheme.muted)
   }
  }.frame(maxWidth:.infinity,alignment:.leading)
 }
}

private extension ChallengeSelection {
 var checkingGuide:String {
  switch kind {
  case .pushUps:return "challenge_guide_pushups"
  case .waveHand:return "challenge_guide_wave"
  case .neckRotation:return "challenge_guide_neck"
  case .jumpingJacks:return "challenge_guide_jacks"
  case .stretching:return "challenge_guide_reach"
  case .guidedRhythm:return rhythmVariant == .seated ? "challenge_guide_seated" : "challenge_guide_standing"
  case .readAloud:return "challenge_guide_words"
  case .readAndChoose,.riddle:return "challenge_guide_answer"
  case .none:return "Stop the alarm with one tap"
  }
 }
}
