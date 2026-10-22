import XCTest

final class ChallengeContentUITests:XCTestCase {
 private func launch(vi:Bool=false,id:String,_ extra:[String]=[])->XCUIApplication {
  let app=XCUIApplication()
  app.launchArguments=["-AppleLanguages","(en)","-AppleLocale","en_US","--ui-testing","--ui-reading-correct-first","--ui-content-id",id]+extra
  if vi {app.launchArguments.append("--ui-language-vi")}
  app.launch();return app
 }
 private func reveal(_ element:XCUIElement,in app:XCUIApplication) {
  for _ in 0..<12 {
   if element.exists,element.isHittable,element.frame.maxY<app.frame.maxY-30 {return}
   app.scrollViews.firstMatch.swipeUp()
  }
  XCTAssertTrue(element.isHittable)
 }
 private func capture(_ app:XCUIApplication,_ name:String) {
  let attachment=XCTAttachment(screenshot:app.screenshot());attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)
 }
 func testReadingInferenceAndExplanationInBothLanguages() {
  for vi in [false,true] {
   let lang=vi ? "vi":"en"
   let app=launch(vi:vi,id:"rc-v2-\(lang)-012",["--ui-empty-home"])
   let purpose=app.buttons["chooseMorningPurpose"];XCTAssertTrue(purpose.waitForExistence(timeout:5));purpose.tap()
   app.buttons["morningPurpose-clearStart"].tap();app.buttons["tryJourneyMission"].tap()
   XCTAssertTrue(app.staticTexts["contentTheme"].waitForExistence(timeout:5))
   XCTAssertEqual(app.staticTexts["contentTheme"].label,vi ? "Bạn bè & kế hoạch":"People & plans")
   XCTAssertFalse(app.staticTexts["contentExplanation"].exists)
   XCTAssertFalse(app.buttons["confirmAwake"].exists)
   capture(app,"content-reading-\(lang)")
   let wrong=app.buttons["readChoice-1"];reveal(wrong,in:app);wrong.tap()
   XCTAssertFalse(app.staticTexts["contentExplanation"].exists)
   let correct=app.buttons["readChoice-0"];reveal(correct,in:app);correct.tap()
   let explanation=app.staticTexts["contentExplanation"];XCTAssertTrue(explanation.waitForExistence(timeout:5));reveal(explanation,in:app)
   XCTAssertTrue(explanation.label.contains(vi ? "chưa chốt":"not confirmed"))
   capture(app,"content-explanation-\(lang)")
   app.buttons["backToHome"].tap()
   XCTAssertTrue(app.staticTexts["journeyProgress"].waitForExistence(timeout:5));XCTAssertTrue(app.staticTexts["journeyProgress"].label.contains("0"))
   XCTAssertFalse(app.staticTexts["homeContentTakeaway"].exists)
   app.terminate()
  }
 }
 func testRealCompletionReturnsHomeWithTakeaway() {
  let app=launch(id:"rc-v2-en-003",["--ui-home-alarms","--ui-journey-fixture","--ui-open-alarm"])
  let correct=app.buttons["readChoice-0"];XCTAssertTrue(correct.waitForExistence(timeout:5));reveal(correct,in:app);correct.tap()
  let takeaway=app.staticTexts["homeContentTakeaway"];XCTAssertTrue(takeaway.waitForExistence(timeout:8));reveal(takeaway,in:app)
  XCTAssertTrue(takeaway.label.contains("lacks a seat"))
  XCTAssertFalse(app.buttons["readChoice-0"].exists)
  XCTAssertEqual(app.staticTexts["journeyProgress"].label,"4 of 7 mornings earned")
  capture(app,"content-real-completion-takeaway");app.terminate()
 }
 func testVietnameseLogicAndVoiceThemesAreVisible() {
  for voice in [false,true] {
   let app=launch(vi:true,id:voice ? "voice-v2-vi-007":"logic-v2-vi-008",["--ui-empty-home"])
   let explore=app.buttons["practiceChallenges"];XCTAssertTrue(explore.waitForExistence(timeout:5));reveal(explore,in:app);explore.tap()
   app.buttons[voice ? "practice-readAloud":"practice-riddle"].tap()
   let theme=app.staticTexts["contentTheme"];XCTAssertTrue(theme.waitForExistence(timeout:5))
   XCTAssertEqual(theme.label,voice ? "Chuyện thường ngày":"Bạn bè & kế hoạch")
   XCTAssertFalse(app.staticTexts["contentExplanation"].exists)
   capture(app,voice ? "content-voice-vi":"content-logic-vi")
   if !voice {
    let correct=app.buttons["Hộp xanh lá"];reveal(correct,in:app);correct.tap()
    let explanation=app.staticTexts["contentExplanation"];XCTAssertTrue(explanation.waitForExistence(timeout:5));reveal(explanation,in:app)
    XCTAssertTrue(explanation.label.contains("cả hai"));capture(app,"content-logic-explanation-vi")
   }
   app.terminate()
  }
 }
 func testLargeVietnameseQuestionKeepsChoicesAndExplanationReachable() {
  let app=launch(vi:true,id:"rc-v2-vi-003",["--ui-empty-home","-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityXXXL"])
  let purpose=app.buttons["chooseMorningPurpose"];XCTAssertTrue(purpose.waitForExistence(timeout:5));reveal(purpose,in:app);purpose.tap()
  let choice=app.buttons["morningPurpose-clearStart"];reveal(choice,in:app);choice.tap()
  let practice=app.buttons["tryJourneyMission"];reveal(practice,in:app);practice.tap()
  let correct=app.buttons["readChoice-0"];XCTAssertTrue(correct.waitForExistence(timeout:5));reveal(correct,in:app)
  capture(app,"content-reading-vi-accessibility");correct.tap()
  let explanation=app.staticTexts["contentExplanation"];XCTAssertTrue(explanation.waitForExistence(timeout:5));reveal(explanation,in:app)
  XCTAssertTrue(explanation.label.contains("thiếu"));capture(app,"content-explanation-vi-accessibility")
  app.terminate()
 }
}
