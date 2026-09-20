import Foundation

/// UserDefaults-backed persistence. No database, no files of our own.
enum SettingsStore {
    private enum Key {
        static let settings = "appSettings"
        static let lastWarmupAt = "lastWarmupAt"
        static let expectedResetAt = "expectedResetAt"
        static let lastScheduledWarmupAt = "lastScheduledWarmupAt"
        static let logs = "warmLogs"
    }

    private static let defaults = UserDefaults.standard

    static func loadSettings() -> AppSettings {
        guard let data = defaults.data(forKey: Key.settings),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data),
              decoded.isValid
        else { return .default }
        return decoded
    }

    static func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Key.settings)
    }

    static var lastWarmupAt: Date? {
        get { defaults.object(forKey: Key.lastWarmupAt) as? Date }
        set { defaults.set(newValue, forKey: Key.lastWarmupAt) }
    }

    static var expectedResetAt: Date? {
        get { defaults.object(forKey: Key.expectedResetAt) as? Date }
        set { defaults.set(newValue, forKey: Key.expectedResetAt) }
    }

    static var lastScheduledWarmupAt: Date? {
        get { defaults.object(forKey: Key.lastScheduledWarmupAt) as? Date }
        set { defaults.set(newValue, forKey: Key.lastScheduledWarmupAt) }
    }

    static func loadLogs() -> [WarmLog] {
        guard let data = defaults.data(forKey: Key.logs),
              let decoded = try? JSONDecoder().decode([WarmLog].self, from: data)
        else { return [] }
        return decoded
    }

    /// Keeps the most recent 20 entries.
    static func save(_ logs: [WarmLog]) {
        let trimmed = Array(logs.prefix(20))
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        defaults.set(data, forKey: Key.logs)
    }
}
