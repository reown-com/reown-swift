import UIKit
import Combine
import Web3

import ReownWalletKit
import YttriumUtilsWrapper

final class SessionRequestPresenter: ObservableObject {
    private let interactor: SessionRequestInteractor
    private let router: SessionRequestRouter
    private let importAccount: ImportAccount
    
    let sessionRequest: Request
    let session: Session?
    let validationStatus: VerifyContext.ValidationStatus?

    // Clear signing (EIP-7730) display model
    @Published var clearSigningIntent: String?
    @Published var clearSigningItems: [(label: String, value: String)] = []
    @Published var clearSigningWarnings: [String] = []
    @Published var clearSigningRawSelector: String?
    @Published var clearSigningRawArgs: [String] = []

    var message: String {
        guard let messages = try? sessionRequest.params.get([String].self),
              let firstMessage = messages.first else {
            return String(describing: sessionRequest.params.value)
        }
        
        // Attempt to decode the message if it's hex-encoded
        let decodedMessage = String(data: Data(hex: firstMessage), encoding: .utf8)

        // Return the decoded message if available, else return the original message
        return decodedMessage?.isEmpty == false ? decodedMessage! : firstMessage
    }

    
    @Published var showError = false
    @Published var errorMessage = "Error"
    @Published var showSignedSheet = false
    
    private var disposeBag = Set<AnyCancellable>()

    init(
        interactor: SessionRequestInteractor,
        router: SessionRequestRouter,
        sessionRequest: Request,
        importAccount: ImportAccount,
        context: VerifyContext?
    ) {
        defer { setupInitialState() }
        self.interactor = interactor
        self.router = router
        self.sessionRequest = sessionRequest
        self.session = interactor.getSession(topic: sessionRequest.topic)
        self.importAccount = importAccount
        self.validationStatus = context?.validation
    }

    @MainActor
    func onApprove() async throws {
        do {
            ActivityIndicatorManager.shared.start()
            let showConnected = try await interactor.respondSessionRequest(sessionRequest: sessionRequest, importAccount: importAccount)
            showConnected ? showSignedSheet.toggle() : router.dismiss()
            ActivityIndicatorManager.shared.stop()
        } catch {
            ActivityIndicatorManager.shared.stop()
            errorMessage = error.localizedDescription
            showError.toggle()
        }
    }

    @MainActor
    func onReject() async throws {
        do {
            ActivityIndicatorManager.shared.start()
            try await interactor.respondError(sessionRequest: sessionRequest)
            ActivityIndicatorManager.shared.stop()
            router.dismiss()
        } catch {
            ActivityIndicatorManager.shared.stop()
            errorMessage = error.localizedDescription
            showError.toggle()
        }
    }
    
    func onSignedSheetDismiss() {
        dismiss()
    }
    
    func dismiss() {
        router.dismiss()
    }
}

// MARK: - Private functions
private extension SessionRequestPresenter {
    func setupInitialState() {
        computeClearSigningPreview()
        WalletKit.instance.requestExpirationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] requestId in
                guard let self = self else { return }
                if requestId == sessionRequest.id {
                    dismiss()
                }
            }.store(in: &disposeBag)
    }

    struct TxLike: Codable {
        let to: String?
        let data: String?
    }

    func computeClearSigningPreview() {
        // Only attempt for Ethereum transaction signing/sending
        let supportedMethods: Set<String> = ["eth_sendTransaction", "eth_signTransaction"]
        guard supportedMethods.contains(sessionRequest.method) else { return }
        guard let chainIdNumber = UInt64(sessionRequest.chainId.reference) else { return }
        guard let txs = try? sessionRequest.params.get([TxLike].self), let tx = txs.first else { return }
        guard let to = tx.to, let calldataHex = tx.data else { return }


        // From YttriumUtilsWrapper UniFFI
        
        let displayModel = try! clearSigningFormat(
            chainId: chainIdNumber,
            to: to,
            calldataHex: calldataHex
        )
        
//        let displayModel = try! clearSigningFormat(
//            chainId: 10,
//            to: "0x521B4C065Bbdbe3E20B3727340730936912DfA46",
//            calldataHex: "0x7c616fe60000000000000000000000000000000000000000000000000000000067741500"
//        )


        clearSigningIntent = displayModel.intent
        clearSigningItems = displayModel.items.map { ($0.label, $0.value) }
        clearSigningWarnings = displayModel.warnings
        if let raw = displayModel.raw {
            clearSigningRawSelector = raw.selector
            clearSigningRawArgs = raw.args
        }
    }
}

// MARK: - SceneViewModel
extension SessionRequestPresenter: SceneViewModel {

}
