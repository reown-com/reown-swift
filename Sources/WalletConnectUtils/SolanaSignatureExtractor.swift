import Foundation

public struct SolanaSignatureExtractor {
    
    public enum Errors: Error {
        case invalidBase64
        case invalidTransaction
        case noSignaturesFound
    }
    
    /// Extracts the first signature from a Base64-encoded Solana transaction and returns it as a Base58-encoded string.
    /// - Parameter base64Transaction: The Base64-encoded transaction string.
    /// - Returns: The first signature as a Base58-encoded string.
    /// - Throws: `Errors` if the input is invalid or no signature is found.
    public static func extractSignature(from base64Transaction: String) throws -> String {
        // Decode the Base64 string into a Data object
        guard let transactionData = Data(base64Encoded: base64Transaction) else {
            throw Errors.invalidBase64
        }

        // Ensure the transaction data is at least 65 bytes (1 byte for numSignatures + 64 bytes for the signature)
        guard transactionData.count >= 65 else {
            throw Errors.invalidTransaction
        }

        // Read the number of signatures from the first byte
        let numSignatures = transactionData[0]

        // Check if there is at least one signature
        guard numSignatures > 0 else {
            throw Errors.noSignaturesFound
        }

        // Extract the first signature (bytes 1 to 64 inclusive)
        let signatureData = transactionData[1..<65]

        // Encode the signature to Base58 using the provided Base58 struct
        let signatureBase58 = Base58.encode(signatureData)

        return signatureBase58
    }
}
