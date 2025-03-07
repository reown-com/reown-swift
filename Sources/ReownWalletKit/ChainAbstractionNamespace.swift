import Foundation
import YttriumWrapper

public class ChainAbstractionNamespace {
    private let chainAbstractionClient: ChainAbstractionClient

    init(chainAbstractionClient: ChainAbstractionClient) {
        self.chainAbstractionClient = chainAbstractionClient
    }

    @available(*, message: "This method is experimental. Use with caution.")
    public func prepare(chainId: String, from: FfiAddress, call: Call, localCurrency: Currency) async throws -> PrepareDetailedResponse {
        return try await chainAbstractionClient.prepareDetailed(chainId: chainId, from: from, call: call, localCurrency: localCurrency)
    }

    @available(*, message: "This method is experimental. Use with caution.")
    public func execute(uiFields: UiFields, routeTxnSigs: [FfiPrimitiveSignature], initialTxnSig: FfiPrimitiveSignature) async throws -> ExecuteDetails {
        return try await chainAbstractionClient.execute(uiFields: uiFields, routeTxnSigs: routeTxnSigs, initialTxnSig: initialTxnSig)
    }
}
