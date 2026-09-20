import AppKit
import SwiftUI

/// The menu bar image. Drawn in colour rather than as a template, so it stands
/// out in a crowded menu bar and carries the status at a glance.
enum MenuBarIcon {
    static func image(for status: AppStatus) -> NSImage {
        let symbol = symbolName(for: status)
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .bold)
        guard let base = NSImage(systemSymbolName: symbol, accessibilityDescription: "Claude Prewarm")?
            .withSymbolConfiguration(config)
        else { return NSImage() }

        let tint = NSColor(color(for: status))
        let size = base.size
        let tinted = NSImage(size: size, flipped: false) { rect in
            base.draw(in: rect)
            tint.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        tinted.isTemplate = false
        return tinted
    }

    private static func symbolName(for status: AppStatus) -> String {
        switch status {
        case .active: return "bolt.fill"
        case .warming: return "bolt.horizontal.fill"
        case .setupRequired: return "bolt.slash.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private static func color(for status: AppStatus) -> Color {
        switch status {
        case .active, .warming: return Theme.accent
        case .setupRequired: return Theme.warning
        case .error: return Theme.danger
        }
    }
}
