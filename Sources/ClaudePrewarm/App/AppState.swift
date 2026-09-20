import AppKit
import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published private(set) var runtime: RuntimeState
    @Published private(set) var logs: [WarmLog]
    @Published private(set) var usage: UsageSnapshot?
    @Published private(set) var isLoadingUsage = false
    @Published private(set) var usageUnavailable = false

    private let schedule = ScheduleService()
    private var observers: [NSObjectProtocol] = []
    private var usageTimer: Timer?
    private var usageTask: Task<Void, Never>?

    /// Window in which a repeat warm is pointless, and in which Warm Now stays disabled.
    static let duplicateWarmWindow: TimeInterval = 10 * 60
    /// How late a missed warm may still run after a wake.
    static let lateWarmGracePeriod: TimeInterval = 60 * 60
    static let usageWindow: TimeInterval = 5 * 60 * 60
    /// How often the limits block re-reads `claude /usage`.
    static let usageRefreshInterval: TimeInterval = 10 * 60

    init() {
        let loaded = SettingsStore.loadSettings()
        settings = loaded
        logs = SettingsStore.loadLogs()
        runtime = RuntimeState(
            lastWarmupAt: SettingsStore.lastWarmupAt,
            expectedResetAt: SettingsStore.expectedResetAt,
            claudePath: ClaudeBinaryFinder.find()
        )
    }

    // MARK: - Lifecycle

    func start() {
        NotificationService.requestAuthorizationIfNeeded()
        syncLaunchAtLogin()
        registerSleepWakeObservers()

        guard runtime.claudePath != nil else { return }
        rescheduleNextWarmup()
        startUsageRefresh()
    }

    func stop() {
        schedule.cancel()
        usageTimer?.invalidate()
        usageTimer = nil
        usageTask?.cancel()
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers.removeAll()
    }

    // MARK: - Derived UI values

    var status: AppStatus { runtime.status }

    var nextWarmupLabel: String {
        guard runtime.claudePath != nil else { return "—" }
        guard let next = runtime.nextWarmupAt else { return "Not scheduled" }
        return DateCalculator.relativeLabel(for: next)
    }

    var workStartLabel: String { settings.workTimeLabel }

    /// The real session reset when `claude /usage` gave us one, else our own estimate.
    var expectedResetLabel: String {
        if let reset = usage?.sessionResetAt, reset > Date() {
            return DateCalculator.compactLabel(for: reset)
        }
        if let raw = usage?.sessionResetRaw, !raw.isEmpty, usage?.sessionResetAt == nil {
            return raw
        }
        if let reset = runtime.expectedResetAt, reset > Date() {
            return DateCalculator.timeLabel(for: reset)
        }
        if isLoadingUsage { return "Checking…" }
        return "—"
    }

    func resetLabel(for date: Date?, raw: String?) -> String {
        if let date { return "resets \(DateCalculator.compactLabel(for: date))" }
        if let raw, !raw.isEmpty { return "resets \(raw)" }
        return "reset time unknown"
    }

    var canWarmNow: Bool {
        guard runtime.claudePath != nil, !runtime.isWarming else { return false }
        return !warmedRecently
    }

    private var warmedRecently: Bool {
        guard let last = runtime.lastWarmupAt else { return false }
        return Date().timeIntervalSince(last) < Self.duplicateWarmWindow
    }

    /// Why Warm Now is unavailable, for the line under the button.
    var warmNowHint: String? {
        if runtime.claudePath == nil {
            return "Claude CLI not found. Install Claude Code, then reopen this app."
        }
        if runtime.isWarming { return nil }
        if warmedRecently, let last = runtime.lastWarmupAt {
            let remaining = Int((Self.duplicateWarmWindow - Date().timeIntervalSince(last)) / 60) + 1
            return "Warmed just now. Available again in \(remaining) min."
        }
        return nil
    }

    // MARK: - Settings

    func update(settings newValue: AppSettings) {
        guard newValue.isValid else { return }
        let launchChanged = newValue.launchAtLogin != settings.launchAtLogin
        settings = newValue
        SettingsStore.save(newValue)

        if launchChanged, let message = LoginItemService.setEnabled(newValue.launchAtLogin) {
            runtime.lastError = message
        }
        rescheduleNextWarmup()
    }

    func clearError() {
        runtime.lastError = nil
    }

    func recheckClaudeBinary() {
        runtime.claudePath = ClaudeBinaryFinder.find()
        if runtime.claudePath != nil { rescheduleNextWarmup() }
    }

    private func syncLaunchAtLogin() {
        let actual = LoginItemService.isEnabled
        guard actual != settings.launchAtLogin else { return }
        if settings.launchAtLogin {
            // Registration can need user approval; reflect reality if it fails.
            if LoginItemService.setEnabled(true) != nil {
                settings.launchAtLogin = false
                SettingsStore.save(settings)
            }
        } else {
            settings.launchAtLogin = actual
            SettingsStore.save(settings)
        }
    }

    // MARK: - Scheduling

    func rescheduleNextWarmup() {
        schedule.cancel()
        let next = schedule.calculateNextWarmup(settings: settings, from: Date())
        runtime.nextWarmupAt = next
        guard let next else { return }
        schedule.schedule(date: next) { [weak self] in
            Task { @MainActor in await self?.runScheduledWarm(scheduledFor: next) }
        }
    }

    private func runScheduledWarm(scheduledFor date: Date) async {
        SettingsStore.lastScheduledWarmupAt = date
        if !warmedRecently {
            await warm(source: .scheduled)
        }
        rescheduleNextWarmup()
        refreshUsage()
    }

    // MARK: - Warming

    func warmNow() async {
        await warm(source: .manual)
        rescheduleNextWarmup()
        refreshUsage()
    }

    private func warm(source: WarmType) async {
        guard !runtime.isWarming, let path = runtime.claudePath else { return }
        runtime.isWarming = true
        runtime.lastError = nil

        let runner = ClaudeRunner(executablePath: path)
        do {
            let result = try await runner.warm()
            runtime.lastWarmupAt = result.startedAt
            runtime.expectedResetAt = result.startedAt.addingTimeInterval(Self.usageWindow)
            SettingsStore.lastWarmupAt = runtime.lastWarmupAt
            SettingsStore.expectedResetAt = runtime.expectedResetAt
            append(WarmLog(date: result.startedAt, type: source, success: true, error: nil))
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            runtime.lastError = message
            append(WarmLog(date: Date(), type: source, success: false, error: message))
            NotificationService.notifyFailure(message)
        }

        runtime.isWarming = false
    }

    private func append(_ log: WarmLog) {
        logs.insert(log, at: 0)
        logs = Array(logs.prefix(20))
        SettingsStore.save(logs)
    }

    // MARK: - Usage limits

    private func startUsageRefresh() {
        refreshUsage()
        usageTimer?.invalidate()
        let timer = Timer(timeInterval: Self.usageRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshUsage() }
        }
        RunLoop.main.add(timer, forMode: .common)
        usageTimer = timer
    }

    /// Called when the panel opens: the numbers should be current every time it is
    /// looked at. The short guard only absorbs a reopen within a couple of seconds.
    func refreshUsageOnOpen() {
        guard let fetchedAt = usage?.fetchedAt else { return refreshUsage() }
        guard Date().timeIntervalSince(fetchedAt) > 5 else { return }
        refreshUsage()
    }

    func refreshUsage() {
        guard let path = runtime.claudePath, !isLoadingUsage else { return }
        isLoadingUsage = true
        usageTask?.cancel()
        usageTask = Task { [weak self] in
            let reader = UsageReader(executablePath: path)
            let snapshot = try? await reader.read()
            await MainActor.run {
                guard let self else { return }
                if let snapshot, snapshot.hasAnything {
                    self.usage = snapshot
                    self.usageUnavailable = false
                } else {
                    self.usageUnavailable = true
                }
                self.isLoadingUsage = false
            }
        }
    }

    // MARK: - Sleep / wake

    private func registerSleepWakeObservers() {
        let center = NSWorkspace.shared.notificationCenter
        let wake = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.handleWake() }
        }
        observers.append(wake)
    }

    private func handleWake() async {
        guard runtime.claudePath != nil else { return }
        if let missed = missedWarmTime() {
            SettingsStore.lastScheduledWarmupAt = missed
            await warm(source: .wakeRecovery)
        }
        rescheduleNextWarmup()
    }

    /// Today's warm time if it passed while the Mac was asleep, within the grace period.
    private func missedWarmTime() -> Date? {
        let now = Date()
        guard let warmTime = DateCalculator.warmTime(onDayOf: now, settings: settings) else { return nil }
        guard warmTime <= now, now.timeIntervalSince(warmTime) <= Self.lateWarmGracePeriod else { return nil }
        guard !warmedRecently else { return nil }
        if let last = runtime.lastWarmupAt, last >= warmTime { return nil }
        return warmTime
    }
}

extension AppState {
    /// One shared instance: the menu bar scene and the AppKit settings window share it.
    static let shared = AppState()

    var menuBarSymbol: String {
        switch status {
        case .active: return "bolt.fill"
        case .warming: return "bolt.horizontal.fill"
        case .setupRequired: return "bolt.slash.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}
