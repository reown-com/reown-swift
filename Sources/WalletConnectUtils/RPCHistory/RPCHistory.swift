import Foundation

public protocol RPCHistoryProtocol {
    
    func deleteAll(forTopic topic: String)
    
    func deleteAll(forTopics topics: [String])
}

public final class RPCHistory: RPCHistoryProtocol {

    public struct Record: Codable {
        public enum Origin: String, Codable {
            case local
            case remote
        }
        public enum TransportType: Codable {
            case relay
            case linkMode
        }
        public let id: RPCID
        public let topic: String
        let origin: Origin
        public let request: RPCRequest
        public let response: RPCResponse?
        public var timestamp: Date?
        public let transportType: TransportType?
    }

    enum HistoryError: Error, LocalizedError {
        case unidentifiedRequest
        case unidentifiedResponse
        case requestDuplicateNotAllowed
        case responseDuplicateNotAllowed
        case requestMatchingResponseNotFound
        var errorDescription: String? {
            switch self {
            case .unidentifiedRequest:
                return "Unidentified request."
            case .unidentifiedResponse:
                return "Unidentified response."
            case .requestDuplicateNotAllowed:
                return "Request duplicates are not allowed."
            case .responseDuplicateNotAllowed:
                return "Response duplicates are not allowed."
            case .requestMatchingResponseNotFound:
                return "Matching request for the response not found."
            }
        }
    }


    private let storage: CodableStore<Record>

    /// Serialises the check-then-act sequences in `set`, `validate` and `resolve`, so two deliveries
    /// of the same request can't both pass the duplicate check.
    private let lock = NSLock()

    /// When true, `resolve` keeps the record with its response instead of deleting it, so a
    /// re-delivered request (the relay can deliver a message more than once) is still rejected
    /// as a duplicate, also after an app restart. Resolved records are removed with their topic
    /// or after 30 days, and are hidden from every read below, which only return pending requests.
    private let keepsResolvedRecords: Bool

    /// Used instead of kept records when `keepsResolvedRecords` is false: ids of the most recently
    /// resolved requests, oldest first, in memory only.
    private var resolvedIds: [String] = []
    private var resolvedIdSet: Set<String> = []
    private let resolvedIdsLimit: Int

    init(keyValueStore: CodableStore<Record>, keepsResolvedRecords: Bool = true, resolvedIdsLimit: Int = 1000) {
        self.storage = keyValueStore
        self.keepsResolvedRecords = keepsResolvedRecords
        self.resolvedIdsLimit = resolvedIdsLimit

        removeOutdated()
    }

    /// The pending (not yet resolved) record for this id.
    public func get(recordId: RPCID) -> Record? {
        guard let record = storedRecord(recordId), record.response == nil else { return nil }
        return record
    }

    public func set(_ request: RPCRequest, forTopic topic: String, emmitedBy origin: Record.Origin, time: TimeProvider = DefaultTimeProvider(), transportType: RPCHistory.Record.TransportType) throws {
        guard let id = request.id else {
            throw HistoryError.unidentifiedRequest
        }
        lock.lock()
        defer { lock.unlock() }
        guard storedRecord(id) == nil, !resolvedIdSet.contains(id.string) else {
            throw HistoryError.requestDuplicateNotAllowed
        }
        let record = Record(id: id, topic: topic, origin: origin, request: request, response: nil, timestamp: time.currentDate, transportType: transportType)
        storage.set(record, forKey: "\(record.id)")
    }

    @discardableResult
    public func resolve(_ response: RPCResponse) throws -> Record {
        lock.lock()
        defer { lock.unlock() }
        let record = try validateLocked(response)
        if keepsResolvedRecords {
            let resolved = Record(id: record.id, topic: record.topic, origin: record.origin, request: record.request, response: response, timestamp: record.timestamp, transportType: record.transportType)
            storage.set(resolved, forKey: "\(record.id)")
        } else {
            storage.delete(forKey: "\(record.id)")
            markResolved(record.id)
        }
        return record
    }

    /// Whether a request with this id was already resolved.
    public func wasResolved(recordId: RPCID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return isResolved(recordId)
    }

    @discardableResult
    public func validate(_ response: RPCResponse) throws -> Record {
        lock.lock()
        defer { lock.unlock() }
        return try validateLocked(response)
    }

    private func validateLocked(_ response: RPCResponse) throws -> Record {
        guard let id = response.id else {
            throw HistoryError.unidentifiedResponse
        }
        if isResolved(id) {
            throw HistoryError.responseDuplicateNotAllowed
        }
        guard let record = storedRecord(id) else {
            throw HistoryError.requestMatchingResponseNotFound
        }
        return record
    }

    private func storedRecord(_ id: RPCID) -> Record? {
        try? storage.get(key: id.string)
    }

    private func isResolved(_ id: RPCID) -> Bool {
        resolvedIdSet.contains(id.string) || storedRecord(id)?.response != nil
    }

    private func markResolved(_ id: RPCID) {
        let key = id.string
        guard resolvedIdSet.insert(key).inserted else { return }
        resolvedIds.append(key)
        if resolvedIds.count > resolvedIdsLimit {
            resolvedIdSet.remove(resolvedIds.removeFirst())
        }
    }

    public func deleteAll(forTopics topics: [String]){
        storage.getAll().forEach { record in
            if topics.contains(record.topic) {
                storage.delete(forKey: "\(record.id)")
            }
        }
    }

    public func getAll<Object: Codable>(of type: Object.Type, topic: String) -> [Object] {
        return pendingRecords()
            .filter{$0.topic == topic}
            .compactMap { try? $0.request.params?.get(Object.self) }
    }

    public func getAll<Object: Codable>(of type: Object.Type) -> [Object] {
        return getAllWithIDs(of: type).map { $0.value }
    }

    public func getAllWithIDs<Object: Codable>(of type: Object.Type) -> [(id: RPCID, value: Object)] {
        return pendingRecords().compactMap { record in
            guard let object = try? record.request.params?.get(Object.self)
            else { return nil }
            return (record.id, object)
        }
    }

    public func delete(id: RPCID) {
        storage.delete(forKey: id.string)
    }

    public func deleteAll(forTopic topic: String) {
        deleteAll(forTopics: [topic])
    }

    public func getPending() -> [Record] {
        pendingRecords()
    }

    private func pendingRecords() -> [Record] {
        storage.getAll().filter { $0.response == nil }
    }

    public func deleteAll() {
        lock.lock()
        defer { lock.unlock() }
        storage.deleteAll()
        resolvedIds.removeAll()
        resolvedIdSet.removeAll()
    }
}

extension RPCHistory {

    func removeOutdated() {
        let records = storage.getAll()

        let thirtyDays: TimeInterval = 30*86400

        for var record in records {
            if let timestamp = record.timestamp {
                if timestamp.distance(to: Date()) > thirtyDays {
                    storage.delete(forKey: record.id.string)
                }
            } else {
                record.timestamp = Date()
                storage.set(record, forKey: "\(record.id)")
            }
        }
    }
}

#if DEBUG
class MockRPCHistory: RPCHistoryProtocol {
    var deletedTopics: [String] = []
    
    func deleteAll(forTopic topic: String) {
        deletedTopics.append(topic)
    }

    func deleteAll(forTopics topics: [String]) {
        deletedTopics.append(contentsOf: topics)
    }
}
#endif
