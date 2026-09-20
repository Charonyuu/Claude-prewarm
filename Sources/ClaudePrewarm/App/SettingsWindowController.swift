import AppKit
import SwiftUI

/// The settings window is plain AppKit so it never opens by itself at launch,
/// the way a SwiftUI `Window` scene would in a menu-bar-only app.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let state: AppState

    init(state: AppState) {
        self.state = state
    }

    func show() {
        if window == nil { window = makeWindow() }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
        didClose()
    }

    fileprivate func didClose() {
        NSApp.setActivationPolicy(.accessory)
    }

    private func makeWindow() -> NSWindow {
        let root = SettingsView(close: { [weak self] in self?.close() })
            .environmentObject(state)
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Claude Prewarm"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = WindowDelegate.shared
        WindowDelegate.shared.controller = self
        return window
    }
}

private final class WindowDelegate: NSObject, NSWindowDelegate {
    static let shared = WindowDelegate()
    weak var controller: AnyObject?

    func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            (controller as? SettingsWindowController)?.didClose()
        }
    }
}
