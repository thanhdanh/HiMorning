import XCTest
@testable import HiMorningCore

final class AlarmSoundTests:XCTestCase {
 func testCatalogKeepsLegacyIDsAndAddsTwelveDistinctChoices() {
  XCTAssertEqual(AlarmSound.allCases.count,15)
  XCTAssertEqual(Set(AlarmSound.allCases.map(\.rawValue)).count,15)
  for raw in ["system","sunrise","softChime","pizzicatoDawn","pizzicatoSteps","pizzicatoRise","pizzicatoBloom","steelShimmer","steelBreeze","steelMorning","steelSparkle","saxHello","saxStroll","saxGlow","saxDaybreak"] {
   XCTAssertNotNil(AlarmSound(rawValue:raw),raw)
  }
 }

 func testEverySoundPersistsAndRestoresWithoutChangingTheSelection() throws {
  let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer {try? FileManager.default.removeItem(at:directory)}
  let persistence=FileAlarmPersistence(url:directory.appendingPathComponent("alarms.json"))
  let time=try AlarmTime(hour:7,minute:15,weekdays:[2,4,6])
  let alarms=AlarmSound.allCases.map {SavedAlarm(time:time,sound:$0)}
  try persistence.save(alarms)
  XCTAssertEqual(try persistence.load(),alarms)
  for sound in AlarmSound.allCases {
   XCTAssertEqual(try JSONDecoder().decode(AlarmSound.self,from:Data("\"\(sound.rawValue)\"".utf8)),sound)
  }
 }

 func testEveryCustomCatalogChoiceHasANonemptyWAVResource() throws {
  var resources=URL(fileURLWithPath:#filePath)
  for _ in 0..<4 {resources.deleteLastPathComponent()}
  resources.appendPathComponent("Resources")
  let custom=AlarmSound.allCases.filter {$0 != .system}
  XCTAssertEqual(custom.count,14)
  for sound in custom {
   let data=try Data(contentsOf:resources.appendingPathComponent(sound.rawValue+".wav"))
   XCTAssertGreaterThan(data.count,44)
   XCTAssertEqual(String(data:Data(data.prefix(4)),encoding:.ascii),"RIFF")
   XCTAssertEqual(String(data:Data(data.dropFirst(8).prefix(4)),encoding:.ascii),"WAVE")
  }
 }
}
