import AlarmKit
import ActivityKit
import AppIntents
import SwiftUI
import HiMorningCore

struct MorningMetadata: AlarmMetadata {
    let alarmID: String
}

struct OpenMorningIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Open HiMorning challenge"
    static var openAppWhenRun = true

    @Parameter(title: "Alarm")
    var alarmID: String

    init() {
        alarmID = ""
    }

    init(id: UUID) {
        alarmID = id.uuidString
    }

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(
            alarmID,
            forKey: "pendingAlarmID"
        )
        return .result()
    }
}

actor NativeAlarmScheduler: AlarmScheduler {

    func schedule(_ alarm: SavedAlarm) async throws {
        let manager = AlarmManager.shared

        guard try await manager.requestAuthorization() == .authorized else {
            throw NativeAlarmError.denied
        }

        // MARK: - Schedule

        let days: [Locale.Weekday] = [
            .sunday,
            .monday,
            .tuesday,
            .wednesday,
            .thursday,
            .friday,
            .saturday
        ]

        let recurrence: Alarm.Schedule.Relative.Recurrence =
            alarm.time.weekdays.isEmpty
            ? .never
            : .weekly(
                alarm.time.weekdays.sorted().map { days[$0 - 1] }
            )

        let relative = Alarm.Schedule.Relative(
            time: .init(
                hour: alarm.time.hour,
                minute: alarm.time.minute
            ),
            repeats: recurrence
        )

        // MARK: - Alarm Presentation

        // AlarmKit requires a Stop button.
        let stopButton = AlarmButton(
            text: LocalizedStringResource(
                stringLiteral: appText("Stop")
            ),
            textColor: .white,
            systemImageName: "stop.fill"
        )

        let openButton = AlarmButton(
            text: LocalizedStringResource(
                stringLiteral: appText("Open HiMorning")
            ),
            textColor: .black,
            systemImageName: "sun.max"
        )

        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(
                stringLiteral: appText("Good morning ☀️")
            ),
            stopButton: stopButton,
            secondaryButton: openButton,
            secondaryButtonBehavior: .custom
        )

        // MARK: - Alarm Attributes

        let attributes: AlarmAttributes<MorningMetadata> =
            AlarmAttributes<MorningMetadata>(
                presentation: AlarmPresentation(
                    alert: alert
                ),
                metadata: MorningMetadata(
                    alarmID: alarm.id.uuidString
                ),
                tintColor: .yellow
            )

        // MARK: - Sound

        let sound: AlertConfiguration.AlertSound =
            alarm.sound == .system
            ? .default
            : .named(alarm.sound.rawValue + ".wav")

        // MARK: - Configuration

        let configuration: AlarmManager.AlarmConfiguration<MorningMetadata> =
            .alarm(
                schedule: .relative(relative),
                attributes: attributes,
                secondaryIntent: OpenMorningIntent(id: alarm.id),
                sound: sound
            )

        // MARK: - Schedule Alarm

        _ = try await manager.schedule(
            id: alarm.id,
            configuration: configuration
        )
    }

    // MARK: - Cancel

    func cancel(id: UUID) async throws {
        let manager = AlarmManager.shared

        if try manager.alarms.contains(where: { $0.id == id }) {
            try manager.cancel(id: id)
        }
    }

    // MARK: - Stop

    func stop(id: UUID) async throws {
        let manager = AlarmManager.shared

        // A system Stop may already have removed a one-time alarm.
        if let alarm = try manager.alarms.first(
            where: { $0.id == id }
        ), alarm.state != .scheduled {
            try manager.stop(id: id)
        }
    }

    // MARK: - Scheduled IDs

    func scheduledIDs() async throws -> Set<UUID> {
        let manager = AlarmManager.shared

        guard manager.authorizationState == .authorized else {
            return []
        }

        return Set(
            try manager.alarms.map(\.id)
        )
    }
}

enum NativeAlarmError: Error {
    case denied
}
