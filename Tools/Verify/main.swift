import Foundation

var failures = 0
func check(_ name: String, _ condition: Bool, _ detail: String = "") {
    print((condition ? "PASS " : "FAIL ") + name + (condition ? "" : "  \(detail)"))
    if !condition { failures += 1 }
}

var cal = Calendar(identifier: .gregorian)
cal.timeZone = TimeZone(identifier: "Asia/Taipei")!
func date(_ s: String) -> Date {
    let f = DateFormatter(); f.calendar = cal; f.timeZone = cal.timeZone
    f.dateFormat = "yyyy-MM-dd HH:mm"; return f.date(from: s)!
}
func label(_ d: Date?) -> String {
    guard let d else { return "nil" }
    let f = DateFormatter(); f.calendar = cal; f.timeZone = cal.timeZone
    f.dateFormat = "yyyy-MM-dd HH:mm"; return f.string(from: d)
}

let monFri = AppSettings.default   // Mon-Fri, 09:00, 120 min

// Wed 2026-09-16 06:00 -> same day 07:00
check("today upcoming",
      label(DateCalculator.nextWarmup(settings: monFri, from: date("2026-09-16 06:00"), calendar: cal)) == "2026-09-16 07:00",
      label(DateCalculator.nextWarmup(settings: monFri, from: date("2026-09-16 06:00"), calendar: cal)))

// Wed 14:00 -> no back-fill, next is Thu 07:00
check("past today skips to next day",
      label(DateCalculator.nextWarmup(settings: monFri, from: date("2026-09-16 14:00"), calendar: cal)) == "2026-09-17 07:00",
      label(DateCalculator.nextWarmup(settings: monFri, from: date("2026-09-16 14:00"), calendar: cal)))

// Fri 14:00 -> skips weekend to Mon 07:00
check("weekend skipped",
      label(DateCalculator.nextWarmup(settings: monFri, from: date("2026-09-18 14:00"), calendar: cal)) == "2026-09-21 07:00",
      label(DateCalculator.nextWarmup(settings: monFri, from: date("2026-09-18 14:00"), calendar: cal)))

// Sat 10:00 -> Mon 07:00
check("saturday -> monday",
      label(DateCalculator.nextWarmup(settings: monFri, from: date("2026-09-19 10:00"), calendar: cal)) == "2026-09-21 07:00",
      label(DateCalculator.nextWarmup(settings: monFri, from: date("2026-09-19 10:00"), calendar: cal)))

// Offset crossing midnight: work 01:00, offset 4h -> previous day 21:00
var nightShift = AppSettings.default
nightShift.workHour = 1
nightShift.prewarmOffsetMinutes = 240
check("offset crosses midnight",
      label(DateCalculator.nextWarmup(settings: nightShift, from: date("2026-09-16 12:00"), calendar: cal)) == "2026-09-16 21:00",
      label(DateCalculator.nextWarmup(settings: nightShift, from: date("2026-09-16 12:00"), calendar: cal)))

// Sunday only
var sundayOnly = AppSettings.default
sundayOnly.enabledWeekdays = [1]
check("single day repeats weekly",
      label(DateCalculator.nextWarmup(settings: sundayOnly, from: date("2026-09-21 08:00"), calendar: cal)) == "2026-09-27 07:00",
      label(DateCalculator.nextWarmup(settings: sundayOnly, from: date("2026-09-21 08:00"), calendar: cal)))

// Invalid settings
var empty = AppSettings.default
empty.enabledWeekdays = []
check("no work day -> nil", DateCalculator.nextWarmup(settings: empty, from: date("2026-09-16 06:00"), calendar: cal) == nil)
check("validation rejects empty days", empty.isValid == false)
check("validation accepts default", monFri.isValid)

// Wake recovery helper
check("warmTime on work day", label(DateCalculator.warmTime(onDayOf: date("2026-09-16 07:45"), settings: monFri, calendar: cal)) == "2026-09-16 07:00")
check("warmTime nil on weekend", DateCalculator.warmTime(onDayOf: date("2026-09-19 07:45"), settings: monFri, calendar: cal) == nil)

// Weekday chip order is Monday-first
check("chip order", DateCalculator.weekdayOrder.map(DateCalculator.weekdayInitial).joined() == "MTWTFSS")

// Offset labels
check("offset labels", AppSettings.offsetChoices.map(AppSettings.offsetLabel) ==
      ["30 minutes before", "1 hour before", "2 hours before", "3 hours before", "4 hours before"])

// Usage parsing
let sample = """
You are currently using your subscription to power your Claude Code usage

Current session: 37% used · resets Sep 20 at 7:10pm (Asia/Taipei)
Current week (all models): 81% used · resets Sep 21 at 5am (Asia/Taipei)

What's contributing to your limits usage?
"""
let parsed = UsageParser.parse(sample, now: date("2026-09-20 16:40"))
check("usage parsed", parsed != nil)
check("session percent", parsed?.sessionPercent == 37, String(describing: parsed?.sessionPercent))
check("weekly percent", parsed?.weeklyPercent == 81, String(describing: parsed?.weeklyPercent))
check("session reset time", label(UsageParser.parseReset("Sep 20 at 7:10pm", now: date("2026-09-20 16:40"), calendar: cal)) == "2026-09-20 19:10",
      label(UsageParser.parseReset("Sep 20 at 7:10pm", now: date("2026-09-20 16:40"), calendar: cal)))
check("weekly reset time (no minutes)", label(UsageParser.parseReset("Sep 21 at 5am", now: date("2026-09-20 16:40"), calendar: cal)) == "2026-09-21 05:00",
      label(UsageParser.parseReset("Sep 21 at 5am", now: date("2026-09-20 16:40"), calendar: cal)))
check("year rolls forward", label(UsageParser.parseReset("Jan 2 at 5am", now: date("2026-12-31 23:00"), calendar: cal)) == "2027-01-02 05:00",
      label(UsageParser.parseReset("Jan 2 at 5am", now: date("2026-12-31 23:00"), calendar: cal)))
check("garbage rejected", UsageParser.parse("no limits here at all") == nil)
check("missing reset still parses", UsageParser.parse("Current session: 12% used")?.sessionPercent == 12)

// Binary + live warm
let path = ClaudeBinaryFinder.find()
check("claude binary found", path != nil, "nil")
if let path {
    print("     path: \(path)")
    let sem = DispatchSemaphore(value: 0)
    Task {
        do {
            let result = try await ClaudeRunner(executablePath: path).warm()
            check("live warm exit 0", result.exitCode == 0)
            print("     output: \(result.output.prefix(40)) | \(String(format: "%.1fs", result.finishedAt.timeIntervalSince(result.startedAt)))")
        } catch {
            check("live warm", false, error.localizedDescription)
        }
        sem.signal()
    }
    sem.wait()
}

if let path {
    let sem = DispatchSemaphore(value: 0)
    Task {
        do {
            let snapshot = try await UsageReader(executablePath: path).read()
            check("live /usage read", snapshot.hasAnything)
            print("     5h: \(snapshot.sessionPercent.map { "\($0)%" } ?? "?") resets \(snapshot.sessionResetRaw ?? "?")")
            print("     weekly: \(snapshot.weeklyPercent.map { "\($0)%" } ?? "?") resets \(snapshot.weeklyResetRaw ?? "?")")
        } catch {
            check("live /usage read", false, error.localizedDescription)
        }
        sem.signal()
    }
    sem.wait()
}

print(failures == 0 ? "\nALL PASS" : "\n\(failures) FAILURES")
exit(failures == 0 ? 0 : 1)
