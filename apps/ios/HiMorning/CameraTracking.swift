import SwiftUI
import Vision
import AVFoundation

struct TrackedJoint:Sendable {
 let point:CGPoint
 let confidence:Float
 var visible:Bool {isVisible(minConfidence:0.6,edgeMargin:0.02)}
 func isVisible(minConfidence:Float,edgeMargin:CGFloat)->Bool {
  confidence.isFinite && confidence>=minConfidence && point.x.isFinite && point.y.isFinite &&
  point.x>edgeMargin && point.x<1-edgeMargin && point.y>edgeMargin && point.y<1-edgeMargin
 }
}

/// Only normalized geometry crosses into the UI. This contains no image or video data.
struct CameraTrackingSnapshot:Sendable {
 struct Segment:Sendable {
  enum Group:Sendable {case leftArm,rightArm,body,hand}
  let start:CGPoint
  let end:CGPoint
  let group:Group
 }
 var imageSize=CGSize(width:480,height:640)
 var segments:[Segment]=[]
 var joints:[CGPoint]=[]
 var headBox:CGRect?
 var faceMidline:[CGPoint]=[]
 var requiredJointsVisible=true
 var observedAt:TimeInterval=0
 static let empty=CameraTrackingSnapshot()
 var hasMarks:Bool {!joints.isEmpty || headBox != nil || !faceMidline.isEmpty}
 var hasRequiredMarks:Bool {hasMarks && requiredJointsVisible}
 func isFresh(at uptime:TimeInterval)->Bool {observedAt.isFinite && uptime>=observedAt && uptime-observedAt<=0.5}

