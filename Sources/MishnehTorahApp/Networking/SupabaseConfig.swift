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

        guard let url = URL(string: urlString), let key, !key.isEmpty, !key.contains("$(") else {
            return nil
        }

        return SupabaseConfig(projectURL: url, publishableKey: key)
    }
}
