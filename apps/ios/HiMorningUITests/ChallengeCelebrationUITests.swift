import XCTest

final class ChallengeCelebrationUITests:XCTestCase {
 private func launch(_ arguments:[String]=[],vietnamese:Bool=false)->XCUIApplication {
  let app=XCUIApplication()
  app.launchArguments=["-AppleLanguages","(en)","-AppleLocale","en_US","--ui-testing"]+arguments
  if vietnamese {app.launchArguments.append("--ui-language-vi")}
  app.launch()
  XCTAssertTrue(app.buttons["practiceChallenges"].waitForExistence(timeout:5))
  return app
 }
 private func checkCelebration(_ app:XCUIApplication,vietnamese:Bool=false) {
  XCTAssertTrue(app.staticTexts[vietnamese ? "Hoan hô!" : "Hooray!"].waitForExistence(timeout:5))
  XCTAssertTrue(app.staticTexts[vietnamese ? "Đã hoàn thành thử thách!" : "Challenge complete!"].exists)
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
   let app=launch(vietnamese:vietnamese)
   app.buttons["practiceChallenges"].tap();app.buttons["practice-readAndChoose"].tap()
   XCTAssertTrue(app.buttons["readChoice-0"].waitForExistence(timeout:5))
   for index in 0..<3 {
    let choice=app.buttons["readChoice-\(index)"]
    if choice.exists {choice.tap()}
    if app.buttons[vietnamese ? "Về trang chính" : "Back to home"].waitForExistence(timeout:1) {break}
   }
   checkCelebration(app,vietnamese:vietnamese)
   XCTAssertEqual(app.alerts.count,0)
   app.terminate()
  }
 }
 func testEverySuccessfulChallengeHasAnExitWithLargeText() {
  for kind in ["pushUps","guidedRhythm","readAloud"] {
   let app=launch(["--ui-complete-challenge","-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityM"],vietnamese:true)
   app.buttons["practiceChallenges"].tap();app.buttons["practice-"+kind].tap()
   if kind == "readAloud" {XCTAssertEqual(app.staticTexts["readingScore"].label,"Điểm khớp từ: 100/100")}
   checkCelebration(app,vietnamese:true)
   XCTAssertEqual(app.alerts.count,0,"Presentation fixtures must not request camera, microphone or alarm access")
   app.terminate()
  }
 }
 func testStoppingAndSelfConfirmationKeepTheirOwnMessages() {
  let app=launch(["--ui-awake-ready"])
  app.buttons["practiceChallenges"].tap();app.buttons["practice-readAloud"].tap()
  app.buttons["stopAlarm"].tap()
  XCTAssertTrue(app.staticTexts["Practice ended. Your alarms are unchanged."].waitForExistence(timeout:5))
  XCTAssertFalse(app.staticTexts["Hooray!"].exists)
  app.buttons["backToHome"].tap()
  app.buttons["practiceChallenges"].tap();app.buttons["practice-none"].tap()
  app.buttons["confirmAwake"].tap()
  XCTAssertTrue(app.staticTexts["You confirmed you are awake. Have a good morning!"].waitForExistence(timeout:5))
  XCTAssertFalse(app.staticTexts["Challenge complete!"].exists)
  XCTAssertTrue(app.buttons["backToHome"].isHittable)
  app.terminate()
 }
 func testAwakeConfirmationCountsDownBeforeEnabling() {
  let app=launch()
  app.buttons["practiceChallenges"].tap();app.buttons["practice-none"].tap()
  let awake=app.buttons["confirmAwake"]
  XCTAssertTrue(awake.waitForExistence(timeout:5))
  XCTAssertFalse(awake.isEnabled)
  XCTAssertTrue(awake.label.contains("Available in 1:") || awake.label.contains("Available in 2:00"))
  XCTAssertTrue(app.buttons["stopAlarm"].isEnabled)
  app.terminate()
  let nearEnd=launch(["--ui-awake-countdown-near-end"],vietnamese:true)
  nearEnd.buttons["practiceChallenges"].tap();nearEnd.buttons["practice-none"].tap()
  let confirm=nearEnd.buttons["confirmAwake"]
  XCTAssertTrue(confirm.waitForExistence(timeout:5))
  let enabled=XCTNSPredicateExpectation(predicate:NSPredicate(format:"enabled == true"),object:confirm)
  XCTAssertEqual(XCTWaiter.wait(for:[enabled],timeout:8),.completed)
  XCTAssertFalse(confirm.label.contains(":"),"Countdown disappears when confirmation becomes available")
  confirm.tap()
  XCTAssertTrue(nearEnd.buttons["backToHome"].waitForExistence(timeout:5))
  nearEnd.terminate()
 }
 func testReadAloudListeningIndicatorNeedsNoAudioPermissionToPresent() {
  let app=launch(["--ui-reading-listening","--ui-reading-transcript","small steps"])
  app.buttons["practiceChallenges"].tap();app.buttons["practice-readAloud"].tap()
  XCTAssertTrue(app.staticTexts["listeningIndicator"].waitForExistence(timeout:5))
  XCTAssertEqual(app.alerts.count,0)
  app.buttons["stopAlarm"].tap()
  XCTAssertTrue(app.buttons["backToHome"].waitForExistence(timeout:5))
  XCTAssertFalse(app.staticTexts["listeningIndicator"].exists)
  app.terminate()
 }
}
