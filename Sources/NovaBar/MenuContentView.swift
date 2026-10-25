import SwiftUI
import AppKit

/// 菜单栏按钮点击后弹出的用量面板
struct MenuContentView: View {
    @EnvironmentObject private var viewModel: UsageViewModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.tint)
                Text("NovaBar · Cursor 用量")
                    .font(.headline)
                Spacer()
            }

            mainSection

            Divider()

            HStack(spacing: 10) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.state == .loading || !viewModel.hasSession)

                if let last = viewModel.lastUpdated {
                    Text("更新于")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(last, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 14) {
                Button {
                    if let url = URL(string: "https://cursor.com/dashboard?tab=usage") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Dashboard", systemImage: "safari")
                }

                Button {
                    // 菜单栏 App 是 accessory 策略，必须先激活，否则设置窗口会被压在后面
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                } label: {
                    Label("设置", systemImage: "gearshape")
                }

                Spacer()

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Text("退出")
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 320)
        .onAppear { viewModel.refreshIfStale() }
    }

    @ViewBuilder
    private var mainSection: some View {
        if !viewModel.hasSession {
            loginPrompt
        } else if viewModel.needsRelogin {
            reloginPrompt
        } else if case .failed(let message) = viewModel.state, viewModel.summary == nil {
            errorView(message)
        } else {
            usageCard
        }
    }

    private var usageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let summary = viewModel.summary {
                if let pool = summary.planPool {
                    poolCard(pool: pool, resetsAt: summary.billingCycleEnd)
                }
                if let onDemand = summary.onDemandPool {
                    onDemandRow(onDemand)
                }
                if summary.isUnlimited && summary.planPool == nil {
                    Label("账户额度不限量", systemImage: "infinity")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if let type = summary.membershipType, !type.isEmpty {
                    Text("套餐：\(type)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else if viewModel.state == .loading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在获取用量…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 10)
            }
        }
    }

    /// Dashboard 同款月度用量卡片
    private func poolCard(pool: UsagePool, resetsAt: Date?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Monthly Usage")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(UsageFormat.money(pool.used))
                    .font(.system(size: 24, weight: .semibold))
                if let limit = pool.limit {
                    Text("/ \(UsageFormat.money(limit))")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(UsageFormat.percentText(pool.percent))
                    .font(.system(size: 15, weight: .medium).monospacedDigit())
                    .foregroundStyle(color(for: pool.percent))
            }
            ProgressView(value: (pool.percent ?? 0) / 100)
                .tint(color(for: pool.percent))
            if let resetsAt {
                Text("Resets \(UsageFormat.resetDate(resetsAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func onDemandRow(_ pool: UsagePool) -> some View {
        HStack {
            Text("按量额度 (On-demand)")
                .font(.callout)
            Spacer()
            Text(UsageFormat.money(pool.used) + (pool.limit.map { " / \(UsageFormat.money($0))" } ?? ""))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
            Text(UsageFormat.percentText(pool.percent))
                .font(.callout.monospacedDigit().weight(.medium))
                .foregroundStyle(color(for: pool.percent))
                .frame(minWidth: 38, alignment: .trailing)
        }
    }

    private var loginPrompt: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.crop.circle.badge.clock")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text("尚未登录 Cursor")
                .font(.headline)
            Text("登录一次后自动显示用量。\n凭证只保存在本机钥匙串。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                openLogin()
            } label: {
                Label("登录 Cursor", systemImage: "person.crop.circle.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private var reloginPrompt: some View {
        VStack(spacing: 8) {
            Label("登录已过期", systemImage: "exclamationmark.triangle")
                .font(.headline)
                .foregroundStyle(.orange)
            Text("请重新登录以继续显示用量。")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                openLogin()
            } label: {
                Label("重新登录", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Label("获取用量失败", systemImage: "wifi.exclamationmark")
                .font(.headline)
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("重试") {
                Task { await viewModel.refresh() }
            }
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private func color(for percent: Double?) -> Color {
        guard let percent else { return .accentColor }
        switch percent {
        case ..<60: return .green
        case ..<85: return .orange
        default: return .red
        }
    }

    private func openLogin() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "login")
    }
}
