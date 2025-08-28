import Combine

import WalletConnectYttrium
import WalletConnectUtils

final class WalletInteractor {
    var sessionsPublisher: AnyPublisher<[Session], Never> {
        return WalletKitRust.instance.sessionsPublisher
    }

    func getSessions() -> [Session] {
        return WalletKitRust.instance.getSessions()
    }
    
    func pair(uri: WalletConnectURI) async throws {
//        try await WalletKit.instance.pair(uri: uri)
        let proposal = try await WalletKitRust.instance.pair(uri: uri.absoluteString)
        print(proposal)
        print(proposal)
    }
    
    func disconnectSession(session: Session) async throws {
        try await WalletKitRust.instance.disconnect(topic: session.topic)
    }

    func disconnectAllSessions() async throws {
        let sessions = getSessions()
        for session in sessions {
            try await WalletKitRust.instance.disconnect(topic: session.topic)
        }
    }

//    func getPendingRequests() -> [(request: Request, context: VerifyContext?)] {
//        WalletKit.instance.getPendingRequests()
//    }
}
