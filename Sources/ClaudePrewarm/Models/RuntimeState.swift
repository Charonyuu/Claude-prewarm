import Foundation

enum AppStatus: Equatable {
    case active
    case warming
    case setupRequired
    case error

    var label: String {
        switch self {
        case .active: return "Active"
        case .warming: return "Warming…"
        case .setupRequired: return "Setup Required"
        case .error: return "Error"
        }
    }
}

struct RuntimeState {
    var nextWarmupAt: Date?
    var lastWarmupAt: Date?
    var expectedResetAt: Date?
    var isWarming: Bool = false
    var lastError: String?
    var claudePath: String?
    /// The CLI is installed but has no usable credentials.
    var needsSignIn: Bool = false

    var status: AppStatus {
        if isWarming { return .warming }
        if claudePath == nil { return .setupRequired }
        if lastError != nil { return .error }
        return .active
    }
}
