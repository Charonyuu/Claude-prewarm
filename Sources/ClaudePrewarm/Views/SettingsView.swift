import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    let close: () -> Void

    @State private var weekdays: Set<Int> = []
    @State private var workTime = Date()
    @State private var offsetMinutes = 120
    @State private var launchAtLogin = true
    @State private var loaded = false

    private let labelWidth: CGFloat = 138

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            row("Work days") {
                HStack(spacing: 8) {
                    ForEach(Array(DateCalculator.weekdayOrder.enumerated()), id: \.offset) { _, weekday in
                        DayChip(
                            title: DateCalculator.weekdayInitial(weekday),
                            isOn: weekdays.contains(weekday)
                        ) {
                            toggle(weekday)
                        }
                    }
                }
            }

            row("I start working at") {
                DatePicker("", selection: $workTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.field)
                    .labelsHidden()
                    // Force 24-hour display, matching the rest of the UI.
                    .environment(\.locale, Locale(identifier: "en_GB"))
                    .frame(width: 148)
            }

            row("Prewarm") {
                Picker("", selection: $offsetMinutes) {
                    ForEach(AppSettings.offsetChoices, id: \.self) { minutes in
                        Text(AppSettings.offsetLabel(minutes)).tag(minutes)
                    }
                }
                .labelsHidden()
                .frame(width: 244)
            }

            HStack(spacing: 0) {
                Color.clear.frame(width: labelWidth, height: 1)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .toggleStyle(.checkbox)
                Spacer(minLength: 0)
            }

            if weekdays.isEmpty {
                Text("Pick at least one work day.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.danger)
            }

            Divider().overlay(Theme.divider)

            HStack {
                Spacer()
                Button("Save", action: save)
                    .buttonStyle(AccentButtonStyle(height: 34, fullWidth: false))
                    .disabled(weekdays.isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 520)
        .onAppear(perform: loadIfNeeded)
    }

    private func row<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Theme.title)
                .frame(width: labelWidth, alignment: .leading)
            content()
            Spacer(minLength: 0)
        }
    }

    private func toggle(_ weekday: Int) {
        if weekdays.contains(weekday) {
            weekdays.remove(weekday)
        } else {
            weekdays.insert(weekday)
        }
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        let settings = state.settings
        weekdays = settings.enabledWeekdays
        offsetMinutes = settings.prewarmOffsetMinutes
        launchAtLogin = settings.launchAtLogin
        workTime = Calendar.current.date(
            bySettingHour: settings.workHour,
            minute: settings.workMinute,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    private func save() {
        guard !weekdays.isEmpty else { return }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: workTime)
        let updated = AppSettings(
            enabledWeekdays: weekdays,
            workHour: comps.hour ?? 9,
            workMinute: comps.minute ?? 0,
            prewarmOffsetMinutes: offsetMinutes,
            launchAtLogin: launchAtLogin
        )
        state.update(settings: updated)
        close()
    }
}

private struct DayChip: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isOn ? .white : Theme.chipOffText)
                .frame(width: 40, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isOn ? Theme.accent : Theme.chipOff)
                )
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
