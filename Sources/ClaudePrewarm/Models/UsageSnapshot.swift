import Foundation

/// One reading of `claude /usage`.
struct UsageSnapshot: Equatable {
    var fetchedAt: Date
    var sessionPercent: Int?
    var sessionResetAt: Date?
    var sessionResetRaw: String?
    var weeklyPercent: Int?
    var weeklyResetAt: Date?
    var weeklyResetRaw: String?

    var hasAnything: Bool { sessionPercent != nil || weeklyPercent != nil }
}
