import AppKit
import SwiftUI

@main
struct ClaudePrewarmApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var state = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                openSettings: { delegate.showSettings() },
                quit: { NSApp.terminate(nil) }
            )
            .environmentObject(state)
        } label: {
            Image(nsImage: MenuBarIcon.image(for: state.status))
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState.shared
    private lazy var settingsWindow = SettingsWindowController(state: state)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        state.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        state.stop()
    }

    func showSettings() {
        // The CLI may have been installed since launch.
        state.recheckClaudeBinary()
        settingsWindow.show()
    }
}
