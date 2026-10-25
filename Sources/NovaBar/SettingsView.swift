import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject private var viewModel: UsageViewModel
    @Environment(\.openWindow) private var openWindow

    @AppStorage("refreshMinutes") private var refreshMinutes = 5
    @AppStorage("iconOnly") private var iconOnly = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchError: String?

    var body: some View {
        Form {
            Section("刷新") {
                Picker("自动刷新间隔", selection: $refreshMinutes) {
                    Text("1 分钟").tag(1)
                    Text("5 分钟").tag(5)
                    Text("15 分钟").tag(15)
                    Text("30 分钟").tag(30)
                }
                .onChange(of: refreshMinutes) { _, _ in
                    viewModel.restartTimer()
                }
            }

            Section("菜单栏") {
                Toggle("只显示图标（不显示百分比）", isOn: $iconOnly)
            }

            Section("账户") {
                LabeledContent("登录状态") {
                    Text(
                        viewModel.needsRelogin
                            ? "已过期，请重新登录"
                            : (viewModel.hasSession ? "已登录" : "未登录")
                    )
                }
                HStack {
                    Button("登录 / 重新登录") {
                        NSApp.activate(ignoringOtherApps: true)
                        openWindow(id: "login")
                    }
                    Button("退出登录", role: .destructive) {
                        viewModel.logout()
                    }
                    .disabled(!viewModel.hasSession)
                }
            }

            Section("通用") {
                Toggle("macOS 登录时自动启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        toggleLaunchAtLogin(enabled)
                    }
                if let launchError {
                    Text(launchError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 430)
    }

    private func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchError = nil
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            launchError = "设置失败：\(error.localizedDescription)（需使用打包后的 NovaBar.app）"
        }
    }
}
