import Foundation
@testable import WalletConnectUtils
@testable import WalletConnectSign
import XCTest

class SIWEFromCacaoPayloadFormatterTests: XCTestCase {
    var sut: SIWEFromCacaoPayloadFormatter!
    let address = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"

    override func setUp() {
        sut = SIWEFromCacaoPayloadFormatter()
    }

    func testFormatMessage() throws {
        let expectedMessage =
            """
            service.invalid wants you to sign in with your Ethereum account:
            0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2

            I accept the ServiceOrg Terms of Service: https://service.invalid/tos

            URI: https://service.invalid/login
            Version: 1
            Chain ID: 1
            Nonce: 32891756
            Issued At: 2021-09-30T16:25:24Z
            Resources:
            - ipfs://bafybeiemxf5abjwjbikoz4mc3a3dla6ual3jsgpdr4cjr3oz3evfyavhwq/
            - https://example.com/my-web2-claim.json
            """
        let cacaoPayload = try CacaoPayloadBuilder.makeCacaoPayload(authPayload: AuthPayload.stub(), account: Account.stub())
        let message = try sut.formatMessage(from: cacaoPayload)
        XCTAssertEqual(message, expectedMessage)
    }

    // MARK: - CAIP-122 Tests

    func testFormatMessageBitcoin() throws {
        let bitcoinAccount = Account("bip122:000000000019d6689c085ae165831e93:1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa")!
        let expectedMessage =
            """
            service.invalid wants you to sign in with your Bitcoin account:
            1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa

            I accept the ServiceOrg Terms of Service: https://service.invalid/tos

            URI: https://service.invalid/login
            Version: 1
            Chain ID: 000000000019d6689c085ae165831e93
            Nonce: 32891756
            Issued At: 2021-09-30T16:25:24Z
            Resources:
            - ipfs://bafybeiemxf5abjwjbikoz4mc3a3dla6ual3jsgpdr4cjr3oz3evfyavhwq/
            - https://example.com/my-web2-claim.json
            """
        let cacaoPayload = try CacaoPayloadBuilder.makeCacaoPayload(authPayload: AuthPayload.stub(), account: bitcoinAccount)
        let message = try sut.formatMessage(from: cacaoPayload)
        XCTAssertEqual(message, expectedMessage)
    }

    func testFormatMessageSolana() throws {
        let solanaAccount = Account("solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp:7S3P4HxJpyyigGzodYwHtCxZyUQe9JiBMHyRWXArAaKv")!
        let expectedMessage =
            """
            service.invalid wants you to sign in with your Solana account:
            7S3P4HxJpyyigGzodYwHtCxZyUQe9JiBMHyRWXArAaKv

            I accept the ServiceOrg Terms of Service: https://service.invalid/tos

            URI: https://service.invalid/login
            Version: 1
            Chain ID: 5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp
            Nonce: 32891756
            Issued At: 2021-09-30T16:25:24Z
            Resources:
            - ipfs://bafybeiemxf5abjwjbikoz4mc3a3dla6ual3jsgpdr4cjr3oz3evfyavhwq/
            - https://example.com/my-web2-claim.json
            """
        let cacaoPayload = try CacaoPayloadBuilder.makeCacaoPayload(authPayload: AuthPayload.stub(), account: solanaAccount)
        let message = try sut.formatMessage(from: cacaoPayload)
        XCTAssertEqual(message, expectedMessage)
    }

    func testFormatMessageUnsupportedChain() throws {
        let unsupportedAccount = Account("cosmos:cosmoshub-4:cosmos1abcdefghijklmnopqrstuvwxyz0123456789")!
        let cacaoPayload = try CacaoPayloadBuilder.makeCacaoPayload(authPayload: AuthPayload.stub(), account: unsupportedAccount)
        
        XCTAssertThrowsError(try sut.formatMessage(from: cacaoPayload)) { error in
            XCTAssertTrue(error is SIWEFromCacaoPayloadFormatter.Errors)
            if let unsupportedError = error as? SIWEFromCacaoPayloadFormatter.Errors {
                XCTAssertEqual(unsupportedError.localizedDescription, "Unsupported blockchain namespace: cosmos. Only eip155, bip122, and solana are supported.")
            }
        }
    }
    
    // MARK: - CacaoSignatureType Tests
    
