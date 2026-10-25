import Foundation

// NovaBar 数据链路调试工具（不启动界面）：
//   .build/release/NovaBarCLI
// 从钥匙串读取登录会话 → 请求一次官方用量接口 → 打印解析结果与原始 JSON。
// 注意：任何情况下都不会打印登录凭证本身。

enum CLIExit {
    static let ok: Int32 = 0
    static let failure: Int32 = 1
    static let noSession: Int32 = 2
}

do {
    guard let cookie = CursorSessionStore.loadSession() else {
        print("❌ 未找到登录会话")
        print("   请先启动 NovaBar.app 完成一次 Cursor 登录，再运行本工具。")
        exit(CLIExit.noSession)
    }
    print("✅ 已从钥匙串读取登录会话")
    print("→ 请求 https://cursor.com/api/usage-summary ...")

    let client = CursorUsageClient()
    let (summary, rawJSON) = try await client.fetchSummary(cookie: cookie)
    print("✅ 请求成功\n")

    print("========== 解析结果 ==========")
    print("套餐类型   : \(summary.membershipType ?? "未知")")
    if let pool = summary.planPool {
        let limit = pool.limit.map { " / \(UsageFormat.money($0))" } ?? " / ∞"
        let percent = pool.percent.map { String(format: " (%.1f%%)", $0) } ?? ""
        print("订阅额度池 : \(UsageFormat.money(pool.used))\(limit)\(percent)")
    } else {
        print("订阅额度池 : 无数据")
    }
    if let pool = summary.onDemandPool {
        let limit = pool.limit.map { " / \(UsageFormat.money($0))" } ?? " / ∞"
        let percent = pool.percent.map { String(format: " (%.1f%%)", $0) } ?? ""
        print("按量额度池 : \(UsageFormat.money(pool.used))\(limit)\(percent)")
    }
    print("不限量账户 : \(summary.isUnlimited ? "是" : "否")")
    if let end = summary.billingCycleEnd {
        print("重置日期   : \(UsageFormat.resetDate(end))")
    }

    print("\n========== 原始 JSON（前 1500 字符，不含凭证） ==========")
    print(String(rawJSON.prefix(1500)))
} catch {
    print("❌ 失败：\(error.localizedDescription)")
    exit(CLIExit.failure)
}
