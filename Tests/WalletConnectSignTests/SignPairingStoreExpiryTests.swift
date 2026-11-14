import XCTest
@testable import WalletConnectSign
@testable import WalletConnectPairing
@testable import WalletConnectUtils

final class SignPairingStoreExpiryTests: XCTestCase {

    func testPairingClientHandlesExpiryOfPairingReadBySign() {
        let storage = RuntimeKeyValueStorage()
        let pairingClientStore = PairingStorage(storage: SequenceStore<WCPairing>(store: .init(defaults: storage, identifier: PairStorageIdentifiers.pairings.rawValue)))
        var expired: [String] = []
        pairingClientStore.onPairingExpiration = { expired.append($0.topic) }
        let signStore = SignClientFactory.makePairingStore(keyValueStorage: storage)
        signStore.onPairingExpiration = { _ in XCTFail("Sign's store should not handle expiry") }
        let pairing = WCPairing.stub(expiryDate: Date(timeIntervalSinceNow: -1))
        pairingClientStore.setPairing(pairing)

        XCTAssertTrue(signStore.getAll().isEmpty)
        XCTAssertNil(signStore.getPairing(forTopic: pairing.topic))

        XCTAssertTrue(pairingClientStore.getAll().isEmpty)
        XCTAssertEqual(expired, [pairing.topic])
    }
}