    func testCacaoSignatureTypeEncoding() throws {
        let encoder = JSONEncoder()
        
        // Test EIP155 types
        let eip191Data = try encoder.encode(CacaoSignatureType.eip155(.eip191))
        let eip191String = String(data: eip191Data, encoding: .utf8)
        XCTAssertEqual(eip191String, "\"eip191\"")
        
        let eip1271Data = try encoder.encode(CacaoSignatureType.eip155(.eip1271))
        let eip1271String = String(data: eip1271Data, encoding: .utf8)
        XCTAssertEqual(eip1271String, "\"eip1271\"")
        
        let eip6492Data = try encoder.encode(CacaoSignatureType.eip155(.eip6492))
        let eip6492String = String(data: eip6492Data, encoding: .utf8)
        XCTAssertEqual(eip6492String, "\"eip6492\"")
        
        // Test BIP122 types
        let ecdsaData = try encoder.encode(CacaoSignatureType.bip122(.ecdsa))
        let ecdsaString = String(data: ecdsaData, encoding: .utf8)
        XCTAssertEqual(ecdsaString, "\"ecdsa\"")
        
        let bip322Data = try encoder.encode(CacaoSignatureType.bip122(.bip322Simple))
        let bip322String = String(data: bip322Data, encoding: .utf8)
        XCTAssertEqual(bip322String, "\"bip322-simple\"")
        
        // Test Solana types
        let ed25519Data = try encoder.encode(CacaoSignatureType.solana(.ed25519))
        let ed25519String = String(data: ed25519Data, encoding: .utf8)
        XCTAssertEqual(ed25519String, "\"ed25519\"")
    }
    
    func testCacaoSignatureTypeDecoding() throws {
        let decoder = JSONDecoder()
        
        // Test EIP155 types
        let eip191Data = "\"eip191\"".data(using: .utf8)!
        let eip191Type = try decoder.decode(CacaoSignatureType.self, from: eip191Data)
        if case .eip155(let innerType) = eip191Type {
            XCTAssertEqual(innerType, .eip191)
        } else {
            XCTFail("Expected eip155(.eip191)")
        }
        
        let eip1271Data = "\"eip1271\"".data(using: .utf8)!
        let eip1271Type = try decoder.decode(CacaoSignatureType.self, from: eip1271Data)
        if case .eip155(let innerType) = eip1271Type {
            XCTAssertEqual(innerType, .eip1271)
        } else {
            XCTFail("Expected eip155(.eip1271)")
        }
        
        // Test BIP122 types
        let ecdsaData = "\"ecdsa\"".data(using: .utf8)!
        let ecdsaType = try decoder.decode(CacaoSignatureType.self, from: ecdsaData)
        if case .bip122(let innerType) = ecdsaType {
            XCTAssertEqual(innerType, .ecdsa)
        } else {
            XCTFail("Expected bip122(.ecdsa)")
        }
        
        // Test Solana types
        let ed25519Data = "\"ed25519\"".data(using: .utf8)!
        let ed25519Type = try decoder.decode(CacaoSignatureType.self, from: ed25519Data)
        if case .solana(let innerType) = ed25519Type {
            XCTAssertEqual(innerType, .ed25519)
        } else {
            XCTFail("Expected solana(.ed25519)")
        }
    }
    
    func testCacaoSignatureTypeNamespaceAndAlgorithm() {
        // Test namespace and algorithm properties
        let eip191 = CacaoSignatureType.eip155(.eip191)
        XCTAssertEqual(eip191.namespace, "eip155")
        XCTAssertEqual(eip191.algorithm, "eip191")
        
        let ecdsa = CacaoSignatureType.bip122(.ecdsa)
        XCTAssertEqual(ecdsa.namespace, "bip122")
        XCTAssertEqual(ecdsa.algorithm, "ecdsa")
        
        let ed25519 = CacaoSignatureType.solana(.ed25519)
        XCTAssertEqual(ed25519.namespace, "solana")
        XCTAssertEqual(ed25519.algorithm, "ed25519")
        
        let bip322 = CacaoSignatureType.bip122(.bip322Simple)
        XCTAssertEqual(bip322.namespace, "bip122")
        XCTAssertEqual(bip322.algorithm, "bip322-simple")
    }
    
