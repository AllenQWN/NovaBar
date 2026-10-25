import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 菜单栏应用：不显示 Dock 图标
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct NovaBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel: UsageViewModel
    @AppStorage("iconOnly") private var iconOnly = false

    init() {
        let vm = UsageViewModel()
        _viewModel = StateObject(wrappedValue: vm)
        // 启动即拉起首次刷新与定时器（面板的 onAppear 只在点开时触发，不够早）
        DispatchQueue.main.async { vm.bootstrap() }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(viewModel)
        } label: {
            if iconOnly {
                Image(systemName: "cursorarrow.rays")
            } else {
                Text(viewModel.menuBarLabel)
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
            }
        }
        .menuBarExtraStyle(.window)

        Window("登录 Cursor", id: "login") {
            LoginView()
                .environmentObject(viewModel)
        }
        .defaultSize(width: 960, height: 660)

        Settings {
            SettingsView()
                .environmentObject(viewModel)
        }
    }
}
