import XCTest
import UIKit
final class PilotUITests:XCTestCase {
 private func reveal(_ element:XCUIElement,in app:XCUIApplication) {
  for _ in 0..<12 {
   if !element.exists {app.swipeUp();continue}
   let frame=element.frame
   let navigation=app.navigationBars.firstMatch
   let top=navigation.exists ? navigation.frame.maxY : app.frame.minY
   let bottom=app.buttons["saveAlarm"].exists ? app.buttons["saveAlarm"].frame.minY : app.frame.maxY
   if element.isHittable,frame.minY>=top,frame.maxY<=bottom {return}
   let mid=CGPoint(x:app.frame.midX,y:(top+bottom)/2)
   let distance=min(180,(bottom-top)*0.35)
   let start=app.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:mid.x,dy:mid.y))
   let end=start.withOffset(CGVector(dx:0,dy:frame.minY<top ? distance : -distance))
   start.press(forDuration:0.05,thenDragTo:end)
  }
  XCTAssertTrue(element.isHittable)
 }
 private func toggleSound(in app:XCUIApplication) {
  if app.buttons["doneSound"].exists {app.buttons["doneSound"].tap()}
  else {let button=app.buttons["chooseSound"];reveal(button,in:app);button.tap()}
 }

 private func capture(_ app:XCUIApplication,name:String) {
  let attachment=XCTAttachment(screenshot:app.screenshot())
  attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)
 }
 private func captureEditorChoices(_ app:XCUIApplication,language:String) {
  let vi=language == "vi"
  XCTAssertTrue(app.staticTexts[vi ? "Mức thử thách" : "Challenge level"].exists)
  for (mode,title) in [("gentle",vi ? "Nhẹ nhàng":"Gentle"),("balanced",vi ? "Vừa sức":"Balanced"),("focused",vi ? "Năng động":"Challenging")] {
   XCTAssertTrue(app.buttons["mode-"+mode].label.contains(title))
  }
  for mode in ["balanced","focused"] {
   app.buttons["mode-"+mode].tap()
   capture(app,name:mode+"-"+language)
  }
  let chooseSound=app.buttons["chooseSound"]
  reveal(chooseSound,in:app)
  chooseSound.tap()
  XCTAssertTrue(app.buttons["sound-system"].waitForExistence(timeout:5))
  app.buttons["sound-sunrise"].tap()
  XCTAssertTrue(app.buttons["chooseSound"].waitForExistence(timeout:3))
  toggleSound(in:app)
  let slider=app.sliders["previewVolume"]
  for _ in 0..<10 where !slider.isHittable {app.swipeUp()}
  XCTAssertTrue(slider.isHittable)
  capture(app,name:"sounds-"+language)
  toggleSound(in:app)
 }
 private func launch(language:String,expired:Bool=false,awakeReady:Bool=false,editorFixture:Bool=false)->XCUIApplication {
  let app=XCUIApplication()
  app.terminate()
  app.launchArguments=["-AppleLanguages","(en)","-AppleLocale","en_US","--ui-testing","--ui-camera-denied"]
  if language == "vi" {app.launchArguments.append("--ui-language-vi")}
  if expired {app.launchArguments.append("--preview-expired")}
  if editorFixture {app.launchArguments.append("--ui-disabled-alarm")}
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
  XCTAssertTrue(app.staticTexts["Wait for the countdown to finish"].exists)
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
  XCTAssertTrue(app.staticTexts["Chờ đếm ngược kết thúc"].exists)
  capture(app,name:"alarm-editor-vi")
  captureEditorChoices(app,language:"vi")
  app.buttons["Hủy"].tap()
  XCTAssertTrue(app.buttons["addAlarm"].waitForExistence(timeout:5))
 }
 func testNewAlarmStartsAtCurrentTimeWithNoRepeatDays() {
  let app=launch(language:"en")
  let before=Date()
  app.buttons["addAlarm"].tap()
  XCTAssertTrue(app.navigationBars["New alarm"].waitForExistence(timeout:5))
  let timeButton=app.datePickers["alarmTimePicker"]
  XCTAssertTrue(timeButton.isHittable)
  let picker=app.datePickers["alarmTimePicker"]
  XCTAssertTrue(picker.exists)
  let pickerValue=picker.value as? String ?? ""
  let after=Date()
  let formatter=DateFormatter();formatter.locale=Locale(identifier:"en_US");formatter.dateStyle = .none;formatter.timeStyle = .short
  let currentTimes=[before,after].map {formatter.string(from:$0)}
  XCTAssertTrue(currentTimes.contains(pickerValue),"The draft should start at the current local time: \(pickerValue)")
  capture(app,name:"composer-clock-time-en")
  reveal(app.buttons["alarmRepeatDay-2"],in:app)
  XCTAssertTrue(app.staticTexts["Rings once"].exists)
  for day in 1...7 {XCTAssertFalse(app.buttons["alarmRepeatDay-\(day)"].isSelected)}
  app.buttons["Cancel"].tap()
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
  XCTAssertEqual(app.buttons["startChallenge"].label,vi ? "Bắt đầu thử thách":"Start challenge")
  XCTAssertTrue(app.descendants(matching:.any)["challengeRequirements"].exists)
  XCTAssertFalse(app.staticTexts.matching(identifier:"challengeMessage").firstMatch.exists,"Initial instructions are a checklist without a filler paragraph")
  capture(app,name:"challenge-ready-"+language)
  app.buttons["startChallenge"].tap()
  XCTAssertTrue(app.buttons[vi ? "Mở camera" : "Open camera"].waitForExistence(timeout:5))
  capture(app,name:"consent-"+language)
  app.buttons[vi ? "Để sau" : "Not now"].tap()
  XCTAssertTrue(app.buttons["backToHome"].exists)
  app.buttons["startChallenge"].tap()
  app.buttons[vi ? "Mở camera" : "Open camera"].tap()
  let unavailable=vi ? "Chưa có quyền camera. Bạn có thể nhấn “Tôi đã thức dậy” khi nút mở khóa." : "Camera access is off. You can tap I’m awake when it unlocks."
  XCTAssertTrue(app.staticTexts[unavailable].waitForExistence(timeout:5))
  XCTAssertFalse(app.staticTexts[vi ? "Hoan hô!" : "Hooray!"].exists)
  capture(app,name:"camera-denied-"+language)
  app.buttons["confirmAwake"].tap()
  let confirmed=vi ? "Bạn đã xác nhận thức dậy." : "You confirmed you are awake."
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
   XCTAssertTrue(today.label.contains(vi ? "Năng động" : "Challenging"))
   XCTAssertTrue(today.isSelected)
   let details=app.otherElements["selectedDayChallenges"]
   XCTAssertTrue(details.staticTexts[vi ? "5 lần chống đẩy" : "5 push-ups"].exists)
   XCTAssertTrue(details.staticTexts[vi ? "Năng động" : "Challenging"].exists)
   XCTAssertTrue(mixed.label.contains(vi ? "Nhiều mức" : "Mixed modes"))
   for _ in 0..<4 where !mixed.isHittable {app.swipeUp()}
   mixed.tap()
   XCTAssertTrue(mixed.isSelected)
   XCTAssertTrue(details.staticTexts[vi ? "Đọc và Chọn" : "Read & Choose"].exists)
   XCTAssertTrue(details.staticTexts[vi ? "Vừa sức" : "Balanced"].exists)
   XCTAssertTrue(details.staticTexts[vi ? "Nhẹ nhàng" : "Gentle"].exists)
   XCTAssertTrue(details.staticTexts[vi ? "Đã dừng" : "Stopped"].exists)
   XCTAssertTrue(details.staticTexts[vi ? "Chưa lưu chi tiết thử thách" : "Challenge details not recorded"].exists)
   capture(app,name:"progress-\(language)-mixed-day")
   XCTAssertTrue(legacy.label.contains(vi ? "Nhẹ nhàng" : "Gentle"))
   XCTAssertTrue(legacy.label.contains(vi ? "Chưa lưu chi tiết thử thách" : "Challenge details not recorded"))
   legacy.tap()
   XCTAssertTrue(details.staticTexts[vi ? "Chưa lưu chi tiết thử thách" : "Challenge details not recorded"].exists)
   XCTAssertFalse(details.staticTexts[vi ? "Năng động" : "Challenging"].exists,"Legacy history must not borrow the current alarm mode")
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
   XCTAssertTrue(today.label.contains(vi ? "Năng động" : "Challenging"))
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
  toggleSound(in:app)
  app.buttons["sound-sunrise"].tap()
  XCTAssertTrue(app.buttons["chooseSound"].waitForExistence(timeout:3))
  toggleSound(in:app)
  let preview=app.buttons["preview-sunrise"]
  XCTAssertTrue(preview.waitForExistence(timeout:5))
  preview.tap()
  let slider=app.sliders["previewVolume"]
  for _ in 0..<10 where !slider.isHittable {app.swipeUp()}
  slider.adjust(toNormalizedSliderPosition:0.25)
  for _ in 0..<10 where !preview.isHittable {app.swipeDown()}
  preview.tap()
  app.buttons["sound-softChime"].tap()
  XCTAssertTrue(app.buttons["chooseSound"].waitForExistence(timeout:3))
  toggleSound(in:app)
  app.buttons["preview-softChime"].tap()
  XCTAssertTrue(app.buttons["doneSound"].exists,"Listening must keep the picker open")
  app.buttons["sound-system"].tap()
  XCTAssertTrue(app.buttons["chooseSound"].waitForExistence(timeout:3))
  XCTAssertFalse(app.sliders["previewVolume"].exists)
  XCTAssertFalse(app.buttons["doneSound"].exists)
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
   toggleSound(in:app)
   XCTAssertEqual(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","sound-")).count,15)
   XCTAssertEqual(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","preview-")).count,14)
   let sound=app.buttons["sound-saxDaybreak"]
   for _ in 0..<10 where !sound.isHittable {app.swipeUp()}
   XCTAssertTrue(sound.isHittable)
   sound.tap()
   XCTAssertTrue(app.buttons["chooseSound"].waitForExistence(timeout:3))
   XCTAssertTrue(app.buttons["chooseSound"].label.contains(language == "vi" ? "Bình minh saxophone" : "Sax daybreak"))
   toggleSound(in:app)
   XCTAssertTrue(sound.isSelected,"The visible row must select the sound")
   reveal(app.buttons["preview-saxDaybreak"],in:app)
   app.buttons["preview-saxDaybreak"].tap()
   app.buttons["preview-saxGlow"].tap()
   XCTAssertFalse(app.staticTexts["alarmSaveError"].exists,"Preview controls must not activate Save")
   capture(app,name:"expanded-sounds-"+language)
   toggleSound(in:app)
   XCTAssertTrue(app.buttons["chooseSound"].label.contains(language == "vi" ? "Bình minh saxophone" : "Sax daybreak"),app.buttons["chooseSound"].debugDescription)
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
   XCTAssertFalse(app.staticTexts[language == "vi" ? "Đọc tốt." : "Great reading."].exists)
   XCTAssertTrue(app.buttons["backToHome"].isHittable)
   XCUIDevice.shared.press(.home)
   app.activate()
   let ready=XCTNSPredicateExpectation(predicate:NSPredicate(format:"enabled == true"),object:start)
   wait(for:[ready],timeout:5)
   XCTAssertTrue(example.exists)
   XCTAssertFalse(app.staticTexts[language == "vi" ? "Đọc tốt." : "Great reading."].exists)
   app.buttons["backToHome"].tap()
   XCTAssertTrue(app.buttons["practiceChallenges"].waitForExistence(timeout:5))
   app.terminate()
  }
 }
 func testAlarmEditorOffersDiverseChallengeChoices() {
  let app=launch(language:"en",editorFixture:true)
  app.descendants(matching:.any)["alarmCard-00000000-0000-0000-0000-000000000001"].coordinate(withNormalizedOffset:CGVector(dx:0.04,dy:0.5)).tap()
  XCTAssertTrue(app.navigationBars["Edit alarm"].waitForExistence(timeout:5))
  XCTAssertTrue(app.buttons["challenge-guidedRhythm"].exists,"The historical saved choice remains available")
  func selectMode(_ mode:String) {
   let button=app.buttons["mode-"+mode]
   for _ in 0..<8 {
    let frame=button.frame
    if frame.minY<app.navigationBars.firstMatch.frame.maxY {app.scrollViews.firstMatch.swipeDown()}
    else if !button.isHittable || frame.midY>app.buttons["saveAlarm"].frame.minY {app.scrollViews.firstMatch.swipeUp()}
    else {break}
   }
   button.tap()
  }
  for (mode,choices) in [("gentle",["none","waveHand","neckRotation"]),("balanced",["readAndChoose","readAloud","riddle"]),("focused",["pushUps","jumpingJacks","stretching"])] {
   selectMode(mode)
   for id in choices {XCTAssertTrue(app.buttons["challenge-"+id].exists,"Missing challenge: \(id)")}
   XCTAssertFalse(app.buttons["challenge-guidedRhythm"].exists,"Switching modes replaces the legacy choice")
  }
  capture(app,name:"energized-challenge-catalog")
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
   XCTAssertTrue(app.staticTexts[vi ? "Đúng rồi. Thử thách hoàn thành!" : "Correct. Challenge completed!"].waitForExistence(timeout:5))
   capture(app,name:"read-choose-complete-"+language)
   app.buttons["backToHome"].tap()
   XCTAssertTrue(app.buttons["practiceChallenges"].waitForExistence(timeout:5))
   app.terminate()
  }
 }
 func testModeDefaultsSelectACompatibleChallenge() {
  let app=launch(language:"en")
  app.buttons["addAlarm"].tap()
  app.buttons["mode-balanced"].tap()
  let readChoice=app.buttons["challenge-readAndChoose"]
  XCTAssertTrue(readChoice.waitForExistence(timeout:3))
  XCTAssertTrue(readChoice.isSelected)
  for _ in 0..<6 where !app.buttons["mode-focused"].isHittable || app.buttons["mode-focused"].frame.minY<app.navigationBars.firstMatch.frame.maxY {app.swipeDown()}
  app.buttons["mode-focused"].tap()
  app.swipeUp()
  let target=app.staticTexts["pushUpTarget"]
  XCTAssertTrue(target.waitForExistence(timeout:3))
  XCTAssertTrue(target.label.contains("10"))
  XCTAssertFalse(app.buttons["challenge-readAndChoose"].exists)
  app.buttons["Cancel"].tap()
 }
 func testPushUpTargetRespectsModeFloorsAndMaximum() {
  let app=launch(language:"en")
  app.buttons["addAlarm"].tap()
  app.buttons["mode-focused"].tap()
  let target=app.staticTexts["pushUpTarget"],increase=app.buttons["increasePushUpTarget"],decrease=app.buttons["decreasePushUpTarget"]
  for _ in 0..<6 where !increase.isHittable {app.swipeUp()}
  XCTAssertTrue(target.label.contains("10"))
  XCTAssertTrue(decrease.exists)
  XCTAssertFalse(decrease.isEnabled,"Challenging cannot go below 10")
  increase.tap()
  XCTAssertTrue(target.label.contains("11"))
  decrease.tap()
  XCTAssertTrue(target.label.contains("10"))
  XCTAssertFalse(decrease.isEnabled)
  increase.tap()
  XCTAssertTrue(target.label.contains("11"))
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
  for (kind,startButton) in [("none",""),("readAloud","startReadAloud"),("guidedRhythm","startGuidedRhythm"),("waveHand","startLocalMovement"),("riddle","")] {
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
   XCTAssertTrue(app.staticTexts[language == "vi" ? "Chọn ý nghĩa gần nhất" : "Choose the closest meaning"].exists)
   app.buttons["mode-focused"].tap()
   XCTAssertTrue(app.buttons["closePro"].waitForExistence(timeout:5))
   capture(app,name:"expired-pro-"+language)
   app.buttons["closePro"].tap()
   app.swipeUp()
   toggleSound(in:app)
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
   toggleSound(in:app)
   app.buttons[language == "vi" ? "Hủy" : "Cancel"].tap()
   app.buttons["morningProgress"].tap()
   XCTAssertTrue(app.buttons["explorePro"].waitForExistence(timeout:5))
   XCTAssertFalse(app.staticTexts[language == "vi" ? "7 ngày qua" : "Past 7 days"].exists)
   XCTAssertFalse(app.buttons[language == "vi" ? "Xóa lịch sử" : "Clear history"].exists)
   capture(app,name:"expired-progress-"+language)
   app.terminate()
  }
 }
 func testExpiredPreviewKeepsBasicChallengeCatalog() {
  let app=launch(language:"en",expired:true)
  app.buttons["addAlarm"].tap()
  app.buttons["mode-gentle"].tap()
  app.swipeUp()
  XCTAssertTrue(app.buttons["challenge-none"].isSelected)
  XCTAssertTrue(app.buttons["challenge-waveHand"].exists)
  app.swipeDown()
  app.buttons["mode-balanced"].tap()
  app.swipeUp()
  XCTAssertTrue(app.buttons["challenge-readAndChoose"].isSelected)
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
