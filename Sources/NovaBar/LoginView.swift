import SwiftUI
import WebKit
import AppKit

/// 内嵌浏览器登录窗口：加载 Cursor 官网登录页，
/// 登录成功（捕获到会话 Cookie）后自动关闭。
struct LoginView: View {
    @EnvironmentObject private var viewModel: UsageViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var captured = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.tint)
                Text("登录 Cursor")
                    .font(.headline)
                Text("登录成功后本窗口自动关闭；凭证只保存在本机钥匙串")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding(12)

            Divider()

            CursorLoginWebView { cookieHeader in
                guard !captured else { return }
                captured = true
                viewModel.completeLogin(cookieHeader: cookieHeader)
                dismiss()
            }
        }
        .onAppear { NSApp.activate(ignoringOtherApps: true) }
    }
}

/// WKWebView 封装：每次页面加载时检查会话 Cookie 是否已出现
struct CursorLoginWebView: NSViewRepresentable {
    let onSessionCaptured: (String) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        if let url = URL(string: "https://cursor.com/login") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSessionCaptured: onSessionCaptured)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onSessionCaptured: (String) -> Void
        private var captured = false

        init(onSessionCaptured: @escaping (String) -> Void) {
            self.onSessionCaptured = onSessionCaptured
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            checkCookies(webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            checkCookies(webView)
        }

        private func checkCookies(_ webView: WKWebView) {
            guard !captured else { return }
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self, !self.captured else { return }
                guard let cookie = cookies.first(where: { $0.name == "WorkosCursorSessionToken" }) else {
                    return
                }
                self.captured = true
                let header = "WorkosCursorSessionToken=\(cookie.value)"
                DispatchQueue.main.async {
                    self.onSessionCaptured(header)
                }
            }
        }
    }
}