 static func body(_ points:[VNHumanBodyPoseObservation.JointName:VNRecognizedPoint],imageSize:CGSize,minConfidence:Float=0.6,edgeMargin:CGFloat=0.02)->Self {
  body(points.mapValues {TrackedJoint(point:$0.location,confidence:$0.confidence)},imageSize:imageSize,uptime:ProcessInfo.processInfo.systemUptime,minConfidence:minConfidence,edgeMargin:edgeMargin)
 }
 static func body(_ points:[VNHumanBodyPoseObservation.JointName:TrackedJoint],imageSize:CGSize,uptime:TimeInterval,minConfidence:Float=0.6,edgeMargin:CGFloat=0.02)->Self {
  var result=Self(imageSize:imageSize,observedAt:uptime)
  typealias Joint=VNHumanBodyPoseObservation.JointName
  let chains:[([Joint],Segment.Group)]=[
   ([.leftShoulder,.leftElbow,.leftWrist],.leftArm),([.rightShoulder,.rightElbow,.rightWrist],.rightArm),
   ([.leftShoulder,.rightShoulder],.body),([.leftHip,.rightHip],.body),
   ([.neck,.root],.body),
   ([.leftShoulder,.leftHip,.leftKnee,.leftAnkle],.body),([.rightShoulder,.rightHip,.rightKnee,.rightAnkle],.body)
  ]
  for (chain,group) in chains {
   for index in 1..<chain.count {
    if let a=points[chain[index-1]],let b=points[chain[index]],a.isVisible(minConfidence:minConfidence,edgeMargin:edgeMargin),b.isVisible(minConfidence:minConfidence,edgeMargin:edgeMargin) {
     result.segments.append(.init(start:a.point,end:b.point,group:group))
    }
   }
  }
  let bodyNames=Set(chains.flatMap {$0.0})
  result.joints=bodyNames.compactMap {points[$0]}.filter {$0.isVisible(minConfidence:minConfidence,edgeMargin:edgeMargin)}.map(\.point)
  let faceNames:[Joint]=[.nose,.leftEye,.rightEye,.leftEar,.rightEar]
  let face=faceNames.compactMap {points[$0]}.filter(\.visible).map(\.point)
  // Require multiple independent facial landmarks, never invent a box from one nose point.
  if face.count>=3,imageSize.width>0,imageSize.height>0,
     let minX=face.map(\.x).min(),let maxX=face.map(\.x).max(),
     let minY=face.map(\.y).min(),let maxY=face.map(\.y).max(),maxX-minX>0.015 {
   let width=(maxX-minX)*1.5
   let height=max((maxY-minY)*2.2,width*imageSize.width/imageSize.height*1.15)
   let box=CGRect(x:(minX+maxX-width)/2,y:(minY+maxY-height)/2,width:width,height:height)
   result.headBox=box.intersection(CGRect(x:0,y:0,width:1,height:1))
  }
  return result
 }
 static func hand(_ points:[VNHumanHandPoseObservation.JointName:VNRecognizedPoint],imageSize:CGSize)->Self {
  var result=Self(imageSize:imageSize,observedAt:ProcessInfo.processInfo.systemUptime)
  let names:[VNHumanHandPoseObservation.JointName]=[.wrist,.indexMCP,.middleMCP,.ringMCP,.littleMCP]
  let visible=points.mapValues {TrackedJoint(point:$0.location,confidence:$0.confidence)}
  result.joints=names.compactMap {visible[$0]}.filter(\.visible).map(\.point)
  if let wrist=visible[.wrist],wrist.visible {
   for name in names.dropFirst() {
    if let point=visible[name],point.visible {result.segments.append(.init(start:wrist.point,end:point.point,group:.hand))}
   }
  }
  return result
 }
 static func face(_ face:VNFaceObservation?,imageSize:CGSize)->Self {
  guard let face else {return Self(imageSize:imageSize)}
  func points(_ region:VNFaceLandmarkRegion2D?)->[CGPoint] {
   guard let region else {return []}
   return Array(region.normalizedPoints)
  }
  return Self.face(box:face.boundingBox,confidence:face.confidence,
   landmarkConfidence:face.landmarks?.confidence ?? 0,
   medianLine:points(face.landmarks?.medianLine),contour:points(face.landmarks?.faceContour),
   imageSize:imageSize,uptime:ProcessInfo.processInfo.systemUptime)
 }
 static func face(box:CGRect,confidence:Float,landmarkConfidence:Float,medianLine:[CGPoint],contour:[CGPoint],imageSize:CGSize,uptime:TimeInterval)->Self {
  var result=Self(imageSize:imageSize,observedAt:uptime)
  guard confidence.isFinite,confidence>=0.6,
        [box.minX,box.minY,box.width,box.height].allSatisfy({$0.isFinite}),box.width>0,box.height>0 else {return result}
  let visibleBox=box.intersection(CGRect(x:0,y:0,width:1,height:1))
  guard !visibleBox.isNull,!visibleBox.isEmpty else {return result}
  result.headBox=visibleBox
  // A rectangle or yaw estimate alone cannot supply a measured face curve.
  guard landmarkConfidence.isFinite,landmarkConfidence>=0.6,medianLine.count>=3,contour.count>=5,
        (medianLine+contour).allSatisfy({$0.x.isFinite && $0.y.isFinite && (0...1).contains($0.x) && (0...1).contains($0.y)}),
        imageSize.width.isFinite,imageSize.height.isFinite,imageSize.width>0,imageSize.height>0 else {return result}
  // Vision orders the contour from cheek through chin to the other cheek.
  let chin=contour[contour.count/2]
  let width=box.width*imageSize.width,height=box.height*imageSize.height
  func distance(_ p:CGPoint)->CGFloat {pow((p.x-chin.x)*width,2)+pow((p.y-chin.y)*height,2)}
  guard let upper=medianLine.max(by:{distance($0)<distance($1)}),distance(upper)>16 else {return result}
  func heightAlongFace(_ p:CGPoint)->CGFloat {
   (p.x-chin.x)*(upper.x-chin.x)*width*width+(p.y-chin.y)*(upper.y-chin.y)*height*height
  }
  let ordered=medianLine.sorted {heightAlongFace($0)>heightAlongFace($1)}
  // Extend the measured upper midline toward the top of the face box; this is
  // a visual guide, not an independently detected skull or a counting input.
  let top=CGPoint(x:min(0.98,max(0.02,upper.x+(upper.x-chin.x)*0.2)),
                  y:min(0.98,max(0.02,upper.y+(upper.y-chin.y)*0.2)))
  let guide=([top]+ordered+[chin]).map {CGPoint(x:box.minX+$0.x*box.width,y:box.minY+$0.y*box.height)}
  guard guide.allSatisfy({(0...1).contains($0.x) && (0...1).contains($0.y)}) else {return result}
  result.faceMidline=guide
  return result
 }
}

