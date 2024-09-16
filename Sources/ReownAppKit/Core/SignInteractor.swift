import Foundation
import Combine

class SignInteractor: ObservableObject {
    
    private let store: Store
    
    lazy var sessionsPublisher: AnyPublisher<[Session], Never> = AppKit.instance.sessionsPublisher
    lazy var sessionSettlePublisher: AnyPublisher<Session, Never> = AppKit.instance.sessionSettlePublisher
    lazy var sessionResponsePublisher: AnyPublisher<W3MResponse, Never> = AppKit.instance.sessionResponsePublisher
    lazy var sessionRejectionPublisher: AnyPublisher<(Session.Proposal, Reason), Never> = AppKit.instance.sessionRejectionPublisher
    lazy var sessionDeletePublisher: AnyPublisher<(String, Reason), Never> = AppKit.instance.sessionDeletePublisher
    lazy var sessionEventPublisher: AnyPublisher<(event: Session.Event, sessionTopic: String, chainId: Blockchain?), Never> = AppKit.instance.sessionEventPublisher
    lazy var authResponsePublisher: AnyPublisher<(id: RPCID, result: Result<(Session?, [Cacao]), AuthError>), Never> = AppKit.instance.authResponsePublisher


    init(store: Store = .shared) {
        self.store = store
    }
    
    func connect(walletUniversalLink: String?) async throws  {
        let uri = try await AppKit.instance.connect(walletUniversalLink: walletUniversalLink)

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
            try await AppKit.instance.disconnect(topic: store.session?.topic ?? "")
        } catch {
            DispatchQueue.main.async {
                self.store.toast = .init(style: .error, message: "Failed to disconnect.")
            }
            AppKit.config.onError(error)
        }
        try await AppKit.instance.cleanup()
    }
}
