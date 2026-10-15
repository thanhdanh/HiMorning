import XCTest
import UIKit
final class PilotUITests:XCTestCase {
 private func capture(_ app:XCUIApplication,name:String) {
  let attachment=XCTAttachment(screenshot:app.screenshot())
  attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)
 }
 private func captureEditorChoices(_ app:XCUIApplication,language:String) {
  for mode in ["balanced","focused"] {
   app.buttons["mode-"+mode].tap()
   capture(app,name:mode+"-"+language)
  }
  app.buttons["chooseSound"].tap()
  XCTAssertTrue(app.navigationBars[language == "vi" ? "Âm thanh" : "Sound"].waitForExistence(timeout:5))
  app.buttons["sound-sunrise"].tap()
  XCTAssertTrue(app.sliders["previewVolume"].exists)
  capture(app,name:"sounds-"+language)
  app.navigationBars.buttons.element(boundBy:0).tap()
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
  captureEditorChoices(app,language:"en")
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
  captureEditorChoices(app,language:"vi")
  app.buttons["Hủy"].tap()
  XCTAssertTrue(app.buttons["addAlarm"].waitForExistence(timeout:5))
 }
 private func assertBrandColors(_ app:XCUIApplication) {
  let image=app.screenshot().image.cgImage!
  let scale=CGFloat(image.width)/app.frame.width
  func rgb(at point:CGPoint)->[UInt8] {
   var pixel=[UInt8](repeating:0,count:4)
   let context=CGContext(data:&pixel,width:1,height:1,bitsPerComponent:8,bytesPerRow:4,
    space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
   let crop=image.cropping(to:CGRect(x:point.x*scale,y:point.y*scale,width:1,height:1))!
   context.draw(crop,in:CGRect(x:0,y:0,width:1,height:1));return Array(pixel.prefix(3))
  }
  let canvas=rgb(at:CGPoint(x:8,y:200))
  let button=app.buttons["addAlarm"].frame
  let primary=rgb(at:CGPoint(x:button.minX+12,y:button.midY))
  for (actual,expected) in zip(canvas,[255,252,246]) {XCTAssertEqual(Int(actual),expected,accuracy:3,"Canvas must match the original warm cream")}
  for (actual,expected) in zip(primary,[245,200,66]) {XCTAssertEqual(Int(actual),expected,accuracy:3,"Primary must match the original sunshine yellow")}
 }
 private func challengeJourney(language:String) {
  let app=launch(language:language),vi=language == "vi"
  assertBrandColors(app)
  let trial=app.buttons["practiceChallenges"]
  guard trial.waitForExistence(timeout:5) else {XCTFail("A rehearsal must be available before setting an alarm");return}
  trial.tap()
  app.buttons["practice-pushUps"].tap()
  XCTAssertTrue(app.buttons["startChallenge"].waitForExistence(timeout:5))
  capture(app,name:"challenge-ready-"+language)
  app.buttons["startChallenge"].tap()
  XCTAssertTrue(app.buttons[vi ? "Đồng ý và mở camera" : "Agree and open camera"].waitForExistence(timeout:5))
  capture(app,name:"consent-"+language)
  app.buttons[vi ? "Chọn cách khác" : "Choose another way"].tap()
  XCTAssertTrue(app.buttons["stopAlarm"].exists)
  app.buttons["startChallenge"].tap()
  app.buttons[vi ? "Đồng ý và mở camera" : "Agree and open camera"].tap()
  let unavailable=vi ? "AI chưa sẵn sàng. Bạn có thể tự xác nhận hoặc dừng ngay." : "AI is not available. You can confirm you are awake or stop."
  XCTAssertTrue(app.staticTexts[unavailable].waitForExistence(timeout:5))
  capture(app,name:"ai-unavailable-"+language)
  app.buttons[vi ? "Tôi đã thức dậy" : "I’m awake"].tap()
  let confirmed=vi ? "Bạn đã tự xác nhận thức dậy. Chúc buổi sáng tốt lành!" : "You confirmed you are awake. Have a good morning!"
  XCTAssertTrue(app.staticTexts[confirmed].waitForExistence(timeout:5))
  capture(app,name:"self-confirmed-"+language)
  app.buttons[vi ? "Về trang chính" : "Back to home"].tap()
  trial.tap()
  app.buttons["practice-pushUps"].tap()
  XCTAssertTrue(app.buttons["stopAlarm"].waitForExistence(timeout:5))
  app.buttons["stopAlarm"].tap()
  let stopped=vi ? "Đã kết thúc buổi thử. Báo thức không thay đổi." : "Practice ended. Your alarms are unchanged."
  XCTAssertTrue(app.staticTexts[stopped].waitForExistence(timeout:5))
  capture(app,name:"stopped-"+language)
  app.buttons[vi ? "Về trang chính" : "Back to home"].tap()
  XCTAssertTrue(app.buttons["addAlarm"].exists)
  XCTAssertEqual(app.alerts.count,0,"Rehearsal must not ask for alarm access")
 }
 func testEnglishBrandAndRehearsalRecovery() {challengeJourney(language:"en")}
 func testVietnameseBrandAndRehearsalRecovery() {challengeJourney(language:"vi")}
 func testFreeProgressAndProDiscoveryInBothLanguages() {
  for language in ["en","vi"] {
   let app=launch(language:language)
   app.buttons["morningProgress"].tap()
   XCTAssertTrue(app.staticTexts[language == "vi" ? "7 ngày qua" : "Past 7 days"].waitForExistence(timeout:5))
   capture(app,name:"progress-"+language)
   app.buttons["closeProgress"].tap()
   app.buttons["hiMorningPro"].tap()
   XCTAssertTrue(app.staticTexts[language == "vi" ? "Lịch sử 30 ngày" : "30-day morning history"].waitForExistence(timeout:5))
   capture(app,name:"pro-"+language)
   app.buttons["closePro"].tap()
   XCTAssertTrue(app.buttons["addAlarm"].exists)
   app.terminate()
  }
 }
 func testAlarmEditorOffersDiverseChallengeChoices() {
  let app=launch(language:"en")
  app.buttons["addAlarm"].tap()
  app.swipeUp()
  let readChoice=app.buttons["challenge-readAndChoose"]
  for _ in 0..<4 where !readChoice.isHittable {app.swipeUp()}
  XCTAssertTrue(readChoice.exists)
  for id in ["none","pushUps","readAndChoose","guidedRhythm","readAloud"] {
   XCTAssertTrue(app.buttons["challenge-"+id].exists,"Missing challenge choice: \(id)")
  }
  readChoice.tap()
  let readSummary=app.staticTexts["Read one short sentence and choose its meaning."]
  for _ in 0..<3 where !readSummary.exists {app.swipeUp()}
  XCTAssertTrue(app.staticTexts["Read one short sentence and choose its meaning."].waitForExistence(timeout:3))
  for _ in 0..<3 where !app.buttons["challenge-readAloud"].isHittable {app.swipeUp()}
  app.buttons["challenge-readAloud"].tap()
  XCTAssertTrue(app.staticTexts["Read the sentence aloud. 80% recognized-word match completes it."].waitForExistence(timeout:3))
  app.buttons["Cancel"].tap()
 }
 func testReadingPracticeCompletesOfflineInBothLanguages() {
  for language in ["en","vi"] {
   let app=launch(language:language),vi=language == "vi"
   app.buttons["practiceChallenges"].tap()
   app.buttons["practice-readAndChoose"].tap()
   XCTAssertTrue(app.buttons["readChoice-0"].waitForExistence(timeout:5))
   XCTAssertFalse(app.buttons["startChallenge"].exists)
   XCTAssertFalse(app.buttons["startReadAloud"].exists)
   XCTAssertTrue(app.buttons["stopAlarm"].exists)
   XCTAssertEqual(app.alerts.count,0,"Reading practice needs no camera, speech or alarm permission")
   for index in 0..<3 {
    let option=app.buttons["readChoice-\(index)"]
    if option.exists {option.tap()}
    if app.buttons[vi ? "Về trang chính" : "Back to home"].waitForExistence(timeout:1) {break}
   }
   XCTAssertTrue(app.staticTexts[vi ? "Chính xác. Đã hoàn thành thử thách!" : "Correct. Challenge completed!"].waitForExistence(timeout:5))
   capture(app,name:"read-choose-complete-"+language)
   app.buttons[vi ? "Về trang chính" : "Back to home"].tap()
   app.terminate()
  }
 }
 func testModeDefaultsMatchTargetAndKeepAnExplicitChallenge() {
  let app=launch(language:"en")
  app.buttons["addAlarm"].tap()
  app.buttons["mode-focused"].tap()
  app.swipeUp()
  let target=app.steppers["pushUpTarget"]
  XCTAssertTrue(target.waitForExistence(timeout:3))
  XCTAssertTrue(target.label.contains("5"))
  app.buttons["challenge-readAndChoose"].tap()
  app.swipeDown()
  app.buttons["mode-balanced"].tap()
  app.swipeUp()
  XCTAssertTrue(app.buttons["challenge-readAndChoose"].isSelected)
  XCTAssertFalse(app.steppers["pushUpTarget"].exists)
  app.buttons["Cancel"].tap()
 }
 func testLocalPracticeKeepsStopAvailableBeforeRequestingPermissions() {
  let app=launch(language:"en")
  for (kind,startButton) in [("none",""),("readAloud","startReadAloud"),("guidedRhythm","startGuidedRhythm")] {
   app.buttons["practiceChallenges"].tap()
   app.buttons["practice-"+kind].tap()
   XCTAssertTrue(app.buttons["stopAlarm"].waitForExistence(timeout:5))
   if !startButton.isEmpty {XCTAssertTrue(app.buttons[startButton].exists)}
   XCTAssertFalse(app.buttons["startChallenge"].exists)
   XCTAssertEqual(app.alerts.count,0)
   app.buttons["stopAlarm"].tap()
   XCTAssertTrue(app.staticTexts["Practice ended. Your alarms are unchanged."].waitForExistence(timeout:5))
   app.buttons["Back to home"].tap()
  }
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
