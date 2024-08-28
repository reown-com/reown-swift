import Foundation
import Combine

class SignInteractor: ObservableObject {
    
    private let store: Store
    
    lazy var sessionsPublisher: AnyPublisher<[Session], Never> = Web3Modal.instance.sessionsPublisher
    lazy var sessionSettlePublisher: AnyPublisher<Session, Never> = Web3Modal.instance.sessionSettlePublisher
    lazy var sessionResponsePublisher: AnyPublisher<W3MResponse, Never> = Web3Modal.instance.sessionResponsePublisher
    lazy var sessionRejectionPublisher: AnyPublisher<(Session.Proposal, Reason), Never> = Web3Modal.instance.sessionRejectionPublisher
    lazy var sessionDeletePublisher: AnyPublisher<(String, Reason), Never> = Web3Modal.instance.sessionDeletePublisher
    lazy var sessionEventPublisher: AnyPublisher<(event: Session.Event, sessionTopic: String, chainId: Blockchain?), Never> = Web3Modal.instance.sessionEventPublisher
    lazy var authResponsePublisher: AnyPublisher<(id: RPCID, result: Result<(Session?, [Cacao]), AuthError>), Never> = Web3Modal.instance.authResponsePublisher


    init(store: Store = .shared) {
        self.store = store
    }
    
    func connect(walletUniversalLink: String?) async throws  {
        let uri = try await Web3Modal.instance.connect(walletUniversalLink: walletUniversalLink)

        DispatchQueue.main.async {
            self.store.uri = uri
            self.store.retryShown = false
        }
    }
    
    func disconnect() async throws {
        defer {
            DispatchQueue.main.async {
                self.store.session = nil
                self.store.account = nil
            }
        }
        
        do {
            try await Web3Modal.instance.disconnect(topic: store.session?.topic ?? "")
        } catch {
            DispatchQueue.main.async {
                self.store.toast = .init(style: .error, message: "Failed to disconnect.")
            }
            Web3Modal.config.onError(error)
        }
        try await Web3Modal.instance.cleanup()
    }
}
