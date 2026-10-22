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
 private func revealAlarmDelete(_ id:String,in app:XCUIApplication) {
  let card=app.descendants(matching:.any)["alarmCard-"+id]
  reveal(card,in:app);card.swipeLeft()
  XCTAssertTrue(app.buttons["deleteAlarm-"+id].isHittable)
 }
 private func tryAlarm(_ id:String,in app:XCUIApplication) {
  let button=app.buttons["tryAlarm-"+id]
  reveal(button,in:app);button.tap()
 }
 private func confirmDelete(in app:XCUIApplication) {
  let button=app.alerts.buttons["confirmDeleteAlarm"].firstMatch
  XCTAssertTrue(button.waitForExistence(timeout:3));button.tap()
 }
 private func toggleSound(in app:XCUIApplication) {
  if app.buttons["doneSound"].exists {app.buttons["doneSound"].tap()}
  else {let button=app.buttons["chooseSound"];reveal(button,in:app);button.tap()}
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
 func testSwipeDeleteRequiresConfirmationAndCancelPreservesTheAlarm() {
  let id="00000000-0000-0000-0000-000000000001"
  let other="00000000-0000-0000-0000-000000000002"
  for vietnamese in [false,true] {
   let app=launch(["--ui-home-alarms"],vietnamese:vietnamese)
   XCTAssertFalse(app.buttons["deleteAlarm-"+id].exists)
   XCTAssertFalse(app.buttons["alarmOptions-"+id].exists)
   revealAlarmDelete(id,in:app)
   XCTAssertFalse(app.navigationBars["Edit alarm"].exists)
   let shown=XCTAttachment(screenshot:app.screenshot());shown.name="swipe-delete-"+(vietnamese ? "vi" : "en");shown.lifetime = .keepAlways;add(shown)
   app.buttons["deleteAlarm-"+id].tap()
   XCTAssertTrue(app.staticTexts["alarmTime-"+id].exists)
   let confirmation=app.alerts[vietnamese ? "Xóa báo thức?" : "Delete alarm?"]
   XCTAssertTrue(confirmation.waitForExistence(timeout:3))
   confirmation.buttons[vietnamese ? "Hủy" : "Cancel"].firstMatch.tap()
   XCTAssertTrue(app.staticTexts["alarmTime-"+id].exists)
   XCTAssertFalse(app.buttons["deleteAlarm-"+id].exists)
   // A vertical drag on the card must still scroll the page.
   app.descendants(matching:.any)["alarmCard-"+id].swipeUp()
   XCTAssertFalse(app.buttons["deleteAlarm-"+id].exists)
   revealAlarmDelete(id,in:app);app.buttons["deleteAlarm-"+id].tap();confirmDelete(in:app)
   let removed=XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == false"),object:app.staticTexts["alarmTime-"+id])
   XCTAssertEqual(XCTWaiter.wait(for:[removed],timeout:5),.completed)
   XCTAssertTrue(app.staticTexts["alarmTime-"+other].exists)
   app.terminate()
  }
 }
 func testDraftChallengePracticeReturnsToTheUnsavedForm() {
  let app=launch(["--ui-home-alarms","--ui-reading-correct-first"])
  let alarms=app.staticTexts.matching(NSPredicate(format:"identifier BEGINSWITH %@","alarmTime-"))
  let before=Set(alarms.allElementsBoundByIndex.map(\.identifier))
  app.buttons["addAlarm"].tap()
  XCTAssertFalse(app.buttons["tryDraftChallenge"].exists)
  reveal(app.buttons["mode-balanced"],in:app);app.buttons["mode-balanced"].tap()
  reveal(app.buttons["challenge-readAndChoose"],in:app);app.buttons["challenge-readAndChoose"].tap()
  reveal(app.textFields["alarmLabel"],in:app);app.textFields["alarmLabel"].tap();app.textFields["alarmLabel"].typeText("My morning")
  reveal(app.buttons["alarmRepeatDay-3"],in:app);app.buttons["alarmRepeatDay-3"].tap()
  let selectedTime=app.datePickers["alarmTimePicker"].value as? String
  reveal(app.buttons["tryDraftChallenge"],in:app);app.buttons["tryDraftChallenge"].tap()
  XCTAssertTrue(app.buttons["backToHome"].waitForExistence(timeout:5))
  XCTAssertEqual(app.buttons["backToHome"].label,"Back to alarm")
  XCTAssertFalse(app.buttons["confirmAwake"].exists)
  XCTAssertTrue(app.staticTexts["Practice only. Your alarms stay as they are."].exists)
  let demo=XCTAttachment(screenshot:app.screenshot());demo.name="draft-challenge-practice";demo.lifetime = .keepAlways;add(demo)
  app.buttons["readChoice-0"].tap()
  XCTAssertTrue(app.buttons["retryChallenge"].waitForExistence(timeout:5))
  app.buttons["backToHome"].tap()
  XCTAssertTrue(app.navigationBars["New alarm"].waitForExistence(timeout:5))
  XCTAssertTrue(app.buttons["challenge-readAndChoose"].isSelected)
  reveal(app.textFields["alarmLabel"],in:app);XCTAssertEqual(app.textFields["alarmLabel"].value as? String,"My morning")
  XCTAssertTrue(app.buttons["alarmRepeatDay-3"].isSelected)
  if let selectedTime {XCTAssertEqual(app.datePickers["alarmTimePicker"].value as? String,selectedTime)}
  app.buttons["Cancel"].tap()
  XCTAssertEqual(Set(alarms.allElementsBoundByIndex.map(\.identifier)),before)
  app.terminate()
 }
 func testAlarmLabelPersistsAndOpensDisabledCardInBothLanguages() {
  let id="00000000-0000-0000-0000-000000000001"
  for vietnamese in [false,true] {
   let app=launch(["--ui-disabled-alarm"],vietnamese:vietnamese)
   let card=app.descendants(matching:.any)["alarmCard-"+id]
   card.coordinate(withNormalizedOffset:CGVector(dx:0.04,dy:0.5)).tap()
   let navigation=app.navigationBars[vietnamese ? "Sửa báo thức" : "Edit alarm"]
   XCTAssertTrue(navigation.waitForExistence(timeout:5))
   let label=app.textFields["alarmLabel"]
   let preview=XCTAttachment(screenshot:app.screenshot())
   preview.name="clock-style-alarm-form-\(vietnamese ? "vi" : "en")";preview.lifetime = .keepAlways;add(preview)
   reveal(label,in:app);XCTAssertTrue(label.exists);label.tap();label.typeText("  School  ")
   XCTAssertEqual(label.value as? String,"  School  ")
   let keyboardPreview=XCTAttachment(screenshot:app.screenshot())
   keyboardPreview.name="composer-label-keyboard";keyboardPreview.lifetime = .keepAlways;add(keyboardPreview)
   if app.buttons["doneSound"].exists {app.buttons["doneSound"].tap()}
   app.buttons["saveAlarm"].tap()
   let saved=app.staticTexts["alarmLabel-"+id]
   XCTAssertTrue(saved.waitForExistence(timeout:5));XCTAssertEqual(saved.label,"School")
   XCTAssertFalse(navigation.exists)
   saved.tap()
   XCTAssertTrue(navigation.waitForExistence(timeout:5))
   XCTAssertEqual(label.value as? String,"School")
   app.buttons[vietnamese ? "Hủy" : "Cancel"].tap()
   app.terminate()
  }
 }
 func testRepeatDaysUseInlineCirclesAndPersistSelection() {
  for (vietnamese,largeText) in [(false,false),(true,false),(true,true)] {
   let arguments=["--ui-disabled-alarm"]+(largeText ? ["-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityM","--ui-reduce-motion"] : [])
   let app=launch(arguments,vietnamese:vietnamese)
   app.staticTexts["alarmTime-00000000-0000-0000-0000-000000000001"].tap()
   reveal(app.buttons["alarmRepeatDay-2"],in:app)
   for day in 1...7 {
    let choice=app.buttons["alarmRepeatDay-\(day)"]
    reveal(choice,in:app)
    XCTAssertEqual(choice.isSelected,[2,4,6].contains(day))
    XCTAssertGreaterThanOrEqual(choice.frame.height,44)
    XCTAssertGreaterThanOrEqual(choice.frame.width,44)
    if !choice.isSelected {choice.tap()}
   }
   XCTAssertEqual(app.staticTexts["alarmRepeatSummary"].label,vietnamese ? "Mỗi ngày" : "Every day")
   let frames=[2,3,4,5,6,7,1].map {app.buttons["alarmRepeatDay-\($0)"].frame}
   for frame in frames {XCTAssertEqual(frame.midY,frames[0].midY,accuracy:1,"Weekdays must stay on one row, including large text")}
   for index in 1..<frames.count {XCTAssertGreaterThanOrEqual(frames[index].minX,frames[index-1].maxX-1)}
   let preview=XCTAttachment(screenshot:app.screenshot())
   preview.name="inline-repeat-circles-\(vietnamese ? "vi" : "en")-\(largeText ? "large" : "default")";preview.lifetime = .keepAlways;add(preview)
   app.buttons["alarmRepeatDay-1"].tap()
   app.buttons["saveAlarm"].tap()
   let edit=app.staticTexts["alarmTime-00000000-0000-0000-0000-000000000001"]
   XCTAssertTrue(edit.waitForExistence(timeout:5));edit.tap()
   reveal(app.buttons["alarmRepeatDay-2"],in:app)
   for day in 1...7 {XCTAssertEqual(app.buttons["alarmRepeatDay-\(day)"].isSelected,day != 1)}
   app.buttons[vietnamese ? "Hủy" : "Cancel"].tap()
   app.terminate()
  }
 }
 func testActiveCardBackgroundOpensConfigAndControlsRemainIndependent() {
  let id="00000000-0000-0000-0000-000000000001"
  let app=launch(["--ui-home-alarms"])
  let card=app.descendants(matching:.any)["alarmCard-"+id]
  card.coordinate(withNormalizedOffset:CGVector(dx:0.04,dy:0.5)).tap()
  XCTAssertTrue(app.navigationBars["Edit alarm"].waitForExistence(timeout:5))
  app.buttons["Cancel"].tap()
  tryAlarm(id,in:app)
  XCTAssertTrue(app.buttons["backToHome"].waitForExistence(timeout:5))
  XCTAssertFalse(app.navigationBars["Edit alarm"].exists)
  app.buttons["backToHome"].tap()
  XCTAssertTrue(app.buttons["addAlarm"].waitForExistence(timeout:5))
  app.switches["toggleAlarm-"+id].tap()
  XCTAssertTrue(app.staticTexts["Off"].waitForExistence(timeout:5))
  XCTAssertFalse(app.navigationBars["Edit alarm"].exists)
  revealAlarmDelete(id,in:app)
  app.buttons["deleteAlarm-"+id].tap()
   confirmDelete(in:app)
  XCTAssertFalse(app.staticTexts["alarmTime-"+id].waitForExistence(timeout:1))
  XCTAssertFalse(app.navigationBars["Edit alarm"].exists)
  app.terminate()
 }
 func testAlarmCardShowsTimeRepeatAndDirectPractice() {
  let id="00000000-0000-0000-0000-000000000001"
  for vietnamese in [false,true] {
   let app=launch(["--ui-home-alarms","--ui-completed-alarm"],vietnamese:vietnamese)
   let time=app.staticTexts["alarmTime-"+id],options=app.buttons["tryAlarm-"+id]
   let repeatDays=app.staticTexts["alarmRepeat-"+id],challenge=app.staticTexts["alarmChallenge-"+id]
   XCTAssertEqual(time.label,"07:15 AM")
   XCTAssertGreaterThan(challenge.frame.minX,time.frame.maxX,"Time and challenge should occupy distinct columns")
   XCTAssertGreaterThanOrEqual(repeatDays.frame.minY,time.frame.maxY)
   XCTAssertEqual(app.staticTexts["alarmTime-00000000-0000-0000-0000-000000000002"].label,"08:30 PM")
   XCTAssertTrue(app.staticTexts["alarmTime-00000000-0000-0000-0000-000000000003"].label.contains("09:00 AM"))
   XCTAssertEqual(challenge.label,vietnamese ? "Đọc và Chọn" : "Read & Choose")
   XCTAssertEqual(repeatDays.label,vietnamese ? "T2, T4, T6" : "Mon, Wed, Fri")
   XCTAssertTrue(app.staticTexts["alarmMode-"+id].label.contains(vietnamese ? "Đã thức dậy" : "Awake"))
   XCTAssertTrue(app.buttons["tryAlarm-"+id].isHittable)
   XCTAssertFalse(app.buttons["deleteAlarm-"+id].exists)
   XCTAssertGreaterThan(options.frame.minY,time.frame.maxY)
   XCTAssertEqual(options.frame.midY,app.switches["toggleAlarm-"+id].frame.midY,accuracy:2)
   XCTAssertGreaterThanOrEqual(options.frame.width,44);XCTAssertGreaterThanOrEqual(options.frame.height,44)
   XCTAssertLessThan(app.descendants(matching:.any)["alarmCard-"+id].frame.height,215)
   XCTAssertEqual(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","editAlarm-")).count,0)
   let attachment=XCTAttachment(screenshot:app.screenshot())
   attachment.name="alarm-design-\(vietnamese ? "vi" : "en")";attachment.lifetime = .keepAlways;add(attachment)
   app.terminate()
  }
 }
 func testYellowCardHandlesLongLabelsAndSchedulingWarningsWithLargeText() {
  let first="00000000-0000-0000-0000-000000000001",second="00000000-0000-0000-0000-000000000002"
  for largeText in [false,true] {
   var arguments=["--ui-home-alarms","--ui-card-layout","--ui-completed-alarm"]
   if largeText {arguments += ["-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityM","--ui-dark-mode"]}
   let app=launch(arguments,vietnamese:largeText)
   let card=app.descendants(matching:.any)["alarmCard-"+first]
   let name=app.staticTexts["alarmLabel-"+first],time=app.staticTexts["alarmTime-"+first]
   let repeatDays=app.staticTexts["alarmRepeat-"+first],challenge=app.staticTexts["alarmChallenge-"+first]
   let mode=app.staticTexts["alarmMode-"+first]
   XCTAssertEqual(name.label,"Morning routine before work")
   XCTAssertLessThanOrEqual(name.frame.maxY,time.frame.minY)
   XCTAssertLessThanOrEqual(time.frame.maxY,repeatDays.frame.minY)
   if largeText {XCTAssertLessThanOrEqual(repeatDays.frame.maxY,challenge.frame.minY)}
   else {XCTAssertGreaterThanOrEqual(challenge.frame.minX,time.frame.maxX)}
   XCTAssertLessThanOrEqual(challenge.frame.maxY,mode.frame.minY)
   for element in [name,time,repeatDays,challenge,mode] {XCTAssertTrue(card.frame.contains(element.frame))}
   XCTAssertTrue(app.staticTexts["nextAlarm-"+first].exists)
   XCTAssertTrue(app.staticTexts["alarmCompleted-"+first].exists)
   let overview=XCTAttachment(screenshot:app.screenshot())
   overview.name=largeText ? "card-layout-dark-large" : "card-layout-long-label"
   overview.lifetime = .keepAlways;add(overview)
   let warning=app.descendants(matching:.any)["alarmState-"+second]
   reveal(warning,in:app)
   XCTAssertTrue(warning.isHittable)
   XCTAssertEqual(app.staticTexts["alarmRepeat-"+second].label,largeText ? "Báo một lần" : "Rings once")
   XCTAssertFalse(app.staticTexts["nextAlarm-"+second].exists,"Unconfirmed alarms must keep their scheduling warning")
   let warningPreview=XCTAttachment(screenshot:app.screenshot())
   warningPreview.name=largeText ? "card-layout-warning-vi-large" : "card-layout-warning-en"
   warningPreview.lifetime = .keepAlways;add(warningPreview)
   app.terminate()
  }
 }
 func testMovementGuidesAndSimplerNoChallengeCard() {
  let first="00000000-0000-0000-0000-000000000001",second="00000000-0000-0000-0000-000000000002"
  let app=launch(["--ui-home-alarms","--ui-movement-cards"],vietnamese:true)
  let movement=app.descendants(matching:.any)["alarmCard-"+first]
  let plain=app.descendants(matching:.any)["alarmCard-"+second]
  XCTAssertLessThan(plain.frame.height,movement.frame.height-40)
  XCTAssertFalse(app.staticTexts["alarmChallenge-"+second].exists)
  XCTAssertTrue(app.staticTexts["alarmRepeat-"+second].exists)
  XCTAssertTrue(app.staticTexts["nextAlarm-"+second].exists)
  XCTAssertFalse(app.buttons["tryAlarm-"+second].exists)
  let overview=XCTAttachment(screenshot:app.screenshot());overview.name="movement-and-plain-cards";overview.lifetime = .keepAlways;add(overview)
  for (kind,instruction) in [("pushUps","Hạ người rồi đẩy lên"),("waveHand","Vẫy tay qua hai bên"),("neckRotation","Quay đầu sang trái rồi phải"),("jumpingJacks","Bật dang rồi khép tay chân"),("stretching","Giơ tay lên rồi hạ xuống"),("guidedRhythm","Khuỵu gối rồi đứng lên")] {
   reveal(app.buttons["practiceChallenges"],in:app);app.buttons["practiceChallenges"].tap();app.buttons["practice-"+kind].tap()
   XCTAssertTrue(app.staticTexts["movementGuideInstruction"].waitForExistence(timeout:5))
   XCTAssertEqual(app.staticTexts["movementGuideInstruction"].label,instruction)
   let framing=["pushUps":"Góc ngang · Toàn thân","waveHand":"Chính diện · Bàn tay","neckRotation":"Chính diện · Khuôn mặt","jumpingJacks":"Chính diện · Toàn thân","stretching":"Chính diện · Thân trên","guidedRhythm":"Góc ngang · Toàn thân"]
   XCTAssertEqual(app.staticTexts["movementCameraFraming"].label,framing[kind])
   let pause=app.buttons["toggleMovementGuide"]
   XCTAssertTrue(pause.isHittable);pause.tap();XCTAssertEqual(pause.label,"Phát hướng dẫn động tác")
   let demo=XCTAttachment(screenshot:app.screenshot());demo.name="movement-guide-"+kind;demo.lifetime = .keepAlways;add(demo)
   pause.tap();XCTAssertEqual(pause.label,"Tạm dừng hướng dẫn động tác")
   app.buttons["backToHome"].tap()
  }
  reveal(app.buttons["practiceChallenges"],in:app);app.buttons["practiceChallenges"].tap();app.buttons["practice-none"].tap()
  XCTAssertTrue(app.buttons["backToHome"].waitForExistence(timeout:5))
  XCTAssertFalse(app.staticTexts["movementGuideInstruction"].exists)
  app.terminate()
 }
 func testSeatedGuideAndReduceMotionAndCatalogIcons() {
  for reduced in [false,true] {
   let args=["--ui-enabled-alarm"]+(reduced ? ["--ui-reduce-motion","--ui-dark-mode","-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityM"] : [])
   let app=launch(args)
   tryAlarm("00000000-0000-0000-0000-000000000001",in:app)
   XCTAssertTrue(app.staticTexts["movementGuideInstruction"].waitForExistence(timeout:5))
   XCTAssertEqual(app.staticTexts["movementGuideInstruction"].label,"Seated · Arms up, then down")
   XCTAssertEqual(app.staticTexts["movementCameraFraming"].label,"Front view · Upper body")
   XCTAssertEqual(app.buttons["toggleMovementGuide"].exists,!reduced)
   XCTAssertTrue(app.buttons["startGuidedRhythm"].isHittable)
   let demo=XCTAttachment(screenshot:app.screenshot());demo.name=reduced ? "movement-guide-reduced-large" : "movement-guide-seated";demo.lifetime = .keepAlways;add(demo)
   app.buttons["backToHome"].tap()
   app.staticTexts["alarmTime-00000000-0000-0000-0000-000000000001"].tap()
   reveal(app.buttons["challenge-guidedRhythm"],in:app)
   XCTAssertTrue(app.buttons["challenge-guidedRhythm"].label.contains("On-device camera"))
   reveal(app.buttons["mode-focused"],in:app);app.buttons["mode-focused"].tap()
   reveal(app.buttons["challenge-jumpingJacks"],in:app)
   XCTAssertTrue(app.buttons["challenge-pushUps"].exists)
   XCTAssertTrue(app.buttons["challenge-pushUps"].label.contains("On-device camera"))
   let catalog=XCTAttachment(screenshot:app.screenshot());catalog.name=reduced ? "movement-catalog-dark-large" : "movement-catalog";catalog.lifetime = .keepAlways;add(catalog)
   app.buttons["Cancel"].tap();app.terminate()
  }
 }
 func testCameraTrackingPreviewAndEmptyStateDoNotCompleteAChallenge() {
  for empty in [false,true] {
   let app=launch(["--ui-home-alarms","--ui-movement-cards","--ui-tracking-overlay"]+(empty ? ["--ui-tracking-empty"] : []),vietnamese:true)
   tryAlarm("00000000-0000-0000-0000-000000000001",in:app)
   XCTAssertTrue(app.staticTexts["trackingFixtureLabel"].waitForExistence(timeout:5))
   XCTAssertEqual(app.staticTexts["cameraTrackingStatus"].label,empty ? "Cần thấy rõ hơn" : "Đang nhận diện")
   XCTAssertEqual(app.staticTexts["cameraRepCounter"].label,"0 / 3")
   XCTAssertFalse(app.buttons["retryChallenge"].exists)
   XCTAssertTrue(app.buttons["startChallenge"].isHittable)
   let image=XCTAttachment(screenshot:app.screenshot());image.name=empty ? "camera-tracking-empty" : "camera-tracking-overlay-fixture";image.lifetime = .keepAlways;add(image)
   app.buttons["backToHome"].tap();app.terminate()
  }
 }
 func testHomeAndProgressAccessibilityLabelsAndTargets() throws {
  let app=launch(["--ui-home-alarms","--ui-completed-alarm","--ui-progress-fixture"],vietnamese:true)
  // Image-based contrast/OCR findings remain in the design evidence for manual review.
  let audits:XCUIAccessibilityAuditType=[.hitRegion,.sufficientElementDescription,.textClipped,.trait]
  try app.performAccessibilityAudit(for:audits)
  app.buttons["morningProgress"].tap()
  XCTAssertTrue(app.staticTexts["monthlyScore"].waitForExistence(timeout:5))
  try app.performAccessibilityAudit(for:audits)
  app.buttons["closeProgress"].tap()
  XCTAssertTrue(app.buttons["morningProgress"].waitForExistence(timeout:5))
  XCTAssertFalse(app.buttons["closeProgress"].exists)
  app.terminate()
 }
 func testDisabledAlarmIsCompactAndCanBeEditedAndDeletedInBothLanguages() {
  let id="00000000-0000-0000-0000-000000000001"
  for vietnamese in [false,true] {
   let app=launch(["--ui-disabled-alarm"],vietnamese:vietnamese)
   let edit=app.staticTexts["alarmTime-"+id]
   XCTAssertTrue(edit.isHittable)
   XCTAssertTrue(edit.label.contains("07:15"))
   XCTAssertTrue(app.staticTexts[vietnamese ? "Đã tắt" : "Off"].exists)
   XCTAssertFalse(app.staticTexts[vietnamese ? "Nhịp điệu hướng dẫn · Ngồi" : "Guided Rhythm · Seated"].exists)
   XCTAssertFalse(app.staticTexts.containing(NSPredicate(format:"label CONTAINS %@",vietnamese ? "Đã thức dậy" : "Awake")).firstMatch.exists)
   XCTAssertFalse(app.buttons[vietnamese ? "Thử thử thách này" : "Try this challenge"].exists)
   XCTAssertTrue(app.switches["toggleAlarm-"+id].isHittable)
   XCTAssertFalse(app.buttons["alarmOptions-"+id].exists)
   app.staticTexts[vietnamese ? "Đã tắt" : "Off"].tap()
   XCTAssertTrue(app.navigationBars[vietnamese ? "Sửa báo thức" : "Edit alarm"].waitForExistence(timeout:5))
   app.buttons[vietnamese ? "Hủy" : "Cancel"].tap()
   revealAlarmDelete(id,in:app)
   app.buttons["deleteAlarm-"+id].tap()
   confirmDelete(in:app)
   let removed=XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == false"),object:edit)
   XCTAssertEqual(XCTWaiter.wait(for:[removed],timeout:5),.completed)
   XCTAssertEqual(app.alerts.count,0)
   app.terminate()
  }
 }
 func testEnabledAlarmChallengeEditClosesAndKeepsTheNewChoiceInBothLanguages() {
  for vietnamese in [false,true] {
   let app=launch(["--ui-enabled-alarm"],vietnamese:vietnamese)
   let edit=app.staticTexts["alarmTime-00000000-0000-0000-0000-000000000001"]
   reveal(edit,in:app);app.staticTexts["alarmChallenge-00000000-0000-0000-0000-000000000001"].tap()
   let navigation=app.navigationBars[vietnamese ? "Sửa báo thức" : "Edit alarm"]
   XCTAssertTrue(navigation.waitForExistence(timeout:5))
   let reading=app.buttons["challenge-readAloud"]
   reveal(reading,in:app);reading.tap();XCTAssertTrue(reading.isSelected)
   if app.buttons["doneSound"].exists {app.buttons["doneSound"].tap()}
   app.buttons["saveAlarm"].tap()
   let closed=XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == false"),object:navigation)
   guard XCTWaiter.wait(for:[closed],timeout:5) == .completed else {
    XCTFail("Saving only a challenge must close the editor without native alarm access: \(app.staticTexts["alarmSaveError"].label)")
    app.terminate();return
   }
   XCTAssertTrue(edit.waitForExistence(timeout:5))
   XCTAssertEqual(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","editAlarm-")).count,0)
   XCTAssertTrue(app.staticTexts[vietnamese ? "Đọc to" : "Read Aloud"].exists)
   XCTAssertEqual(app.alerts.count,0)
   edit.tap();reveal(reading,in:app);XCTAssertTrue(reading.isSelected)
   if app.buttons["doneSound"].exists {app.buttons["doneSound"].tap()}
   app.buttons["saveAlarm"].tap()
   let unchanged=XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == false"),object:navigation)
   XCTAssertEqual(XCTWaiter.wait(for:[unchanged],timeout:5),.completed,"Saving unchanged settings must also close")
   app.terminate()
  }
 }
 func testSaveButtonRespondsAcrossItsVisibleWidth() {
  for (vietnamese,x) in [(false,0.1),(false,0.9),(true,0.5)] {
   let app=launch(["--ui-disabled-alarm"],vietnamese:vietnamese)
   let edit=app.staticTexts["alarmTime-00000000-0000-0000-0000-000000000001"]
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
   XCTAssertTrue(app.buttons["backToHome"].isHittable)
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
   let edit=app.staticTexts["alarmTime-00000000-0000-0000-0000-000000000001"]
   reveal(edit,in:app);edit.tap()
   XCTAssertTrue(app.navigationBars[vietnamese ? "Sửa báo thức" : "Edit alarm"].waitForExistence(timeout:5))
   XCTAssertTrue(app.datePickers["alarmTimePicker"].isHittable,"Time is the primary control")
   XCTAssertTrue(app.buttons["mode-balanced"].isSelected)
   reveal(app.buttons["challenge-guidedRhythm"],in:app)
   XCTAssertTrue(app.buttons["challenge-guidedRhythm"].isSelected)
   reveal(app.buttons[vietnamese ? "Ngồi" : "Seated"],in:app)
   XCTAssertTrue(app.buttons[vietnamese ? "Ngồi" : "Seated"].isSelected)
   toggleSound(in:app)
   XCTAssertTrue(app.buttons["sound-sunrise"].isSelected)
   app.buttons["sound-softChime"].tap()
   toggleSound(in:app)
   XCTAssertTrue(app.buttons["mode-balanced"].isSelected,"Changing panels must retain the alarm draft")
   toggleSound(in:app)
   XCTAssertTrue(app.buttons["sound-softChime"].isSelected,"Panel changes must retain the selected sound")
   if app.buttons["doneSound"].exists {app.buttons["doneSound"].tap()}
   app.buttons["saveAlarm"].tap()
   XCTAssertTrue(edit.waitForExistence(timeout:5))
   XCTAssertEqual(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","editAlarm-")).count,0)
   XCTAssertTrue(app.staticTexts[vietnamese ? "Đã tắt" : "Off"].exists)
   XCTAssertEqual(app.staticTexts.matching(NSPredicate(format:"identifier BEGINSWITH %@","nextAlarm-")).count,0)
   XCTAssertFalse(app.staticTexts.containing(NSPredicate(format:"label CONTAINS %@",vietnamese ? "Chuông dịu" : "Soft chime")).firstMatch.exists)
   XCTAssertEqual(app.alerts.count,0,"Editing a disabled alarm must not request alarm access")
   edit.tap();reveal(app.buttons["chooseSound"],in:app);toggleSound(in:app)
   XCTAssertTrue(app.buttons["sound-softChime"].isSelected,"Collapsed details must still persist")
   app.terminate()
  }
 }
 func testSoundAccessExpiringAtSavePreservesDraftAndOffersRecovery() {
  let app=launch(["--ui-disabled-alarm","--ui-sound-access-expires"])
  let edit=app.staticTexts["alarmTime-00000000-0000-0000-0000-000000000001"]
  edit.tap();toggleSound(in:app);app.buttons["sound-softChime"].tap()
  if app.buttons["doneSound"].exists {app.buttons["doneSound"].tap()}
  app.buttons["saveAlarm"].tap()
  XCTAssertTrue(app.staticTexts["This sound is no longer available. Choose System sound or unlock Pro."].waitForExistence(timeout:5))
  toggleSound(in:app)
  XCTAssertTrue(app.buttons["sound-softChime"].isSelected,"Save must not silently replace the selected sound")
  toggleSound(in:app)
  XCTAssertTrue(app.buttons["saveAlarm"].isEnabled)
  app.buttons["Cancel"].tap();edit.tap();toggleSound(in:app)
  XCTAssertTrue(app.buttons["sound-sunrise"].isSelected,"Failed Save must preserve the stored alarm")
  app.buttons["sound-system"].tap();toggleSound(in:app);app.buttons["saveAlarm"].tap()
  XCTAssertTrue(edit.waitForExistence(timeout:5))
  edit.tap();toggleSound(in:app)
  XCTAssertTrue(app.buttons["sound-system"].isSelected)
  toggleSound(in:app);app.buttons["Cancel"].tap();app.terminate()
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
 func testSelectedChallengeSettingsAreGroupedAndAdjustable() {
  let app=launch()
  app.buttons["addAlarm"].tap()
  reveal(app.buttons["mode-focused"],in:app);app.buttons["mode-focused"].tap()
  reveal(app.buttons["challenge-pushUps"],in:app);app.buttons["challenge-pushUps"].tap()
  let card=app.otherElements["challenge-settings-pushUps"]
  let summary=app.staticTexts["challenge-summary-pushUps"],target=app.staticTexts["pushUpTarget"]
  reveal(target,in:app)
  XCTAssertTrue(card.exists);XCTAssertTrue(summary.exists);XCTAssertTrue(target.exists)
  XCTAssertTrue(card.frame.contains(summary.frame))
  XCTAssertTrue(card.frame.contains(target.frame))
  XCTAssertTrue(app.buttons["decreasePushUpTarget"].isEnabled == false)
  app.buttons["increasePushUpTarget"].tap()
  XCTAssertTrue(target.label.contains("11"))
  app.buttons["Cancel"].tap()
 }
 func testGlassComposerSelectionAndPinnedControlsInDarkAndLargeText() {
  for largeText in [false,true] {
   var args=["--ui-dark-mode","--ui-reduce-motion"]
   if largeText {args += ["-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityM","--ui-reduce-transparency"]}
   let app=launch(args,vietnamese:true)
   app.buttons["addAlarm"].tap()
   XCTAssertTrue(app.staticTexts["composerChallengeTitle"].waitForExistence(timeout:5))
   let time=app.datePickers["alarmTimePicker"],save=app.buttons["saveAlarm"]
   XCTAssertTrue(time.isHittable);XCTAssertTrue(save.isHittable)
   let selected=app.buttons["challenge-waveHand"]
   reveal(selected,in:app);selected.tap()
   XCTAssertTrue(selected.isSelected)
   XCTAssertEqual(app.staticTexts["composerChallengeTitle"].label,"Vẫy chào")
   toggleSound(in:app)
   XCTAssertTrue(app.buttons["sound-system"].isSelected)
   toggleSound(in:app)
   reveal(time,in:app)
   XCTAssertEqual(app.staticTexts["composerChallengeTitle"].label,"Vẫy chào")
   reveal(time,in:app)
   XCTAssertTrue(time.isHittable);XCTAssertTrue(save.isHittable)
   XCTAssertTrue(app.windows.firstMatch.frame.contains(time.frame))
   XCTAssertTrue(app.windows.firstMatch.frame.contains(save.frame))
   let screenshot=XCTAttachment(screenshot:app.screenshot())
   screenshot.name=largeText ? "composer-dark-large-reduced" : "composer-dark-glass"
   screenshot.lifetime = .keepAlways;add(screenshot)
   app.buttons["Hủy"].tap();app.terminate()
  }
 }
 func testEnabledAlarmSoundEditReschedulesTheSameNativeAlarm() throws {
  let app=launch()
  let edits=app.staticTexts.matching(NSPredicate(format:"identifier BEGINSWITH %@","alarmTime-"))
  let before=Set(edits.allElementsBoundByIndex.map(\.identifier))
  addTeardownBlock {
   if app.buttons["Cancel"].isHittable {app.buttons["Cancel"].tap()}
   let created=Set(edits.allElementsBoundByIndex.map(\.identifier)).subtracting(before)
   guard created.count == 1,let identifier=created.first else {
    XCTAssertTrue(created.isEmpty,"Only this test’s one disposable alarm may be removed")
    return
   }
   let alarmID=String(identifier.dropFirst("alarmTime-".count)),edit=app.staticTexts[identifier],delete=app.buttons["deleteAlarm-"+alarmID]
   self.revealAlarmDelete(alarmID,in:app);delete.tap();self.confirmDelete(in:app)
   let removed=XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == false"),object:edit)
   self.wait(for:[removed],timeout:10)
  }
  app.buttons["addAlarm"].tap()
  reveal(app.buttons["chooseSound"],in:app);toggleSound(in:app)
  app.buttons["sound-sunrise"].tap()
  toggleSound(in:app)
  if app.buttons["doneSound"].exists {app.buttons["doneSound"].tap()}
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
  let alarmID=String(identifier.dropFirst("alarmTime-".count)),edit=app.staticTexts[identifier]
  reveal(edit,in:app)
  XCTAssertFalse(app.staticTexts["Alarm is set"].exists)
  XCTAssertTrue(app.staticTexts["nextAlarm-"+alarmID].exists)
  edit.tap()
  reveal(app.buttons["chooseSound"],in:app);toggleSound(in:app)
  XCTAssertTrue(app.buttons["sound-sunrise"].isSelected)
  app.buttons["sound-softChime"].tap()
  toggleSound(in:app)
  if app.buttons["doneSound"].exists {app.buttons["doneSound"].tap()}
  app.buttons["saveAlarm"].tap()
  let edited=XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == false"),object:app.navigationBars["Edit alarm"])
  guard XCTWaiter.wait(for:[edited],timeout:15) == .completed else {
   try skipIfNativeAlarmAccessIsDenied(app)
   XCTFail("The real native scheduler did not confirm editing the same alarm ID: \(app.staticTexts["alarmSaveError"].label)")
   return
  }
  XCTAssertEqual(Set(edits.allElementsBoundByIndex.map(\.identifier)),before.union([identifier]))
  reveal(edit,in:app)
  XCTAssertFalse(app.staticTexts["Alarm is set"].exists)
  XCTAssertTrue(app.staticTexts["nextAlarm-"+alarmID].exists)
  edit.tap()
  reveal(app.buttons["chooseSound"],in:app);toggleSound(in:app)
  XCTAssertTrue(app.buttons["sound-softChime"].isSelected,"The same alarm must persist its changed sound")
  toggleSound(in:app)
  app.buttons["Cancel"].tap()
 }
}
