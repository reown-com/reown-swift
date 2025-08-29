import Foundation


import ReownRouter
import WalletConnectYttrium

final class SessionRequestInteractor {
    func respondSessionRequest(sessionRequest: Request, importAccount: ImportAccount) async throws -> Bool {
        do {
            let result = try await Signer.sign(request: sessionRequest, importAccount: importAccount)
            AlertPresenter.present(message: result.description, type: .success)
            try await WalletKitRust.instance.respond(
                topic: sessionRequest.topic,
                requestId: sessionRequest.id,
                response: .response(result)
            )
            /* Redirect */
            let session = getSession(topic: sessionRequest.topic)
            if let uri = session?.peer.redirect?.native {
                ReownRouter.goBack(uri: uri)
                return false
            } else {
                return true
            }
        } catch {
            throw error
        }
    }

    func respondError(sessionRequest: Request) async throws {
        try await WalletKitRust.instance.respond(
            topic: sessionRequest.topic,
            requestId: sessionRequest.id,
            response: .error(.init(code: 0, message: ""))
        )
        
        /* Redirect */
        let session = getSession(topic: sessionRequest.topic)
        if let uri = session?.peer.redirect?.native {
            ReownRouter.goBack(uri: uri)
        }
    }
    
    func getSession(topic: String) -> Session? {
        return WalletKitRust.instance.getSessions().first(where: { $0.topic == topic })
    }
}