/// Vision points already include the front-camera mirror and use a lower-left origin.
/// Match resizeAspect without applying a second mirror or stretching letterboxed video.
struct TrackingProjection {
 let imageSize:CGSize
 let bounds:CGRect
 var videoRect:CGRect {
  guard imageSize.width>0,imageSize.height>0,imageSize.width.isFinite,imageSize.height.isFinite else {return .zero}
  let scale=min(bounds.width/imageSize.width,bounds.height/imageSize.height)
  let size=CGSize(width:imageSize.width*scale,height:imageSize.height*scale)
  return CGRect(x:bounds.midX-size.width/2,y:bounds.midY-size.height/2,width:size.width,height:size.height)
 }
 func point(_ point:CGPoint)->CGPoint {
  let rect=videoRect
  return CGPoint(x:rect.minX+point.x*rect.width,y:rect.minY+(1-point.y)*rect.height)
 }
 func facePath(_ points:[CGPoint])->Path {
  let points=points.map {point($0)}
  var path=Path()
  guard points.count>=3,let first=points.first,let last=points.last else {return path}
  path.move(to:first)
  // Quadratic joins stay inside the landmark hull and avoid sharp zigzags.
  for index in 1..<points.count-1 {
   let current=points[index],next=points[index+1]
   path.addQuadCurve(to:CGPoint(x:(current.x+next.x)/2,y:(current.y+next.y)/2),control:current)
  }
  path.addQuadCurve(to:last,control:last)
  return path
 }

 func box(_ box:CGRect)->CGRect {
  let origin=point(CGPoint(x:box.minX,y:box.maxY)),rect=videoRect
  return CGRect(origin:origin,size:CGSize(width:box.width*rect.width,height:box.height*rect.height))
 }
}

struct CameraTrackingOverlay:View {
 let snapshot:CameraTrackingSnapshot
 var body:some View {
  Canvas {context,size in
   let projection=TrackingProjection(imageSize:snapshot.imageSize,bounds:CGRect(origin:.zero,size:size))
   for segment in snapshot.segments {
    var line=Path();line.move(to:projection.point(segment.start));line.addLine(to:projection.point(segment.end))
    let color:Color=switch segment.group {case .leftArm,.hand:.mint;case .rightArm:.cyan;case .body:.yellow}
    context.stroke(line,with:.color(.black.opacity(0.7)),style:.init(lineWidth:6,lineCap:.round))
    context.stroke(line,with:.color(color),style:.init(lineWidth:3,lineCap:.round))
   }
   for joint in snapshot.joints {
    let point=projection.point(joint)
    let circle=Path(ellipseIn:CGRect(x:point.x-3.5,y:point.y-3.5,width:7,height:7))
    context.fill(circle,with:.color(.white));context.stroke(circle,with:.color(.black.opacity(0.7)),lineWidth:1)
   }
   if !snapshot.faceMidline.isEmpty {
    let path=projection.facePath(snapshot.faceMidline)
    context.stroke(path,with:.color(.black.opacity(0.7)),style:.init(lineWidth:6,lineCap:.round,lineJoin:.round))
    context.stroke(path,with:.color(.mint),style:.init(lineWidth:3,lineCap:.round,lineJoin:.round))
   }
   if let box=snapshot.headBox {
    let path=Path(roundedRect:projection.box(box),cornerRadius:5)
    context.stroke(path,with:.color(.black.opacity(0.7)),lineWidth:5)
    context.stroke(path,with:.color(.orange),lineWidth:2.5)
   }
  }.allowsHitTesting(false).accessibilityHidden(true)
 }
}

struct TrackedCameraPreview:View {
 let session:AVCaptureSession
 let tracking:CameraTrackingSnapshot
 let counter:String
 var largeCounter=false
 var body:some View {
  TimelineView(.periodic(from:.now,by:0.1)) {_ in
   let fresh=tracking.isFresh(at:ProcessInfo.processInfo.systemUptime)
   CameraPreview(session:session)
    .overlay {if fresh {CameraTrackingOverlay(snapshot:tracking)}}
    .background(.black)
    .overlay(alignment:.bottomLeading) {
     Label(appText(fresh && tracking.hasRequiredMarks ? "Tracking movement" : "Waiting for a clear view"),systemImage:"viewfinder")
      .font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
      .foregroundStyle(fresh && tracking.hasRequiredMarks ? Color.mint : .yellow)
      .padding(8).background(.black.opacity(0.7),in:Capsule()).padding(10)
      .accessibilityIdentifier("cameraTrackingStatus")
    }
    .overlay(alignment:.topTrailing) {
     Text(counter).font(.system(size:largeCounter ? 44 : 30,weight:.bold,design:.rounded)).monospacedDigit()
      .padding(.horizontal,12).padding(.vertical,6).foregroundStyle(.white)
      .background(.black.opacity(0.7),in:Capsule()).padding(10).accessibilityIdentifier("cameraRepCounter")
    }
  }.clipShape(RoundedRectangle(cornerRadius:24)).accessibilityElement(children:.contain).accessibilityIdentifier("trackedCameraPreview")
 }
}

