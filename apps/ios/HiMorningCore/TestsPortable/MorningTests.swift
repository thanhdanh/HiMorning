import Foundation

private let morningNow=ISO8601DateFormatter().date(from:"2026-10-13T06:30:00+07:00")!
private var morningCalendar:Calendar {
 var value=Calendar(identifier:.gregorian)
 value.timeZone=TimeZone(identifier:"Asia/Ho_Chi_Minh")!
 return value
}
private func morningDate(_ value:String)->Date {ISO8601DateFormatter().date(from:value)!}
private func withMorningJournal(_ run:(inout MorningJournal,URL)throws->Void) throws {
 let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
 defer {try? FileManager.default.removeItem(at:root)}
 let url=root.appendingPathComponent("morning.json")
 var journal=try MorningJournal(url:url)
 try run(&journal,url)
}

func runMorningTests() throws {
 // Rehearsals and duplicate callbacks must not manufacture successful mornings.
 try withMorningJournal {journal,_ in
  let confirmed=MorningEntry(date:morningNow,outcome:.selfConfirmed)
  XCTAssertEqual(try journal.record(confirmed,rehearsal:true,now:morningNow,calendar:morningCalendar), false)
  XCTAssertEqual(try journal.record(confirmed,now:morningNow,calendar:morningCalendar), true)
  XCTAssertEqual(try journal.record(confirmed,now:morningNow,calendar:morningCalendar), false)
  XCTAssertEqual(try journal.record(MorningEntry(date:morningNow,outcome:.openaiVerified),now:morningNow,calendar:morningCalendar), true)
  XCTAssertEqual(try journal.record(MorningEntry(date:morningNow,outcome:.dismissed),now:morningNow,calendar:morningCalendar), true)
  XCTAssertEqual(journal.completedDays(inLast:7,now:morningNow,calendar:morningCalendar),1)
  XCTAssertEqual(journal.entries.count,3)
 }
 // Use local calendar days, exclude future evidence, retain at most 30 days.
 try withMorningJournal {journal,_ in
  for timestamp in ["2026-09-10T06:00:00+07:00","2026-09-20T06:00:00+07:00","2026-10-06T06:00:00+07:00","2026-10-07T00:00:00+07:00","2026-10-13T06:00:00+07:00"] {
   _=try journal.record(MorningEntry(date:morningDate(timestamp),outcome:.selfConfirmed),now:morningNow,calendar:morningCalendar)
  }
  XCTAssertEqual(try journal.record(MorningEntry(date:morningNow.addingTimeInterval(1),outcome:.selfConfirmed),now:morningNow,calendar:morningCalendar), false)
  XCTAssertEqual(journal.recent(days:7,now:morningNow,calendar:morningCalendar).count,2)
  XCTAssertEqual(journal.recent(days:30,now:morningNow,calendar:morningCalendar).count,4)
  XCTAssertTrue(journal.recent(days:0,now:morningNow,calendar:morningCalendar).isEmpty)
  XCTAssertTrue(journal.recent(days:31,now:morningNow,calendar:morningCalendar).isEmpty)
 }
 // Downgrading changes access, without deleting history or the saved goal.
 try withMorningJournal {journal,url in
  try journal.setWeeklyGoal(5)
  _=try journal.record(MorningEntry(date:morningDate("2026-09-20T06:00:00+07:00"),outcome:.openaiVerified),now:morningNow,calendar:morningCalendar)
  let restored=try MorningJournal(url:url)
  XCTAssertEqual(MorningAccess.free.historyDays,7)
  XCTAssertEqual(MorningAccess.pro.historyDays,30)
  XCTAssertEqual(MorningAccess.free.weeklyGoal(stored:restored.weeklyGoal),3)
  XCTAssertEqual(MorningAccess.pro.weeklyGoal(stored:restored.weeklyGoal),5)
  XCTAssertEqual(restored.recent(days:30,now:morningNow,calendar:morningCalendar).first?.outcome,.openaiVerified)
  XCTAssertThrowsError(try journal.setWeeklyGoal(0))
  XCTAssertThrowsError(try journal.setWeeklyGoal(8))
  XCTAssertEqual(journal.weeklyGoal,5)
  try journal.clear()
  XCTAssertEqual(try MorningJournal(url:url).entries.isEmpty, true)
 }
 // Corrupt storage pauses changes; it is never silently reset.
 try withMorningJournal {journal,url in
  _=try journal.record(MorningEntry(date:morningNow,outcome:.selfConfirmed),now:morningNow,calendar:morningCalendar)
  let corrupt=Data("broken".utf8)
  try corrupt.write(to:url)
  XCTAssertThrowsError(try MorningJournal(url:url))
  XCTAssertEqual(try Data(contentsOf:url),corrupt)
 }
 // A failed write must not change the in-memory record or weekly goal.
 try withMorningJournal {journal,url in
  try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
  try Data("not a directory".utf8).write(to:url.deletingLastPathComponent().appendingPathComponent("blocked"))
  var blocked=try MorningJournal(url:url.deletingLastPathComponent().appendingPathComponent("blocked/morning.json"))
  XCTAssertThrowsError(try blocked.record(MorningEntry(date:morningNow,outcome:.selfConfirmed),now:morningNow,calendar:morningCalendar))
  XCTAssertThrowsError(try blocked.setWeeklyGoal(5))
  XCTAssertTrue(blocked.entries.isEmpty)
  XCTAssertEqual(blocked.weeklyGoal,3)
 }
}
