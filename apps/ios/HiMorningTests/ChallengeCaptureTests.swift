import XCTest
@testable import HiMorning

final class ChallengeCaptureTests:XCTestCase {
 func testStandingAnglesRespectTheOrientedImageAspectRatio() {
  let knee=CGPoint(x:0.5,y:0.5)
  let hip=CGPoint(x:0.5,y:0.7)
  let ankle=CGPoint(x:0.9,y:0.3)
  XCTAssertEqual(GuidedRhythmCapture.jointAngle(hip,knee,ankle,imageSize:CGSize(width:320,height:640)),135,accuracy:0.001)
  XCTAssertEqual(GuidedRhythmCapture.jointAngle(hip,knee,ankle,imageSize:CGSize(width:640,height:320)),104.036,accuracy:0.001)
 }

 @MainActor func testStoppedCapturesCannotRestartOrRequestPermissions() async {
  let speech=SpeechChallengeCapture(target:"Small steps create steady progress.") {_ in XCTFail("Stopped speech capture must not publish updates")}
  let rhythm=GuidedRhythmCapture(variant:.seated) {_ in XCTFail("Stopped rhythm capture must not publish updates")}
  speech.stop();rhythm.stop()
  await speech.start()
  await rhythm.start()
  let camera=CameraCapture(target:1) {_ in XCTFail("Stopped camera must not publish updates")}
  camera.stop()
  await camera.start(requestAccess:{XCTFail("Stopped camera must not request permission");return false})
 }

 func testDeniedPushUpCameraReportsAnEndedAttemptWithoutEvidence() async {
  let ended=expectation(description:"Camera denial ends the attempt")
  let camera=CameraCapture(target:1) {update in
   XCTAssertTrue(update.ended)
   XCTAssertFalse(update.ready)
   XCTAssertTrue(update.frames.isEmpty)
   ended.fulfill()
  }
  await camera.start(requestAccess:{false})
  await fulfillment(of:[ended],timeout:1)
  camera.stop()
 }
}
