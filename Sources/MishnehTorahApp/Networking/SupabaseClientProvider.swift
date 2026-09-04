import Foundation
import Supabase

enum SupabaseClientProvider {
    static func makeClient(config: SupabaseConfig) -> SupabaseClient {
        SupabaseClient(supabaseURL: config.projectURL, supabaseKey: config.publishableKey)
    }
}
