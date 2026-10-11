import XCTest
final class PilotUITests:XCTestCase {
 private func capture(_ app:XCUIApplication,name:String) {
  let attachment=XCTAttachment(screenshot:app.screenshot())
  attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)
 }
 private func launch(language:String)->XCUIApplication {
  let app=XCUIApplication()
  app.launchArguments=["-AppleLanguages","(en)","-AppleLocale","en_US"]
  app.launch()
  app.buttons["appLanguage"].tap()
  if language == "en" {app.buttons["English"].tap()}
  else {
   let choice=app.buttons["Vietnamese"].exists ? app.buttons["Vietnamese"] : app.buttons["Tiếng Việt"]
   choice.tap()
  }
  return app
 }
 func testEnglishGentleDefaultAndCancelWithoutPermissions() {
  let app=launch(language:"en")
  capture(app,name:"home-en")
  app.buttons["addAlarm"].tap()
  XCTAssertTrue(app.navigationBars["New alarm"].waitForExistence(timeout:5))
  XCTAssertTrue(app.staticTexts["Wake up at your own pace"].exists)
  capture(app,name:"alarm-editor-en")
  app.buttons["Cancel"].tap()
  XCTAssertTrue(app.buttons["addAlarm"].waitForExistence(timeout:5))
 }
 func testVietnameseGentleDefaultAndCancelWithoutPermissions() {
  let app=launch(language:"vi")
  capture(app,name:"home-vi")
  app.buttons["addAlarm"].tap()
  XCTAssertTrue(app.navigationBars["Báo thức mới"].waitForExistence(timeout:5))
  XCTAssertTrue(app.staticTexts["Thức dậy theo nhịp của bạn"].exists)
  capture(app,name:"alarm-editor-vi")
  app.buttons["Hủy"].tap()
  XCTAssertTrue(app.buttons["addAlarm"].waitForExistence(timeout:5))
 }
 func testLanguageChoiceSurvivesRelaunch() {
  let app=launch(language:"en")
  app.buttons["appLanguage"].tap()
  app.buttons["Vietnamese"].tap()
  XCTAssertTrue(app.buttons["Thêm báo thức"].waitForExistence(timeout:5))
  app.terminate()
  app.launchArguments=["-AppleLanguages","(en)","-AppleLocale","en_US"]
  app.launch()
  XCTAssertTrue(app.buttons["Thêm báo thức"].waitForExistence(timeout:5))
 }
}
