import Foundation

protocol SyncLogging {
    func debug(_ message: String)
}

struct ConsoleSyncLogger: SyncLogging {
    func debug(_ message: String) {
        #if DEBUG
        print("[Sync] \(message)")
        #endif
    }
}

final class CapturingSyncLogger: SyncLogging {
    private(set) var messages: [String] = []

    func debug(_ message: String) {
        messages.append(message)
    }
}
