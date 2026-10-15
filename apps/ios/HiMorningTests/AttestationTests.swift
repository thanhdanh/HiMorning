import XCTest
import FirebaseCore
import FirebaseAppCheck
@testable import HiMorning

final class AttestationTests:XCTestCase {
 private func app(projectID:String) throws ->FirebaseApp {
  let options=FirebaseOptions(googleAppID:"1:1234567890:ios:1234567890abcdef",gcmSenderID:"1234567890")
  options.apiKey="unit-test-not-a-credential";options.projectID=projectID
  let name="attestation-test-"+UUID().uuidString
  FirebaseApp.configure(name:name,options:options)
  return try XCTUnwrap(FirebaseApp.app(name:name))
 }
 func testStagingUsesDebugAttestationOnlyInADebugBuild() throws {
  let app=try app(projectID:"himorning-staging-0109")
  defer {app.delete {_ in}}
  let provider=try XCTUnwrap(AttestationFactory().createProvider(with:app))
  #if DEBUG
  XCTAssertTrue(provider is AppCheckDebugProvider)
  #else
  XCTAssertTrue(provider is AppAttestProvider,"Release must never select a debug provider")
  #endif
 }
 func testAnotherProjectNeverUsesDebugAttestation() throws {
  let app=try app(projectID:"demo-other-project")
  defer {app.delete {_ in}}
  XCTAssertTrue(AttestationFactory().createProvider(with:app) is AppAttestProvider)
 }
}
