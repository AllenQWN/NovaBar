import Foundation
import Security

/// Cursor 登录会话的本地存储（macOS 钥匙串，加密保存，仅本应用可读）。
///
/// 保存内容是形如 `WorkosCursorSessionToken=xxx` 的 Cookie 头，
/// 由应用内嵌浏览器在用户登录成功后捕获。
public enum CursorSessionStore {
    private static let service = "app.novabar.cursor"
    private static let account = "usage-session"

    /// 保存会话（已存在则覆盖）
    public static func saveSession(_ cookieHeader: String) {
        SecItemDelete(baseQuery as CFDictionary)

        var attributes = baseQuery
        attributes[kSecValueData as String] = Data(cookieHeader.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    /// 读取会话，不存在返回 nil
    public static func loadSession() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty
        else { return nil }
        return value
    }

    /// 删除会话（退出登录）
    public static func deleteSession() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    public static var hasSession: Bool { loadSession() != nil }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
