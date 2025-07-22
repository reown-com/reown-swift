import Combine

import ReownWalletKit
import WalletConnectNotify

final class WalletInteractor {
    var sessionsPublisher: AnyPublisher<[Session], Never> {
        return WalletKit.instance.sessionsPublisher
    }

    func getSessions() -> [Session] {
        return WalletKit.instance.getSessions()
    }
    
    func pair(uri: WalletConnectURI) async throws {
//        try await WalletKit.instance.pair(uri: uri)
        let proposal = try await WalletKitRust.instance.pair(uri: uri.absoluteString)
        print(proposal)
        print(proposal)
    }
    
    func disconnectSession(session: Session) async throws {
        try await WalletKit.instance.disconnect(topic: session.topic)
    }

    func getPendingRequests() -> [(request: Request, context: VerifyContext?)] {
        WalletKit.instance.getPendingRequests()
    }
}
