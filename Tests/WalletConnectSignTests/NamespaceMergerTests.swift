import XCTest
@testable import WalletConnectSign

final class NamespaceMergerTests: XCTestCase {

    let ethChain = Blockchain("eip155:1")!
    let polyChain = Blockchain("eip155:137")!
    let cosmosChain = Blockchain("cosmos:cosmoshub-4")!
    let solanaChain = Blockchain("solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp")!

    // MARK: - Basic merging tests

    func testMergeEmptyRequiredIntoEmptyOptional() {
        let requiredNamespaces: [String: ProposalNamespace] = [:]
        let optionalNamespaces: [String: ProposalNamespace]? = nil
        
        let result = NamespaceMerger.mergeRequiredIntoOptional(
            requiredNamespaces: requiredNamespaces,
            optionalNamespaces: optionalNamespaces
        )
        
        XCTAssertTrue(result.isEmpty, "Result should be empty when both inputs are empty")
    }

    func testMergeRequiredIntoEmptyOptional() {
        let requiredNamespaces: [String: ProposalNamespace] = [
            "eip155": ProposalNamespace(
                chains: [ethChain],
                methods: ["eth_sign", "personal_sign"],
                events: ["chainChanged"]
            )
        ]
        
        let result = NamespaceMerger.mergeRequiredIntoOptional(
            requiredNamespaces: requiredNamespaces,
            optionalNamespaces: nil
        )
        
        XCTAssertEqual(result.count, 1, "Should have one namespace")
        XCTAssertNotNil(result["eip155"], "Should contain eip155 namespace")
        
        let eip155Namespace = result["eip155"]!
        XCTAssertEqual(eip155Namespace.chains, [ethChain], "Chains should match")
        XCTAssertEqual(eip155Namespace.methods, ["eth_sign", "personal_sign"], "Methods should match")
        XCTAssertEqual(eip155Namespace.events, ["chainChanged"], "Events should match")
    }

    func testMergeEmptyRequiredIntoExistingOptional() {
        let requiredNamespaces: [String: ProposalNamespace] = [:]
        let optionalNamespaces: [String: ProposalNamespace] = [
            "eip155": ProposalNamespace(
                chains: [ethChain],
                methods: ["eth_sign"],
                events: ["chainChanged"]
            )
        ]
        
        let result = NamespaceMerger.mergeRequiredIntoOptional(
            requiredNamespaces: requiredNamespaces,
            optionalNamespaces: optionalNamespaces
        )
        
        XCTAssertEqual(result.count, 1, "Should have one namespace")
        XCTAssertNotNil(result["eip155"], "Should contain eip155 namespace")
        
        let eip155Namespace = result["eip155"]!
        XCTAssertEqual(eip155Namespace.chains, [ethChain], "Chains should match")
        XCTAssertEqual(eip155Namespace.methods, ["eth_sign"], "Methods should match")
        XCTAssertEqual(eip155Namespace.events, ["chainChanged"], "Events should match")
    }

    // MARK: - Merging different namespaces

    func testMergeDifferentNamespaces() {
        let requiredNamespaces: [String: ProposalNamespace] = [
            "eip155": ProposalNamespace(
                chains: [ethChain],
                methods: ["eth_sign"],
                events: ["chainChanged"]
            )
        ]
        let optionalNamespaces: [String: ProposalNamespace] = [
            "cosmos": ProposalNamespace(
                chains: [cosmosChain],
                methods: ["cosmos_signDirect"],
                events: ["someEvent"]
            )
        ]
        
        let result = NamespaceMerger.mergeRequiredIntoOptional(
            requiredNamespaces: requiredNamespaces,
            optionalNamespaces: optionalNamespaces
        )
        
        XCTAssertEqual(result.count, 2, "Should have two namespaces")
        XCTAssertNotNil(result["eip155"], "Should contain eip155 namespace")
        XCTAssertNotNil(result["cosmos"], "Should contain cosmos namespace")
        
        let eip155Namespace = result["eip155"]!
        XCTAssertEqual(eip155Namespace.chains, [ethChain], "eip155 chains should match")
        XCTAssertEqual(eip155Namespace.methods, ["eth_sign"], "eip155 methods should match")
        XCTAssertEqual(eip155Namespace.events, ["chainChanged"], "eip155 events should match")
        
        let cosmosNamespace = result["cosmos"]!
        XCTAssertEqual(cosmosNamespace.chains, [cosmosChain], "cosmos chains should match")
        XCTAssertEqual(cosmosNamespace.methods, ["cosmos_signDirect"], "cosmos methods should match")
        XCTAssertEqual(cosmosNamespace.events, ["someEvent"], "cosmos events should match")
    }

    // MARK: - Merging same namespace with different content

    func testMergeSameNamespaceWithDifferentChains() {
        let requiredNamespaces: [String: ProposalNamespace] = [
            "eip155": ProposalNamespace(
                chains: [ethChain],
                methods: ["eth_sign"],
                events: ["chainChanged"]
            )
        ]
        let optionalNamespaces: [String: ProposalNamespace] = [
            "eip155": ProposalNamespace(
                chains: [polyChain],
                methods: ["personal_sign"],
                events: ["accountsChanged"]
            )
        ]
        
        let result = NamespaceMerger.mergeRequiredIntoOptional(
            requiredNamespaces: requiredNamespaces,
            optionalNamespaces: optionalNamespaces
        )
        
        XCTAssertEqual(result.count, 1, "Should have one namespace")
        XCTAssertNotNil(result["eip155"], "Should contain eip155 namespace")
        
        let eip155Namespace = result["eip155"]!
        XCTAssertEqual(eip155Namespace.chains, [ethChain, polyChain], "Chains should be merged")
        XCTAssertEqual(eip155Namespace.methods, ["eth_sign", "personal_sign"], "Methods should be merged")
        XCTAssertEqual(eip155Namespace.events, ["chainChanged", "accountsChanged"], "Events should be merged")
    }


