import ActivityKit
import SwiftUI
import WidgetKit

struct HiMorningWidgetEntry: TimelineEntry {
 let date: Date
 let snapshot: MorningWidgetSnapshot
}

struct HiMorningProvider: TimelineProvider {
 func placeholder(in context: Context) -> HiMorningWidgetEntry {
  HiMorningWidgetEntry(
   date: Date(),
   snapshot: MorningWidgetSnapshot(
    nextAlarmTime: Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()),
    challengeTitle: "Read & Choose",
    modeTitle: "Balanced",
    journeyCompleted: 3,
    journeyTotal: 7
   )
  )
 }

 func getSnapshot(in context: Context, completion: @escaping (HiMorningWidgetEntry) -> Void) {
  completion(HiMorningWidgetEntry(date: Date(), snapshot: MorningWidgetStore.load()))
 }

 func getTimeline(in context: Context, completion: @escaping (Timeline<HiMorningWidgetEntry>) -> Void) {
  let entry = HiMorningWidgetEntry(date: Date(), snapshot: MorningWidgetStore.load())
  let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
  completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
 }
}

struct HiMorningNextAlarmWidgetView: View {
 @Environment(\.widgetFamily) private var family
 let entry: HiMorningWidgetEntry

 var body: some View {
  switch family {
  case .accessoryCircular:
   ZStack {
    AccessoryWidgetBackground()
    VStack(spacing: 2) {
     Image(systemName: "sunrise.fill")
      .font(.caption)
     if let next = entry.snapshot.nextAlarmTime {
      Text(next, format: .dateTime.hour().minute())
       .font(.caption2.weight(.semibold))
       .monospacedDigit()
     } else {
      Text("\(entry.snapshot.journeyCompleted)/\(entry.snapshot.journeyTotal)")
       .font(.caption2.weight(.semibold))
     }
    }
   }
  case .accessoryRectangular:
   VStack(alignment: .leading, spacing: 2) {
    HStack(spacing: 4) {
     Image(systemName: "sunrise.fill")
     Text("HiMorning")
      .font(.caption.weight(.bold))
    }
    if let next = entry.snapshot.nextAlarmTime {
     Text(next, style: .time)
      .font(.headline.monospacedDigit())
     Text(entry.snapshot.challengeTitle ?? "Ready")
      .font(.caption2)
      .lineLimit(1)
    } else {
     Text("No upcoming alarm")
      .font(.caption)
    }
   }
  default:
   VStack(alignment: .leading, spacing: 8) {
    HStack {
     Image(systemName: "sunrise.fill")
      .foregroundStyle(Color(red: 41 / 255, green: 37 / 255, blue: 29 / 255))
     Spacer()
     Text("\(entry.snapshot.journeyCompleted)/\(entry.snapshot.journeyTotal)")
      .font(.caption2.weight(.bold))
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(.white.opacity(0.6), in: Capsule())
    }
    Spacer()
    if let next = entry.snapshot.nextAlarmTime {
     Text(next, style: .time)
      .font(.title2.weight(.bold))
      .monospacedDigit()
     Text(entry.snapshot.challengeTitle ?? "Morning challenge")
      .font(.caption.weight(.medium))
      .lineLimit(2)
    } else {
     Text("No alarm set")
      .font(.headline)
     Text("Tap to plan tomorrow")
      .font(.caption)
      .opacity(0.75)
    }
   }
   .foregroundStyle(Color(red: 41 / 255, green: 37 / 255, blue: 29 / 255))
   .containerBackground(Color(red: 249 / 255, green: 224 / 255, blue: 125 / 255), for: .widget)
  }
 }
}

struct HiMorningNextAlarmWidget: Widget {
 let kind = "HiMorningNextAlarmWidget"

 var body: some WidgetConfiguration {
  StaticConfiguration(kind: kind, provider: HiMorningProvider()) { entry in
   HiMorningNextAlarmWidgetView(entry: entry)
  }
  .configurationDisplayName("Next Morning Alarm")
  .description("See your upcoming wake time, mission, and seven-morning progress.")
  .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryCircular])
 }
}

struct HiMorningLiveActivity: Widget {
 var body: some WidgetConfiguration {
  ActivityConfiguration(for: MorningAlarmAttributes.self) { context in
   HStack(spacing: 12) {
    Image(systemName: context.state.completed ? "checkmark.circle.fill" : "sunrise.fill")
     .font(.title2)
    VStack(alignment: .leading, spacing: 2) {
     Text(context.attributes.challengeTitle)
      .font(.headline)
     Text(context.state.completed ? "Morning complete" : context.attributes.modeTitle)
      .font(.caption)
      .opacity(0.8)
    }
    Spacer()
    Text(context.state.wakeTime, style: .time)
     .font(.title3.weight(.bold))
     .monospacedDigit()
   }
   .padding(16)
   .foregroundStyle(Color(red: 41 / 255, green: 37 / 255, blue: 29 / 255))
   .activityBackgroundTint(Color(red: 249 / 255, green: 224 / 255, blue: 125 / 255))
  } dynamicIsland: { context in
   DynamicIsland {
    DynamicIslandExpandedRegion(.leading) {
     Label(context.attributes.challengeTitle, systemImage: "sunrise.fill")
      .font(.caption.weight(.semibold))
    }
    DynamicIslandExpandedRegion(.trailing) {
     Text(context.state.wakeTime, style: .time)
      .font(.headline.monospacedDigit())
    }
   } compactLeading: {
    Image(systemName: "sunrise.fill")
   } compactTrailing: {
    Text(context.state.wakeTime, style: .time)
     .font(.caption2.monospacedDigit())
   } minimal: {
    Image(systemName: "sunrise.fill")
   }
  }
 }
}

@main
struct HiMorningWidgetBundle: WidgetBundle {
 var body: some Widget {
  HiMorningNextAlarmWidget()
  HiMorningLiveActivity()
 }
}
