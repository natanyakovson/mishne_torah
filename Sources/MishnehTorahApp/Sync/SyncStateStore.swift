import Foundation

struct SyncState: Equatable {
    var lastContentVersion: Int
    var lastSuccessfulSyncAt: String?
    var schemaVersion: Int
}

protocol SyncStateStoring {
    func load() -> SyncState
    func save(_ state: SyncState)
}

final class UserDefaultsSyncStateStore: SyncStateStoring {
    private enum Key {
        static let lastContentVersion = "MTSyncLastContentVersion"
        static let lastSuccessfulSyncAt = "MTSyncLastSuccessfulSyncAt"
        static let schemaVersion = "MTSyncSchemaVersion"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> SyncState {
        SyncState(
            lastContentVersion: defaults.integer(forKey: Key.lastContentVersion),
            lastSuccessfulSyncAt: defaults.string(forKey: Key.lastSuccessfulSyncAt),
            schemaVersion: max(defaults.integer(forKey: Key.schemaVersion), 1)
        )
    }

    func save(_ state: SyncState) {
        defaults.set(state.lastContentVersion, forKey: Key.lastContentVersion)
        defaults.set(state.lastSuccessfulSyncAt, forKey: Key.lastSuccessfulSyncAt)
        defaults.set(state.schemaVersion, forKey: Key.schemaVersion)
    }
}

final class InMemorySyncStateStore: SyncStateStoring {
    private var state: SyncState

    init(state: SyncState = SyncState(lastContentVersion: 0, lastSuccessfulSyncAt: nil, schemaVersion: 1)) {
        self.state = state
    }

    func load() -> SyncState {
        state
    }

    func save(_ state: SyncState) {
        self.state = state
    }
}
