import Foundation
import SwiftUI

@MainActor
final class UsageViewModel: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    @Published private(set) var state: LoadState = .idle
    @Published private(set) var summary: UsageSummary?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var hasSession: Bool
    @Published private(set) var needsRelogin = false

    private let client = CursorUsageClient()
    private var timer: Timer?
    private var bootstrapped = false

    init() {
        hasSession = CursorSessionStore.loadSession() != nil
    }

    // MARK: 生命周期

    /// App 启动时调用：首次拉取 + 启动定时刷新（幂等）
    func bootstrap() {
        guard !bootstrapped else { return }
        bootstrapped = true
        if hasSession {
            Task { await refresh() }
        }
        restartTimer()
    }

    /// 按设置里的间隔启动定时刷新
    func restartTimer() {
        timer?.invalidate()
        let stored = UserDefaults.standard.object(forKey: "refreshMinutes") as? Int ?? 5
        let minutes = max(1, stored)
        timer = Timer.scheduledTimer(withTimeInterval: Double(minutes * 60), repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.refresh()
            }
        }
    }

    // MARK: 数据

    func refresh() async {
        guard let cookie = CursorSessionStore.loadSession() else {
            hasSession = false
            state = .idle
            return
        }
        hasSession = true
        state = .loading
        do {
            let (newSummary, _) = try await client.fetchSummary(cookie: cookie)
            summary = newSummary
            lastUpdated = Date()
            needsRelogin = false
            state = .loaded
        } catch CursorUsageClient.Failure.unauthorized {
            needsRelogin = true
            state = .failed("登录已过期，请重新登录")
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// 打开面板时调用：数据足够新（< 60 秒）就不重复请求
    func refreshIfStale() {
        bootstrap()
        guard state != .loading else { return }
        if let last = lastUpdated, Date().timeIntervalSince(last) < 60 { return }
        if hasSession {
            Task { await refresh() }
        }
    }

    /// 内嵌浏览器登录成功后回调
    func completeLogin(cookieHeader: String) {
        CursorSessionStore.saveSession(cookieHeader)
        hasSession = true
        needsRelogin = false
        Task { await refresh() }
    }

    func logout() {
        CursorSessionStore.deleteSession()
        hasSession = false
        needsRelogin = false
        summary = nil
        lastUpdated = nil
        state = .idle
    }

    // MARK: 菜单栏显示

    var menuBarLabel: String {
        if needsRelogin { return "⚠︎" }
        if case .failed = state, summary == nil { return "⚠︎" }
        guard let summary else { return hasSession ? "…" : "Cursor" }
        if summary.isUnlimited, summary.primaryPool == nil { return "∞" }
        guard let percent = summary.primaryPool?.percent else { return "Cursor" }
        return UsageFormat.percentText(percent)
    }
}
