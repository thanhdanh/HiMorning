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
  let chooseSound=app.buttons["chooseSound"]
  XCTAssertTrue(chooseSound.isHittable,"Sound selection must be reachable without scrolling")
  chooseSound.tap()
  XCTAssertTrue(app.buttons["sound-system"].waitForExistence(timeout:5))
  app.buttons["sound-sunrise"].tap()
  let slider=app.sliders["previewVolume"]
  for _ in 0..<10 where !slider.isHittable {app.swipeUp()}
  XCTAssertTrue(slider.isHittable)
  capture(app,name:"sounds-"+language)
  app.buttons["chooseSound"].tap()
 }
 private func launch(language:String,expired:Bool=false,awakeReady:Bool=false)->XCUIApplication {
  let app=XCUIApplication()
  app.terminate()
  app.launchArguments=["-AppleLanguages","(en)","-AppleLocale","en_US","--ui-testing"]
  if language == "vi" {app.launchArguments.append("--ui-language-vi")}
  if expired {app.launchArguments.append("--preview-expired")}
  if awakeReady {app.launchArguments.append("--ui-awake-ready")}
  app.launch()
  for identifier in ["closeProgress","closePro"] {
   if app.buttons[identifier].exists {app.buttons[identifier].tap()}
  }
  XCTAssertTrue(app.buttons["appLanguage"].waitForExistence(timeout:5))
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
  let app=launch(language:language,awakeReady:true),vi=language == "vi"
  assertBrandColors(app)
  let trial=app.buttons["practiceChallenges"]
  guard trial.waitForExistence(timeout:5) else {XCTFail("A rehearsal must be available before setting an alarm");return}
  trial.tap()
  app.buttons["practice-pushUps"].tap()
  XCTAssertTrue(app.buttons["startChallenge"].waitForExistence(timeout:5))
  XCTAssertEqual(app.staticTexts.matching(identifier:"challengeMessage").count,1)
  capture(app,name:"challenge-ready-"+language)
  app.buttons["startChallenge"].tap()
  XCTAssertTrue(app.buttons[vi ? "Đồng ý và chạy thử" : "Agree and run test"].waitForExistence(timeout:5))
  capture(app,name:"consent-"+language)
  app.buttons[vi ? "Chọn cách khác" : "Choose another way"].tap()
  XCTAssertTrue(app.buttons["backToHome"].exists)
  app.buttons["startChallenge"].tap()
  app.buttons[vi ? "Đồng ý và chạy thử" : "Agree and run test"].tap()
  let unavailable=vi ? "Chưa chạy được phép thử từ xa. Bạn vẫn có thể dừng." : "The remote test is unavailable. You can still stop."
  XCTAssertTrue(app.staticTexts[unavailable].waitForExistence(timeout:5))
  XCTAssertFalse(app.staticTexts[vi ? "Hoan hô!" : "Hooray!"].exists)
  capture(app,name:"ai-unavailable-"+language)
  app.buttons["confirmAwake"].tap()
  let confirmed=vi ? "Bạn đã tự xác nhận thức dậy. Chúc buổi sáng tốt lành!" : "You confirmed you are awake. Have a good morning!"
  XCTAssertTrue(app.staticTexts[confirmed].waitForExistence(timeout:5))
  capture(app,name:"self-confirmed-"+language)
  app.buttons["backToHome"].tap()
  trial.tap()
  app.buttons["practice-pushUps"].tap()
  XCTAssertTrue(app.buttons["backToHome"].waitForExistence(timeout:5))
  app.buttons["backToHome"].tap()
  XCTAssertTrue(trial.waitForExistence(timeout:5))
  capture(app,name:"returned-home-"+language)
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
 func testProgressScoresAndEmptyStateInBothLanguages() {
  for language in ["en","vi"] {
   for fixture in [false,true] {
    let app=XCUIApplication()
    app.launchArguments=["-AppleLanguages","(en)","-AppleLocale","en_US","--ui-testing"]
    if language == "vi" {app.launchArguments.append("--ui-language-vi")}
    if fixture {app.launchArguments.append("--ui-progress-fixture")}
    app.launch()
    XCTAssertTrue(app.buttons["morningProgress"].waitForExistence(timeout:5))
    let check=app.alerts[language == "vi" ? "Cần kiểm tra" : "Please check"]
    if check.waitForExistence(timeout:1) {check.buttons[language == "vi" ? "Đã hiểu" : "Got it"].tap()}
    app.buttons["morningProgress"].tap()
    XCTAssertTrue(app.staticTexts["monthlyScore"].waitForExistence(timeout:5))
    XCTAssertEqual(app.staticTexts["monthlyScore"].label == "—",!fixture)
    XCTAssertEqual(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","morningScore-")).count,7)
    if fixture {
     XCTAssertTrue(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@ AND label CONTAINS %@","morningScore-","50")).firstMatch.exists)
    } else {
     XCTAssertEqual(app.staticTexts["monthlyRating"].label,language == "vi" ? "Khởi đầu mới" : "A fresh start")
    }
    capture(app,name:"progress-\(language)-\(fixture ? "scores" : "empty")")
    app.swipeUp()
    XCTAssertFalse(app.buttons[language == "vi" ? "Xóa lịch sử" : "Clear history"].exists)
    app.terminate()
   }
  }
 }
 func testProgressDayModesAndChallengeDetailsInBothLanguages() {
  for language in ["en","vi"] {
   let app=XCUIApplication(),vi=language == "vi"
   app.launchArguments=["-AppleLanguages","(en)","-AppleLocale","en_US","--ui-testing","--ui-progress-fixture"]
   if vi {app.launchArguments.append("--ui-language-vi")}
   app.launch()
   XCTAssertTrue(app.buttons["morningProgress"].waitForExistence(timeout:5))
   let check=app.alerts[vi ? "Cần kiểm tra" : "Please check"]
   if check.waitForExistence(timeout:1) {check.buttons[vi ? "Đã hiểu" : "Got it"].tap()}
   app.buttons["morningProgress"].tap()
   let calendar=Calendar.current,now=Date()
   func dayButton(_ offset:Int)->XCUIElement {
    let date=calendar.date(byAdding:.day,value:offset,to:now)!
    return app.buttons["morningScore-\(calendar.component(.day,from:date))"]
   }
   let today=dayButton(0),mixed=dayButton(-2),legacy=dayButton(-6),empty=dayButton(-5)
   XCTAssertTrue(today.waitForExistence(timeout:5))
   XCTAssertTrue(today.label.contains(vi ? "Bứt phá" : "Energized"))
   XCTAssertTrue(today.isSelected)
   let details=app.otherElements["selectedDayChallenges"]
   XCTAssertTrue(details.staticTexts[vi ? "5 lần chống đẩy" : "5 push-ups"].exists)
   XCTAssertTrue(details.staticTexts[vi ? "Bứt phá" : "Energized"].exists)
   XCTAssertTrue(mixed.label.contains(vi ? "Nhiều mức" : "Mixed modes"))
   for _ in 0..<4 where !mixed.isHittable {app.swipeUp()}
   mixed.tap()
   XCTAssertTrue(mixed.isSelected)
   XCTAssertTrue(details.staticTexts[vi ? "Đọc và chọn" : "Read & Choose"].exists)
   XCTAssertTrue(details.staticTexts[vi ? "Tỉnh táo" : "Awake"].exists)
   XCTAssertTrue(details.staticTexts[vi ? "Nhẹ nhàng" : "Gentle"].exists)
   XCTAssertTrue(details.staticTexts[vi ? "Đã dừng" : "Stopped"].exists)
   XCTAssertTrue(details.staticTexts[vi ? "Chưa lưu chi tiết thử thách" : "Challenge details not recorded"].exists)
   capture(app,name:"progress-\(language)-mixed-day")
   XCTAssertTrue(legacy.label.contains(vi ? "Nhẹ nhàng" : "Gentle"))
   XCTAssertTrue(legacy.label.contains(vi ? "Chưa lưu chi tiết thử thách" : "Challenge details not recorded"))
   legacy.tap()
   XCTAssertTrue(details.staticTexts[vi ? "Chưa lưu chi tiết thử thách" : "Challenge details not recorded"].exists)
   XCTAssertFalse(details.staticTexts[vi ? "Bứt phá" : "Energized"].exists,"Legacy history must not borrow the current alarm mode")
   empty.tap()
   XCTAssertTrue(details.staticTexts[vi ? "Chưa có thử thách được ghi nhận" : "No challenges recorded"].exists)
   app.terminate()
  }
 }
 func testExpiredProgressHasNoHistoryDeletionInBothLanguages() {
  for language in ["en","vi"] {
   let app=launch(language:language,expired:true)
   app.buttons["morningProgress"].tap()
   XCTAssertTrue(app.buttons["explorePro"].waitForExistence(timeout:5))
   XCTAssertFalse(app.staticTexts["monthlyScore"].exists)
   XCTAssertFalse(app.buttons[language == "vi" ? "Xóa lịch sử" : "Clear history"].exists)
   capture(app,name:"progress-expired-\(language)")
   app.terminate()
  }
 }
 func testProgressReadErrorDoesNotInventScores() {
  let app=XCUIApplication()
  app.launchArguments=["-AppleLanguages","(en)","-AppleLocale","en_US","--ui-testing","--ui-progress-read-error","-appLanguage","en"]
  app.launch()
  XCTAssertTrue(app.buttons["morningProgress"].waitForExistence(timeout:5))
  let check=app.alerts["Please check"]
  if check.waitForExistence(timeout:1) {check.buttons["Got it"].tap()}
  app.buttons["morningProgress"].tap()
  XCTAssertTrue(app.staticTexts["Your progress could not be read. Your alarms are unchanged."].waitForExistence(timeout:5))
  XCTAssertFalse(app.staticTexts["monthlyScore"].exists)
  XCTAssertEqual(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","morningScore-")).count,0)
  capture(app,name:"progress-read-error")
  app.buttons["closeProgress"].tap()
  XCTAssertTrue(app.buttons["morningProgress"].exists)
 }
 func testProgressSupportsLargeText() {
  for language in ["en","vi"] {
   let app=XCUIApplication(),vi=language == "vi"
   app.launchArguments=["-AppleLanguages","(en)","-AppleLocale","en_US","--ui-testing","--ui-progress-fixture","-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityM"]
   if vi {app.launchArguments.append("--ui-language-vi")}
   app.launch()
   XCTAssertTrue(app.buttons["morningProgress"].waitForExistence(timeout:5))
   let check=app.alerts[vi ? "Cần kiểm tra" : "Please check"]
   if check.waitForExistence(timeout:1) {check.buttons[vi ? "Đã hiểu" : "Got it"].tap()}
   app.buttons["morningProgress"].tap()
   XCTAssertTrue(app.staticTexts["monthlyScore"].waitForExistence(timeout:5))
   capture(app,name:"progress-\(language)-large-month")
   app.swipeUp()
   let scores=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","morningScore-"))
   XCTAssertGreaterThan(scores.count,0)
   let today=app.buttons["morningScore-\(Calendar.current.component(.day,from:Date()))"]
   for _ in 0..<6 where !today.isHittable {app.swipeUp()}
   XCTAssertTrue(today.isHittable)
   XCTAssertGreaterThanOrEqual(today.frame.height,44)
   XCTAssertTrue(today.label.contains(vi ? "Bứt phá" : "Energized"))
   today.tap()
   let challenge=app.otherElements["selectedDayChallenges"].staticTexts[vi ? "5 lần chống đẩy" : "5 push-ups"]
   for _ in 0..<4 where !challenge.isHittable {app.swipeUp()}
   XCTAssertTrue(challenge.exists)
   capture(app,name:"progress-\(language)-large-week")
   app.buttons["closeProgress"].tap()
   XCTAssertTrue(app.buttons["morningProgress"].waitForExistence(timeout:5))
   app.terminate()
  }
 }
 func testSoundPreviewKeepsEditorUsable() {
  let app=launch(language:"en")
  app.buttons["addAlarm"].tap()
  app.swipeUp()
  app.buttons["chooseSound"].tap()
  app.buttons["sound-sunrise"].tap()
  let preview=app.buttons["preview-sunrise"]
  XCTAssertTrue(preview.waitForExistence(timeout:5))
  preview.tap()
  let slider=app.sliders["previewVolume"]
  for _ in 0..<10 where !slider.isHittable {app.swipeUp()}
  slider.adjust(toNormalizedSliderPosition:0.25)
  for _ in 0..<10 where !preview.isHittable {app.swipeDown()}
  preview.tap()
  app.buttons["sound-softChime"].tap()
  app.buttons["preview-softChime"].tap()
  app.buttons["sound-system"].tap()
  XCTAssertFalse(app.sliders["previewVolume"].exists)
  app.buttons["chooseSound"].tap()
  app.buttons["Cancel"].tap()
  XCTAssertTrue(app.buttons["addAlarm"].waitForExistence(timeout:5))
  app.buttons["addAlarm"].tap()
  XCTAssertTrue(app.navigationBars["New alarm"].waitForExistence(timeout:5))
  app.buttons["Cancel"].tap()
 }
 func testExpandedSoundCatalogSelectsANewSoundInBothLanguages() {
  for language in ["en","vi"] {
   let app=launch(language:language)
   app.buttons["addAlarm"].tap()
   app.swipeUp()
   app.buttons["chooseSound"].tap()
   XCTAssertEqual(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","sound-")).count,15)
   XCTAssertEqual(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","preview-")).count,14)
   let sound=app.buttons["sound-saxDaybreak"]
   for _ in 0..<10 where !sound.isHittable {app.swipeUp()}
   XCTAssertTrue(sound.isHittable)
   sound.tap()
   XCTAssertTrue(sound.isSelected,"The visible row must select the sound")
   app.buttons["preview-saxDaybreak"].tap()
   app.buttons["preview-saxGlow"].tap()
   XCTAssertFalse(app.staticTexts["alarmSaveError"].exists,"Preview controls must not activate Save")
   capture(app,name:"expanded-sounds-"+language)
   app.buttons["chooseSound"].tap()
   XCTAssertTrue(app.buttons["chooseSound"].label.contains(language == "vi" ? "Sax ban mai" : "Sax daybreak"),app.buttons["chooseSound"].debugDescription)
   app.buttons[language == "vi" ? "Hủy" : "Cancel"].tap()
   app.terminate()
  }
 }
 func testSpokenExampleNeedsNoMicrophoneAndCannotCompleteReading() {
  for language in ["en","vi"] {
   let app=launch(language:language)
   app.buttons["practiceChallenges"].tap()
   app.buttons["practice-readAloud"].tap()
   let example=app.buttons["hearSentence"],start=app.buttons["startReadAloud"]
   XCTAssertTrue(example.waitForExistence(timeout:5))
   example.tap()
   XCTAssertEqual(app.alerts.count,0,"The example must not request microphone access")
   XCTAssertFalse(app.staticTexts[language == "vi" ? "Bạn đọc tốt lắm. Chúc bạn buổi sáng tốt lành!" : "Great reading. Have a good morning!"].exists)
   XCTAssertTrue(app.buttons["backToHome"].isHittable)
   XCUIDevice.shared.press(.home)
   app.activate()
   let ready=XCTNSPredicateExpectation(predicate:NSPredicate(format:"enabled == true"),object:start)
   wait(for:[ready],timeout:5)
   XCTAssertTrue(example.exists)
   XCTAssertFalse(app.staticTexts[language == "vi" ? "Bạn đọc tốt lắm. Chúc bạn buổi sáng tốt lành!" : "Great reading. Have a good morning!"].exists)
   app.buttons["backToHome"].tap()
   XCTAssertTrue(app.buttons["practiceChallenges"].waitForExistence(timeout:5))
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
  XCTAssertTrue(app.staticTexts["Read the English sentence aloud. See your score and matching words as you read."].waitForExistence(timeout:3))
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
   XCTAssertTrue(app.buttons["backToHome"].exists)
   XCTAssertEqual(app.alerts.count,0,"Reading practice needs no camera, speech or alarm permission")
   for index in 0..<3 {
    let option=app.buttons["readChoice-\(index)"]
    if option.exists {option.tap()}
    if app.buttons["retryChallenge"].waitForExistence(timeout:1) {break}
   }
   XCTAssertTrue(app.staticTexts[vi ? "Chính xác. Đã hoàn thành thử thách!" : "Correct. Challenge completed!"].waitForExistence(timeout:5))
   capture(app,name:"read-choose-complete-"+language)
   app.buttons["backToHome"].tap()
   XCTAssertTrue(app.buttons["practiceChallenges"].waitForExistence(timeout:5))
   app.terminate()
  }
 }
 func testModeDefaultsMatchTargetAndKeepAnExplicitChallenge() {
  let app=launch(language:"en")
  app.buttons["addAlarm"].tap()
  app.buttons["mode-focused"].tap()
  app.swipeUp()
  let target=app.staticTexts["pushUpTarget"]
  XCTAssertTrue(target.waitForExistence(timeout:3))
  XCTAssertTrue(target.label.contains("10"))
  app.buttons["challenge-readAndChoose"].tap()
  app.swipeDown()
  app.buttons["mode-balanced"].tap()
  app.swipeUp()
  XCTAssertTrue(app.buttons["challenge-readAndChoose"].isSelected)
  XCTAssertFalse(app.staticTexts["pushUpTarget"].exists)
  app.buttons["Cancel"].tap()
 }
 func testPushUpTargetRespectsModeFloorsAndMaximum() {
  let app=launch(language:"en")
  app.buttons["addAlarm"].tap()
  app.buttons["mode-balanced"].tap()
  let target=app.staticTexts["pushUpTarget"],increase=app.buttons["increasePushUpTarget"],decrease=app.buttons["decreasePushUpTarget"]
  for _ in 0..<6 where !increase.isHittable {app.swipeUp()}
  XCTAssertTrue(target.label.contains("5"))
  XCTAssertTrue(decrease.exists)
  XCTAssertFalse(decrease.isEnabled,"Awake cannot go below 5")
  increase.tap()
  XCTAssertTrue(target.label.contains("6"))
  decrease.tap()
  XCTAssertTrue(target.label.contains("5"))
  XCTAssertFalse(decrease.isEnabled)
  increase.tap()
  for _ in 0..<6 where !app.buttons["mode-focused"].isHittable || app.buttons["mode-focused"].frame.minY<app.buttons["editorChallengeSection"].frame.maxY {app.swipeDown()}
  app.buttons["mode-focused"].tap()
  for _ in 0..<6 where !increase.isHittable {app.swipeUp()}
  XCTAssertTrue(target.label.contains("10"))
  XCTAssertFalse(decrease.isEnabled,"Energized cannot go below 10")
  increase.tap()
  decrease.tap()
  XCTAssertTrue(target.label.contains("10"))
  XCTAssertFalse(decrease.isEnabled)
  increase.tap()
  XCTAssertTrue(target.label.contains("11"))
  for _ in 0..<6 where !app.buttons["mode-balanced"].isHittable || app.buttons["mode-balanced"].frame.minY<app.buttons["editorChallengeSection"].frame.maxY {app.swipeDown()}
  app.buttons["mode-balanced"].tap()
  for _ in 0..<6 where !increase.isHittable {app.swipeUp()}
  XCTAssertTrue(target.label.contains("11"),"Switching to an easier mode must preserve the chosen target")
  for _ in 0..<39 {increase.tap()}
  XCTAssertTrue(target.label.contains("50"))
  XCTAssertFalse(increase.isEnabled,"The target must stop at the supported maximum")
  decrease.tap()
  XCTAssertTrue(target.label.contains("49"))
  XCTAssertTrue(increase.isEnabled)
  app.buttons["Cancel"].tap()
 }
 func testLocalPracticeCanReturnHomeBeforeRequestingPermissions() {
  let app=launch(language:"en")
  for (kind,startButton) in [("none",""),("readAloud","startReadAloud"),("guidedRhythm","startGuidedRhythm")] {
   app.buttons["practiceChallenges"].tap()
   app.buttons["practice-"+kind].tap()
   XCTAssertTrue(app.buttons["backToHome"].waitForExistence(timeout:5))
   if !startButton.isEmpty {XCTAssertTrue(app.buttons[startButton].exists)}
   XCTAssertFalse(app.buttons["startChallenge"].exists)
   XCTAssertEqual(app.alerts.count,0)
   app.buttons["backToHome"].tap()
   XCTAssertTrue(app.buttons["practiceChallenges"].waitForExistence(timeout:5))
  }
 }
 func testExpiredPreviewKeepsBasicAlarmChoicesInBothLanguages() {
  for language in ["en","vi"] {
   let app=launch(language:language,expired:true)
   app.buttons["addAlarm"].tap()
   app.buttons["mode-balanced"].tap()
   XCTAssertEqual(app.staticTexts["modeExplanation"].label,language == "vi" ? "Gợi ý 5 lần chống đẩy" : "Try 5 push-ups")
   app.buttons["mode-focused"].tap()
   XCTAssertTrue(app.buttons["closePro"].waitForExistence(timeout:5))
   capture(app,name:"expired-pro-"+language)
   app.buttons["closePro"].tap()
   app.swipeUp()
   app.buttons["chooseSound"].tap()
   app.buttons["sound-sunrise"].tap()
   XCTAssertTrue(app.buttons["closePro"].waitForExistence(timeout:5))
   app.buttons["closePro"].tap()
   XCTAssertTrue(app.buttons["sound-system"].isSelected)
   app.buttons["preview-sunrise"].tap()
   XCTAssertTrue(app.buttons["closePro"].waitForExistence(timeout:5))
   app.buttons["closePro"].tap()
   let premium=app.buttons["sound-saxDaybreak"]
   for _ in 0..<10 where !premium.isHittable {app.swipeUp()}
   premium.tap()
   XCTAssertTrue(app.buttons["closePro"].waitForExistence(timeout:5))
   app.buttons["closePro"].tap()
   app.buttons["preview-saxDaybreak"].tap()
   XCTAssertTrue(app.buttons["closePro"].waitForExistence(timeout:5))
   app.buttons["closePro"].tap()
   let system=app.buttons["sound-system"]
   for _ in 0..<10 where !system.isHittable {app.swipeDown()}
   XCTAssertTrue(system.isSelected)
   app.buttons["chooseSound"].tap()
   app.buttons[language == "vi" ? "Hủy" : "Cancel"].tap()
   app.buttons["morningProgress"].tap()
   XCTAssertTrue(app.buttons["explorePro"].waitForExistence(timeout:5))
   XCTAssertFalse(app.staticTexts[language == "vi" ? "7 ngày qua" : "Past 7 days"].exists)
   XCTAssertFalse(app.buttons[language == "vi" ? "Xóa lịch sử" : "Clear history"].exists)
   capture(app,name:"expired-progress-"+language)
   app.terminate()
  }
 }
 func testExpiredPreviewCapsPushUpsAndKeepsLocalChallengeChoice() {
  let app=launch(language:"en",expired:true)
  app.buttons["addAlarm"].tap()
  app.buttons["mode-balanced"].tap()
  app.swipeUp()
  let target=app.staticTexts["pushUpTarget"]
  XCTAssertTrue(target.waitForExistence(timeout:3))
  XCTAssertTrue(target.label.contains("5"))
  XCTAssertFalse(app.buttons["increasePushUpTarget"].isEnabled)
  app.buttons["challenge-readAndChoose"].tap()
  app.swipeDown()
  app.buttons["mode-gentle"].tap()
  app.swipeUp()
  XCTAssertTrue(app.buttons["challenge-readAndChoose"].isSelected)
  XCTAssertFalse(target.exists)
  app.buttons["Cancel"].tap()
  app.buttons["practiceChallenges"].tap()
  app.buttons["practice-readAndChoose"].tap()
  XCTAssertTrue(app.buttons["readChoice-0"].waitForExistence(timeout:5))
  XCTAssertFalse(app.buttons["startChallenge"].exists)
  app.buttons["backToHome"].tap()
  XCTAssertTrue(app.buttons["practiceChallenges"].waitForExistence(timeout:5))
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
