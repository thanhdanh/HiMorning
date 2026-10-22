import Foundation
#if !PORTABLE_TESTS
import XCTest
@testable import HiMorningCore
#endif

final class MotionCounterTests:XCTestCase {
 func testOneEuroPassesConstantSignalUnchanged() {
  var filter=OneEuroFilter(minCutoff:1.0,beta:0.3)
  for t in stride(from:0,through:1_000,by:33) {XCTAssertEqual(filter.filter(5,timestampMs:t),5,accuracy:0.000_001)}
 }
 func testOneEuroSuppressesJitterAtRest() {
  var filter=OneEuroFilter(minCutoff:1.0,beta:0.3)
  var peak=0.0
  for (index,t) in stride(from:0,through:2_000,by:33).enumerated() {
   let out=filter.filter(index%2==0 ? 1:-1,timestampMs:t)
   if t>=1_000 {peak=max(peak,abs(out))}
  }
  XCTAssertTrue(peak<0.5)
 }
 func testOneEuroBetaReducesLagOnFastRamp() {
  func final(beta:Double)->Double {
   var filter=OneEuroFilter(minCutoff:1.0,beta:beta)
   var out=0.0
   for t in stride(from:0,through:297,by:33) {out=filter.filter(10*Double(t)/300,timestampMs:t)}
   return out
  }
  XCTAssertGreaterThan(final(beta:0.3),final(beta:0))
 }
 func testOneEuroResetsOnNonFinite() {
  var filter=OneEuroFilter(minCutoff:1.0,beta:0.3)
  _ = filter.filter(3,timestampMs:0)
  XCTAssertTrue(filter.filter(.nan,timestampMs:33).isNaN)
  XCTAssertEqual(filter.filter(7,timestampMs:66),7,accuracy:0.000_001)
 }

 private func centerX(hz:Double,amplitude:Double,at t:Int)->Double {100+amplitude*100*sin(2 * .pi * hz * Double(t)/1_000)}
 private func wave(hz:Double,amplitude:Double,spacingMs:Int,durationMs:Int,target:Int=3)->WaveCounter {
  var counter=WaveCounter(target:target)
  for t in stride(from:0,through:durationMs,by:spacingMs) {counter.observe(centerX:centerX(hz:hz,amplitude:amplitude,at:t),handWidth:100,timestampMs:t)}
  return counter
 }
 private func readyIndex(lossFromMs:Int,lossToMs:Int)->Int? {
  var counter=WaveCounter(target:3),observed=0
  for t in stride(from:0,through:3_000,by:33) {
   if (lossFromMs..<lossToMs).contains(t) {counter.observeLoss(timestampMs:t);continue}
   observed+=1
   counter.observe(centerX:centerX(hz:2,amplitude:1,at:t),handWidth:100,timestampMs:t)
   if counter.ready {return observed}
  }
  return nil
 }
 func testTwoHertzWaveCountsAtThirtyAndSevenFramesPerSecond() {
  XCTAssertTrue(wave(hz:2,amplitude:1,spacingMs:33,durationMs:3_000).ready)
  XCTAssertTrue(wave(hz:2,amplitude:1,spacingMs:133,durationMs:3_000).ready)
 }
 func testFourHertzWaveAtThirtyFramesCounts() {
  XCTAssertTrue(wave(hz:4,amplitude:0.6,spacingMs:33,durationMs:2_000).ready)
 }
 func testJitterNeverCounts() {
  var counter=WaveCounter(target:1)
  for (index,t) in stride(from:0,through:5_000,by:33).enumerated() {counter.observe(centerX:100+(index%2==0 ? 10:-10),handWidth:100,timestampMs:t)}
  XCTAssertEqual(counter.completed,0)
 }
 private func completedAfterFourSwings(gapMs:Int)->Int {
  var counter=WaveCounter(target:10)
  counter.observe(centerX:100,handWidth:100,timestampMs:0)
  for swing in 0..<4 {
   let start=swing*gapMs+gapMs,from=swing%2==0 ? 100.0:150.0,to=swing%2==0 ? 150.0:100.0
   for step in 1...4 {counter.observe(centerX:from+(to-from)*Double(step)/4,handWidth:100,timestampMs:start+step*33)}
   for hold in 1...5 {counter.observe(centerX:to,handWidth:100,timestampMs:start+132+hold*100)}
  }
  return counter.completed
 }
 func testSwingsMoreThanTwoSecondsApartDoNotPair() {
  XCTAssertGreaterThan(completedAfterFourSwings(gapMs:1_000),0)
  XCTAssertEqual(completedAfterFourSwings(gapMs:2_500),0)
 }
 func testBriefLossKeepsProgressAndLongLossClearsPendingSwing() {
  let baseline=readyIndex(lossFromMs:Int.max,lossToMs:Int.max)
  let withLoss=readyIndex(lossFromMs:600,lossToMs:1_000)
  XCTAssertNotNil(baseline)
  XCTAssertNotNil(withLoss)
  XCTAssertTrue(abs((withLoss ?? 0)-(baseline ?? 0))<=3)

  var counter=WaveCounter(target:3)
  for t in stride(from:0,through:100,by:33) {counter.observe(centerX:centerX(hz:2,amplitude:1,at:t),handWidth:100,timestampMs:t)}
  for t in stride(from:133,through:933,by:100) {counter.observeLoss(timestampMs:t)}
  for t in stride(from:1_000,through:1_100,by:33) {counter.observe(centerX:centerX(hz:2,amplitude:1,at:t),handWidth:100,timestampMs:t)}
  XCTAssertEqual(counter.completed,0)
 }

