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

    // MARK: - Chain ordering tests

    func testChainOrderingInMerge() {
        // Create multiple chains in specific order
        let chain1 = Blockchain("eip155:1")!
        let chain2 = Blockchain("eip155:137")!
        let chain3 = Blockchain("eip155:5")!
        let chain4 = Blockchain("eip155:10")!
        let chain5 = Blockchain("eip155:56")!
        
        // Required namespaces with chains in specific order
        let requiredNamespaces: [String: ProposalNamespace] = [
            "eip155": ProposalNamespace(
                chains: [chain1, chain2, chain3], // Order: 1, 137, 5
                methods: ["eth_sign"],
                events: ["chainChanged"]
            )
        ]
        
        // Optional namespaces with chains in different order
        let optionalNamespaces: [String: ProposalNamespace] = [
            "eip155": ProposalNamespace(
                chains: [chain4, chain5, chain2], // Order: 10, 56, 137 (chain2 is duplicate)
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
        
        // Verify that required chains come first in their original order
        // Then optional chains that aren't duplicates, in their original order
        let expectedChainOrder = [chain1, chain2, chain3, chain4, chain5]
        XCTAssertEqual(eip155Namespace.chains, expectedChainOrder, "Chains should be merged in correct order: required first, then optional")
    }

    func testChainOrderingWithMultipleNamespaces() {
        // Create chains for different namespaces
        let ethChain1 = Blockchain("eip155:1")!
        let ethChain2 = Blockchain("eip155:137")!
        let ethChain3 = Blockchain("eip155:5")!
        let ethChain4 = Blockchain("eip155:10")!
        
        let solanaChain1 = Blockchain("solana:mainnet")!
        let solanaChain2 = Blockchain("solana:devnet")!
        let solanaChain3 = Blockchain("solana:testnet")!
        
        // Required namespaces with specific chain orders
        let requiredNamespaces: [String: ProposalNamespace] = [
            "eip155": ProposalNamespace(
                chains: [ethChain1, ethChain2], // Order: 1, 137
                methods: ["eth_sign"],
                events: ["chainChanged"]
            ),
            "solana": ProposalNamespace(
                chains: [solanaChain1, solanaChain2], // Order: mainnet, devnet
                methods: ["solana_signMessage"],
                events: []
            )
        ]
        
        // Optional namespaces with different chain orders and some duplicates
        let optionalNamespaces: [String: ProposalNamespace] = [
            "eip155": ProposalNamespace(
                chains: [ethChain3, ethChain4, ethChain1], // Order: 5, 10, 1 (1 is duplicate)
                methods: ["personal_sign"],
                events: ["accountsChanged"]
            ),
            "solana": ProposalNamespace(
                chains: [solanaChain3, solanaChain1], // Order: testnet, mainnet (mainnet is duplicate)
                methods: ["solana_signTransaction"],
                events: ["accountChanged"]
            )
        ]
        
        let result = NamespaceMerger.mergeRequiredIntoOptional(
            requiredNamespaces: requiredNamespaces,
            optionalNamespaces: optionalNamespaces
        )
        
        XCTAssertEqual(result.count, 2, "Should have two namespaces")
        
        // Check eip155 namespace chain ordering
        let eip155Namespace = result["eip155"]!
        let expectedEip155Chains = [ethChain1, ethChain2, ethChain3, ethChain4]
        XCTAssertEqual(eip155Namespace.chains, expectedEip155Chains, "eip155 chains should be in correct order: required first, then optional")
        
        // Check solana namespace chain ordering
        let solanaNamespace = result["solana"]!
        let expectedSolanaChains = [solanaChain1, solanaChain2, solanaChain3]
        XCTAssertEqual(solanaNamespace.chains, expectedSolanaChains, "solana chains should be in correct order: required first, then optional")
    }

    func testChainOrderingWithNilChains() {
        // Test that nil chains are handled correctly and don't affect ordering
        let chain1 = Blockchain("eip155:1")!
        let chain2 = Blockchain("eip155:137")!
        
        let requiredNamespaces: [String: ProposalNamespace] = [
            "eip155": ProposalNamespace(
                chains: [chain1, chain2], // Has chains
                methods: ["eth_sign"],
                events: ["chainChanged"]
            ),
            "cosmos": ProposalNamespace(
                chains: nil, // No chains
                methods: ["cosmos_signDirect"],
                events: ["someEvent"]
            )
        ]
        
        let optionalNamespaces: [String: ProposalNamespace] = [
            "eip155": ProposalNamespace(
                chains: nil, // No chains
                methods: ["personal_sign"],
                events: ["accountsChanged"]
            ),
            "cosmos": ProposalNamespace(
                chains: [cosmosChain], // Has chains
                methods: ["cosmos_signAmino"],
                events: ["anotherEvent"]
            )
        ]
        
        let result = NamespaceMerger.mergeRequiredIntoOptional(
            requiredNamespaces: requiredNamespaces,
            optionalNamespaces: optionalNamespaces
        )
        
        XCTAssertEqual(result.count, 2, "Should have two namespaces")
        
        // Check eip155 namespace - should preserve chains from required
        let eip155Namespace = result["eip155"]!
        XCTAssertEqual(eip155Namespace.chains, [chain1, chain2], "eip155 should preserve required chains in order")
        
        // Check cosmos namespace - should have chains from optional
        let cosmosNamespace = result["cosmos"]!
        XCTAssertEqual(cosmosNamespace.chains, [cosmosChain], "cosmos should have optional chains")
    }
} 
