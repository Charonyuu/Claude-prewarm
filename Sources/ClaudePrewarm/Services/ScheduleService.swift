import Foundation

@MainActor
protocol ScheduleServicing {
    func calculateNextWarmup(settings: AppSettings, from date: Date) -> Date?
    func schedule(date: Date, action: @escaping () -> Void)
    func cancel()
}

/// One-shot timer for the next warm, plus a slow tick that catches clock drift
/// and timers that never fired (sleep, suspended run loop).
@MainActor
final class ScheduleService: ScheduleServicing {
    private var timer: Timer?
    private var tick: Timer?
    private var pendingDate: Date?
    private var pendingAction: (() -> Void)?

    func calculateNextWarmup(settings: AppSettings, from date: Date) -> Date? {
        DateCalculator.nextWarmup(settings: settings, from: date)
    }

    func schedule(date: Date, action: @escaping () -> Void) {
        cancel()
        pendingDate = date
        pendingAction = action

        let timer = Timer(fire: date, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.fire() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        let tick = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let due = self.pendingDate else { return }
                if Date() >= due { self.fire() }
            }
        }
        RunLoop.main.add(tick, forMode: .common)
        self.tick = tick
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        tick?.invalidate()
        tick = nil
        pendingDate = nil
        pendingAction = nil
    }

    private func fire() {
        guard let action = pendingAction else { return }
        cancel()
        action()
    }
}