 func testOneEuroDerivativeUsesPreviousRawSample() {
  let minCutoff=1.0,beta=0.5,derivativeCutoff=1.0
  var filter=OneEuroFilter(minCutoff:minCutoff,beta:beta,derivativeCutoff:derivativeCutoff)
  func alpha(_ cutoff:Double,_ dt:Double)->Double {1/(1+1/(2 * .pi * cutoff)/dt)}
  let samples:[Double]=[0,10,10,4]
  var lastRaw=0.0,smoothed=0.0,derivative=0.0
  for (index,sample) in samples.enumerated() {
   let t=index*33,actual=filter.filter(sample,timestampMs:t)
   if index>0 {
    let dt=0.033
    derivative+=alpha(derivativeCutoff,dt)*((sample-lastRaw)/dt-derivative)
    smoothed+=alpha(minCutoff+beta*abs(derivative),dt)*(sample-smoothed)
   }
   lastRaw=sample
   XCTAssertEqual(actual,smoothed,accuracy:0.000_001)
  }
 }
 func testWaveCounterTreatsOverflowingRatioAsLoss() {
  var counter=WaveCounter(target:3)
  counter.observe(centerX:1e300,handWidth:1e-300,timestampMs:0)
  for t in stride(from:33,through:3_000,by:33) {counter.observe(centerX:centerX(hz:2,amplitude:1,at:t),handWidth:100,timestampMs:t)}
  XCTAssertTrue(counter.ready)
 }

