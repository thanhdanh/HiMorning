import XCTest

final class MorningJourneyUITests:XCTestCase {
 private func launch(vi:Bool=false,_ args:[String]=[])->XCUIApplication {
  let app=XCUIApplication();app.launchArguments=["-AppleLanguages","(en)","-AppleLocale","en_US","--ui-testing","--ui-reading-correct-first"]+args
  if vi {app.launchArguments.append("--ui-language-vi")}
  app.launch();return app
 }
 private func reveal(_ item:XCUIElement,in app:XCUIApplication) {
  for _ in 0..<14 {
   if item.exists,item.isHittable,item.frame.maxY<app.frame.maxY-30 {return}
   app.swipeUp()
  }
  XCTAssertTrue(item.isHittable)
 }
 private func capture(_ app:XCUIApplication,_ name:String) {
  let a=XCTAttachment(screenshot:app.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)
 }
 private func choose(_ focus:String,in app:XCUIApplication) {
  let button=app.buttons["chooseMorningPurpose"].exists ? app.buttons["chooseMorningPurpose"] : app.buttons["changeMorningPurpose"]
  reveal(button,in:app);button.tap()
  let choice=app.buttons["morningPurpose-"+focus];XCTAssertTrue(choice.waitForExistence(timeout:5));reveal(choice,in:app);choice.tap()
  XCTAssertTrue(app.staticTexts["journeyProgress"].waitForExistence(timeout:5))
 }
 func testPurposePracticeAndPresetDraftInBothLanguages() {
  for vi in [false,true] {
   let app=launch(vi:vi,["--ui-empty-home"])
   choose("clearStart",in:app)
   XCTAssertEqual(app.staticTexts["journeyProgress"].label,vi ? "Đã hoàn thành 0 trong 7 buổi sáng" : "0 of 7 mornings earned")
   XCTAssertTrue(app.staticTexts["journeyMission"].exists)
   XCTAssertTrue(app.staticTexts["journeyNextMission"].label.contains(vi ? "Đố vui" : "Riddle"))
   capture(app,"journey-purpose-\(vi ? "vi" : "en")")
   app.buttons["tryJourneyMission"].tap()
   XCTAssertTrue(app.buttons["readChoice-0"].waitForExistence(timeout:5));app.buttons["readChoice-0"].tap()
   XCTAssertTrue(app.staticTexts["practiceCompleteExplanation"].waitForExistence(timeout:5))
   app.buttons["backToHome"].tap()
   XCTAssertTrue(app.staticTexts["journeyProgress"].waitForExistence(timeout:5))
   XCTAssertTrue(app.staticTexts["journeyProgress"].label.contains("0"))
   let plan=app.buttons["planJourneyMission"];reveal(plan,in:app);plan.tap()
   XCTAssertTrue(app.buttons["saveAlarm"].waitForExistence(timeout:5))
   XCTAssertTrue(app.buttons["challenge-readAndChoose"].isSelected)
   app.buttons[vi ? "Hủy" : "Cancel"].tap()
   XCTAssertTrue(app.staticTexts["journeyProgress"].waitForExistence(timeout:5))
   XCTAssertFalse(app.staticTexts["recentWinCount"].exists)
   app.terminate()
  }
 }
 func testGentleMissionDraftPreservesExistingScheduleAndProgressOnPurposeChange() {
  let app=launch(["--ui-home-alarms","--ui-journey-fixture","--preview-expired"])
  choose("gentleMovement",in:app)
  XCTAssertEqual(app.staticTexts["journeyProgress"].label,"3 of 7 mornings earned")
  XCTAssertTrue(app.staticTexts["journeyWelcomeBack"].exists)
  app.buttons["planJourneyMission"].tap()
  let id="00000000-0000-0000-0000-000000000001"
  app.buttons["journeyAlarm-"+id].tap()
  XCTAssertTrue(app.buttons["saveAlarm"].waitForExistence(timeout:5))
  XCTAssertTrue(app.buttons["challenge-waveHand"].isSelected)
  XCTAssertFalse(app.datePickers["alarmTimePicker"].exists)
  app.buttons["Cancel"].tap()
  let time=app.staticTexts["alarmTime-"+id];reveal(time,in:app)
  XCTAssertTrue(time.label.contains("07:15") || time.label.contains("7:15"))
  XCTAssertEqual(app.switches["toggleAlarm-"+id].value as? String,"1")
  app.terminate()
 }
 func testRealCompletionEarnsNextStepAndOffersPreparingTomorrow() {
  let app=launch(["--ui-home-alarms","--ui-journey-fixture","--ui-open-alarm"])
  XCTAssertTrue(app.buttons["readChoice-0"].waitForExistence(timeout:5));app.buttons["readChoice-0"].tap()
  XCTAssertTrue(app.staticTexts["journeyTodayWin"].waitForExistence(timeout:5))
  XCTAssertEqual(app.staticTexts["journeyProgress"].label,"4 of 7 mornings earned")
  XCTAssertTrue(app.staticTexts["journeyNextMission"].label.contains("Read & Choose"))
  capture(app,"journey-real-win-next-mission")
  app.buttons["planJourneyMission"].tap()
  app.buttons["journeyAlarm-00000000-0000-0000-0000-000000000001"].tap()
  XCTAssertTrue(app.buttons["challenge-readAndChoose"].waitForExistence(timeout:5));XCTAssertTrue(app.buttons["challenge-readAndChoose"].isSelected)
  app.buttons["Cancel"].tap();app.terminate()
 }
 func testMilestonesAndExplicitNewRoundKeepEarnedHistory() {
  for today in [false,true] {
   let args=["--ui-empty-home","--ui-journey-fixture","--ui-journey-complete"]+(today ? ["--ui-journey-today"]:[])
   let app=launch(args)
   XCTAssertTrue(app.staticTexts["journeyMilestone"].waitForExistence(timeout:5))
   XCTAssertEqual(app.staticTexts["journeyProgress"].label,"7 of 7 mornings earned")
   capture(app,today ? "journey-seven-morning-today" : "journey-seven-morning-milestone")
   app.buttons["restartJourney"].tap();app.alerts.buttons["confirmRestartJourney"].firstMatch.tap()
   XCTAssertEqual(app.staticTexts["journeyProgress"].label,"0 of 7 mornings earned")
   XCTAssertEqual(app.staticTexts["journeyRounds"].label,"Completed rounds on this device: 1")
   if today {
    XCTAssertTrue(app.staticTexts["journeyNextMission"].label.contains("Tomorrow"))
    XCTAssertTrue(app.buttons["planJourneyMission"].exists)
   }
   app.terminate()
  }
 }
 func testThreeMorningRewardAndLargeVietnameseMission() {
  let three=launch(["--ui-empty-home","--ui-journey-fixture","--ui-journey-today"])
  XCTAssertTrue(three.staticTexts["journeyMilestone"].waitForExistence(timeout:5));capture(three,"journey-three-morning-reward");three.terminate()
  let app=launch(vi:true,["--ui-empty-home","-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityXXXL"])
  choose("gentleMovement",in:app)
  reveal(app.buttons["tryJourneyMission"],in:app)
  capture(app,"journey-gentle-vi-accessibility")
  XCTAssertTrue(app.buttons["tryJourneyMission"].isHittable)
  app.terminate()
 }
 func testDeeperRoutineAndReflectionUseRealCompletedPatterns() {
  let app=launch(["--ui-empty-home","--ui-progress-fixture"])
  choose("energize",in:app)
  XCTAssertEqual(app.staticTexts["journeyPurpose"].label,"Move with energy")
  XCTAssertTrue(app.staticTexts["journeyNextMission"].label.contains("5 push-ups"))
  let disclosure=app.buttons["What’s working for me?"];reveal(disclosure,in:app);disclosure.tap()
  let days=app.staticTexts["journeyReflectionDays"];reveal(days,in:app)
  XCTAssertEqual(days.label,"5 of the past 30 days with a completed challenge")
  XCTAssertTrue(app.staticTexts["You returned to Push-ups on 2 days."].exists)
  capture(app,"journey-deeper-routine-reflection")
  app.terminate()
 }

