import Foundation

/// User-configurable settings, persisted in UserDefaults.
struct AppSettings: Codable, Equatable {
    /// Calendar weekday numbers (1 = Sunday ... 7 = Saturday).
    var enabledWeekdays: Set<Int>
    var workHour: Int
    var workMinute: Int
    var prewarmOffsetMinutes: Int
    var launchAtLogin: Bool

    static let `default` = AppSettings(
        enabledWeekdays: [2, 3, 4, 5, 6],
        workHour: 9,
        workMinute: 0,
        prewarmOffsetMinutes: 120,
        launchAtLogin: true
    )

    static let offsetChoices = [30, 60, 120, 180, 240]

    static func offsetLabel(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) minutes before" }
        let hours = minutes / 60
        return hours == 1 ? "1 hour before" : "\(hours) hours before"
    }

    var isValid: Bool {
        !enabledWeekdays.isEmpty
            && (0...23).contains(workHour)
            && (0...59).contains(workMinute)
            && AppSettings.offsetChoices.contains(prewarmOffsetMinutes)
    }

    var workTimeLabel: String {
        String(format: "%02d:%02d", workHour, workMinute)
    }
}
