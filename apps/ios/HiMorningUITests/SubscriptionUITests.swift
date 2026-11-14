import XCTest
import StoreKit
import StoreKitTest

@MainActor final class SubscriptionUITests:XCTestCase {
 private func testSession() throws ->SKTestSession {
  let file=try XCTUnwrap(Bundle(for:Self.self).url(forResource:"HiMorning",withExtension:"storekit"))
  let session=try SKTestSession(contentsOf:file)
  session.resetToDefaultState()
  session.clearTransactions()
  session.disableDialogs=true
  session.storefront="USA"
  session.locale=Locale(identifier:"en_US")
  return session
 }

 private func openPro(accessibility:Bool=false)->XCUIApplication {
  let app=XCUIApplication()
  app.launchArguments=["--ui-testing","--preview-expired","-AppleLanguages","(en)","-AppleLocale","en_US"]
  if accessibility {
   app.launchArguments += ["--ui-language-vi","--ui-dark-mode","-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityXXXL"]
  }
  app.launch()
  let pro=app.buttons["hiMorningPro"]
  XCTAssertTrue(pro.waitForExistence(timeout:5))
  pro.tap()
  XCTAssertTrue(app.buttons["closePro"].waitForExistence(timeout:5))
  return app
 }

 private func capture(_ app:XCUIApplication,name:String) {
  let attachment=XCTAttachment(screenshot:app.screenshot())
  attachment.name=name
  attachment.lifetime = .keepAlways
  add(attachment)
 }

 private func reveal(_ element:XCUIElement,in app:XCUIApplication) {
  for _ in 0..<7 where !element.isHittable {app.swipeUp()}
  XCTAssertTrue(element.isHittable)
 }

 private func checkout(in app:XCUIApplication)->XCUIElement {
  app.buttons["subscribeToPro"]
 }

 func testCheckoutUnlocksProFromNativeStoreKit() throws {
  let session=try testSession()
  defer {session.clearTransactions()}
  let app=openPro()
  capture(app,name:"pro-benefits-en")
  let checkout=checkout(in:app)
  guard checkout.waitForExistence(timeout:10) else {return XCTFail(app.debugDescription)}
  XCTAssertTrue(app.buttons["restorePurchases"].exists)
  XCTAssertFalse(app.buttons.matching(NSPredicate(format:"label CONTAINS[c] %@","Redeem Code")).firstMatch.exists)
  let yearly=app.buttons["annualProPlan"]
  reveal(yearly,in:app)
  XCTAssertTrue(yearly.label.contains("per year"))
  yearly.tap()
  XCTAssertTrue(yearly.isSelected)
  reveal(checkout,in:app)
  capture(app,name:"pro-checkout-en")
  checkout.tap()
  XCTAssertTrue(app.buttons["manageSubscription"].waitForExistence(timeout:12))
  XCTAssertTrue(app.staticTexts["Pro is active"].exists)
  XCTAssertFalse(checkout.exists)
  capture(app,name:"pro-active-en")
  app.buttons["closePro"].tap()
  XCTAssertTrue(app.buttons["addAlarm"].exists)
 }

 func testUnavailableCatalogCanRetryAndRestoreAtLargeVietnameseText() async throws {
  let session=try testSession()
  defer {session.resetToDefaultState();session.clearTransactions()}
  try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))),forAPI:.loadProducts)
  let app=openPro(accessibility:true)
  let retry=app.buttons["retrySubscriptionLoad"]
  reveal(retry,in:app)
  XCTAssertEqual(retry.label,"Thử lại")
  capture(app,name:"pro-unavailable-vi-accessibility")

  let restore=app.buttons["restorePurchases"]
  reveal(restore,in:app)
  XCTAssertEqual(restore.label,"Khôi phục gói đã mua")
  restore.tap()
  let feedback=app.staticTexts["purchaseMessage"]
  XCTAssertTrue(feedback.waitForExistence(timeout:8))
  XCTAssertEqual(feedback.label,"Không tìm thấy gói Pro đang hoạt động.")
  reveal(feedback,in:app)
  capture(app,name:"pro-restore-vi-accessibility")

  try await session.setSimulatedError(nil,forAPI:.loadProducts)
  for _ in 0..<7 where !retry.isHittable {app.swipeDown()}
  XCTAssertTrue(retry.isHittable)
  retry.tap()
  let checkout=checkout(in:app)
  guard checkout.waitForExistence(timeout:10) else {return XCTFail(app.debugDescription)}
  reveal(checkout,in:app)
  capture(app,name:"pro-checkout-vi-accessibility")
 }
}
