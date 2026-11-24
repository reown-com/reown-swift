import Foundation

public protocol SequenceObject: Codable {
    var expiryDate: Date { get }
    var topic: String { get }
}

public final class SequenceStore<T> where T: SequenceObject {

    public var onSequenceUpdate: (() -> Void)?
    public var onSequenceExpiration: ((_ sequence: T) -> Void)?

    private let store: CodableStore<T>
    private let dateInitializer: () -> Date
    private let handlesExpiry: Bool
    private var expiryMonitorTimer: Timer?

    /// - Parameter handlesExpiry: Pass `false` for a store that reads the same storage as another
    ///   `SequenceStore` that handles expiry. Expired sequences are then skipped but not deleted,
    ///   `onSequenceExpiration` is never called and no expiry timer runs.
    public init(store: CodableStore<T>, dateInitializer: @escaping () -> Date = Date.init, handlesExpiry: Bool = true) {
        self.store = store
        self.dateInitializer = dateInitializer
        self.handlesExpiry = handlesExpiry
        if handlesExpiry {
            startExpiryMonitor()
        }
    }

    public func hasSequence(forTopic topic: String) -> Bool {
        (try? getSequence(forTopic: topic)) != nil
    }

    public func setSequence(_ sequence: T) {
        store.set(sequence, forKey: sequence.topic)
        onSequenceUpdate?()
    }

    public func getSequence(forTopic topic: String) throws -> T? {
        guard let value = try store.get(key: topic) else { return nil }
        return verifyExpiry(on: value)
    }

    public func getAll() -> [T] {
        let values = store.getAll()
        return values.compactMap { verifyExpiry(on: $0) }
    }

    public func delete(topic: String) {
        store.delete(forKey: topic)
        onSequenceUpdate?()
    }

    public func deleteAll() {
        store.deleteAll()
        onSequenceUpdate?()
    }

    // MARK: Expiry Monitor

    private func startExpiryMonitor() {
        expiryMonitorTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.checkAllSequencesForExpiry()
        }
    }

    private func checkAllSequencesForExpiry() {
        let allSequences = getAll()
        allSequences.forEach { _ = verifyExpiry(on: $0) }
    }
}

// MARK: Privates

private extension SequenceStore {

    func verifyExpiry(on sequence: T) -> T? {
        let now = dateInitializer()
        guard now >= sequence.expiryDate else {
            return sequence
        }
        if handlesExpiry {
            delete(topic: sequence.topic)
            onSequenceExpiration?(sequence)
        }
        return nil
    }
}
