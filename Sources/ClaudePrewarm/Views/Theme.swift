import SwiftUI

/// One palette, two schemes. Every colour used by the UI comes from here.
enum Theme {
    static let accent = Color(light: Color(red: 0.94, green: 0.42, blue: 0.13),
                              dark: Color(red: 0.98, green: 0.49, blue: 0.19))
    static let accentPressed = Color(light: Color(red: 0.85, green: 0.36, blue: 0.09),
                                     dark: Color(red: 0.90, green: 0.43, blue: 0.14))
    static let accentGradient = LinearGradient(
        colors: [Color(red: 0.98, green: 0.55, blue: 0.24), Color(red: 0.91, green: 0.36, blue: 0.10)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let title = Color.primary
    static let label = Color.secondary
    static let value = Color.primary
    static let online = Color(light: Color(red: 0.20, green: 0.72, blue: 0.35),
                              dark: Color(red: 0.30, green: 0.83, blue: 0.45))
    static let warning = Color(light: Color(red: 0.87, green: 0.60, blue: 0.10),
                               dark: Color(red: 0.97, green: 0.72, blue: 0.22))
    static let danger = Color(light: Color(red: 0.80, green: 0.22, blue: 0.18),
                              dark: Color(red: 0.96, green: 0.42, blue: 0.38))

    static let chipOff = Color(light: Color(white: 0.93), dark: Color(white: 0.24))
    static let chipOffText = Color(light: Color(white: 0.45), dark: Color(white: 0.72))
    static let rowHover = Color(light: Color.black.opacity(0.05), dark: Color.white.opacity(0.08))
    static let divider = Color(light: Color.black.opacity(0.09), dark: Color.white.opacity(0.12))
    static let fieldBackground = Color(light: .white, dark: Color(white: 0.20))
    static let fieldBorder = Color(light: Color.black.opacity(0.14), dark: Color.white.opacity(0.16))

    static func statusColor(_ status: AppStatus) -> Color {
        switch status {
        case .active: return online
        case .warming: return accent
        case .setupRequired: return warning
        case .error: return danger
        }
    }
}

extension Color {
    /// Resolves per appearance, so one declaration covers both schemes.
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(isDark ? dark : light)
        })
    }
}

/// The orange app mark: a rounded tile with a bolt.
struct AppMark: View {
    var size: CGFloat = 46

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(Theme.accentGradient)
            .overlay(
                Image(systemName: "bolt.fill")
                    .font(.system(size: size * 0.46, weight: .bold))
                    .foregroundStyle(.white)
            )
            .frame(width: size, height: size)
            .shadow(color: Theme.accent.opacity(0.35), radius: 6, y: 2)
    }
}

/// Filled orange button used for Warm Now and Save.
struct AccentButtonStyle: ButtonStyle {
    var height: CGFloat = 38
    var fullWidth: Bool = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: height)
            .padding(.horizontal, fullWidth ? 0 : 22)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(configuration.isPressed ? Theme.accentPressed : Theme.accent)
            )
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}
