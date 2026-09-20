import Foundation

struct ProcessOutput {
    let stdout: String
    let stderr: String
    let exitCode: Int32

    var combined: String { stderr.isEmpty ? stdout : stderr }
}

/// Launches the Claude CLI the same way for every call: empty working directory,
/// a PATH a GUI app would otherwise lack, and a hard timeout.
enum ProcessRunner {
    static func execute(
        executablePath: String,
        arguments: [String],
        timeout: TimeInterval
    ) throws -> ProcessOutput {
        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            throw WarmError.binaryNotFound
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.currentDirectoryURL = scratchDirectory()
        process.environment = childEnvironment()

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw WarmError.launchFailed(error.localizedDescription)
        }

        let timedOut = Atomic(false)
        let deadline = DispatchWorkItem {
            if process.isRunning {
                timedOut.value = true
                process.terminate()
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: deadline)

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        deadline.cancel()

        if timedOut.value { throw WarmError.timedOut(seconds: Int(timeout)) }

        return ProcessOutput(
            stdout: String(decoding: outData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines),
            stderr: String(decoding: errData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines),
            exitCode: process.terminationStatus
        )
    }

    /// Throws unless the command succeeded; returns stdout.
    static func run(
        executablePath: String,
        arguments: [String],
        timeout: TimeInterval
    ) throws -> String {
        let output = try execute(executablePath: executablePath, arguments: arguments, timeout: timeout)
        guard output.exitCode == 0 else {
            throw WarmError.failed(exitCode: output.exitCode, message: String(output.combined.prefix(300)))
        }
        return output.stdout
    }

    /// An empty directory, so the CLI never picks up a project's files or CLAUDE.md.
    private static func scratchDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ClaudePrewarm", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// A GUI app's PATH is minimal; give the CLI the usual locations plus whatever it had.
    private static func childEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let home = NSHomeDirectory()
        var parts = [
            "\(home)/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]
        if let existing = env["PATH"] { parts.append(existing) }
        env["PATH"] = parts.joined(separator: ":")
        env["HOME"] = home
        env["CLAUDE_CODE_NONINTERACTIVE"] = "1"
        return env
    }
}

/// Minimal lock-protected box, so the timeout handler and the caller can share a flag.
final class Atomic<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: T

    init(_ value: T) { stored = value }

    var value: T {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}