    func testMergeBothWithNilChains() {
        let requiredNamespaces: [String: ProposalNamespace] = [
            "eip155:1": ProposalNamespace(
                methods: ["eth_sign"],
                events: ["chainChanged"]
            )
        ]
        let optionalNamespaces: [String: ProposalNamespace] = [
            "eip155:1": ProposalNamespace(
                methods: ["personal_sign"],
                events: ["accountsChanged"]
            )
        ]
        
        let result = NamespaceMerger.mergeRequiredIntoOptional(
            requiredNamespaces: requiredNamespaces,
            optionalNamespaces: optionalNamespaces
        )
        
        XCTAssertEqual(result.count, 1, "Should have one namespace")
        XCTAssertNotNil(result["eip155:1"], "Should contain eip155:1 namespace")
        
        let eip155Namespace = result["eip155:1"]!
        XCTAssertNil(eip155Namespace.chains, "Chains should be nil")
        XCTAssertEqual(eip155Namespace.methods, ["eth_sign", "personal_sign"], "Methods should be merged")
        XCTAssertEqual(eip155Namespace.events, ["chainChanged", "accountsChanged"], "Events should be merged")
    }

    // MARK: - Complex merging scenarios

    func testMergeMultipleNamespaces() {
        let requiredNamespaces: [String: ProposalNamespace] = [
            "eip155": ProposalNamespace(
                chains: [ethChain],
                methods: ["eth_sign"],
                events: ["chainChanged"]
            ),
            "solana": ProposalNamespace(
                chains: [solanaChain],
                methods: ["solana_signMessage"],
                events: []
            )
        ]
        let optionalNamespaces: [String: ProposalNamespace] = [
            "eip155": ProposalNamespace(
                chains: [polyChain],
                methods: ["personal_sign"],
                events: ["accountsChanged"]
            ),
            "cosmos": ProposalNamespace(
                chains: [cosmosChain],
                methods: ["cosmos_signDirect"],
                events: ["someEvent"]
            )
        ]
        
        let result = NamespaceMerger.mergeRequiredIntoOptional(
            requiredNamespaces: requiredNamespaces,
            optionalNamespaces: optionalNamespaces
        )
        
        XCTAssertEqual(result.count, 3, "Should have three namespaces")
        
        // Check eip155 (merged)
        let eip155Namespace = result["eip155"]!
        XCTAssertEqual(eip155Namespace.chains, [ethChain, polyChain], "eip155 chains should be merged")
        XCTAssertEqual(eip155Namespace.methods, ["eth_sign", "personal_sign"], "eip155 methods should be merged")
        XCTAssertEqual(eip155Namespace.events, ["chainChanged", "accountsChanged"], "eip155 events should be merged")
        
        // Check solana (from required only)
        let solanaNamespace = result["solana"]!
        XCTAssertEqual(solanaNamespace.chains, [solanaChain], "solana chains should match")
        XCTAssertEqual(solanaNamespace.methods, ["solana_signMessage"], "solana methods should match")
        XCTAssertEqual(solanaNamespace.events, [], "solana events should match")
        
        // Check cosmos (from optional only)
        let cosmosNamespace = result["cosmos"]!
        XCTAssertEqual(cosmosNamespace.chains, [cosmosChain], "cosmos chains should match")
        XCTAssertEqual(cosmosNamespace.methods, ["cosmos_signDirect"], "cosmos methods should match")
        XCTAssertEqual(cosmosNamespace.events, ["someEvent"], "cosmos events should match")
    }

    // MARK: - Edge cases

    func testMergeWithDuplicateMethodsAndEvents() {
        let requiredNamespaces: [String: ProposalNamespace] = [
            "eip155": ProposalNamespace(
                chains: [ethChain],
                methods: ["eth_sign", "personal_sign"],
                events: ["chainChanged", "accountsChanged"]
            )
        ]
        let optionalNamespaces: [String: ProposalNamespace] = [
            "eip155": ProposalNamespace(
                chains: [polyChain],
                methods: ["personal_sign", "eth_signTypedData"], // personal_sign is duplicate
                events: ["accountsChanged", "someEvent"] // accountsChanged is duplicate
            )
        ]
        
        let result = NamespaceMerger.mergeRequiredIntoOptional(
            requiredNamespaces: requiredNamespaces,
            optionalNamespaces: optionalNamespaces
        )
        
        XCTAssertEqual(result.count, 1, "Should have one namespace")
        XCTAssertNotNil(result["eip155"], "Should contain eip155 namespace")
        
        let eip155Namespace = result["eip155"]!
        XCTAssertEqual(eip155Namespace.chains, [ethChain, polyChain], "Chains should be merged")
        XCTAssertEqual(eip155Namespace.methods, ["eth_sign", "personal_sign", "eth_signTypedData"], "Methods should be merged without duplicates")
        XCTAssertEqual(eip155Namespace.events, ["chainChanged", "accountsChanged", "someEvent"], "Events should be merged without duplicates")
    }
} 
