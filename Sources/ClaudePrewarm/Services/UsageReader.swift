import Foundation

/// Reads the real limits from `claude /usage`, which reports the live 5-hour
/// session window and the weekly window for the signed-in subscription.
struct UsageReader {
    let executablePath: String
    var timeout: TimeInterval = 30

    static let arguments = [
        "-p", "/usage",
        "--no-session-persistence",
        "--strict-mcp-config"
    ]

    func read() async throws -> UsageSnapshot {
        let output = try ProcessRunner.run(
            executablePath: executablePath,
            arguments: Self.arguments,
            timeout: timeout
        )
        guard let snapshot = UsageParser.parse(output) else {
            throw WarmError.failed(exitCode: 0, message: "Usage output could not be read.")
        }
        return snapshot
    }
}

enum UsageParser {
    /// Matches lines such as:
    ///   Current session: 37% used · resets Sep 20 at 7:10pm (Asia/Taipei)
    ///   Current week (all models): 81% used · resets Sep 21 at 5am (Asia/Taipei)
    static func parse(_ output: String, now: Date = Date()) -> UsageSnapshot? {
        let session = match(#"Current session:\s*(\d+)%\s*used(?:\s*·\s*resets\s*([^\n(]+))?"#, in: output)
        let weekly = match(#"Current week[^:\n]*:\s*(\d+)%\s*used(?:\s*·\s*resets\s*([^\n(]+))?"#, in: output)
        guard session != nil || weekly != nil else { return nil }

        return UsageSnapshot(
            fetchedAt: now,
            sessionPercent: session?.percent,
            sessionResetAt: session?.reset.flatMap { parseReset($0, now: now) },
            sessionResetRaw: session?.reset,
            weeklyPercent: weekly?.percent,
            weeklyResetAt: weekly?.reset.flatMap { parseReset($0, now: now) },
            weeklyResetRaw: weekly?.reset
        )
    }

    private static func match(_ pattern: String, in text: String) -> (percent: Int, reset: String?)? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        else { return nil }

        func group(_ index: Int) -> String? {
            guard let range = Range(m.range(at: index), in: text) else { return nil }
            return String(text[range]).trimmingCharacters(in: .whitespaces)
        }
        guard let percentText = group(1), let percent = Int(percentText) else { return nil }
        return (percent, group(2))
    }

    /// "Sep 20 at 7:10pm" / "Sep 21 at 5am". The year is absent, so it is inferred.
    static func parseReset(_ raw: String, now: Date = Date(), calendar: Calendar = .current) -> Date? {
        let cleaned = raw.trimmingCharacters(in: .whitespaces)
        let formats = ["MMM d 'at' h:mma", "MMM d 'at' ha", "MMM d h:mma", "MMM d ha"]
        let year = calendar.component(.year, from: now)

        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.amSymbol = "am"
            formatter.pmSymbol = "pm"
            formatter.dateFormat = "yyyy " + format
            guard let parsed = formatter.date(from: "\(year) \(cleaned)") else { continue }
            // A reset is always near: if the inferred year lands far in the past, roll it forward.
            if parsed < now.addingTimeInterval(-2 * 24 * 3600),
               let next = calendar.date(byAdding: .year, value: 1, to: parsed) {
                return next
            }
            return parsed
        }
        return nil
    }
}
