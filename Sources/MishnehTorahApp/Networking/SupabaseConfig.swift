import Foundation

struct SupabaseConfig: Equatable {
    static let projectURLInfoKey = "MTSupabaseProjectURL"
    static let publishableKeyInfoKey = "MTSupabasePublishableKey"

    let projectURL: URL
    let publishableKey: String

    static var bundled: SupabaseConfig? {
        let info = Bundle.main.infoDictionary ?? [:]
        let urlString = (info[projectURLInfoKey] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? "https://inlmifnzboisiazbeuqk.supabase.co"
        let key = (info[publishableKeyInfoKey] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ProcessInfo.processInfo.environment["SUPABASE_PUBLISHABLE_KEY"]?
                .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: urlString), url.scheme == "https", url.host != nil,
              let key, isPublicKey(key) else {
            return nil
        }

        return SupabaseConfig(projectURL: url, publishableKey: key)
    }

    static func isPublicKey(_ key: String) -> Bool {
        if key.hasPrefix("sb_publishable_"), key.count > 15, !key.contains("$(") { return true }
        let parts = key.split(separator: ".")
        guard parts.count == 3 else { return false }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        return claims["role"] as? String == "anon"
    }
}
