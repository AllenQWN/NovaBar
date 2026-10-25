import Foundation

// MARK: - 数据模型

/// 一个额度池（金额单位：美元；percent 取值 0-100）
public struct UsagePool: Sendable, Equatable {
    public let used: Double
    public let limit: Double?
    public let percent: Double?

    public init(used: Double, limit: Double?, percent: Double?) {
        self.used = used
        self.limit = limit
        self.percent = percent
    }
}

/// 一次用量快照（与 cursor.com/dashboard 展示口径一致）
public struct UsageSummary: Sendable, Equatable {
    public let membershipType: String?
    public let billingCycleEnd: Date?
    public let isUnlimited: Bool
    /// 订阅额度池（Monthly Usage）
    public let planPool: UsagePool?
    /// 按量额度池（On-demand）
    public let onDemandPool: UsagePool?

    /// 菜单栏优先展示的额度池：订阅池优先，其次按量池
    public var primaryPool: UsagePool? { planPool ?? onDemandPool }

    public init(
        membershipType: String?,
        billingCycleEnd: Date?,
        isUnlimited: Bool,
        planPool: UsagePool?,
        onDemandPool: UsagePool?
    ) {
        self.membershipType = membershipType
        self.billingCycleEnd = billingCycleEnd
        self.isUnlimited = isUnlimited
        self.planPool = planPool
        self.onDemandPool = onDemandPool
    }
}

// MARK: - 解析（字段口径参考 cursor.com Dashboard 及开源实现）

enum UsageSummaryParser {
    static func parse(_ json: [String: Any]) -> UsageSummary {
        let individual = json["individualUsage"] as? [String: Any]
        let team = json["teamUsage"] as? [String: Any]

        // 订阅额度池：优先 individualUsage.plan；
        // 企业/团队账号可能只有 overall（个人上限）或 pooled（团队共享池）
        let planPool = pool(individual?["plan"] as? [String: Any])
            ?? pool(individual?["overall"] as? [String: Any])
            ?? pool(team?["pooled"] as? [String: Any])
        let onDemandPool = pool(individual?["onDemand"] as? [String: Any])

        return UsageSummary(
            membershipType: json["membershipType"] as? String,
            billingCycleEnd: date(json["billingCycleEnd"] as? String),
            isUnlimited: json["isUnlimited"] as? Bool ?? false,
            planPool: planPool,
            onDemandPool: onDemandPool)
    }

    /// used/limit 单位是"美分"，转换为美元；
    /// 百分比优先用接口直接给出的字段（其本身就是百分比单位，如 86.2 表示 86.2%）
    private static func pool(_ dict: [String: Any]?) -> UsagePool? {
        guard let dict else { return nil }
        if let enabled = dict["enabled"] as? Bool, !enabled { return nil }

        let used = (number(dict["used"]) ?? 0) / 100
        let limit = number(dict["limit"]).map { $0 / 100 }

        var percent: Double?
        if let total = number(dict["totalPercentUsed"]) {
            percent = clampPercent(total)
        } else if let auto = number(dict["autoPercentUsed"]).map(clampPercent),
                  let api = number(dict["apiPercentUsed"]).map(clampPercent) {
            percent = (auto + api) / 2
        } else if let api = number(dict["apiPercentUsed"]).map(clampPercent) {
            percent = api
        } else if let auto = number(dict["autoPercentUsed"]).map(clampPercent) {
            percent = auto
        } else if let limit, limit > 0 {
            percent = clampPercent(used / limit * 100)
        }

        if used == 0, limit == nil, percent == nil { return nil }
        return UsagePool(used: used, limit: limit, percent: percent)
    }

    private static func number(_ any: Any?) -> Double? {
        if let n = any as? NSNumber { return n.doubleValue }
        if let n = any as? Double { return n }
        if let n = any as? Int { return Double(n) }
        if let s = any as? String { return Double(s) }
        return nil
    }

    private static func clampPercent(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }

    private static func date(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = formatter.date(from: raw) { return parsed }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: raw)
    }
}

// MARK: - 显示格式

public enum UsageFormat {
    /// 431.2 → "$431.20"；500 → "$500"
    public static func money(_ value: Double) -> String {
        abs(value - value.rounded()) < 0.005
            ? "$\(Int(value.rounded()))"
            : String(format: "$%.2f", value)
    }

    /// "Oct 1, 2026"（与 Dashboard 英文格式一致）
    public static func resetDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    /// 86.2 → "86%"
    public static func percentText(_ percent: Double?) -> String {
        guard let percent else { return "--" }
        return "\(Int(percent.rounded()))%"
    }
}

// MARK: - 用量接口客户端

public struct CursorUsageClient: Sendable {
    public enum Failure: Swift.Error, Equatable, LocalizedError {
        case unauthorized
        case http(Int)
        case badResponse

        public var errorDescription: String? {
            switch self {
            case .unauthorized: return "登录会话已过期，请重新登录"
            case .http(let code): return "Cursor 接口返回 HTTP \(code)"
            case .badResponse: return "Cursor 接口返回内容无法解析"
            }
        }
    }

    public init() {}

    /// 携带登录会话请求官方用量接口，返回解析结果 + 原始 JSON（调试用）。
    /// 注意：cookie 只在内存中传递，不会写日志。
    public func fetchSummary(cookie: String) async throws -> (summary: UsageSummary, rawJSON: String) {
        var request = URLRequest(url: URL(string: "https://cursor.com/api/usage-summary")!)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw Failure.badResponse }
        switch http.statusCode {
        case 200: break
        case 401, 403: throw Failure.unauthorized
        case let code: throw Failure.http(code)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Failure.badResponse
        }
        return (UsageSummaryParser.parse(json), String(data: data, encoding: .utf8) ?? "")
    }
}
