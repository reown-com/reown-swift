import Foundation

final class PairingCleanupService {

    private let pairingStore: WCPairingStorage
    private let kms: KeyManagementServiceProtocol
    private let networkInteractor: NetworkInteracting

    init(pairingStore: WCPairingStorage, kms: KeyManagementServiceProtocol, networkInteractor: NetworkInteracting) {
        self.pairingStore = pairingStore
        self.kms = kms
        self.networkInteractor = networkInteractor
    }

    func cleanup() throws {
        let topics = pairingStore.getAll().map { $0.topic }
        topics.forEach { networkInteractor.unsubscribe(topic: $0) }
        pairingStore.deleteAll()
        try kms.deleteAll()
    }
}
