import Foundation

public struct RPCHistoryFactory {

    private static let networkIdentifier = "com.walletconnect.sdk.wc_jsonRpcHistoryRecord"
    private static let relayIdentifier = "com.walletconnect.sdk.relayer_client.subscription_json_rpc_record"

    /// Keeps resolved requests (like the Kotlin and JS SDKs), so a re-delivered request is
    /// rejected as a duplicate even after an app restart.
    public static func createForNetwork(keyValueStorage: KeyValueStorage) -> RPCHistory {
        return RPCHistoryFactory.create(keyValueStorage: keyValueStorage, identifier: RPCHistoryFactory.networkIdentifier, keepsResolvedRecords: true)
    }

    /// The relay client resolves an ack for every incoming message, so keeping those records
    /// would grow storage with every message. It remembers recently resolved ids in memory instead.
    public static func createForRelay(keyValueStorage: KeyValueStorage) -> RPCHistory {
        return RPCHistoryFactory.create(keyValueStorage: keyValueStorage, identifier: RPCHistoryFactory.relayIdentifier, keepsResolvedRecords: false)
    }

    static func create(keyValueStorage: KeyValueStorage, identifier: String, keepsResolvedRecords: Bool) -> RPCHistory {
        let keyValueStore = CodableStore<RPCHistory.Record>(defaults: keyValueStorage, identifier: identifier)
        return RPCHistory(keyValueStore: keyValueStore, keepsResolvedRecords: keepsResolvedRecords)
    }
}
