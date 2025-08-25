import Combine
import Foundation
import YttriumWrapper
import WalletConnectKMS
import WalletConnectUtils
import WalletConnectPairing
import WalletConnectSign


class SessionStoreImpl: SessionStore {
    public var onSessionsUpdate: (() -> Void)?
    
    private let store: CodableStore<CodableSession>
    private let kms: KeyManagementServiceProtocol

    init(defaults: KeyValueStorage = UserDefaults.standard,
         kms: KeyManagementServiceProtocol) {
        self.store = CodableStore<CodableSession>(
            defaults: defaults,
            identifier: SignStorageIdentifiers.sessions.rawValue
        )
        self.kms = kms
    }

    func addSession(session: Yttrium.SessionFfi) {
        // Convert to CodableSession and store
        guard let codable = session.toCodableSession() else {
            print("SessionStore: Failed to convert SessionFfi to CodableSession")
            return
        }
        store.set(codable, forKey: codable.topic)
        let symKey = try! SymmetricKey(rawRepresentation: session.sessionSymKey)
        try! kms.setSymmetricKey(symKey, for: session.topic)
        onSessionsUpdate?()
    }

    func deleteSession(topic: String) {
        store.delete(forKey: topic)
        onSessionsUpdate?()
    }

    func getSession(topic: String) -> Yttrium.SessionFfi? {
        // Try decode as CodableSession (migration compatible with WCSession JSON layout)
        guard let codable = try? store.get(key: topic) else { return nil }
        
        let symKey =  kms.getSymmetricKey(for: topic)!.rawRepresentation
        
        return codable.toYttriumSession(symKey: symKey)
    }

    func getAllSessions() -> [Yttrium.SessionFfi] {
        let all = store.getAll()
        return all.compactMap { session in
            guard let symKey = kms.getSymmetricKey(for: session.topic) else {
                print("SessionStore: Failed to get symmetric key for topic: \(session.topic)")
                return nil
            }
            return session.toYttriumSession(symKey: symKey.rawRepresentation)
        }
    }
}
