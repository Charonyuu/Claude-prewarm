import Foundation

struct WarmResult {
    let startedAt: Date
    let finishedAt: Date
    let output: String
    let exitCode: Int32
}

enum WarmError: LocalizedError {
    case binaryNotFound
    case launchFailed(String)
    case timedOut(seconds: Int)
    case notSignedIn(String)
    case failed(exitCode: Int32, message: String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "Claude CLI not found. Install it, then reopen Claude Prewarm."
        case .launchFailed(let message):
            return "Claude CLI could not be started. \(message)"
        case .timedOut(let seconds):
            return "Claude CLI timed out after \(seconds) seconds."
        case .notSignedIn:
            return "Claude needs to be signed in.\n\nOpen Terminal and run:\nclaude"
        case .failed(let exitCode, let message):
            let detail = message.isEmpty ? "" : "\n\n\(message)"
            return "Claude CLI exited with code \(exitCode).\(detail)"
        }
    }

    static func looksLikeAuthFailure(_ message: String) -> Bool {
        let lowered = message.lowercased()
        return ["login", "log in", "sign in", "signed in", "authentication", "unauthorized", "oauth", "credentials"]
            .contains { lowered.contains($0) }
    }
}

protocol ClaudeRunning {
    func warm() async throws -> WarmResult
}

/// Runs one minimal Haiku request through the locally signed-in Claude CLI.
struct ClaudeRunner: ClaudeRunning {
    let executablePath: String
    var timeout: TimeInterval = 30

    static let arguments = [
        "-p", "Reply only OK.",
        "--model", "haiku",
        "--effort", "low",
        "--no-session-persistence",
        "--strict-mcp-config",
        "--disable-slash-commands"
    ]

    func warm() async throws -> WarmResult {
        let startedAt = Date()
        let output = try ProcessRunner.execute(
            executablePath: executablePath,
            arguments: Self.arguments,
            timeout: timeout
        )

        guard output.exitCode == 0 else {
            if WarmError.looksLikeAuthFailure(output.combined) {
                throw WarmError.notSignedIn(output.combined)
            }
            throw WarmError.failed(exitCode: output.exitCode, message: String(output.combined.prefix(300)))
        }

        return WarmResult(
            startedAt: startedAt,
            finishedAt: Date(),
            output: output.stdout,
            exitCode: output.exitCode
        )
    }
}