 func testPlannerOnlyOffersUpcomingEnabledConfirmedAlarms() {
  let app=launch(["--ui-home-alarms","--ui-elapsed-once","--ui-journey-fixture"])
  XCTAssertTrue(app.buttons["planJourneyMission"].waitForExistence(timeout:5))
  app.buttons["planJourneyMission"].tap()
  XCTAssertTrue(app.buttons["journeyAlarm-00000000-0000-0000-0000-000000000001"].exists)
  XCTAssertFalse(app.buttons["journeyAlarm-00000000-0000-0000-0000-000000000002"].exists)
  XCTAssertFalse(app.buttons["journeyAlarm-00000000-0000-0000-0000-000000000003"].exists)
  app.buttons["journeyNewAlarm"].tap()
  XCTAssertTrue(app.buttons["saveAlarm"].waitForExistence(timeout:5))
  XCTAssertTrue(app.datePickers["alarmTimePicker"].exists)
  app.buttons["Cancel"].tap();app.terminate()
 }

 func testDeeperRoutineExplainsPaidValueWithoutChangingFreePurpose() {
  let app=launch(["--ui-empty-home","--preview-expired"])
  app.buttons["chooseMorningPurpose"].tap()
  let energy=app.buttons["morningPurpose-energize"];XCTAssertTrue(energy.waitForExistence(timeout:5));reveal(energy,in:app);energy.tap()
  XCTAssertTrue(app.buttons["closePro"].waitForExistence(timeout:5))
  XCTAssertTrue(app.staticTexts["Find a routine worth returning to."].exists)
  app.buttons["closePro"].tap()
  XCTAssertTrue(app.buttons["chooseMorningPurpose"].waitForExistence(timeout:5))
  XCTAssertFalse(app.staticTexts["journeyPurpose"].exists)
  app.terminate()
 }

}
