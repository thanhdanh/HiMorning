import Foundation
// Portable assertions for Command Line Tools hosts without XCTest.
func XCTAssertTrue(_ value: @autoclosure () -> Bool) { precondition(value()) }
func XCTAssertFalse(_ value: @autoclosure () -> Bool) { precondition(!value()) }
func XCTAssertEqual<T: Equatable>(_ a: T, _ b: T) { precondition(a == b, "Expected \(a) == \(b)") }
func XCTAssertNil<T>(_ value: T?) { precondition(value == nil) }
func XCTAssertGreaterThan<T: Comparable>(_ a: T, _ b: T) { precondition(a > b) }
func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T) { do { _ = try expression(); preconditionFailure("Expected error") } catch {} }
func XCTAssertNoThrow<T>(_ expression: @autoclosure () throws -> T) { do { _ = try expression() } catch { preconditionFailure("Unexpected error: \(error)") } }
class XCTestCase {}
func XCTAssertEqual(_ a:Double,_ b:Double,accuracy:Double) {precondition(abs(a-b)<=accuracy)}
func XCTAssertNotNil<T>(_ value:T?,_ message:String="") {precondition(value != nil,message)}
func XCTUnwrap<T>(_ value:T?) throws ->T {guard let value else {preconditionFailure("Expected a value")};return value}
actor FakeScheduler: AlarmScheduler {
 var ids:Set<UUID>=[]
 var shouldFail=false
 var stops=0
 func schedule(_ alarm:SavedAlarm) async throws { if shouldFail {throw DomainError.invalidAlarmTime};ids.insert(alarm.id) }
 func cancel(id:UUID) async throws {ids.remove(id)}
 func stop(id:UUID) async throws {stops+=1}
 func scheduledIDs() async throws -> Set<UUID> {ids}
 func failNext() {shouldFail=true}
}
func testNativeLibrary() async throws {
 let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
 defer {try? FileManager.default.removeItem(at:dir)}
 try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
 let persistence=FileAlarmPersistence(url:dir.appendingPathComponent("alarms.json"))
 let scheduler=FakeScheduler()
 let library=try AlarmLibrary(persistence:persistence,scheduler:scheduler)
 let alarm=SavedAlarm(time:try AlarmTime(hour:6,minute:30,weekdays:[2,3,4,5,6]),mode:.gentle,sound:.sunrise)
 try await library.add(alarm)
 let saved=await library.all();XCTAssertEqual(saved.first?.state,.confirmed)
 let restarted=try AlarmLibrary(persistence:persistence,scheduler:scheduler)
 let restored=await restarted.all();XCTAssertEqual(restored.first?.id,alarm.id)
 try await library.disable(id:alarm.id)
 let disabled=await library.all();XCTAssertEqual(disabled.first?.state,.off)
 try await library.enable(id:alarm.id)
 let enabled=await library.all();XCTAssertEqual(enabled.first?.state,.confirmed)
 try await library.remove(id:alarm.id)
 let removed=await library.all();XCTAssertTrue(removed.isEmpty)
 await scheduler.failNext()
 do {try await library.add(SavedAlarm(time:alarm.time,mode:.balanced,sound:.system));preconditionFailure("Expected schedule failure")} catch {}
 let failed=await library.all();XCTAssertEqual(failed.last?.state,.needsReview)
 try await library.reconcile()
}
func testAlarmLabelAndOccurrencePersistence() async throws {
 let time=try AlarmTime(hour:7,minute:15,weekdays:[])
 let alarm=SavedAlarm(time:time,mode:.gentle,label:"  Morning  ")
 XCTAssertEqual(alarm.label,"Morning")
 let occurrence=Date(timeIntervalSince1970:1_800_000_000)
 let tagged=SavedAlarm(time:time,mode:.focused,sound:.sunrise,challenge:.pushUps(repetitions:10),label:alarm.label,scheduledOccurrence:occurrence)
 let effective=MorningAccess.free.effectiveAlarm(tagged)
 XCTAssertEqual(effective.label,"Morning");XCTAssertEqual(effective.scheduledOccurrence,occurrence)
 let encoded=try JSONEncoder().encode(alarm)
 var object=try XCTUnwrap(JSONSerialization.jsonObject(with:encoded) as? [String:Any])
 object.removeValue(forKey:"label");object.removeValue(forKey:"scheduledOccurrence")
 let legacy=try JSONDecoder().decode(SavedAlarm.self,from:JSONSerialization.data(withJSONObject:object))
 XCTAssertEqual(legacy.label,"");XCTAssertNil(legacy.scheduledOccurrence)
 let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
 defer {try? FileManager.default.removeItem(at:directory)}
 let persistence=FileAlarmPersistence(url:directory.appendingPathComponent("alarms.json"))
 let scheduler=FakeScheduler();let library=try AlarmLibrary(persistence:persistence,scheduler:scheduler)
 try await library.add(alarm)
 let addedAlarms=await library.all();let added=try XCTUnwrap(addedAlarms.first)
 let anchor=try XCTUnwrap(added.scheduledOccurrence)
 var renamed=added;renamed.label="Morning routine"
 try await library.update(renamed)
 let metadataAlarms=await library.all();let metadataEdit=try XCTUnwrap(metadataAlarms.first)
 XCTAssertEqual(metadataEdit.scheduledOccurrence,anchor)
 let changedTime=try AlarmTime(hour:(time.hour+1)%24,minute:time.minute,weekdays:[])
 var changed=metadataEdit
 changed=SavedAlarm(id:changed.id,time:changedTime,mode:changed.mode,sound:changed.sound,challenge:changed.challenge,label:changed.label)
 let expectedBeforeUpdate=changedTime.next(after:Date(),calendar:.current)
 try await library.update(changed)
 let expectedAfterUpdate=changedTime.next(after:Date(),calendar:.current)
 let timeAlarms=await library.all();let timeEdit=try XCTUnwrap(timeAlarms.first)
 XCTAssertNotNil(timeEdit.scheduledOccurrence)
 XCTAssertTrue([expectedBeforeUpdate,expectedAfterUpdate].contains(timeEdit.scheduledOccurrence))
 try await library.disable(id:alarm.id);try await library.enable(id:alarm.id)
 let enabledAlarms=await library.all();let enabled=try XCTUnwrap(enabledAlarms.first)
 XCTAssertNotNil(enabled.scheduledOccurrence)
 let reloaded=try AlarmLibrary(persistence:persistence,scheduler:scheduler)
 let reloadedAlarms=await reloaded.all();XCTAssertEqual(reloadedAlarms.first?.label,"Morning routine")
}
func testCaptureSelectsCompleteCyclesAndDiscardsInterruptedEvidence() {
 var capture=CycleCapture(target:1)
 for (i,angle) in [165.0,120,80,120,165].enumerated() {capture.observe(angle:angle,visible:true,jpeg:Data([UInt8(i+1)]),timestampMs:i*300)}
 XCTAssertEqual(capture.completedReps,1);XCTAssertEqual(capture.frames.count,5);XCTAssertTrue(capture.ready)
 capture.observe(angle:165,visible:true,jpeg:Data([10]),timestampMs:1800)
 XCTAssertEqual(capture.frames.count,5)
 capture.clear();XCTAssertTrue(capture.frames.isEmpty)
 var interrupted=CycleCapture(target:1)
 interrupted.observe(angle:165,visible:true,jpeg:Data([1]),timestampMs:0)
 interrupted.observe(angle:120,visible:true,jpeg:Data([2]),timestampMs:300)
 interrupted.observe(angle:80,visible:false,jpeg:Data([3]),timestampMs:600)
 interrupted.observe(angle:165,visible:true,jpeg:Data([4]),timestampMs:900)
 XCTAssertEqual(interrupted.completedReps,0);XCTAssertTrue(interrupted.frames.isEmpty)
 var oversize=EvidenceBuffer()
 XCTAssertFalse(oversize.append(Data(repeating:1,count:50001),timestampMs:0))
}
func testMovementRequiresStableOrderedPoses() {
 var still=MovementChallengeProgress(kind:.jumpingJacks,target:1)
 for timestamp in stride(from:0,through:3_000,by:300) {_ = still.observe(.jumpingJack(open:true),timestampMs:timestamp)}
 XCTAssertEqual(still.completed,0)
 var capture=MovementChallengeProgress(kind:.jumpingJacks,target:1)
 for (open,time) in [(false,0),(false,300),(true,600),(true,900)] {_ = capture.observe(.jumpingJack(open:open),timestampMs:time)}
 _ = capture.observe(.unavailable,timestampMs:1_200)
 for (open,time) in [(false,1_500),(false,1_800),(true,2_100),(true,2_400),(false,2_700),(false,3_000)] {_ = capture.observe(.jumpingJack(open:open),timestampMs:time)}
 XCTAssertEqual(capture.completed,1)
 var partial=MovementChallengeProgress(kind:.jumpingJacks,target:1)
 for (open,time) in [(false,0),(false,300)] {_ = partial.observe(.jumpingJack(open:open),timestampMs:time)}
 for time in [600,900] {_ = partial.observe(.transition,timestampMs:time)}
 for (open,time) in [(true,1_200),(true,1_500),(false,1_800),(false,2_100)] {_ = partial.observe(.jumpingJack(open:open),timestampMs:time)}
 XCTAssertEqual(partial.completed,1)
}
func testBriefTrackingLossKeepsProgressWhileSustainedLossResets() {
 var brief=MovementChallengeProgress(kind:.jumpingJacks,target:1)
 for (open,time) in [(false,0),(false,300),(true,600),(true,900)] {_ = brief.observe(.jumpingJack(open:open),timestampMs:time)}
 _ = brief.observe(.unavailable,timestampMs:1_000)
 _ = brief.observe(.unavailable,timestampMs:1_100)
 for (open,time) in [(false,1_200),(false,1_500)] {_ = brief.observe(.jumpingJack(open:open),timestampMs:time)}
 XCTAssertEqual(brief.completed,1)

 var sustained=MovementChallengeProgress(kind:.jumpingJacks,target:1)
 for (open,time) in [(false,0),(false,300),(true,600),(true,900)] {_ = sustained.observe(.jumpingJack(open:open),timestampMs:time)}
 _ = sustained.observe(.unavailable,timestampMs:1_000)
 _ = sustained.observe(.unavailable,timestampMs:1_700)
 for (open,time) in [(false,2_000),(false,2_300)] {_ = sustained.observe(.jumpingJack(open:open),timestampMs:time)}
 XCTAssertEqual(sustained.completed,0)

}
func testPersistedTimeCannotBypassValidation() {
 XCTAssertThrowsError(try JSONDecoder().decode(AlarmTime.self,from:Data(#"{"hour":24,"minute":30,"weekdays":[]}"#.utf8)))
}
actor FakeCloud: CloudVerification {
 var continuation:CheckedContinuation<CloudDecision,Error>?
 var started:CheckedContinuation<Void,Never>?
 var cancelled=false
 var creates=0
 var targets:[Int]=[]
 func create(target:Int,requestID:UUID) async throws -> CloudSession {creates+=1;targets.append(target);return CloudSession(sessionID:String(repeating:"a",count:64),nonce:UUID().uuidString,expiresAt:Date().addingTimeInterval(120).timeIntervalSince1970*1000)}
 func verify(_ request:VerificationSubmission) async throws -> CloudDecision {
  return try await withCheckedThrowingContinuation {continuation=$0;started?.resume();started=nil}
 }
 func waitStarted() async {if continuation != nil {return};await withCheckedContinuation {started=$0}}
 func getResult(sessionID:String,evidenceID:String) async throws ->CloudDecision {throw ChallengeError.cloudUnavailable}
 func cancel(sessionID:String) async throws {cancelled=true}
 func release() {continuation?.resume(returning:CloudDecision(status:"verified",decisionID:UUID().uuidString,verifiedRepCount:3));continuation=nil}
}
@MainActor func testLocalChallengePrivacyBoundariesAndExplicitPushUpTarget() async throws {
 let time=try AlarmTime(hour:6,minute:30,weekdays:[])
 let cloud=FakeCloud();let scheduler=FakeScheduler()
 let localSelections:[ChallengeSelection]=[.none,.readAndChoose,.guidedRhythm(variant:.standing),.readAloud,.init(kind:.riddle),.init(kind:.waveHand),.init(kind:.neckRotation),.init(kind:.jumpingJacks),.init(kind:.stretching)]
 for challenge in localSelections {
  let flow=ChallengeCoordinator(alarm:SavedAlarm(time:time,mode:.focused,challenge:challenge),cloud:cloud,scheduler:scheduler)
  do {try await flow.startCloud(consent:true);preconditionFailure("Local challenge must not create a cloud session")} catch {}
 }
 XCTAssertEqual(await cloud.creates,0)

 let local=ChallengeCoordinator(alarm:SavedAlarm(time:time,mode:.balanced,challenge:.readAndChoose),cloud:cloud,scheduler:scheduler)
 try await local.finish(.localCompleted)
 XCTAssertEqual(local.session.outcome,.localCompleted)
 XCTAssertEqual(await scheduler.stops,1)

 let localScheduler=FakeScheduler()
 for challenge in [ChallengeSelection(kind:.riddle),.init(kind:.waveHand),.init(kind:.neckRotation),.init(kind:.jumpingJacks),.init(kind:.stretching)] {
  let flow=ChallengeCoordinator(alarm:SavedAlarm(time:time,mode:challenge.kind.preferredMode,challenge:challenge),cloud:cloud,scheduler:localScheduler)
  try await flow.finish(.localCompleted)
  XCTAssertEqual(flow.session.outcome,.localCompleted)
 }
 XCTAssertEqual(await localScheduler.stops,5)

 for challenge in [ChallengeSelection.none,.pushUps(repetitions:2)] {
  let unsupported=ChallengeCoordinator(alarm:SavedAlarm(time:time,mode:.gentle,challenge:challenge),cloud:cloud,scheduler:scheduler)
  do {try await unsupported.finish(.localCompleted);preconditionFailure("Unsupported local completion") } catch {}
  XCTAssertNil(unsupported.session.outcome)
 }
 XCTAssertEqual(await scheduler.stops,1)

 let explicit=ChallengeCoordinator(alarm:SavedAlarm(time:time,mode:.gentle,challenge:.pushUps(repetitions:2)),cloud:cloud,scheduler:scheduler)
 try await explicit.startCloud(consent:true)
 XCTAssertEqual(await cloud.targets,[2])
}
@MainActor func testCloudStopRaceAndConsent() async throws {
 let cloud=FakeCloud();let scheduler=FakeScheduler()
 let alarm=SavedAlarm(time:try AlarmTime(hour:6,minute:30,weekdays:[]),mode:.balanced,challenge:.pushUps(repetitions:3))
 let flow=ChallengeCoordinator(alarm:alarm,cloud:cloud,scheduler:scheduler)
 do {try await flow.startCloud(consent:false);preconditionFailure("Consent required")} catch {}
 try await flow.startCloud(consent:true)
 try await flow.startCloud(consent:true)
 let creates=await cloud.creates;XCTAssertEqual(creates,1)
 let evidence=(0..<15).map {EvidenceFrame(jpeg:Data([UInt8($0+1)]),timestampMs:$0*300)}
 let pending=Task {try await flow.submit(evidence)}
 await cloud.waitStarted()
 try await flow.finish(.dismissed)
 await cloud.release()
 let applied=try await pending.value
 XCTAssertFalse(applied);XCTAssertEqual(flow.session.outcome,.dismissed)
 let cancelled=await cloud.cancelled;XCTAssertTrue(cancelled)
 let suspendedCloud=FakeCloud()
 let suspended=ChallengeCoordinator(alarm:alarm,cloud:suspendedCloud,scheduler:scheduler)
 try await suspended.startCloud(consent:true)
 let before=await scheduler.stops
 await suspended.suspend()
 let after=await scheduler.stops
 XCTAssertEqual(before,after);XCTAssertNil(suspended.session.outcome)
 let noCloud=ChallengeCoordinator(alarm:alarm,cloud:nil,scheduler:scheduler)
 do {try await noCloud.startCloud(consent:true);preconditionFailure("Missing backend")} catch {}
 try await noCloud.finish(.selfConfirmed);XCTAssertEqual(noCloud.session.outcome,.selfConfirmed)
}

let pushUps=PushUpTests()
pushUps.testCompleteCyclesCountOnceWithoutImages()
pushUps.testStandingBentBodyOcclusionAndStaleFramesCannotComplete()
pushUps.testSingleFrameElbowDipNeverCountsAsAPushUp()
pushUps.testShallowBendsNeverCountAsAPushUp()
pushUps.testFastDescentWithoutMiddleBandSamplesCounts()
pushUps.testBriefOcclusionKeepsTheRep()
pushUps.testLongOcclusionResets()
pushUps.testResumeAfterLongOcclusionWithoutHiddenSamplesResets()
pushUps.testTargetsAboveFiveAreKeptAndCompleted()
pushUps.testRepsKeepCountingUntilTheCameraLimit()
try await pushUps.testLocalCameraCompletionNeedsTheTargetAndNeverCallsCloud()
try await pushUps.testCameraCompletionAcceptsTheSelectedTargetAboveFive()
try await pushUps.testStopWinsWhileCameraCompletionIsWaitingForTheAlarm()
try await pushUps.testFailedNativeStopCannotRecordCameraSuccess()
let wakeEnforcement=WakeEnforcementTests()
try wakeEnforcement.testFireDatesAreFifteenRingsTwoMinutesApart()
try wakeEnforcement.testWindowEdges()
try wakeEnforcement.testResolvingOutcomeEndsTheWakeButDismissedDoesNot()
try await wakeEnforcement.testInMemoryResolutionEndsWakeAndCancelsBackups()
try wakeEnforcement.testSelfConfirmAvailableFiveMinutesAfterFirstRing()
try wakeEnforcement.testOneTimeAlarmWithoutConfirmedScheduleGetsNoFutureBackups()
try wakeEnforcement.testCompletedOneTimeAlarmDoesNotPlanTomorrowEvenBeforeReconcile()
try wakeEnforcement.testUnscheduledAndUnanchoredOneTimeAlarmsDoNotInventWake()
try await wakeEnforcement.testFailedCancellationRemainsDurableAndRetriesAfterRestart()
try await wakeEnforcement.testUncertainScheduleKeepsItsIDUntilCancellationCanBeRetried()
try await wakeEnforcement.testChangingSoundReplacesBackupRingsAtTheSameOccurrence()
try wakeEnforcement.testEarliestOverlappingWakeWins()
try await wakeEnforcement.testPlanSchedulesFifteenRingsForNextConfirmedOccurrence()
try await wakeEnforcement.testPlanIsIdempotentAcrossRestart()
try await wakeEnforcement.testDisablingAlarmCancelsItsRings()
try await wakeEnforcement.testResolveCancelsOnlyThatAlarmsRings()
try await wakeEnforcement.testLiveWakeKeepsRemainingRingsOnly()
try await wakeEnforcement.testScheduleFailureKeepsEarlierRingsAndReportsLimited()
try await wakeEnforcement.testResolveDuringPlanLeavesNoRingsForThatAlarm()
try await wakeEnforcement.testConcurrentPlansDoNotDuplicateRings()
try await wakeEnforcement.testCorruptRingFileIsMovedAsideAndEnforcementContinues()
try await wakeEnforcement.testSaveFailureBeforeSchedulingLeavesNothingScheduledOrStored()
try await wakeEnforcement.testScheduleFailureLeavesStoredEqualToScheduled()
try await wakeEnforcement.testLaterSaveFailureDoesNotOrphanTheRingThatWasNotPersisted()
let motionCounters=MotionCounterTests()
motionCounters.testOneEuroPassesConstantSignalUnchanged()
motionCounters.testOneEuroSuppressesJitterAtRest()
motionCounters.testOneEuroBetaReducesLagOnFastRamp()
motionCounters.testOneEuroResetsOnNonFinite()
motionCounters.testTwoHertzWaveCountsAtThirtyAndSevenFramesPerSecond()
motionCounters.testFourHertzWaveAtThirtyFramesCounts()
motionCounters.testOneEuroDerivativeUsesPreviousRawSample()
motionCounters.testWaveCounterTreatsOverflowingRatioAsLoss()
motionCounters.testStaticHandWithChangingWidthNeverCounts()
motionCounters.testWaveCountsAnywhereInFrameWhileHandWidthChanges()
motionCounters.testSmallHeadTurnsNeverCount()
motionCounters.testMissingFaceFramesCannotConnectSeparateTurns()
motionCounters.testLeftFirstAndRightFirstBothCount()
motionCounters.testSameSideTwiceDoesNotCount()
motionCounters.testNoiseAroundCentreNeverCountsATurn()
motionCounters.testFaceLostAtFullTurnStillCompletesOnReturn()
motionCounters.testHoldExpiresAfterLongLossAtTurn()
motionCounters.testLossNearCentreClearsAfterGrace()
motionCounters.testThreeRepsAtSevenFramesPerSecond()
motionCounters.testJitterNeverCounts()
motionCounters.testSmallSideToSideFidgetNeverCountsAsAWave()
motionCounters.testLiftingAndSettlingTheHandNeverCounts()
motionCounters.testHandEnteringTheFrameCannotCompleteAWave()
motionCounters.testHorizontalWaveWithASmallVerticalArcStillCounts()
motionCounters.testDeliberateWavesStillCountAfterLiftingTheHand()
motionCounters.testSwingsMoreThanTwoSecondsApartDoNotPair()
motionCounters.testBriefLossKeepsProgressAndLongLossClearsPendingSwing()
motionCounters.testFullBodyInFrameIsOk()
motionCounters.testNoJointsIsNoPerson()
motionCounters.testCutOffAtBottomEdgeSaysStepBack()
motionCounters.testMissingFeetAwayFromEdgeSaysShowFeet()
motionCounters.testSmallBodySaysComeCloser()
motionCounters.testUpperBodyOnlyIsOkWhenFeetNotNeeded()
let suite = CoreTests()
suite.testLanguageSelectionAndFallback()
suite.testPresetsAreGentleAndBounded()
try suite.testAlarmValidation()
try suite.testNextWeekdayInVietnamAndOneTimeTomorrow()
try suite.testSpringDSTDoesNotCreatePastAlarm()
suite.testStopInvalidatesPendingResponseAndDoesNotCountAsSuccess()
suite.testVerifiedResultCanOnlyApplyOnce()
suite.testFallbackAndSnoozeRemainExplicit()
suite.testEvidenceBufferNeverExceedsCap()
try suite.testChallengeDefaultsUseModeFloorsButRemainIndependent()
try suite.testHistoricalExplicitTargetsDecodeWithoutBeingRaised()
suite.testCaptureStoresFiftyCompleteCyclesWithinEvidenceBounds()
try suite.testSavedAlarmDecodesLegacyPayloadAndRoundTripsExplicitChallenge()
suite.testLocalCompletionInvalidatesPendingCloudResult()
suite.testRecognizedWordScoreUsesNormalizedTokenEditDistanceAndPassesAtEightyPercent()
suite.testGuidedRhythmSupportsStandingAndSeatedWithoutImageEvidence()
suite.testGuidedRhythmKeepsProgressThroughBriefOcclusion()
suite.testGuidedRhythmResetsAfterSustainedOcclusion()
suite.testGuidedTransitionsCannotBridgeUnheldPoses()
suite.testMissingCameraFramesCannotCompleteGuidedRhythm()
suite.testJacksAndStretchingRejectSpikesAndPartialCycles()
suite.testGuidedRhythmSingleFramePoseIsIgnored()
suite.testGuidedRhythmResetsOnOutOfOrderAndExpiredWindow()
try suite.testModeChallengeCatalogAndPreferredDefaults()
suite.testLocalMovementRequiresStableOrderedVisiblePoses()
let sounds=AlarmSoundTests()
sounds.testCatalogKeepsLegacyIDsAndAddsTwelveDistinctChoices()
try sounds.testEverySoundPersistsAndRestoresWithoutChangingTheSelection()
try sounds.testEveryCustomCatalogChoiceHasANonemptyWAVResource()
let editing=AlarmEditingTests()
try await editing.testEditingEnabledAlarmKeepsIdentityAndReschedulesItsNewSound()
try await editing.testEditingEnabledChallengePersistsWithoutNativeScheduling()
try await editing.testEditingChallengeParametersPersistsWithoutNativeScheduling()
try await editing.testEditingModeKeepsExplicitChallengeWithoutNativeScheduling()
try await editing.testSavingUnchangedAlarmDoesNotTouchNativeSchedule()
try await editing.testEditingChallengePreservesUncertainNativeState()
try await editing.testChallengeEditPersistenceFailureRollsBackWithoutNativeScheduling()
try await editing.testEditingOnlyTimeStillReschedulesNativeAlarm()
try await editing.testEditingDisabledAlarmKeepsItOffWithoutScheduling()
try await editing.testFailedEditKeepsPreviousSettingsAndCanBeRetried()
try await editing.testCancellationFailureKeepsWorkingAlarmAndDoesNotTryReplacement()
try await editing.testReplacementAndRestoreFailurePreservesPreviousSettingsForReview()
try await editing.testEditPersistenceFailureDoesNotRescheduleOrLoseOriginal()
try await editing.testPersistenceFailureAfterReschedulingKeepsNewSettingsForReview()
try await editing.testEditingUncertainDisabledAlarmDoesNotFalselyConfirmItIsOff()
try await editing.testConcurrentReconcileReportsBusyWhileOriginalCheckFinishesNormally()
let contentTests=ChallengeContentTests()
try contentTests.testStoreLoadsFixtureAndFiltersByLanguage()
try contentTests.testInvalidRemoteItemsAreDroppedAndBundledStays()
contentTests.testItemRulesRejectMalformedItems()
contentTests.testDuplicateTextIsDroppedPerLanguageIgnoringCaseAndPunctuation()
contentTests.testHistoryResetAvoidsTheImmediatelyPreviousPick()
try contentTests.testOlderCachedPackIsIgnored()
try contentTests.testNoRepeatWithinTwentyPicks()
try contentTests.testSmallPoolStillPicksAfterHistoryFills()
contentTests.testVietnameseKeepsToneMarksEnglishFolds()
let reading=ReadAloudTests()
reading.testFinishingRequiresMatchingWordsInsteadOfOnlySpeechLength()
reading.testFinishOrTimeoutCannotPassSilenceOrPartialSpeech()
reading.testACompleteReadingAtTimeoutCanFinishAndStopRejectsLateResults()
reading.testLongerSentencesAllowAnUnhurriedReading()
reading.testEmptyTargetCannotComplete()
reading.testLiveFeedbackDistinguishesCorrectWrongAndUnreadWords()
reading.testSkippedWordsDoNotShiftLaterMatches()
reading.testExtraAndRepeatedWordsLowerTheScore()
reading.testFinalFeedbackMarksUnreadWordsAsMissed()
reading.testLiveRecognitionRevisionsReplaceThePreviousWordAssessment()
reading.testAHighPartialScoreDoesNotAutoFinishBeforeTheLastWords()
reading.testSilenceAndUnrelatedSpeechNeverReceiveCorrectWordFeedback()
let preview=PreviewTests()
preview.testPreviewStartsOnceAndExpiresAtExactlyThirtyDays()
try preview.testClockRollbackCannotRestoreExpiredPreviewAfterRelaunch()
preview.testPreviewAndProUnlockAllCapabilities()
try preview.testFreeKeepsBasicAlarmCapabilitiesWithoutChangingSavedPreferences()
preview.testPaidVerificationNeverReturnsPreview()
preview.testAccessPreservesExplicitLocalChallengesAndCapsOnlyFreePushUps()
try preview.testEffectiveAlarmPreservesIdentityStateAndSavedPreferences()
 try await CloudTests().testFiftyRepSubmissionAcceptsTwoHundredFiftyBoundedFramesAndRejectsOverflow()
try await CloudTests().testCompletedChallengeRetriesDoNotStopTheAlarmAgainOrReplaceItsJournalEntry()
 try await CloudTests().testRestartDuringCancellationKeepsTheNewSessionAndConsent()
try await CloudTests().testColdStartPollsWithoutResubmittingAndRecordsNeutralSuccess()
try await CloudTests().testStopCancelsSleepingPollWithoutWaitingForItsNextInterval()
try await CloudTests().testPollingDeadlineCancelsRemoteJobAndNeverMarksSuccess()
try CloudTests().testBothHistoricalAndNewVerifiedOutcomesDecodeWithoutMigration()
try RemoteDemoTests().testEndpointRejectsUntrustedURLs()
try RemoteDemoTests().testGeneratedFramesShareTheServerFixtureAndBounds()
try await RemoteDemoTests().testDemoCannotStopAnAlarmOrRecordVerifiedEvenWithAMaliciousSuccess()
try await testNativeLibrary()
try await testAlarmLabelAndOccurrencePersistence()
testCaptureSelectsCompleteCyclesAndDiscardsInterruptedEvidence()
testMovementRequiresStableOrderedPoses()
testBriefTrackingLossKeepsProgressWhileSustainedLossResets()
testPersistedTimeCannotBypassValidation()
try await testCloudStopRaceAndConsent()
try await testLocalChallengePrivacyBoundariesAndExplicitPushUpTarget()
func testSharedMobileFixtures() throws {
 let root=URL(fileURLWithPath:CommandLine.arguments[1])
 let data=try Data(contentsOf:root.appendingPathComponent("wire-fixtures.json"))
 let wire=try JSONSerialization.jsonObject(with:data) as! [String:Any]
 let session=try JSONDecoder().decode(CloudSession.self,from:JSONSerialization.data(withJSONObject:wire["CreateResponse"]!))
 XCTAssertEqual(session.expiresAt,2000000000000)
 let decision=try JSONDecoder().decode(CloudDecision.self,from:JSONSerialization.data(withJSONObject:wire["Decision"]!))
 XCTAssertEqual(decision.status,"verified");XCTAssertEqual(decision.verifiedRepCount,1)
 let submission=wire["SubmitRequest"] as! [String:Any]
 let frames=submission["frames"] as! [[String:Any]]
 let evidence=frames.map {EvidenceFrame(jpeg:Data(base64Encoded:$0["jpegBase64"] as! String)!,timestampMs:$0["timestampMs"] as! Int)}
 let encoded=try JSONSerialization.jsonObject(with:JSONEncoder().encode(VerificationSubmission(session:session,evidenceID:UUID(uuidString:submission["evidenceID"] as! String)!,frames:evidence))) as! NSDictionary
 XCTAssertEqual(encoded,submission as NSDictionary)
 let modes=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("wake-modes.json"))) as! [String:[String:Int]]
 for mode in WakeMode.allCases {
  let expected=modes[mode.rawValue]!
  XCTAssertEqual(mode.policy.reps,expected["reps"]!)
  XCTAssertEqual(mode.policy.snoozes,expected["snoozes"]!)
 }
}
try testSharedMobileFixtures()

let scores=MorningScoreTests()
try scores.testTodayCompletionMatchesOnlySuccessfulAlarmAndSurvivesReload()
try scores.testTodayCompletionUsesLocalMidnightAndExcludesFuture()
try scores.testLegacyMorningEntriesKeepProgressWithoutGuessingAlarmIdentity()
try scores.testDayEntriesKeepRecordedModesAndChallengeTargetsAfterAlarmEditsAndReload()
scores.testOnlyCompletedChallengesEarnPointsAndEmptyIsUnrated()
scores.testRatingThresholds()
try scores.testWeekUsesLocalDaysAveragesAttemptsAndExcludesPracticeAndFuture()
try scores.testMonthRetainsDayOneThroughDayThirtyOneAndSurvivesReload()
try runMorningTests()
runSubscriptionPeriodTests()
print("PASS: shared Swift core tests and portable integration journeys")
