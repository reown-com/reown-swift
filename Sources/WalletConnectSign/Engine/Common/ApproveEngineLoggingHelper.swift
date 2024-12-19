
import Foundation


final class ApproveEngineLoggingHelper {

    private let logger: ConsoleLogging

    init(logger: ConsoleLogging) {
        self.logger = logger
    }

    func logProposalNamespaces(title: String, _ namespaces: [String: ProposalNamespace]) {
        logger.debug("\(title):")
        for (key, namespace) in namespaces {
            logger.debug("  Namespace Key: \(key)")

            if let chains = namespace.chains, !chains.isEmpty {
                let chainList = chains.map { $0.absoluteString }.joined(separator: ", ")
                logger.debug("    Chains: [\(chainList)]")
            } else {
                logger.debug("    Chains: None")
            }

            if !namespace.methods.isEmpty {
                let methodsList = namespace.methods.sorted().joined(separator: ", ")
                logger.debug("    Methods: [\(methodsList)]")
            } else {
                logger.debug("    Methods: None")
            }

            if !namespace.events.isEmpty {
                let eventsList = namespace.events.sorted().joined(separator: ", ")
                logger.debug("    Events: [\(eventsList)]")
            } else {
                logger.debug("    Events: None")
            }
        }
    }

    func logSessionNamespaces(_ sessionNamespaces: [String: SessionNamespace]) {
        logger.debug("Session Namespaces:")
        for (namespaceKey, ns) in sessionNamespaces {
            logger.debug("Namespace: \(namespaceKey)")

            if let chains = ns.chains, !chains.isEmpty {
                let chainStrings = chains.map { $0.absoluteString }.joined(separator: ", ")
                logger.debug("  Chains: [\(chainStrings)]")
            } else {
                logger.debug("  Chains: None")
            }

            if !ns.accounts.isEmpty {
                // Assuming `Account` has a property `address` and `blockchain`
                let accountStrings = ns.accounts.map { "\($0.blockchain.absoluteString):\($0.address)" }.joined(separator: ", ")
                logger.debug("  Accounts: [\(accountStrings)]")
            } else {
                logger.debug("  Accounts: None")
            }

            if !ns.methods.isEmpty {
                let methodList = ns.methods.sorted().joined(separator: ", ")
                logger.debug("  Methods: [\(methodList)]")
            } else {
                logger.debug("  Methods: None")
            }

            if !ns.events.isEmpty {
                let eventList = ns.events.sorted().joined(separator: ", ")
                logger.debug("  Events: [\(eventList)]")
            } else {
                logger.debug("  Events: None")
            }
        }
    }
}
