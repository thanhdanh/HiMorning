import SwiftUI
import UIKit

/// A horizontal-only recognizer leaves vertical alarm-list scrolling to the scroll view.
private struct AlarmCardPan:UIGestureRecognizerRepresentable {
 var canClose:Bool
 var action:(UIPanGestureRecognizer)->Void
 final class Coordinator:NSObject,UIGestureRecognizerDelegate {
  var canClose:Bool
  init(canClose:Bool) {self.canClose=canClose}
  func gestureRecognizerShouldBegin(_ recognizer:UIGestureRecognizer)->Bool {
   guard let pan=recognizer as? UIPanGestureRecognizer else {return false}
   let velocity=pan.velocity(in:pan.view)
   return abs(velocity.x)>abs(velocity.y)*1.2 && (velocity.x<0 || canClose)
  }
 }
 func makeCoordinator(converter:CoordinateSpaceConverter)->Coordinator {Coordinator(canClose:canClose)}
 func makeUIGestureRecognizer(context:Context)->UIPanGestureRecognizer {
  let pan=UIPanGestureRecognizer()
  pan.maximumNumberOfTouches=1;pan.delegate=context.coordinator
  return pan
 }
 func updateUIGestureRecognizer(_ recognizer:UIPanGestureRecognizer,context:Context) {context.coordinator.canClose=canClose}
 func handleUIGestureRecognizerAction(_ recognizer:UIPanGestureRecognizer,context:Context) {action(recognizer)}
}

struct SwipeableAlarmCard<Content:View>:View {
 let id:UUID
 @Binding var revealedID:UUID?
 let delete:()->Void
 @ViewBuilder var content:()->Content
 @Environment(\.accessibilityReduceMotion) private var reduceMotion
 @State private var dragOffset:CGFloat?
 @State private var origin:CGFloat=0
 private let actionWidth:CGFloat=88
 private var isOpen:Bool {revealedID == id}
 private var offset:CGFloat {dragOffset ?? (isOpen ? -actionWidth : 0)}
 var body:some View {
  ZStack(alignment:.trailing) {
   Button(role:.destructive) {requestDelete()} label: {
    VStack(spacing:5) {
     Image(systemName:"trash").font(.title3)
     Text(appText("Delete")).font(.caption.weight(.semibold))
    }.foregroundStyle(.white).frame(width:actionWidth).frame(maxHeight:.infinity)
     .contentShape(Rectangle())
   }.buttonStyle(.plain).accessibilityLabel(appText("Delete"))
    .accessibilityIdentifier("deleteAlarm-"+id.uuidString)
    .allowsHitTesting(isOpen).accessibilityHidden(!isOpen)
   content().offset(x:offset)
  }
  .background(offset<0 ? Color.red : .clear,in:RoundedRectangle(cornerRadius:26))
  .clipShape(RoundedRectangle(cornerRadius:26))
  .gesture(AlarmCardPan(canClose:isOpen) {pan in
   switch pan.state {
   case .began:
    origin=offset;dragOffset=origin;revealedID=nil
   case .changed:
    dragOffset=max(-actionWidth,min(0,origin+pan.translation(in:pan.view).x))
   case .ended:
    let velocity=pan.velocity(in:pan.view).x
    settle(open:velocity < -180 || (velocity < 180 && offset < -actionWidth/2))
   case .cancelled,.failed:settle(open:origin<0)
   default:break
   }
  })
  .accessibilityAction(named:Text(appText("Delete"))) {requestDelete()}
 }
 private func settle(open:Bool) {
  withAnimation(reduceMotion ? nil : .snappy(duration:0.22)) {revealedID=open ? id : nil;dragOffset=nil}
 }
 private func requestDelete() {settle(open:false);delete()}
}
