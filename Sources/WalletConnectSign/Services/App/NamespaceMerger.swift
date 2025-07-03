import Foundation

/// A utility class for merging required namespaces into optional namespaces
/// to improve connection compatibility between dApps and wallets.
final class NamespaceMerger {
    
    /// Merges required namespaces into optional namespaces, avoiding duplications.
    /// This method moves all required namespaces to optional namespaces to prevent
    /// connection failures when wallets don't support all required methods/chains.
    ///
    /// - Parameters:
    ///   - requiredNamespaces: The required namespaces to be merged
    ///   - optionalNamespaces: The existing optional namespaces (can be nil)
    /// - Returns: A merged dictionary of optional namespaces containing both original optional and moved required namespaces
    static func mergeRequiredIntoOptional(
        requiredNamespaces: [String: ProposalNamespace],
        optionalNamespaces: [String: ProposalNamespace]? = nil
    ) -> [String: ProposalNamespace] {
        var mergedOptionalNamespaces = optionalNamespaces ?? [:]
        
        // Merge required namespaces into optional namespaces, avoiding duplications
        for (key, requiredNamespace) in requiredNamespaces {
            if let existingOptional = mergedOptionalNamespaces[key] {
                // Merge chains
                let mergedChains = mergeChains(required: requiredNamespace.chains, optional: existingOptional.chains)
                
                // Merge methods
                let mergedMethods = requiredNamespace.methods.union(existingOptional.methods)
                
                // Merge events
                let mergedEvents = requiredNamespace.events.union(existingOptional.events)
                
                mergedOptionalNamespaces[key] = ProposalNamespace(
                    chains: mergedChains,
                    methods: mergedMethods,
                    events: mergedEvents
                )
            } else {
                // If no existing optional namespace for this key, add the required one
                mergedOptionalNamespaces[key] = requiredNamespace
            }
        }
        
        return mergedOptionalNamespaces
    }
    
    /// Helper method to merge chains from required and optional namespaces
    /// - Parameters:
    ///   - required: The chains from the required namespace
    ///   - optional: The chains from the optional namespace
    /// - Returns: A merged array of chains without duplicates
    private static func mergeChains(required: [Blockchain]?, optional: [Blockchain]?) -> [Blockchain]? {
        var mergedChains: [Blockchain] = []
        
        if let required = required {
            mergedChains.append(contentsOf: required)
        }
        
        if let optional = optional {
            // Add optional chains that are not already in the merged list
            for chain in optional {
                if !mergedChains.contains(chain) {
                    mergedChains.append(chain)
                }
            }
        }
        
        return mergedChains.isEmpty ? nil : mergedChains
    }
} 