 private func neckFeed(_ counter:inout NeckTurnCounter,_ yaw:Double,ms:Int,from start:Int,step:Int=33)->Int {
  var t=start
  while t<start+ms {counter.observe(yawDegrees:yaw,timestampMs:t);t+=step}
  return t
 }
 private func neckLoss(_ counter:inout NeckTurnCounter,ms:Int,from start:Int)->Int {
  var t=start
  while t<start+ms {counter.observeLoss(timestampMs:t);t+=33}
  return t
 }
 private func neckSequence(_ yaws:[Double])->NeckTurnCounter {
  var counter=NeckTurnCounter(target:5),t=0
  for yaw in yaws {t=neckFeed(&counter,yaw,ms:300,from:t)}
  return counter
 }
 func testLeftFirstAndRightFirstBothCount() {
  XCTAssertEqual(neckSequence([0,-30,0,30,0]).completed,1)
  XCTAssertEqual(neckSequence([0,30,0,-30,0]).completed,1)
 }
 func testSameSideTwiceDoesNotCount() {
  XCTAssertEqual(neckSequence([0,-30,0,-30,0]).completed,0)
 }
 func testNoiseAroundCentreNeverCountsATurn() {
  var counter=NeckTurnCounter(target:1)
  for (index,t) in stride(from:0,to:3_000,by:33).enumerated() {counter.observe(yawDegrees:index%2==0 ? 10:-10,timestampMs:t)}
  XCTAssertEqual(counter.completed,0)
 }
 private func neckWithLoss(lossMs:Int)->Int {
  var counter=NeckTurnCounter(target:5),t=0
  t=neckFeed(&counter,0,ms:300,from:t)
  t=neckFeed(&counter,35,ms:300,from:t)
  t=neckLoss(&counter,ms:lossMs,from:t)
  for yaw in [0.0,-30,0] {t=neckFeed(&counter,yaw,ms:300,from:t)}
  return counter.completed
 }
 func testFaceLostAtFullTurnStillCompletesOnReturn() {
  XCTAssertEqual(neckWithLoss(lossMs:1_000),1)
 }
 func testHoldExpiresAfterLongLossAtTurn() {
  XCTAssertEqual(neckWithLoss(lossMs:1_700),0)
 }
 func testLossNearCentreClearsAfterGrace() {
  var counter=NeckTurnCounter(target:5),t=0
  t=neckFeed(&counter,0,ms:300,from:t)
  t=neckFeed(&counter,30,ms:300,from:t)
  t=neckFeed(&counter,10,ms:900,from:t)
  t=neckLoss(&counter,ms:700,from:t)
  for yaw in [0.0,-30,0] {t=neckFeed(&counter,yaw,ms:300,from:t)}
  XCTAssertEqual(counter.completed,0)
 }
 func testThreeRepsAtSevenFramesPerSecond() {
  var counter=NeckTurnCounter(target:3),t=0
  t=neckFeed(&counter,0,ms:400,from:t,step:133)
  for _ in 0..<3 {
   for yaw in [-30.0,0,30,0] {t=neckFeed(&counter,yaw,ms:400,from:t,step:133)}
  }
  XCTAssertTrue(counter.ready)
 }
 private func joints(_ ys:[BodyJoint:Double],x:Double=0.5,confidence:Double=0.9)->[BodyJoint:JointSample] {
  ys.mapValues {JointSample(x:x,y:$0,confidence:confidence)}
 }
 private let fullBody:[BodyJoint:Double]=[.nose:0.9,.leftShoulder:0.8,.rightShoulder:0.8,.leftHip:0.5,.rightHip:0.5,.leftKnee:0.3,.rightKnee:0.3,.leftAnkle:0.1,.rightAnkle:0.1]
 func testFullBodyInFrameIsOk() {
  XCTAssertEqual(BodyFraming.hint(joints(fullBody),needsFeet:true),.ok)
 }
 func testNoJointsIsNoPerson() {
  XCTAssertEqual(BodyFraming.hint([:],needsFeet:true),.noPerson)
  let weak=joints(fullBody,confidence:0.2)
  XCTAssertEqual(BodyFraming.hint(weak,needsFeet:false),.noPerson)
 }
 func testCutOffAtBottomEdgeSaysStepBack() {
  let body=joints([.nose:0.9,.leftShoulder:0.8,.rightShoulder:0.8,.leftKnee:0.01,.rightKnee:0.01])
  XCTAssertEqual(BodyFraming.hint(body,needsFeet:true),.stepBack)
 }
 func testMissingFeetAwayFromEdgeSaysShowFeet() {
  let body=joints([.nose:0.9,.leftShoulder:0.8,.rightShoulder:0.8,.leftHip:0.5,.rightHip:0.5,.leftKnee:0.3])
  XCTAssertEqual(BodyFraming.hint(body,needsFeet:true),.showFeet)
 }
 func testSmallBodySaysComeCloser() {
  let body=joints([.nose:0.6,.leftShoulder:0.5,.rightShoulder:0.5,.leftHip:0.35,.rightHip:0.35,.leftAnkle:0.35,.rightAnkle:0.35])
  XCTAssertEqual(BodyFraming.hint(body,needsFeet:true),.comeCloser)
 }
 func testUpperBodyOnlyIsOkWhenFeetNotNeeded() {
  let body=joints([.nose:0.9,.leftShoulder:0.75,.rightShoulder:0.75,.leftHip:0.45,.rightHip:0.45])
  XCTAssertEqual(BodyFraming.hint(body,needsFeet:false),.ok)
 }
}
