import XCTest

final class ChallengeCelebrationUITests:XCTestCase {
 private func answerReadAndChoose(in app:XCUIApplication,until result:XCUIElement) {
  for index in 0..<3 {
   let choice=app.buttons["readChoice-\(index)"]
   XCTAssertTrue(choice.waitForExistence(timeout:5),"The reading challenge should offer three answer choices")
   choice.tap()
   if result.waitForExistence(timeout:1) {return}
  }
  XCTFail("One of the answer choices should complete the reading challenge")
 }
 private func launch(_ arguments:[String]=[],vietnamese:Bool=false)->XCUIApplication {
  let app=XCUIApplication()
  app.launchArguments=["-AppleLanguages","(en)","-AppleLocale","en_US","--ui-testing"]+arguments
  if vietnamese {app.launchArguments.append("--ui-language-vi")}
  app.launch()
  if !arguments.contains("--ui-open-alarm") {XCTAssertTrue(app.buttons["practiceChallenges"].waitForExistence(timeout:5))}
  return app
 }
 func testRealAlarmCompletionReturnsHomeAndMarksOnlyThatAlarmInBothLanguages() {
  let first="00000000-0000-0000-0000-000000000001",second="00000000-0000-0000-0000-000000000002"
  for vietnamese in [false,true] {
   let largeText=vietnamese ? ["-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityM"] : []
   let app=launch(["--ui-home-alarms","--ui-open-alarm","--ui-reading-correct-first"]+largeText,vietnamese:vietnamese)
   let completed=app.staticTexts["alarmCompleted-"+first]
   answerReadAndChoose(in:app,until:completed)
   XCTAssertTrue(completed.waitForExistence(timeout:5),"A real completed challenge must return Home automatically")
   XCTAssertEqual(completed.label,vietnamese ? "Đã xong hôm nay" : "Completed today")
   XCTAssertFalse(app.descendants(matching:.any)["alarmCompleted-"+second].exists)
   XCTAssertTrue(app.staticTexts["nextAlarm-"+first].exists,"Completion must preserve the repeating alarm's next ring")
   XCTAssertEqual(app.switches["toggleAlarm-"+first].value as? String,"1")
   XCTAssertFalse(app.staticTexts[vietnamese ? "Đã đặt với hệ thống" : "Alarm is set"].exists)
   let attachment=XCTAttachment(screenshot:app.screenshot())
   attachment.name="alarm-home-completed-\(vietnamese ? "vi-large" : "en")"
   attachment.lifetime = .keepAlways;add(attachment)
   XCTAssertEqual(app.alerts.count,0)
   app.buttons["morningProgress"].tap()
   let history=app.otherElements["selectedDayChallenges"]
   XCTAssertTrue(history.waitForExistence(timeout:5))
   XCTAssertTrue(history.staticTexts.matching(NSPredicate(format:"identifier BEGINSWITH %@","historyMode-")).firstMatch.label.contains(vietnamese ? "Vừa sức" : "Balanced"))
   XCTAssertTrue(history.staticTexts.matching(NSPredicate(format:"identifier BEGINSWITH %@","historyChallenge-")).firstMatch.label.contains(vietnamese ? "Đọc và Chọn" : "Read & Choose"))
   app.terminate()
  }
 }
 func testRealAlarmProgressSaveFailureReturnsHomeWithAnHonestWarning() {
  let app=launch(["--ui-home-alarms","--ui-open-alarm","--ui-progress-save-error","--ui-reading-correct-first"])
  let progressError=app.staticTexts["homeProgressError"]
  answerReadAndChoose(in:app,until:progressError)
  XCTAssertTrue(progressError.waitForExistence(timeout:5))
  XCTAssertFalse(app.descendants(matching:.any)["alarmCompleted-00000000-0000-0000-0000-000000000001"].exists)
  app.terminate()
 }
 func testCompletionDoesNotHideSchedulingWarningsOrMarkPractice() {
  let id="00000000-0000-0000-0000-000000000001"
  let app=launch(["--ui-enabled-alarm","--ui-completed-alarm"])
  XCTAssertTrue(app.staticTexts["alarmCompleted-"+id].waitForExistence(timeout:5))
  XCTAssertTrue(app.descendants(matching:.any)["alarmState-"+id].label.contains("Check system alarms"))
  app.terminate()
  let practice=launch(["--ui-home-alarms","--ui-complete-challenge"])
  for _ in 0..<8 where !practice.buttons["practiceChallenges"].isHittable {practice.swipeUp()}
  practice.buttons["practiceChallenges"].tap();practice.buttons["practice-readAndChoose"].tap()
  checkCelebration(practice)
  XCTAssertEqual(practice.descendants(matching:.any).matching(NSPredicate(format:"identifier BEGINSWITH %@","alarmCompleted-")).count,0)
  practice.terminate()
 }
 private func checkCelebration(_ app:XCUIApplication,vietnamese:Bool=false) {
  XCTAssertTrue(app.staticTexts[vietnamese ? "Chúc mừng!" : "Hooray!"].waitForExistence(timeout:5))
  XCTAssertTrue(app.staticTexts[vietnamese ? "Thử thách hoàn thành!" : "Challenge complete!"].exists)
  let retry=app.buttons["retryChallenge"]
  XCTAssertTrue(retry.isHittable,"A passed challenge must still allow another attempt")
  XCTAssertEqual(retry.label,vietnamese ? "Thử lại" : "Try again")
  let home=app.buttons["backToHome"]
  XCTAssertTrue(home.isHittable,"Exit must be usable while the celebration is visible")
  XCTAssertTrue(app.windows.firstMatch.frame.contains(home.frame),"Exit must fit on screen")
  let attachment=XCTAttachment(screenshot:app.screenshot())
  attachment.name="challenge-celebration-\(vietnamese ? "vi" : "en")"
  attachment.lifetime = .keepAlways;add(attachment)
  home.tap()
  XCTAssertTrue(app.buttons["practiceChallenges"].waitForExistence(timeout:5))
 }
 func testReadingSuccessCelebratesAndReturnsHomeInBothLanguages() {
  for vietnamese in [false,true] {
   let app=launch(["--ui-reading-correct-first"],vietnamese:vietnamese)
   app.buttons["practiceChallenges"].tap();app.buttons["practice-readAndChoose"].tap()
   XCTAssertTrue(app.buttons["readChoice-0"].waitForExistence(timeout:5))
   for index in 0..<3 {
    let choice=app.buttons["readChoice-\(index)"]
    if choice.exists {choice.tap()}
    if app.buttons["retryChallenge"].waitForExistence(timeout:1) {break}
   }
   for _ in 0..<2 {
    let retry=app.buttons["retryChallenge"]
    XCTAssertTrue(retry.waitForExistence(timeout:5))
    retry.tap()
    XCTAssertFalse(app.staticTexts["Hooray!"].exists)
    XCTAssertTrue(app.buttons["readChoice-0"].waitForExistence(timeout:5))
    for index in 0..<3 {
     let choice=app.buttons["readChoice-\(index)"]
     if choice.exists {choice.tap()}
     if retry.waitForExistence(timeout:1) {break}
    }
   }
   checkCelebration(app,vietnamese:vietnamese)
   XCTAssertEqual(app.alerts.count,0)
   app.terminate()
  }
 }
 func testReadAloudRetryKeepsTheSentenceAndClearsThePreviousScore() {
  let app=launch(["--ui-complete-challenge","--ui-reading-transcript","small steps create steady","--ui-reading-finished"])
  app.buttons["practiceChallenges"].tap();app.buttons["practice-readAloud"].tap()
  XCTAssertTrue(app.buttons["retryChallenge"].waitForExistence(timeout:5))
  let prompt=app.staticTexts["readingPrompt"].label
  XCTAssertEqual(app.staticTexts["readingScore"].label,"Word match: 80/100")
  app.buttons["retryChallenge"].tap()
  XCTAssertTrue(app.buttons["startReadAloud"].waitForExistence(timeout:5))
  XCTAssertEqual(app.staticTexts["readingPrompt"].label,prompt)
  XCTAssertEqual(app.staticTexts["readingScore"].label,"Word match: 0/100")
  XCTAssertFalse(app.staticTexts["speechTranscript"].exists)
  XCTAssertFalse(app.staticTexts["readingIncorrectWords"].exists)
  XCTAssertFalse(app.staticTexts["listeningIndicator"].exists)
  XCTAssertFalse(app.buttons["retryChallenge"].exists)
  XCTAssertEqual(app.alerts.count,0)
  XCTAssertFalse(app.buttons["stopAlarm"].exists)
  XCTAssertFalse(app.buttons["End practice"].exists)
  app.buttons["backToHome"].tap()
  XCTAssertTrue(app.buttons["practiceChallenges"].waitForExistence(timeout:5))
  app.terminate()
 }
 func testMovementRetryRestoresStartControlsWithoutRequestingPermissions() {
  for (kind,start) in [("pushUps","startChallenge"),("guidedRhythm","startGuidedRhythm")] {
   let app=launch(["--ui-complete-challenge"])
   app.buttons["practiceChallenges"].tap();app.buttons["practice-"+kind].tap()
   XCTAssertTrue(app.buttons["retryChallenge"].waitForExistence(timeout:5))
   app.buttons["retryChallenge"].tap()
   XCTAssertTrue(app.buttons[start].waitForExistence(timeout:5))
   XCTAssertTrue(app.buttons[start].isEnabled)
   XCTAssertEqual(app.alerts.count,0)
   app.buttons["backToHome"].tap()
   XCTAssertTrue(app.buttons["practiceChallenges"].waitForExistence(timeout:5))
   app.terminate()
  }
 }
 func testEverySuccessfulChallengeHasAnExitWithLargeText() {
  for kind in ["pushUps","guidedRhythm","readAloud"] {
   let app=launch(["--ui-complete-challenge","-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityM"],vietnamese:true)
   app.buttons["practiceChallenges"].tap();app.buttons["practice-"+kind].tap()
   if kind == "readAloud" {XCTAssertEqual(app.staticTexts["readingScore"].label,"Trùng khớp từ: 100/100")}
   checkCelebration(app,vietnamese:true)
   XCTAssertEqual(app.alerts.count,0,"Presentation fixtures must not request camera, microphone or alarm access")
   app.terminate()
  }
 }
 func testPracticeExitReturnsHomeAndSelfConfirmationKeepsItsOwnMessage() {
  let app=launch(["--ui-awake-ready"])
  app.buttons["practiceChallenges"].tap();app.buttons["practice-readAloud"].tap()
  XCTAssertTrue(app.buttons["backToHome"].waitForExistence(timeout:5))
  XCTAssertFalse(app.buttons["stopAlarm"].exists)
  app.buttons["backToHome"].tap()
  XCTAssertTrue(app.buttons["practiceChallenges"].waitForExistence(timeout:5))
  XCTAssertFalse(app.staticTexts["Hooray!"].exists)
  XCTAssertFalse(app.buttons["retryChallenge"].exists)
  app.buttons["practiceChallenges"].tap();app.buttons["practice-none"].tap()
  app.buttons["confirmAwake"].tap()
  XCTAssertTrue(app.staticTexts["You confirmed you are awake."].waitForExistence(timeout:5))
  XCTAssertFalse(app.staticTexts["Challenge complete!"].exists)
  XCTAssertFalse(app.buttons["retryChallenge"].exists)
  XCTAssertTrue(app.buttons["backToHome"].isHittable)
  app.terminate()
 }
 func testAwakeConfirmationCountsDownBeforeEnabling() {
  let app=launch()
  app.buttons["practiceChallenges"].tap();app.buttons["practice-none"].tap()
  let awake=app.buttons["confirmAwake"]
  XCTAssertTrue(awake.waitForExistence(timeout:5))
  XCTAssertFalse(awake.isEnabled)
  XCTAssertTrue(awake.label.contains("Available in 4:") || awake.label.contains("Available in 5:00"))
  XCTAssertFalse(app.buttons["stopAlarm"].exists)
  XCTAssertTrue(app.buttons["backToHome"].isEnabled)
  app.terminate()
  let nearEnd=launch(["--ui-awake-countdown-near-end"],vietnamese:true)
  nearEnd.buttons["practiceChallenges"].tap();nearEnd.buttons["practice-none"].tap()
  let confirm=nearEnd.buttons["confirmAwake"]
  XCTAssertTrue(confirm.waitForExistence(timeout:5))
  let enabled=XCTNSPredicateExpectation(predicate:NSPredicate(format:"enabled == true"),object:confirm)
  XCTAssertEqual(XCTWaiter.wait(for:[enabled],timeout:8),.completed)
  XCTAssertFalse(confirm.label.contains(":"),"Countdown disappears when confirmation becomes available")
  confirm.tap()
  XCTAssertTrue(nearEnd.staticTexts["Bạn đã xác nhận thức dậy."].waitForExistence(timeout:5))
  nearEnd.terminate()
 }
 func testReadAloudListeningIndicatorNeedsNoAudioPermissionToPresent() {
  let app=launch(["--ui-reading-listening","--ui-reading-transcript","small steps"])
  app.buttons["practiceChallenges"].tap();app.buttons["practice-readAloud"].tap()
  XCTAssertTrue(app.staticTexts["listeningIndicator"].waitForExistence(timeout:5))
  XCTAssertEqual(app.alerts.count,0)
  app.buttons["backToHome"].tap()
  XCTAssertTrue(app.buttons["practiceChallenges"].waitForExistence(timeout:5))
  XCTAssertFalse(app.staticTexts["listeningIndicator"].exists)
  app.terminate()
 }
}
