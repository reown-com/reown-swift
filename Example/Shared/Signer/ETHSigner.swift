import Foundation
import Commons
import Web3

struct ETHSigner {
    private let importAccount: ImportAccount

    init(importAccount: ImportAccount) {
        self.importAccount = importAccount
    }

    var address: String {
        return privateKey.address.hex(eip55: true)
    }

    private var privateKey: EthereumPrivateKey {
        return try! EthereumPrivateKey(hexPrivateKey: importAccount.privateKey)
    }

    func personalSign(_ params: AnyCodable) -> AnyCodable {
        let params = try! params.get([String].self)
        let messageToSign = params[0]

        // Determine if the message is hex-encoded or plain text
        let dataToSign: Bytes
        if messageToSign.hasPrefix("0x") {
            // Hex-encoded message, remove "0x" and convert
            let messageData = Data(hex: String(messageToSign.dropFirst(2)))
            dataToSign = dataToHash(messageData)
        } else {
            // Plain text message, convert directly to data
            let messageData = Data(messageToSign.utf8)
            dataToSign = dataToHash(messageData)
        }

        // Sign the data
        let (v, r, s) = try! privateKey.sign(message: .init(Data(dataToSign)))
        let result = "0x" + r.toHexString() + s.toHexString() + String(v + 27, radix: 16)
        return AnyCodable(result)
    }

    func signHash(_ hashToSign: String) throws -> String {

        let dataToSign: Bytes
        if hashToSign.hasPrefix("0x") {
            // Hex-encoded message, remove "0x" and convert
            let messageData = Data(hex: String(hashToSign.dropFirst(2)))
            dataToSign = messageData.bytes
        } else {
            // Plain text message, convert directly to data
            let messageData = Data(hashToSign.utf8)
            dataToSign = messageData.bytes
        }

        let (v, r, s) = try! privateKey.sign(hash: dataToSign)
        let result = "0x" + r.toHexString() + s.toHexString() + String(v + 27, radix: 16)
        return result
    }

    /// Sign EIP-712 typed data using SignTypedDataSigner
    /// - Parameter params: AnyCodable containing the params (typically [address, typedDataJson])
    /// - Returns: The signature as a hex string in format 0x{r}{s}{v}
    func signTypedData(_ params: AnyCodable) async throws -> String {
        let signer = SignTypedDataSigner(privateKey: importAccount.privateKey)

        var signatureJson: String

        // Try to get params as String first
        if let paramsString = try? params.get(String.self) {
            print("[ETHSigner] signTypedData params (String): \(paramsString.prefix(300))...")
            signatureJson = try await signer.signTypedDataFromParams(paramsString)
        }
        // Try to get data representation and convert to JSON string
        else if let jsonData = try? params.getDataRepresentation(),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("[ETHSigner] signTypedData params (Data): \(jsonString.prefix(300))...")
            signatureJson = try await signer.signTypedDataFromParams(jsonString)
        } else {
            print("[ETHSigner] signTypedData: Could not extract params")
            throw SignTypedDataSigner.SignTypedDataError.invalidParams
        }

        // Extract and format signature from {v, r, s} JSON to 0x{r}{s}{v} hex
        return try extractSignatureFromJson(signatureJson)
    }

    /// Extract hex signature from EIP-712 signature JSON response
    /// - Parameter signatureJson: JSON string containing {v, r, s}
    /// - Returns: Formatted signature as 0x{r}{s}{v}
    private func extractSignatureFromJson(_ signatureJson: String) throws -> String {
        struct SignatureResponse: Decodable {
            let v: Int
            let r: String
            let s: String
        }

        let signature = try JSONDecoder().decode(SignatureResponse.self, from: Data(signatureJson.utf8))
        let rHex = signature.r.hasPrefix("0x") ? String(signature.r.dropFirst(2)) : signature.r
        let sHex = signature.s.hasPrefix("0x") ? String(signature.s.dropFirst(2)) : signature.s
        let vHex = String(format: "%02x", signature.v)
        return "0x\(rHex)\(sHex)\(vHex)"
    }

    func sendTransaction(_ params: AnyCodable) throws -> AnyCodable {
//        let params = try params.get([Tx].self)
//        var transaction = params[0]
//        transaction.gas = EthereumQuantity(quantity: BigUInt("1234"))
//        transaction.nonce = EthereumQuantity(quantity: BigUInt("0"))
//        transaction.gasPrice = EthereumQuantity(quantity: BigUInt(0))
//        print(transaction.description)
//        let signedTx = try transaction.sign(with: self.privateKey, chainId: 4)
//        let (r, s, v) = (signedTx.r, signedTx.s, signedTx.v)
//        let result = r.hex() + s.hex().dropFirst(2) + String(v.quantity, radix: 16)
        return AnyCodable("0xabcd12340000000000000000000000111111111111111111111111111111111111111110000000000000000000000000000000000000000000000000000000000000f0")
    }

    private func dataToHash(_ data: Data) -> Bytes {
        let prefix = "\u{19}Ethereum Signed Message:\n"
        let prefixData = (prefix + String(data.count)).data(using: .utf8)!
        let prefixedMessageData = prefixData + data
        return .init(hex: prefixedMessageData.toHexString())
    }
}
