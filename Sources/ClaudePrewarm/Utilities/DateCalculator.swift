import Foundation

enum DateCalculator {
    /// Weekday chips in UI order, Monday first. Values are Calendar weekday numbers.
    static let weekdayOrder = [2, 3, 4, 5, 6, 7, 1]

    static func weekdayInitial(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "S"
        case 2: return "M"
        case 3: return "T"
        case 4: return "W"
        case 5: return "T"
        case 6: return "F"
        default: return "S"
        }
    }

    /// Next warm time strictly after `now`, searching today plus the next 7 days.
    /// A warm time that already passed today is skipped, never back-filled.
    static func nextWarmup(
        settings: AppSettings,
        from now: Date,
        calendar: Calendar = .current
    ) -> Date? {
        guard settings.isValid else { return nil }

        for dayOffset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            guard settings.enabledWeekdays.contains(weekday) else { continue }
            guard let workDate = calendar.date(
                bySettingHour: settings.workHour,
                minute: settings.workMinute,
                second: 0,
                of: day
            ) else { continue }
            let warmDate = workDate.addingTimeInterval(-Double(settings.prewarmOffsetMinutes) * 60)
            if warmDate > now { return warmDate }
        }
        return nil
    }

    /// The warm time for `date`'s own day, whether or not it has passed. Used by wake recovery.
    static func warmTime(
        onDayOf date: Date,
        settings: AppSettings,
        calendar: Calendar = .current
    ) -> Date? {
        let weekday = calendar.component(.weekday, from: date)
        guard settings.enabledWeekdays.contains(weekday) else { return nil }
        guard let workDate = calendar.date(
            bySettingHour: settings.workHour,
            minute: settings.workMinute,
            second: 0,
            of: date
        ) else { return nil }
        return workDate.addingTimeInterval(-Double(settings.prewarmOffsetMinutes) * 60)
    }

    /// "Today 07:00" / "Tomorrow 07:00" / "Mon 07:00".
    static func relativeLabel(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let time = timeLabel(for: date, calendar: calendar)
        if calendar.isDateInToday(date) { return "Today \(time)" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow \(time)" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return "\(formatter.string(from: date)) \(time)"
    }

    /// "19:10" today, "Tomorrow 05:00", otherwise "Sun 05:00".
    static func compactLabel(for date: Date, calendar: Calendar = .current) -> String {
        let time = timeLabel(for: date, calendar: calendar)
        if calendar.isDateInToday(date) { return time }
        if calendar.isDateInTomorrow(date) { return "Tomorrow \(time)" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return "\(formatter.string(from: date)) \(time)"
    }

    static func timeLabel(for date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", comps.hour ?? 0, comps.minute ?? 0)
    }
}
