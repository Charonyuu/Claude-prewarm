import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var state: AppState
    let openSettings: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(Theme.divider).padding(.vertical, 12)
            infoRows
            if let error = state.runtime.lastError {
                errorBox(error)
            }
            actionButton
            if let hint = state.warmNowHint {
                Text(hint)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.label)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
            Divider().overlay(Theme.divider).padding(.vertical, 12)
            limitsBlock
            Divider().overlay(Theme.divider).padding(.vertical, 12)
            MenuRow(icon: "gearshape.fill", title: "Settings…", action: openSettings)
            MenuRow(icon: "power", title: "Quit", action: quit)
        }
        .padding(16)
        .frame(width: 300)
        .onAppear { state.refreshUsageOnOpen() }
    }

    private var limitsBlock: some View {
        VStack(alignment: .leading, spacing: 11) {
            if state.usageUnavailable && state.usage == nil {
                Text("Usage limits unavailable.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.label)
            } else {
                LimitBar(
                    title: "5h limit",
                    percent: state.usage?.sessionPercent,
                    detail: state.resetLabel(for: state.usage?.sessionResetAt, raw: state.usage?.sessionResetRaw),
                    isRefreshing: state.isLoadingUsage
                )
                LimitBar(
                    title: "Weekly limit",
                    percent: state.usage?.weeklyPercent,
                    detail: state.resetLabel(for: state.usage?.weeklyResetAt, raw: state.usage?.weeklyResetRaw),
                    isRefreshing: state.isLoadingUsage
                )
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            AppMark(size: 46)
            VStack(alignment: .leading, spacing: 4) {
                Text("Claude Prewarm")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.title)
                HStack(spacing: 6) {
                    Circle()
                        .fill(Theme.statusColor(state.status))
                        .frame(width: 8, height: 8)
                    Text(state.status.label)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.label)
                }
            }
            Spacer(minLength: 0)
            if state.isLoadingUsage {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.8)
            }
        }
        .frame(height: 46)
    }

    private var infoRows: some View {
        VStack(spacing: 9) {
            InfoRow(label: "Next warmup", value: state.nextWarmupLabel)
            InfoRow(label: "Work starts", value: state.workStartLabel)
            InfoRow(label: "Claude resets around", value: state.expectedResetLabel)
        }
    }

    private func errorBox(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 11))
            .foregroundStyle(Theme.danger)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(9)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Theme.danger.opacity(0.12))
            )
            .padding(.top, 12)
    }

    @ViewBuilder
    private var actionButton: some View {
        switch state.setupAction {
        case .installCLI:
            Button(action: state.openInstallInstructions) {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.down.circle.fill").font(.system(size: 12, weight: .bold))
                    Text("Install Claude Code")
                }
            }
            .buttonStyle(AccentButtonStyle(height: 40))
            .padding(.top, 14)
        case .signIn:
            Button(action: state.openTerminalToSignIn) {
                HStack(spacing: 7) {
                    Image(systemName: "terminal.fill").font(.system(size: 12, weight: .bold))
                    Text("Sign in to Claude")
                }
            }
            .buttonStyle(AccentButtonStyle(height: 40))
            .padding(.top, 14)
        case .none:
            warmButton
        }
    }

    private var warmButton: some View {
        Button {
            Task { await state.warmNow() }
        } label: {
            HStack(spacing: 7) {
                if state.runtime.isWarming {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                    Text("Warming…")
                } else {
                    Image(systemName: "play.fill").font(.system(size: 11, weight: .bold))
                    Text("Warm Now")
                }
            }
        }
        .buttonStyle(AccentButtonStyle(height: 40))
        .disabled(!state.canWarmNow)
        .padding(.top, 14)
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Theme.label)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.value)
        }
    }
}

/// One limit: name, percent used, a bar, and when it resets.
private struct LimitBar: View {
    let title: String
    let percent: Int?
    let detail: String
    let isRefreshing: Bool

    private var fraction: Double { Double(min(max(percent ?? 0, 0), 100)) / 100 }

    private var barColor: Color {
        switch percent ?? 0 {
        case ..<70: return Theme.accent
        case ..<90: return Theme.warning
        default: return Theme.danger
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.label)
                Spacer(minLength: 12)
                Text(percent.map { "\($0)% used" } ?? (isRefreshing ? "Checking…" : "—"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(percent == nil ? Theme.label : Theme.value)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.chipOff)
                    Capsule()
                        .fill(barColor)
                        .frame(width: max(geometry.size.width * fraction, percent == nil ? 0 : 4))
                }
            }
            .frame(height: 5)
            if percent != nil {
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.label)
            }
        }
    }
}

private struct MenuRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .frame(width: 18)
                Text(title).font(.system(size: 13))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.title)
            .padding(.vertical, 7)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(hovering ? Theme.rowHover : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