#if DEBUG
/// Synthetic geometry for projection/UI checks. It never starts a camera or counts a rep.
struct CameraTrackingFixturePreview:View {
 @State private var session=AVCaptureSession()
 var body:some View {
  VStack(spacing:8) {
   Text(appText("Tracking preview (test fixture)")).font(.caption).accessibilityIdentifier("trackingFixtureLabel")
   TimelineView(.periodic(from:.now,by:0.1)) {_ in
    let snapshot=ProcessInfo.processInfo.arguments.contains("--ui-tracking-empty") ? CameraTrackingSnapshot.empty : sample()
    TrackedCameraPreview(session:session,tracking:snapshot,counter:"0 / 3").frame(height:300)
   }
  }
 }
 private func sample()->CameraTrackingSnapshot {
  if ProcessInfo.processInfo.arguments.contains("--ui-tracking-face") {
   let turn=0.2*sin(ProcessInfo.processInfo.systemUptime*1.5)
   return .face(box:CGRect(x:0.25,y:0.22,width:0.5,height:0.6),confidence:0.95,landmarkConfidence:0.95,
    medianLine:[CGPoint(x:0.5,y:0.82),CGPoint(x:0.5+turn*0.7,y:0.64),CGPoint(x:0.5+turn,y:0.47),CGPoint(x:0.5+turn*0.4,y:0.28)],
    contour:[CGPoint(x:0.1,y:0.6),CGPoint(x:0.2,y:0.3),CGPoint(x:0.5,y:0.08),CGPoint(x:0.8,y:0.3),CGPoint(x:0.9,y:0.6)],
    imageSize:CGSize(width:480,height:640),uptime:ProcessInfo.processInfo.systemUptime)
  }
  typealias Joint=VNHumanBodyPoseObservation.JointName
  let positions:[Joint:CGPoint]=[
   .nose:CGPoint(x:0.5,y:0.84),.leftEye:CGPoint(x:0.46,y:0.88),.rightEye:CGPoint(x:0.54,y:0.88),
   .leftEar:CGPoint(x:0.42,y:0.85),.rightEar:CGPoint(x:0.58,y:0.85),
   .neck:CGPoint(x:0.5,y:0.74),.root:CGPoint(x:0.5,y:0.45),
   .leftShoulder:CGPoint(x:0.34,y:0.72),.rightShoulder:CGPoint(x:0.66,y:0.72),
   .leftElbow:CGPoint(x:0.2,y:0.57),.leftWrist:CGPoint(x:0.16,y:0.4),
   .rightElbow:CGPoint(x:0.8,y:0.57),.rightWrist:CGPoint(x:0.84,y:0.4),
   .leftHip:CGPoint(x:0.4,y:0.45),.rightHip:CGPoint(x:0.6,y:0.45),
   .leftKnee:CGPoint(x:0.38,y:0.26),.rightKnee:CGPoint(x:0.62,y:0.26),
   .leftAnkle:CGPoint(x:0.36,y:0.07),.rightAnkle:CGPoint(x:0.64,y:0.07)
  ]
  let partial=ProcessInfo.processInfo.arguments.contains("--ui-tracking-partial")
  var points=positions.mapValues {TrackedJoint(point:$0,confidence:0.95)}
  if partial {points[.rightWrist]=nil}
  var snapshot=CameraTrackingSnapshot.body(points,imageSize:CGSize(width:480,height:640),uptime:ProcessInfo.processInfo.systemUptime)
  snapshot.requiredJointsVisible = !partial
  return snapshot
 }
}
#endif
