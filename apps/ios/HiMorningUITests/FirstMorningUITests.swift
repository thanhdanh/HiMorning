import XCTest

final class FirstMorningUITests:XCTestCase {
 private func launch(vietnamese:Bool=false,arguments:[String]=[])->XCUIApplication {
  let app=XCUIApplication()
  app.launchArguments=["-AppleLanguages","(en)","-AppleLocale","en_US","--ui-testing"]+arguments
  if vietnamese {app.launchArguments.append("--ui-language-vi")}
  app.launch()
  XCTAssertTrue(app.buttons["appLanguage"].waitForExistence(timeout:5))
  return app
 }
 private func reveal(_ element:XCUIElement,in app:XCUIApplication) {
  for _ in 0..<10 {
   if element.exists,element.isHittable,element.frame.maxY<app.frame.maxY-30 {return}
   app.swipeUp()
  }
  XCTAssertTrue(element.isHittable)
 }
 private func capture(_ app:XCUIApplication,_ name:String) {
  let attachment=XCTAttachment(screenshot:app.screenshot())
  attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)
 }
 func testFirstPracticeExplainsValueAndOffersFirstAlarmWithoutCountingInBothLanguages() {
  for vi in [false,true] {
   let app=launch(vietnamese:vi,arguments:["--ui-empty-home","--ui-reading-correct-first"])
   XCTAssertEqual(app.staticTexts["firstMorningPromise"].label,vi ? "Bắt đầu buổi sáng bằng một thành công nhỏ." : "Start your morning with a small win.")
   capture(app,"first-morning-\(vi ? "vi" : "en")")
   let practice=app.buttons["quickPractice"];reveal(practice,in:app);practice.tap()
   let choice=app.buttons["readChoice-0"]
   XCTAssertTrue(choice.waitForExistence(timeout:5))
   XCTAssertEqual(app.alerts.count,0,"Reading practice needs no permission prompt")
   choice.tap()
   XCTAssertTrue(app.staticTexts["practiceCompleteExplanation"].waitForExistence(timeout:5))
   capture(app,"practice-complete-\(vi ? "vi" : "en")")
   let next=app.buttons["setFirstAlarmAfterPractice"]
   XCTAssertTrue(next.isHittable);next.tap()
   XCTAssertTrue(app.buttons["saveAlarm"].waitForExistence(timeout:5))
   app.buttons[vi ? "Hủy" : "Cancel"].tap()
   XCTAssertTrue(app.buttons["quickPractice"].waitForExistence(timeout:5))
   XCTAssertFalse(app.staticTexts["recentWinCount"].exists)
   app.buttons["morningProgress"].tap()
   XCTAssertTrue(app.staticTexts[vi ? "Hoàn thành thử thách đầu tiên để xem xếp hạng của bạn." : "Complete your first challenge to see your rating."].waitForExistence(timeout:5))
   app.terminate()
  }
 }
 func testFreeHomeShowsRecentActualWinsAndPracticeKeepsCount() {
  let app=launch(arguments:["--ui-home-alarms","--ui-progress-fixture","--preview-expired","--ui-reading-correct-first"])
  let count=app.staticTexts["recentWinCount"];reveal(count,in:app)
  XCTAssertEqual(count.label,"5 of the last 7 days with a completed challenge")
  capture(app,"free-home-recent-wins")
  let explore=app.buttons["practiceChallenges"]
  if !explore.isHittable {app.swipeDown()}
  explore.tap();app.buttons["practice-readAndChoose"].tap()
  XCTAssertTrue(app.buttons["readChoice-0"].waitForExistence(timeout:5));app.buttons["readChoice-0"].tap()
  XCTAssertTrue(app.staticTexts["practiceCompleteExplanation"].waitForExistence(timeout:5))
  XCTAssertFalse(app.buttons["setFirstAlarmAfterPractice"].exists)
  app.buttons["backToHome"].tap()
  reveal(count,in:app)
  XCTAssertEqual(count.label,"5 of the last 7 days with a completed challenge")
  app.terminate()
 }
 func testFirstUseRemainsReachableWithLargeVietnameseText() {
  let app=launch(vietnamese:true,arguments:["--ui-empty-home","-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityXXXL"])
  XCTAssertTrue(app.staticTexts["firstMorningPromise"].exists)
  reveal(app.buttons["quickPractice"],in:app)
  capture(app,"first-morning-vi-accessibility")
  app.terminate()
 }
}