    func testCacaoSignatureTypeInvalidDecoding() {
        let decoder = JSONDecoder()
        
        // Test invalid signature type
        let invalidData = "\"invalid-signature\"".data(using: .utf8)!
        XCTAssertThrowsError(try decoder.decode(CacaoSignatureType.self, from: invalidData)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }
    
    // MARK: - Existing Tests (Updated for Ethereum)

    func testNilStatement() throws {
        let expectedMessage =
            """
            service.invalid wants you to sign in with your Ethereum account:
            0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2


            URI: https://service.invalid/login
            Version: 1
            Chain ID: 1
            Nonce: 32891756
            Issued At: 2021-09-30T16:25:24Z
            Resources:
            - ipfs://bafybeiemxf5abjwjbikoz4mc3a3dla6ual3jsgpdr4cjr3oz3evfyavhwq/
            - https://example.com/my-web2-claim.json
            """
        let cacaoPayload = try CacaoPayloadBuilder.makeCacaoPayload(
            authPayload: AuthPayload.stub(
                requestParams: AuthRequestParams.stub(statement: nil)
            ),
            account: Account.stub())
        let message = try sut.formatMessage(from: cacaoPayload)
        XCTAssertEqual(message, expectedMessage)
    }

    func testNilResources() throws {
        let expectedMessage =
            """
            service.invalid wants you to sign in with your Ethereum account:
            0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2

            I accept the ServiceOrg Terms of Service: https://service.invalid/tos

            URI: https://service.invalid/login
            Version: 1
            Chain ID: 1
            Nonce: 32891756
            Issued At: 2021-09-30T16:25:24Z
            """
        let cacaoPayload = try CacaoPayloadBuilder.makeCacaoPayload(
            authPayload: AuthPayload.stub(
                requestParams: AuthRequestParams.stub(resources: nil)
            ),
            account: Account.stub())
        let message = try sut.formatMessage(from: cacaoPayload)
        XCTAssertEqual(message, expectedMessage)
    }

    func testResourcesEmptyArray() throws {
        let expectedMessage =
            """
            service.invalid wants you to sign in with your Ethereum account:
            0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2

            I accept the ServiceOrg Terms of Service: https://service.invalid/tos

            URI: https://service.invalid/login
            Version: 1
            Chain ID: 1
            Nonce: 32891756
            Issued At: 2021-09-30T16:25:24Z
            Resources:
            """
        let cacaoPayload = try CacaoPayloadBuilder.makeCacaoPayload(
            authPayload: AuthPayload.stub(
                requestParams: AuthRequestParams.stub(resources: [])
            ),
            account: Account.stub())
        let message = try sut.formatMessage(from: cacaoPayload)
        XCTAssertEqual(message, expectedMessage)
    }

    func testNilAllOptionalParams() throws {
        let expectedMessage =
            """
            service.invalid wants you to sign in with your Ethereum account:
            0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2

            
            URI: https://service.invalid/login
            Version: 1
            Chain ID: 1
            Nonce: 32891756
            Issued At: 2021-09-30T16:25:24Z
            """
        let cacaoPayload = try CacaoPayloadBuilder.makeCacaoPayload(
            authPayload: AuthPayload.stub(
                requestParams: AuthRequestParams.stub(statement: nil, resources: nil)
            ),
            account: Account.stub())
        let message = try sut.formatMessage(from: cacaoPayload)
        XCTAssertEqual(message, expectedMessage)
    }

    func testWithValidRecapAndStatement() throws {
        let validRecapUrn = "urn:recap:eyJhdHQiOiB7ImVpcDE1NSI6IHsicmVxdWVzdC9ldGhfc2VuZFRyYW5zYWN0aW9uIjogW10sICJyZXF1ZXN0L3BlcnNvbmFsX3NpZ24iOiBbXX19fQ=="

        let expectedMessage =
            """
            service.invalid wants you to sign in with your Ethereum account:
            0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2

            I accept the ServiceOrg Terms of Service: https://service.invalid/tos I further authorize the stated URI to perform the following actions on my behalf: (1) 'request': 'eth_sendTransaction', 'personal_sign' for 'eip155'.

            URI: https://service.invalid/login
            Version: 1
            Chain ID: 1
            Nonce: 32891756
            Issued At: 2021-09-30T16:25:24Z
            Resources:
            - urn:recap:eyJhdHQiOiB7ImVpcDE1NSI6IHsicmVxdWVzdC9ldGhfc2VuZFRyYW5zYWN0aW9uIjogW10sICJyZXF1ZXN0L3BlcnNvbmFsX3NpZ24iOiBbXX19fQ==
            """


        let cacaoPayload = try CacaoPayloadBuilder.makeCacaoPayload(
            authPayload: AuthPayload.stub(
                requestParams: AuthRequestParams.stub(resources: [validRecapUrn])
            ),
            account: Account.stub())
        let message = try sut.formatMessage(from: cacaoPayload)

        XCTAssertEqual(message, expectedMessage)
    }

    func testWithValidRecapAndNoStatement() throws {
        let validRecapUrn = "urn:recap:eyJhdHQiOiB7ImVpcDE1NSI6IHsicmVxdWVzdC9ldGhfc2VuZFRyYW5zYWN0aW9uIjogW10sICJyZXF1ZXN0L3BlcnNvbmFsX3NpZ24iOiBbXX19fQ=="

        let expectedMessage =
            """
            service.invalid wants you to sign in with your Ethereum account:
            0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2

            I further authorize the stated URI to perform the following actions on my behalf: (1) 'request': 'eth_sendTransaction', 'personal_sign' for 'eip155'.

            URI: https://service.invalid/login
            Version: 1
            Chain ID: 1
            Nonce: 32891756
            Issued At: 2021-09-30T16:25:24Z
            Resources:
            - urn:recap:eyJhdHQiOiB7ImVpcDE1NSI6IHsicmVxdWVzdC9ldGhfc2VuZFRyYW5zYWN0aW9uIjogW10sICJyZXF1ZXN0L3BlcnNvbmFsX3NpZ24iOiBbXX19fQ==
            """

        let cacaoPayload = try CacaoPayloadBuilder.makeCacaoPayload(
            authPayload: AuthPayload.stub(
                requestParams: AuthRequestParams.stub(statement: nil, resources: [validRecapUrn])
            ),
            account: Account.stub())
        let message = try sut.formatMessage(from: cacaoPayload)
        XCTAssertEqual(message, expectedMessage)
    }

    func testWithSignAndNotifyRecaps() throws {
        let recap1 = "urn:recap:ewogICAiYXR0Ijp7CiAgICAgICJlaXAxNTUiOnsKICAgICAgICAgInJlcXVlc3QvZXRoX3NlbmRUcmFuc2FjdGlvbiI6IFt7fV0sCiAgICAgICAgICJyZXF1ZXN0L3BlcnNvbmFsX3NpZ24iOiBbe31dCiAgICAgIH0KICAgfQp9"

        let recap2 = "urn:recap:ewogICAiYXR0Ijp7CiAgICAgICJodHRwczovL25vdGlmeS53YWxsZXRjb25uZWN0LmNvbS9hbGwtYXBwcyI6ewogICAgICAgICAiY3J1ZC9ub3RpZmljYXRpb25zIjogW3t9XSwKICAgICAgICAgImNydWQvc3Vic2NyaXB0aW9ucyI6IFt7fV0KICAgICAgfQogICB9Cn0"

        let expectedMessage =
            """
            service.invalid wants you to sign in with your Ethereum account:
            0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2

            I further authorize the stated URI to perform the following actions on my behalf: (1) 'request': 'eth_sendTransaction', 'personal_sign' for 'eip155'. (2) 'crud': 'notifications', 'subscriptions' for 'https://notify.walletconnect.com/all-apps'.

            URI: https://service.invalid?walletconnect_notify_key=did:key:z6MktW4hKdsvcXgt9wXmYbSD5sH4NCk5GmNZnokP9yh2TeCf
            Version: 1
            Chain ID: 1
            Nonce: 32891756
            Issued At: 2021-09-30T16:25:24Z
            Resources:
            - urn:recap:eyJhdHQiOnsiZWlwMTU1Ijp7InJlcXVlc3RcL2V0aF9zZW5kVHJhbnNhY3Rpb24iOlt7fV0sInJlcXVlc3RcL3BlcnNvbmFsX3NpZ24iOlt7fV19LCJodHRwczpcL1wvbm90aWZ5LndhbGxldGNvbm5lY3QuY29tXC9hbGwtYXBwcyI6eyJjcnVkXC9ub3RpZmljYXRpb25zIjpbe31dLCJjcnVkXC9zdWJzY3JpcHRpb25zIjpbe31dfX19
            """


        let uri = "https://service.invalid?walletconnect_notify_key=did:key:z6MktW4hKdsvcXgt9wXmYbSD5sH4NCk5GmNZnokP9yh2TeCf"
        let cacaoPayload = try CacaoPayloadBuilder.makeCacaoPayload(
            authPayload: AuthPayload.stub(
                requestParams: AuthRequestParams.stub(uri: uri, statement: nil, resources: [recap1, recap2])
            ),
            account: Account.stub())
        let message = try sut.formatMessage(from: cacaoPayload)
        XCTAssertEqual(message, expectedMessage)
    }
}
