import AppKit
import SwiftUI

/// The settings window is plain AppKit so it never opens by itself at launch,
/// the way a SwiftUI `Window` scene would in a menu-bar-only app.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let state: AppState
    private static let frameName = "ClaudePrewarmSettingsWindow"

    init(state: AppState) {
        self.state = state
    }

    func show() {
        if window == nil { window = makeWindow() }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
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

        // Keep wherever the user last dragged it; only place it ourselves the first time.
        let restored = window.setFrameUsingName(Self.frameName)
        window.setFrameAutosaveName(Self.frameName)
        if !restored { center(window) }
        return window
    }

    /// `NSWindow.center()` sits a third of the way down, which lands under the
    /// menu bar panel. Put it in the actual middle of the active screen instead.
    private func center(_ window: NSWindow) {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let size = window.frame.size
        window.setFrameOrigin(
            NSPoint(
                x: visible.midX - size.width / 2,
                y: visible.midY - size.height / 2
            )
        )
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
