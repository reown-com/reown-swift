import UIKit
import Combine
import Web3

import ReownWalletKit
import YttriumUtilsWrapper

final class SessionRequestPresenter: ObservableObject {
    private let interactor: SessionRequestInteractor
    private let router: SessionRequestRouter
    private let importAccount: ImportAccount
    private let typedDataMethods: Set<String> = [
        "eth_signTypedData",
        "eth_signTypedData_v3",
        "eth_signTypedData_v4"
    ]
    private let transactionMethods: Set<String> = [
        "eth_sendTransaction",
        "eth_signTransaction"
    ]
    
    let sessionRequest: Request
    let session: Session?
    let validationStatus: VerifyContext.ValidationStatus?

    // Clear signing (EIP-7730) display model
    @Published var clearSigningIntent: String?
    @Published var clearSigningItems: [(label: String, value: String)] = []
    @Published var clearSigningInterpolatedIntent: String?
    @Published var clearSigningWarnings: [String] = []
    @Published var clearSigningRawSelector: String?
    @Published var clearSigningRawArgs: [String] = []

    var message: String {
        if let typedPayload = resolveTypedDataPayloadForDisplay() {
            return prettyPrintedJSON(from: typedPayload) ?? typedPayload
        }

        if let messages = try? sessionRequest.params.get([String].self),
           let firstMessage = messages.first {
            if let decodedMessage = String(data: Data(hex: firstMessage), encoding: .utf8),
               !decodedMessage.isEmpty {
                return decodedMessage
            }
            return firstMessage
        }

        return String(describing: sessionRequest.params.value)
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

    enum ClearSigningContext {
        case typedData(json: String)
        case transaction(chainId: UInt64, tx: TxLike)
    }

    struct SessionRequestEnvelope: Codable {
        struct InnerRequest: Codable {
            let method: String
            let params: [AnyCodable]
        }

        let chainId: String?
        let request: InnerRequest
    }

    func computeClearSigningPreview() {
        clearSigningInterpolatedIntent = nil
        guard let context = resolveClearSigningContext() else { return }

        switch context {
        case .typedData(let json):
            renderTypedDataPreview(typedDataJson: json)
        case .transaction(let chainId, let tx):
            renderTransactionPreview(chainId: chainId, transaction: tx)
        }
    }

    func resolveClearSigningContext() -> ClearSigningContext? {
        if typedDataMethods.contains(sessionRequest.method),
           let payload = extractTypedDataPayload(from: sessionRequest.params) {
            return .typedData(json: payload)
        }

        if transactionMethods.contains(sessionRequest.method),
           let chainIdNumber = UInt64(sessionRequest.chainId.reference),
           let tx = extractTransaction(from: sessionRequest.params) {
            return .transaction(chainId: chainIdNumber, tx: tx)
        }

        if sessionRequest.method == "wc_sessionRequest",
           let envelope = decodeSessionRequestEnvelope(from: sessionRequest.params) {
            let innerMethod = envelope.request.method
            let chainReference = envelope.chainId ?? sessionRequest.chainId.reference

            if typedDataMethods.contains(innerMethod),
               let payload = extractTypedDataPayload(from: envelope.request.params) {
                return .typedData(json: payload)
            }

            if transactionMethods.contains(innerMethod),
               let chainIdNumber = parseChainId(from: chainReference),
               let tx = extractTransaction(from: envelope.request.params) {
                return .transaction(chainId: chainIdNumber, tx: tx)
            }
        }

        return nil
    }

    func renderTransactionPreview(chainId: UInt64, transaction: TxLike) {
        guard let to = transaction.to, let calldataHex = transaction.data else { return }

        do {
            let displayModel = try clearSigningFormat(
                chainId: chainId,
                to: to,
                calldataHex: calldataHex
            )

            clearSigningIntent = displayModel.intent
            clearSigningInterpolatedIntent = displayModel.interpolatedIntent
            clearSigningItems = displayModel.items.map { ($0.label, $0.value) }
            clearSigningWarnings = displayModel.warnings
            if let raw = displayModel.raw {
                clearSigningRawSelector = raw.selector
                clearSigningRawArgs = raw.args
            } else {
                clearSigningRawSelector = nil
                clearSigningRawArgs = []
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func renderTypedDataPreview(typedDataJson: String) {
        do {
            let displayModel = try clearSigningFormatTyped(typedDataJson: typedDataJson)

            clearSigningIntent = displayModel.intent
            clearSigningInterpolatedIntent = displayModel.interpolatedIntent
            clearSigningItems = displayModel.items.map { ($0.label, $0.value) }
            clearSigningWarnings = displayModel.warnings
            clearSigningRawSelector = nil
            clearSigningRawArgs = []
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func decodeSessionRequestEnvelope(from params: AnyCodable) -> SessionRequestEnvelope? {
        if let rawString = params.value as? String,
           let data = rawString.data(using: .utf8) {
            return try? JSONDecoder().decode(SessionRequestEnvelope.self, from: data)
        }

        if let dictionary = params.value as? [String: Any],
           JSONSerialization.isValidJSONObject(dictionary),
           let data = try? JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys]) {
            return try? JSONDecoder().decode(SessionRequestEnvelope.self, from: data)
        }

        return try? params.get(SessionRequestEnvelope.self)
    }

    func parseChainId(from caip2: String?) -> UInt64? {
        guard let caip2 = caip2 else { return nil }
        let components = caip2.split(separator: ":")
        guard let reference = components.last else { return nil }
        return UInt64(reference)
    }

    func extractTransaction(from params: AnyCodable) -> TxLike? {
        guard let txs = try? params.get([TxLike].self) else { return nil }
        return txs.first
    }

    func extractTransaction(from params: [AnyCodable]) -> TxLike? {
        let rawValues = params.map { $0.value }
        guard JSONSerialization.isValidJSONObject(rawValues),
              let data = try? JSONSerialization.data(withJSONObject: rawValues, options: []) else { return nil }
        let txs = try? JSONDecoder().decode([TxLike].self, from: data)
        return txs?.first
    }

    func extractTypedDataPayload(from params: AnyCodable) -> String? {
        if let stringArray = try? params.get([String].self), stringArray.count >= 2 {
            return sanitizeTypedDataPayload(stringArray[1])
        }

        if let anyArray = try? params.get([AnyCodable].self) {
            return extractTypedDataPayload(from: anyArray)
        }

        return nil
    }

    func extractTypedDataPayload(from params: [AnyCodable]) -> String? {
        guard params.count >= 2 else { return nil }
        return coerceJSON(from: params[1].value)
    }

    func sanitizeTypedDataPayload(_ payload: String) -> String? {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func coerceJSON(from value: Any) -> String? {
        if let stringValue = value as? String {
            return sanitizeTypedDataPayload(stringValue)
        }

        if let dictionary = value as? [String: Any],
           JSONSerialization.isValidJSONObject(dictionary),
           let data = try? JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys]),
           let jsonString = String(data: data, encoding: .utf8) {
            return jsonString
        }

        if let array = value as? [Any],
           JSONSerialization.isValidJSONObject(array),
           let data = try? JSONSerialization.data(withJSONObject: array, options: [.sortedKeys]),
           let jsonString = String(data: data, encoding: .utf8) {
            return jsonString
        }

        if let anyCodable = value as? AnyCodable {
            return sanitizeTypedDataPayload(anyCodable.stringRepresentation)
        }

        return nil
    }

    func resolveTypedDataPayloadForDisplay() -> String? {
        if typedDataMethods.contains(sessionRequest.method),
           let payload = extractTypedDataPayload(from: sessionRequest.params) {
            return payload
        }

        if sessionRequest.method == "wc_sessionRequest",
           let envelope = decodeSessionRequestEnvelope(from: sessionRequest.params),
           typedDataMethods.contains(envelope.request.method),
           let payload = extractTypedDataPayload(from: envelope.request.params) {
            return payload
        }

        return nil
    }

    func prettyPrintedJSON(from text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        if let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]) {
            return String(data: pretty, encoding: .utf8)
        }
        return nil
    }
}

// MARK: - SceneViewModel
extension SessionRequestPresenter: SceneViewModel {

}
