import XCTest

final class DeviceFixesUITests:XCTestCase {
 private func launch(_ arguments:[String]=[],vietnamese:Bool=false)->XCUIApplication {
  let app=XCUIApplication()
  app.launchArguments=["-AppleLanguages","(en)","-AppleLocale","en_US","--ui-testing"]+arguments
  if vietnamese {app.launchArguments.append("--ui-language-vi")}
  app.launch()
  XCTAssertTrue(app.buttons["addAlarm"].waitForExistence(timeout:5))
  let check=app.alerts[vietnamese ? "Cần kiểm tra" : "Please check"]
  if check.waitForExistence(timeout:2),check.buttons[vietnamese ? "Đã hiểu" : "Got it"].exists {
   let attachment=XCTAttachment(string:check.debugDescription)
   attachment.name="startup-alarm-check";attachment.lifetime = .keepAlways;add(attachment)
   check.buttons[vietnamese ? "Đã hiểu" : "Got it"].tap()
  }
  return app
 }
 private func reveal(_ element:XCUIElement,in app:XCUIApplication) {
  for _ in 0..<8 where !element.isHittable {app.swipeUp()}
  XCTAssertTrue(element.isHittable)
 }
 private func skipIfNativeAlarmAccessIsDenied(_ app:XCUIApplication) throws {
  let feedback=app.staticTexts["alarmSaveError"]
  guard feedback.exists,feedback.label == "Alarm access is off. Allow alarms for HiMorning in Settings, then try again." else {return}
  let settings=app.buttons["openAlarmSettings"]
  XCTAssertTrue(settings.isHittable,"Permission denial must offer a visible Settings recovery action")
  XCTAssertTrue(app.buttons["saveAlarm"].isEnabled,"The user must be able to retry after changing Settings")
  guard settings.isHittable,app.buttons["saveAlarm"].isEnabled else {return}
  throw XCTSkip("Real AlarmKit scheduling is blocked by denied system alarm access; same-ID rescheduling is unverified.")
 }
 func testEnabledAlarmChallengeEditClosesAndKeepsTheNewChoiceInBothLanguages() {
  for vietnamese in [false,true] {
   let app=launch(["--ui-enabled-alarm"],vietnamese:vietnamese)
   let edit=app.buttons["editAlarm-00000000-0000-0000-0000-000000000001"]
   reveal(edit,in:app);edit.tap()
   let navigation=app.navigationBars[vietnamese ? "Sửa báo thức" : "Edit alarm"]
   XCTAssertTrue(navigation.waitForExistence(timeout:5))
   let reading=app.buttons["challenge-readAloud"]
   reveal(reading,in:app);reading.tap();XCTAssertTrue(reading.isSelected)
   app.buttons["saveAlarm"].tap()
   let closed=XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == false"),object:navigation)
   guard XCTWaiter.wait(for:[closed],timeout:5) == .completed else {
    XCTFail("Saving only a challenge must close the editor without native alarm access: \(app.staticTexts["alarmSaveError"].label)")
    app.terminate();return
   }
   XCTAssertTrue(edit.waitForExistence(timeout:5))
   XCTAssertEqual(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","editAlarm-")).count,1)
   XCTAssertTrue(app.staticTexts[vietnamese ? "Đọc thành tiếng" : "Read Aloud"].exists)
   XCTAssertEqual(app.alerts.count,0)
   edit.tap();reveal(reading,in:app);XCTAssertTrue(reading.isSelected)
   app.buttons["saveAlarm"].tap()
   let unchanged=XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == false"),object:navigation)
   XCTAssertEqual(XCTWaiter.wait(for:[unchanged],timeout:5),.completed,"Saving unchanged settings must also close")
   app.terminate()
  }
 }
 func testSaveButtonRespondsAcrossItsVisibleWidth() {
  for (vietnamese,x) in [(false,0.1),(false,0.9),(true,0.5)] {
   let app=launch(["--ui-disabled-alarm"],vietnamese:vietnamese)
   let edit=app.buttons["editAlarm-00000000-0000-0000-0000-000000000001"]
   reveal(edit,in:app);edit.tap()
   let navigation=app.navigationBars[vietnamese ? "Sửa báo thức" : "Edit alarm"]
   XCTAssertTrue(navigation.waitForExistence(timeout:5))
   let reading=app.buttons["challenge-readAloud"]
   reveal(reading,in:app);reading.tap()
   let save=app.buttons["saveAlarm"]
   XCTAssertTrue(save.isHittable)
   save.coordinate(withNormalizedOffset:CGVector(dx:x,dy:0.5)).tap()
   let closed=XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == false"),object:navigation)
   guard XCTWaiter.wait(for:[closed],timeout:5) == .completed else {
    XCTFail("The visible Save button must respond at horizontal offset \(x)")
    app.terminate();return
   }
   edit.tap();reveal(reading,in:app);XCTAssertTrue(reading.isSelected)
   app.buttons[vietnamese ? "Hủy" : "Cancel"].tap();app.terminate()
  }
 }
 func testReadAloudKeepsStartVisibleWithoutScrolling() {
  for (vietnamese,largeText) in [(false,false),(true,false),(true,true)] {
   let arguments=largeText ? ["-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityM","--ui-reading-transcript","small extra steps with several additional words to review while reading"] : []
   let app=launch(arguments,vietnamese:vietnamese)
   reveal(app.buttons["practiceChallenges"],in:app)
   app.buttons["practiceChallenges"].tap();app.buttons["practice-readAloud"].tap()
   let start=app.buttons["startReadAloud"]
   XCTAssertTrue(start.waitForExistence(timeout:5))
   let screenshot=XCTAttachment(screenshot:app.screenshot())
   screenshot.name="read-aloud-start-\(vietnamese ? "vi" : "en")-\(largeText ? "large" : "default")"
   screenshot.lifetime = .keepAlways;add(screenshot)
   XCTAssertTrue(start.isHittable,"Start reading must be available before scrolling")
   XCTAssertTrue(app.windows.firstMatch.frame.contains(start.frame),"The entire reading button must be on screen")
   let awake=app.buttons["confirmAwake"]
   XCTAssertLessThanOrEqual(start.frame.maxY,awake.frame.minY,"The fixed footer must not cover Start reading")
   app.swipeUp()
   XCTAssertTrue(start.isHittable,"Reading controls must remain reachable while reviewing feedback")
   app.swipeDown()
   XCTAssertTrue(start.isHittable)
   XCTAssertTrue(app.buttons["stopAlarm"].isHittable)
   XCTAssertEqual(app.alerts.count,0)
   app.terminate()
  }
 }
 func testReadAloudShowsLiveWordFeedbackInBothLanguages() {
  for vietnamese in [false,true] {
   let app=launch(["--ui-reading-transcript","small stops"],vietnamese:vietnamese)
   app.buttons["practiceChallenges"].tap();app.buttons["practice-readAloud"].tap()
   let score=app.staticTexts["readingScore"]
   XCTAssertTrue(score.waitForExistence(timeout:5))
   XCTAssertEqual(score.label,vietnamese ? "Điểm khớp từ: 20/100" : "Word match: 20/100")
   XCTAssertTrue(app.staticTexts["readingIncorrectWords"].label.contains("steps"))
   let summary=app.staticTexts["readingPrompt"].value as? String ?? ""
   XCTAssertTrue(summary.contains(vietnamese ? "Đọc khớp: small" : "Correct: small"))
   XCTAssertTrue(summary.contains(vietnamese ? "Chưa đọc: create, steady, progress" : "Not read yet: create, steady, progress"))
   XCTAssertEqual(app.alerts.count,0,"Feedback rendering must not request microphone access")
   app.terminate()
  }
 }
 func testReadAloudFinalFeedbackKeepsMissedAndExtraWordsVisible() {
  let app=launch(["--ui-reading-transcript","small extra steps","--ui-reading-finished"])
  app.buttons["practiceChallenges"].tap();app.buttons["practice-readAloud"].tap()
  XCTAssertTrue(app.staticTexts["readingScore"].waitForExistence(timeout:5))
  XCTAssertEqual(app.staticTexts["readingScore"].label,"Word match: 20/100")
  XCTAssertTrue(app.staticTexts["readingIncorrectWords"].label.contains("create, steady, progress"))
  reveal(app.staticTexts["readingExtraWords"],in:app)
  XCTAssertEqual(app.staticTexts["readingExtraWords"].label,"Extra words: extra")
 }
 func testExistingAlarmSoundCanBeEditedWithoutEnablingItInBothLanguages() {
  for vietnamese in [false,true] {
   let app=launch(["--ui-disabled-alarm"],vietnamese:vietnamese)
   let edit=app.buttons["editAlarm-00000000-0000-0000-0000-000000000001"]
   reveal(edit,in:app);edit.tap()
   XCTAssertTrue(app.navigationBars[vietnamese ? "Sửa báo thức" : "Edit alarm"].waitForExistence(timeout:5))
   XCTAssertTrue(app.buttons["mode-balanced"].isSelected)
   reveal(app.buttons["challenge-guidedRhythm"],in:app)
   XCTAssertTrue(app.buttons["challenge-guidedRhythm"].isSelected)
   XCTAssertTrue(app.buttons[vietnamese ? "Ngồi" : "Seated"].isSelected)
   reveal(app.buttons["chooseSound"],in:app);app.buttons["chooseSound"].tap()
   XCTAssertTrue(app.buttons["sound-sunrise"].isSelected)
   app.buttons["sound-softChime"].tap()
   app.navigationBars.buttons.element(boundBy:0).tap()
   app.buttons["saveAlarm"].tap()
   XCTAssertTrue(edit.waitForExistence(timeout:5))
   XCTAssertEqual(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","editAlarm-")).count,1)
   XCTAssertTrue(app.staticTexts[vietnamese ? "Đã tắt" : "Off"].exists)
   XCTAssertEqual(app.staticTexts.matching(NSPredicate(format:"identifier BEGINSWITH %@","nextAlarm-")).count,0)
   XCTAssertTrue(app.staticTexts.containing(NSPredicate(format:"label CONTAINS %@",vietnamese ? "Chuông dịu" : "Soft chime")).firstMatch.exists)
   XCTAssertEqual(app.alerts.count,0,"Editing a disabled alarm must not request alarm access")
   app.terminate()
  }
 }
 func testSaveWaitsAndRetainsEditorOnFailure() {
  let app=launch(["--ui-alarm-save-failure"])
  app.buttons["addAlarm"].tap()
  let save=app.buttons["saveAlarm"]
  XCTAssertTrue(save.waitForExistence(timeout:5));save.tap()
  let busyLabel=save.label,saveEnabled=save.isEnabled,cancelEnabled=app.buttons["Cancel"].isEnabled
  let accessibility=XCTAttachment(string:save.debugDescription)
  accessibility.name="alarm-save-in-progress-accessibility";accessibility.lifetime = .keepAlways;add(accessibility)
  let screenshot=XCTAttachment(screenshot:app.screenshot())
  screenshot.name="alarm-save-in-progress";screenshot.lifetime = .keepAlways;add(screenshot)
  XCTAssertEqual(busyLabel,"Saving…")
  XCTAssertFalse(saveEnabled)
  XCTAssertFalse(cancelEnabled)
  XCTAssertTrue(app.staticTexts["alarmSaveError"].waitForExistence(timeout:5))
  XCTAssertTrue(save.isEnabled)
  XCTAssertTrue(app.navigationBars["New alarm"].exists)
  app.buttons["Cancel"].tap()
 }
 func testChallengeSummaryAndSettingsAreInsideSelectedCard() {
  let app=launch()
  app.buttons["addAlarm"].tap()
  reveal(app.buttons["challenge-pushUps"],in:app);app.buttons["challenge-pushUps"].tap()
  let card=app.otherElements["challenge-card-pushUps"]
  let summary=app.staticTexts["challenge-summary-pushUps"],stepper=app.steppers["pushUpTarget"]
  XCTAssertTrue(card.exists);XCTAssertTrue(summary.exists);XCTAssertTrue(stepper.exists)
  XCTAssertTrue(card.frame.contains(summary.frame))
  XCTAssertTrue(card.frame.contains(stepper.frame))
  app.buttons["Cancel"].tap()
 }
 func testEnabledAlarmSoundEditReschedulesTheSameNativeAlarm() throws {
  let app=launch()
  let edits=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","editAlarm-"))
  let before=Set(edits.allElementsBoundByIndex.map(\.identifier))
  addTeardownBlock {
   if app.buttons["Cancel"].isHittable {app.buttons["Cancel"].tap()}
   let created=Set(edits.allElementsBoundByIndex.map(\.identifier)).subtracting(before)
   guard created.count == 1,let identifier=created.first else {
    XCTAssertTrue(created.isEmpty,"Only this test’s one disposable alarm may be removed")
    return
   }
   let edit=app.buttons[identifier]
   self.reveal(edit,in:app)
   let deletes=app.buttons.matching(identifier:"Delete").allElementsBoundByIndex.filter {
    $0.isHittable && abs($0.frame.midY-edit.frame.midY)<8 && $0.frame.minX>edit.frame.maxX
   }
   guard deletes.count == 1 else {XCTFail("Could not safely identify the disposable alarm’s Delete button");return}
   deletes[0].tap()
   let removed=XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == false"),object:edit)
   self.wait(for:[removed],timeout:10)
  }
  app.buttons["addAlarm"].tap()
  reveal(app.buttons["chooseSound"],in:app);app.buttons["chooseSound"].tap()
  app.buttons["sound-sunrise"].tap()
  app.navigationBars.buttons.element(boundBy:0).tap()
  app.buttons["saveAlarm"].tap()
  let permission=XCUIApplication(bundleIdentifier:"com.apple.springboard").alerts.firstMatch
  if permission.waitForExistence(timeout:2) {
   let allow=permission.buttons.matching(NSPredicate(format:"label == %@ OR label == %@","Allow","Allow Alarms")).firstMatch
   XCTAssertTrue(allow.exists,"Native alarm access must be allowed to verify real scheduling")
   if allow.exists {allow.tap()}
  }
  let saved=XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == false"),object:app.navigationBars["New alarm"])
  guard XCTWaiter.wait(for:[saved],timeout:15) == .completed else {
   try skipIfNativeAlarmAccessIsDenied(app)
   XCTFail("The real native scheduler did not confirm the new alarm: \(app.staticTexts["alarmSaveError"].label)")
   return
  }
  let created=Set(edits.allElementsBoundByIndex.map(\.identifier)).subtracting(before)
  guard created.count == 1,let identifier=created.first else {XCTFail("Expected exactly one new alarm");return}
  let alarmID=String(identifier.dropFirst("editAlarm-".count)),edit=app.buttons[identifier]
  let state=app.descendants(matching:.any).matching(identifier:"alarmState-"+alarmID).firstMatch
  reveal(edit,in:app)
  XCTAssertTrue(state.label.contains("Alarm is set"))
  XCTAssertTrue(app.staticTexts["nextAlarm-"+alarmID].exists)
  edit.tap()
  reveal(app.buttons["chooseSound"],in:app);app.buttons["chooseSound"].tap()
  XCTAssertTrue(app.buttons["sound-sunrise"].isSelected)
  app.buttons["sound-softChime"].tap()
  app.navigationBars.buttons.element(boundBy:0).tap()
  app.buttons["saveAlarm"].tap()
  let edited=XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == false"),object:app.navigationBars["Edit alarm"])
  guard XCTWaiter.wait(for:[edited],timeout:15) == .completed else {
   try skipIfNativeAlarmAccessIsDenied(app)
   XCTFail("The real native scheduler did not confirm editing the same alarm ID: \(app.staticTexts["alarmSaveError"].label)")
   return
  }
  XCTAssertEqual(Set(edits.allElementsBoundByIndex.map(\.identifier)),before.union([identifier]))
  reveal(edit,in:app)
  XCTAssertTrue(state.label.contains("Alarm is set"))
  XCTAssertTrue(app.staticTexts["nextAlarm-"+alarmID].exists)
  edit.tap()
  reveal(app.buttons["chooseSound"],in:app);app.buttons["chooseSound"].tap()
  XCTAssertTrue(app.buttons["sound-softChime"].isSelected,"The same alarm must persist its changed sound")
  app.navigationBars.buttons.element(boundBy:0).tap()
  app.buttons["Cancel"].tap()
 }
}
