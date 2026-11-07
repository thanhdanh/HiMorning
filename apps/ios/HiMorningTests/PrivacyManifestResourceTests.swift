import XCTest

final class PrivacyManifestResourceTests:XCTestCase {
 func testAppBundleDeclaresItsRequiredReasonAPIs() throws {
  let url=try XCTUnwrap(Bundle.main.url(forResource:"PrivacyInfo",withExtension:"xcprivacy"))
  let data=try Data(contentsOf:url)
  let manifest=try XCTUnwrap(PropertyListSerialization.propertyList(from:data,format:nil) as? [String:Any])
  let entries=try XCTUnwrap(manifest["NSPrivacyAccessedAPITypes"] as? [[String:Any]])
  var declared:[String:[String]]=[:]
  for entry in entries {
   let category=try XCTUnwrap(entry["NSPrivacyAccessedAPIType"] as? String)
   let reasons=try XCTUnwrap(entry["NSPrivacyAccessedAPITypeReasons"] as? [String])
   XCTAssertNil(declared[category],"Each API category must be declared only once")
   XCTAssertFalse(reasons.isEmpty)
   declared[category]=reasons
  }
  XCTAssertEqual(declared["NSPrivacyAccessedAPICategoryUserDefaults"],["CA92.1"])
  XCTAssertEqual(declared["NSPrivacyAccessedAPICategorySystemBootTime"],["35F9.1"])
 }
}
