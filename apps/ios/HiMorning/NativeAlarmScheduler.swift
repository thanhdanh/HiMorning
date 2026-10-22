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

actor NativeAlarmScheduler: AlarmScheduler, BackupRingScheduler {

    func schedule(_ alarm: SavedAlarm) async throws {
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

        _ = try await AlarmManager.shared.schedule(
            id: alarm.id,
            configuration: try await configuration(
                for: alarm,
                schedule: alarm.time.weekdays.isEmpty ? alarm.scheduledOccurrence.map { .fixed($0) } ?? .relative(relative) : .relative(relative)
            )
        )
    }

    func scheduleBackup(
        _ ring: BackupRing,
        for alarm: SavedAlarm
    ) async throws {
        _ = try await AlarmManager.shared.schedule(
            id: ring.id,
            configuration: try await configuration(
                for: alarm,
                schedule: .fixed(ring.fireDate)
            )
        )
    }

    private func configuration(
        for alarm: SavedAlarm,
        schedule: Alarm.Schedule
    ) async throws -> AlarmManager.AlarmConfiguration<MorningMetadata> {
        guard try await AlarmManager.shared.requestAuthorization() == .authorized else {
            throw NativeAlarmError.denied
        }

        return .alarm(
            schedule: schedule,
            attributes: attributes(for: alarm),
            stopIntent: OpenMorningIntent(id: alarm.id),
            secondaryIntent: OpenMorningIntent(id: alarm.id),
            sound: sound(for: alarm)
        )
    }

    private func attributes(
        for alarm: SavedAlarm
    ) -> AlarmAttributes<MorningMetadata> {
        let openButton = AlarmButton(
            text: LocalizedStringResource(
                stringLiteral: appText("Open HiMorning")
            ),
            textColor: .black,
            systemImageName: "sun.max"
        )

        let title = LocalizedStringResource(
            stringLiteral: appText("Good morning ☀️")
        )

        let alert: AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
            alert = AlarmPresentation.Alert(
                title: title,
                secondaryButton: openButton,
                secondaryButtonBehavior: .custom
            )
        } else {
            alert = AlarmPresentation.Alert(
                title: title,
                stopButton: AlarmButton(
                    text: LocalizedStringResource(
                        stringLiteral: appText("Stop")
                    ),
                    textColor: .white,
                    systemImageName: "stop.fill"
                ),
                secondaryButton: openButton,
                secondaryButtonBehavior: .custom
            )
        }

        return AlarmAttributes<MorningMetadata>(
            presentation: AlarmPresentation(
                alert: alert
            ),
            metadata: MorningMetadata(
                alarmID: alarm.id.uuidString
            ),
            tintColor: .yellow
        )
    }

    private func sound(
        for alarm: SavedAlarm
    ) -> AlertConfiguration.AlertSound {
        alarm.sound == .system
            ? .default
            : .named(alarm.sound.rawValue + ".wav")
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
