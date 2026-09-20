import Foundation

enum ClaudeBinaryFinder {
    private static let fallbackPaths = [
        "~/.local/bin/claude",
        "~/.claude/local/claude",
        "~/.claude/local/bin/claude",
        "/opt/homebrew/bin/claude",
        "/usr/local/bin/claude",
        "/usr/bin/claude",
        "/bin/claude"
    ]

    /// A GUI app inherits a minimal PATH, so ask a login shell first and fall back
    /// to the usual install locations.
    static func find() -> String? {
        if let path = viaLoginShell(), isExecutable(path) { return path }
        for candidate in fallbackPaths {
            let expanded = (candidate as NSString).expandingTildeInPath
            if isExecutable(expanded) { return expanded }
        }
        return nil
    }

    private static func isExecutable(_ path: String) -> Bool {
        FileManager.default.isExecutableFile(atPath: path)
    }

    private static func viaLoginShell() -> String? {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-lc", "command -v claude"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let output = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return output.isEmpty ? nil : output
    }
}
