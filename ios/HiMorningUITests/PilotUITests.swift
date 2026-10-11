import XCTest
final class PilotUITests:XCTestCase {
 func testGentleDefaultAndCancelWithoutPermissionOrCloud() {
  let app=XCUIApplication();app.launch()
  app.buttons["addAlarm"].tap()
  XCTAssertTrue(app.navigationBars["Báo thức mới"].waitForExistence(timeout:5))
  XCTAssertTrue(app.staticTexts["Thức dậy theo nhịp của bạn"].exists)
  app.buttons["Hủy"].tap()
  XCTAssertTrue(app.buttons["addAlarm"].waitForExistence(timeout:5))
 }
}
