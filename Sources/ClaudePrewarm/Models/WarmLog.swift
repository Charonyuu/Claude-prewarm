import Foundation

enum WarmType: String, Codable {
    case scheduled
    case manual
    case wakeRecovery
}

struct WarmLog: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let type: WarmType
    let success: Bool
    let error: String?
}
