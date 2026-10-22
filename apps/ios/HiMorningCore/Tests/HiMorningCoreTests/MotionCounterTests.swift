import Foundation
#if !PORTABLE_TESTS
import XCTest
@testable import HiMorningCore
#endif

final class MotionCounterTests:XCTestCase {
 private func reachArms(width:Double=0.2,raised:Bool,imageWidth:Double=480,imageHeight:Double=640)->[BodyJoint:JointSample] {
  let elbowY=0.55-width*imageWidth/imageHeight*(raised ? 0.05:0.75)
  let reach=raised ? 0.95:0.6
  return [
   .leftShoulder:.init(x:0.5-width/2,y:0.55,confidence:0.95),
   .rightShoulder:.init(x:0.5+width/2,y:0.55,confidence:0.95),
   .leftElbow:.init(x:0.5-width*reach,y:elbowY,confidence:0.95),
   .rightElbow:.init(x:0.5+width*reach,y:elbowY,confidence:0.95)
  ]
 }
 func testReachUpCountsRaisedArmsWithoutStartingOrFinishingLowered() {
  var progress=MovementChallengeProgress(kind:.stretching,target:3)
  for time in [0,50,100,119] {_=progress.observe(.stretch(overhead:true),timestampMs:time)}
  XCTAssertEqual(progress.completed,0)
  _=progress.observe(.stretch(overhead:true),timestampMs:120)
  XCTAssertEqual(progress.completed,1)
  for time in stride(from:200,through:3000,by:50) {_=progress.observe(.stretch(overhead:true),timestampMs:time)}
  XCTAssertEqual(progress.completed,1)
 }
 func testReachUpSlightlyLowerRaisedArmsCountQuicklyButSmallLiftsDoNot() {
  for heightBelowShoulder in [0.12,0.16,0.55] {
   var joints=reachArms(raised:true)
   let elbowY=0.55-heightBelowShoulder*0.2*480/640
   joints[.leftElbow] = .init(x:0.3,y:elbowY,confidence:0.8)
   joints[.rightElbow] = .init(x:0.7,y:elbowY,confidence:0.8)
   let pose=ReachUpGeometry.assess(joints,imageWidth:480,imageHeight:640).pose
   XCTAssertEqual(pose,heightBelowShoulder<0.13 ? .raised:heightBelowShoulder>=0.4 ? .lowered:.transition)
   var progress=MovementChallengeProgress(kind:.stretching,target:3)
   for time in stride(from:0,through:1000,by:30) {_=progress.observe(pose.observation,timestampMs:time)}
   XCTAssertEqual(progress.completed,heightBelowShoulder<0.13 ? 1:0)
  }
 }
 func testReachUpRearmsOnlyAfterBothArmsAreLowered() {
  var progress=MovementChallengeProgress(kind:.stretching,target:3)
  for time in [0,150] {_=progress.observe(.stretch(overhead:true),timestampMs:time)}
  for time in [200,500] {_=progress.observe(.transition,timestampMs:time)}
  for time in [600,750] {_=progress.observe(.stretch(overhead:true),timestampMs:time)}
  XCTAssertEqual(progress.completed,1)
  _=progress.observe(.stretch(overhead:false),timestampMs:800)
  for time in [850,1000] {_=progress.observe(.stretch(overhead:true),timestampMs:time)}
  XCTAssertEqual(progress.completed,1)
  for time in [1100,1320] {_=progress.observe(.stretch(overhead:false),timestampMs:time)}
  XCTAssertEqual(progress.completed,1)
  for time in [1400,1550] {_=progress.observe(.stretch(overhead:true),timestampMs:time)}
  XCTAssertEqual(progress.completed,2)
 }
 func testReachUpTrackingLossAndInterruptCannotRecountHeldArms() {
  var progress=MovementChallengeProgress(kind:.stretching,target:3)
  for time in [0,150] {_=progress.observe(.stretch(overhead:true),timestampMs:time)}
  for time in [200,900] {_=progress.observe(.unavailable,timestampMs:time)}
  for time in [1000,1150] {_=progress.observe(.stretch(overhead:true),timestampMs:time)}
  progress.interrupt()
  for time in [1200,1350,4000,4150] {_=progress.observe(.stretch(overhead:true),timestampMs:time)}
  XCTAssertEqual(progress.completed,1)
  for time in [4200,4420] {_=progress.observe(.stretch(overhead:false),timestampMs:time)}
  for time in [4500,4650] {_=progress.observe(.stretch(overhead:true),timestampMs:time)}
  XCTAssertEqual(progress.completed,2)
 }
 func testReachUpRejectsRaisedSpikesAndStopsAtTarget() {
  var progress=MovementChallengeProgress(kind:.stretching,target:1)
  _=progress.observe(.stretch(overhead:true),timestampMs:0)
  _=progress.observe(.transition,timestampMs:33)
  _=progress.observe(.stretch(overhead:true),timestampMs:100)
  _=progress.observe(.unavailable,timestampMs:150)
  XCTAssertEqual(progress.completed,0)
  for time in [200,350] {_=progress.observe(.stretch(overhead:true),timestampMs:time)}
  XCTAssertTrue(progress.ready)
  for (raised,time) in [(false,400),(false,650),(true,700),(true,900)] {_=progress.observe(.stretch(overhead:raised),timestampMs:time)}
  XCTAssertEqual(progress.completed,1)
 }
 func testReachUpGeometryCountsRaisedUpperArmsWithoutWristsOrLowering() {
  for width in [0.1,0.2,0.34] {
   var progress=MovementChallengeProgress(kind:.stretching,target:1)
   for time in stride(from:0,through:150,by:50) {
    let pose=ReachUpGeometry.assess(reachArms(width:width,raised:true),imageWidth:480,imageHeight:640).pose
    _=progress.observe(pose.observation,timestampMs:time)
   }
   XCTAssertTrue(progress.ready)
  }
 }
 func testReachUpIgnoresCutOffLowerBodyAndDoesNotRequireAHead() {
  var joints=reachArms(raised:true)
  joints[.leftHip] = .init(x:0.35,y:0.01,confidence:0.9)
  joints[.rightAnkle] = .init(x:0.65,y:-0.4,confidence:0.9)
  XCTAssertEqual(BodyFraming.hint(joints,needsFeet:false),.stepBack)
  XCTAssertEqual(BodyFraming.upperBodyHint(joints),.ok)
  let assessment=ReachUpGeometry.assess(joints,imageWidth:480,imageHeight:640)
  XCTAssertEqual(assessment.pose,.raised);XCTAssertEqual(assessment.hint,.ok)
 }
 func testReachUpScalesToNearAndFarPeopleInPortraitAndLandscape() {
  for (width,height) in [(480.0,640.0),(640.0,480.0)] {
   for shoulderWidth in [0.1,0.2,0.34] {
    for raised in [false,true] {
     let joints=reachArms(width:shoulderWidth,raised:raised,imageWidth:width,imageHeight:height)
     let assessment=ReachUpGeometry.assess(joints,imageWidth:width,imageHeight:height)
     XCTAssertEqual(assessment.pose,raised ? .raised:.lowered);XCTAssertEqual(assessment.hint,.ok)
    }
   }
  }
 }
 func testReachUpWholeCyclesCountWithOnlyVisibleUpperBodyAtDifferentDistances() {
  for width in [0.1,0.2,0.34] {
   var progress=MovementChallengeProgress(kind:.stretching,target:3)
   for rep in 0..<3 {
    for (raised,start,end) in [(false,0,300),(true,400,1000),(false,1100,1400)] {
     for time in stride(from:start,through:end,by:50) {
      let assessment=ReachUpGeometry.assess(reachArms(width:width,raised:raised),imageWidth:480,imageHeight:640)
      _=progress.observe(assessment.pose.observation,timestampMs:rep*1600+time)
     }
    }
    XCTAssertEqual(progress.completed,rep+1)
   }
  }
 }
 func testReachUpOneArmAndSmallUpperArmLiftsNeverCount() {
  for oneArm in [false,true] {
   var progress=MovementChallengeProgress(kind:.stretching,target:3)
   for time in stride(from:0,through:4000,by:50) {
    var joints=reachArms(width:0.1,raised:false)
    if time>350 && time<3000 {
     let elbowY=oneArm ? 0.55:0.55-0.1*480/640*0.55+0.003*sin(Double(time))
     joints[.leftElbow] = .init(x:0.405,y:elbowY,confidence:0.95)
     if !oneArm {joints[.rightElbow] = .init(x:0.595,y:elbowY,confidence:0.95)}
    }
    let assessment=ReachUpGeometry.assess(joints,imageWidth:480,imageHeight:640)
    _=progress.observe(assessment.pose.observation,timestampMs:time)
   }
   XCTAssertEqual(progress.completed,0)
  }
 }
 func testReachUpAcceptsCloseUpperArmsNearImageEdgesWithModerateConfidence() {
  for confidence in [0.4,0.5,0.59] {
   var progress=MovementChallengeProgress(kind:.stretching,target:1)
   let joints:[BodyJoint:JointSample]=[
    .leftShoulder:.init(x:0.15,y:0.55,confidence:confidence),
    .rightShoulder:.init(x:0.85,y:0.55,confidence:confidence),
    .leftElbow:.init(x:0.008,y:0.58,confidence:confidence),
    .rightElbow:.init(x:0.992,y:0.58,confidence:confidence)
   ]
   let pose=ReachUpGeometry.assess(joints,imageWidth:480,imageHeight:640)
   XCTAssertEqual(pose.hint,.ok);XCTAssertEqual(pose.pose,.raised)
   for time in [0,50,100,150] {_=progress.observe(pose.pose.observation,timestampMs:time)}
   XCTAssertTrue(progress.ready)
  }
 }
 func testReachUpAcceptsForeshortenedUpperArmsWhileRejectingCollapsedJoints() {
  for offset in [0.01,0.045] {
   var joints=reachArms(width:0.3,raised:true)
   joints[.leftElbow] = .init(x:0.35-offset,y:0.55,confidence:0.8)
   joints[.rightElbow] = .init(x:0.65+offset,y:0.55,confidence:0.8)
   XCTAssertEqual(ReachUpGeometry.assess(joints,imageWidth:480,imageHeight:640).pose,offset<0.03 ? .unclear:.raised)
  }
 }
 func testReachUpCloseViewStillRequiresBothArmsAndRejectsWeakOrOffscreenJoints() {
  for joint in [BodyJoint.leftShoulder,.rightShoulder,.leftElbow,.rightElbow] {
   for sample:JointSample? in [nil,.init(x:0.1,y:0.6,confidence:0.39),.init(x:-0.01,y:0.6,confidence:0.9),.init(x:1.01,y:0.6,confidence:0.9)] {
    var joints=reachArms(raised:true);joints[joint]=sample
    var progress=MovementChallengeProgress(kind:.stretching,target:1)
    let assessment=ReachUpGeometry.assess(joints,imageWidth:480,imageHeight:640)
    XCTAssertEqual(assessment.pose,.unclear)
    for time in [0,150,300] {_=progress.observe(assessment.pose.observation,timestampMs:time)}
    XCTAssertEqual(progress.completed,0)
   }
  }
 }
 func testReachUpReportsMissingOrUncertainRequiredArms() {
  for joint in [BodyJoint.leftShoulder,.rightShoulder,.leftElbow,.rightElbow] {
   for sample:JointSample? in [nil,.init(x:0.5,y:0.7,confidence:0.2),.init(x:0,y:0.7,confidence:0.95),.init(x:.nan,y:0.7,confidence:0.95)] {
    var joints=reachArms(raised:true);joints[joint]=sample
    let assessment=ReachUpGeometry.assess(joints,imageWidth:480,imageHeight:640)
    XCTAssertEqual(assessment.pose,.unclear);XCTAssertEqual(assessment.hint,.showArms)
   }
  }
 }
 func testReachUpMissingElbowsCannotCompleteACycle() {
  var progress=MovementChallengeProgress(kind:.stretching,target:1)
  for time in stride(from:0,through:2400,by:50) {
   var joints=reachArms(raised:time>=400 && time<1800)
   if time>=400 && time<1800 {joints[.rightElbow]=nil}
   let assessment=ReachUpGeometry.assess(joints,imageWidth:480,imageHeight:640)
   _=progress.observe(assessment.pose.observation,timestampMs:time)
  }
  XCTAssertEqual(progress.completed,0)
 }
 func testReachUpRejectsUnresolvableBodyScaleAndInvalidImageSizes() {
  let far=ReachUpGeometry.assess(reachArms(width:0.02,raised:true),imageWidth:480,imageHeight:640)
  XCTAssertEqual(far.pose,.unclear);XCTAssertEqual(far.hint,.comeCloser)
  for size in [(0.0,640.0),(480.0,Double.nan),(Double.infinity,640.0)] {
   XCTAssertEqual(ReachUpGeometry.assess(reachArms(raised:true),imageWidth:size.0,imageHeight:size.1).pose,.unclear)
  }
 }
 func testReachUpIgnoresOffscreenOrUncertainWrists() {
  for raised in [false,true] {
   var joints=reachArms(raised:raised)
   joints[.leftWrist] = .init(x:-0.4,y:1.3,confidence:0.95)
   joints[.rightWrist] = .init(x:.nan,y:.nan,confidence:0)
   let assessment=ReachUpGeometry.assess(joints,imageWidth:480,imageHeight:640)
   XCTAssertEqual(assessment.pose,raised ? .raised:.lowered)
   XCTAssertEqual(assessment.hint,.ok)
  }
 }
 func testReachUpUsesTheShoulderAxisWithATiltedCamera() {
  for raised in [false,true] {
   for angle in [-0.45,0.45] {
    let points=reachArms(raised:raised).mapValues {joint in
     let x=(joint.x-0.5)*480,y=(joint.y-0.5)*640
     return JointSample(x:0.5+(x*cos(angle)-y*sin(angle))/480,y:0.5+(x*sin(angle)+y*cos(angle))/640,confidence:joint.confidence)
    }
    XCTAssertEqual(ReachUpGeometry.assess(points,imageWidth:480,imageHeight:640).pose,raised ? .raised:.lowered)
   }
  }
 }
 func testReachUpShoulderShrugsAndWholeBodyMovementNeverCount() {
  for shrug in [false,true] {
   var progress=MovementChallengeProgress(kind:.stretching,target:1)
   for time in stride(from:0,through:4000,by:50) {
    let shift=0.02*sin(Double(time)/200)
    let points=reachArms(raised:false).mapValues {joint in
     JointSample(x:joint.x,y:joint.y+shift,confidence:joint.confidence)
    }
    var moved=points
    if shrug {
     for name in [BodyJoint.leftElbow,.rightElbow] {moved[name]=reachArms(raised:false)[name]}
    }
    _=progress.observe(ReachUpGeometry.assess(moved,imageWidth:480,imageHeight:640).pose.observation,timestampMs:time)
   }
   XCTAssertEqual(progress.completed,0)
  }
 }
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
  for t in stride(from:0,through:durationMs,by:spacingMs) {counter.observe(centerX:centerX(hz:hz,amplitude:amplitude,at:t),centerY:0,handWidth:100,timestampMs:t)}
  return counter
 }
 private func readyIndex(lossFromMs:Int,lossToMs:Int)->Int? {
  var counter=WaveCounter(target:3),observed=0
  for t in stride(from:0,through:3_000,by:33) {
   if (lossFromMs..<lossToMs).contains(t) {counter.observeLoss(timestampMs:t);continue}
   observed+=1
   counter.observe(centerX:centerX(hz:2,amplitude:1,at:t),centerY:0,handWidth:100,timestampMs:t)
   if counter.ready {return observed}
  }
  return nil
 }
 func testTwoHertzWaveCountsAtThirtyAndSevenFramesPerSecond() {
  XCTAssertTrue(wave(hz:2,amplitude:1,spacingMs:33,durationMs:3_000).ready)
  XCTAssertTrue(wave(hz:2,amplitude:1,spacingMs:133,durationMs:3_000).ready)
 }
 func testComfortableHorizontalWaveCountsAtBothFrameRates() {
  for spacing in [33,133] {
   XCTAssertTrue(wave(hz:1.2,amplitude:0.40,spacingMs:spacing,durationMs:5_000).ready)
  }
 }
 func testRelaxedHeadTurnsCountWithoutLongPauses() {
  for direction in [-1.0,1.0] {
   var counter=NeckTurnCounter(target:1),t=0
   for yaw in [0.0,30*direction,0,-30*direction,0] {
    t=neckFeed(&counter,yaw,ms:264,from:t)
   }
   XCTAssertEqual(counter.completed,1)
  }
 }
 func testFourHertzWaveAtThirtyFramesCounts() {
  XCTAssertEqual(wave(hz:4,amplitude:0.6,spacingMs:33,durationMs:2_000).completed,3)
 }
 func testJitterNeverCounts() {
  var counter=WaveCounter(target:1)
  for (index,t) in stride(from:0,through:5_000,by:33).enumerated() {counter.observe(centerX:100+(index%2==0 ? 10:-10),centerY:0,handWidth:100,timestampMs:t)}
  XCTAssertEqual(counter.completed,0)
 }
 func testSmallSideToSideFidgetNeverCountsAsAWave() {
  var counter=WaveCounter(target:10)
  for t in stride(from:0,through:5_000,by:33) {
   counter.observe(centerX:centerX(hz:1,amplitude:0.30,at:t),centerY:0,handWidth:100,timestampMs:t)
  }
  XCTAssertEqual(counter.completed,0)
 }
 func testLiftingAndSettlingTheHandNeverCounts() {
  for spacing in [33,133] {
   var counter=WaveCounter(target:10)
   for t in stride(from:0,through:3_000,by:spacing) {
    let lift=min(1,max(0,Double(t-400)/600))
    let settle=min(1,max(0,Double(t-1_400)/600))
    counter.observe(centerX:100+80*lift-80*settle,centerY:100+180*lift,handWidth:100,timestampMs:t)
   }
   XCTAssertEqual(counter.completed,0)
  }
 }
 func testHandEnteringTheFrameCannotCompleteAWave() {
  var counter=WaveCounter(target:10)
  for t in stride(from:0,through:1_500,by:33) {
   let x=t<200 ? 100+100*sin(2 * .pi*Double(t)/200):100
   counter.observe(centerX:x,centerY:100,handWidth:100,timestampMs:t)
  }
  XCTAssertEqual(counter.completed,0)
 }
 func testHorizontalWaveWithASmallVerticalArcStillCounts() {
  for spacing in [33,133] {
   var counter=WaveCounter(target:3)
   for t in stride(from:0,through:4_000,by:spacing) {
    let phase=2 * .pi*1.2*Double(t)/1_000
    counter.observe(centerX:200+80*sin(phase),centerY:200+12*cos(phase),handWidth:100,timestampMs:t)
   }
   XCTAssertTrue(counter.ready)
  }
 }
 func testDeliberateWavesStillCountAfterLiftingTheHand() {
  var counter=WaveCounter(target:3)
  for t in stride(from:0,through:1_000,by:33) {
   let lift=min(1,Double(t)/600)
   counter.observe(centerX:100+80*lift,centerY:100+180*lift,handWidth:100,timestampMs:t)
  }
  XCTAssertEqual(counter.completed,0)
  for t in stride(from:1_033,through:5_500,by:33) {
   let phase=2 * .pi*1.2*Double(t-1_033)/1_000
   counter.observe(centerX:180+80*sin(phase),centerY:280+10*cos(phase),handWidth:100,timestampMs:t)
  }
  XCTAssertTrue(counter.ready)
 }
 private func completedAfterFourSwings(gapMs:Int)->Int {
  var counter=WaveCounter(target:10)
  counter.observe(centerX:100,centerY:0,handWidth:100,timestampMs:0)
  for swing in 0..<4 {
   let start=swing*gapMs+gapMs,from=swing%2==0 ? 100.0:200.0,to=swing%2==0 ? 200.0:100.0
   for step in 1...4 {counter.observe(centerX:from+(to-from)*Double(step)/4,centerY:0,handWidth:100,timestampMs:start+step*33)}
   for hold in 1...5 {counter.observe(centerX:to,centerY:0,handWidth:100,timestampMs:start+132+hold*100)}
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
  // A stricter travel gate can require the next half swing (250 ms / about eight frames at 2 Hz).
  XCTAssertTrue(abs((withLoss ?? 0)-(baseline ?? 0))<=8)

  var counter=WaveCounter(target:3)
  for t in stride(from:0,through:100,by:33) {counter.observe(centerX:centerX(hz:2,amplitude:1,at:t),centerY:0,handWidth:100,timestampMs:t)}
  for t in stride(from:133,through:933,by:100) {counter.observeLoss(timestampMs:t)}
  for t in stride(from:1_000,through:1_100,by:33) {counter.observe(centerX:centerX(hz:2,amplitude:1,at:t),centerY:0,handWidth:100,timestampMs:t)}
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
  counter.observe(centerX:1e300,centerY:0,handWidth:1e-300,timestampMs:0)
  for t in stride(from:33,through:3_000,by:33) {counter.observe(centerX:centerX(hz:2,amplitude:1,at:t),centerY:0,handWidth:100,timestampMs:t)}
  XCTAssertTrue(counter.ready)
 }
 private func staticHandCompleted(widthAt:(Int)->Double)->Int {
  var counter=WaveCounter(target:3)
  for t in stride(from:0,through:6_000,by:33) {counter.observe(centerX:240,centerY:0,handWidth:widthAt(t),timestampMs:t)}
  return counter.completed
 }
 func testStaticHandWithChangingWidthNeverCounts() {
  XCTAssertEqual(staticHandCompleted(widthAt:{t in 66+6*sin(2 * .pi*Double(t)/1_000)}),0)
  XCTAssertEqual(staticHandCompleted(widthAt:{t in 67.5+7.5*sin(2 * .pi*0.7*Double(t)/1_000)}),0)
 }
 func testWaveCountsAnywhereInFrameWhileHandWidthChanges() {
  for base in [80.0,240,400] {
   var counter=WaveCounter(target:3)
   for t in stride(from:0,through:3_000,by:33) {
    let seconds=Double(t)/1_000
    counter.observe(centerX:base+40*sin(2 * .pi*2*seconds),centerY:0,handWidth:66+6*sin(2 * .pi*1.3*seconds),timestampMs:t)
   }
   XCTAssertTrue(counter.ready)
  }
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
 func testSmallHeadTurnsNeverCount() {
  var counter=NeckTurnCounter(target:1)
  for t in stride(from:0,through:6_000,by:33) {counter.observe(yawDegrees:15*sin(2 * .pi*Double(t)/1_000),timestampMs:t)}
  XCTAssertEqual(counter.completed,0)
 }
 func testMissingFaceFramesCannotConnectSeparateTurns() {
  var counter=NeckTurnCounter(target:1),t=0
  for yaw in [0.0,-35,0] {t=neckFeed(&counter,yaw,ms:400,from:t)}
  t+=2_000
  for yaw in [35.0,0] {t=neckFeed(&counter,yaw,ms:400,from:t)}
  XCTAssertEqual(counter.completed,0)
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
