import Foundation

class VerifyContextFactory {

    private func ensureUrlHasScheme(_ urlString: String) -> String {
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return urlString
        } else {
            return "https://" + urlString
        }
    }

    public func createVerifyContext(origin: String?, domain: String, isScam: Bool?, isVerified: Bool?) -> VerifyContext {

        guard isScam != true else {
            return VerifyContext(
                origin: origin,
                validation: .scam
            )
        }

        // If isVerified is provided and is false, return unknown
        if let isVerified = isVerified, !isVerified {
            return VerifyContext(
                origin: origin,
                validation: .unknown
            )
        }

        // Ensure both origin and domain have a scheme
        let originWithScheme = origin.map { ensureUrlHasScheme($0) }
        let domainWithScheme = ensureUrlHasScheme(domain)

        if let originWithScheme, let originUrl = URL(string: originWithScheme), let domainUrl = URL(string: domainWithScheme) {
            return VerifyContext(
                origin: origin,
                validation: (originUrl.host == domainUrl.host) ? .valid : .invalid
            )
        } else {
            return VerifyContext(
                origin: origin,
                validation: .unknown
            )
        }
    }

    public func createVerifyContextForLinkMode(redirectUniversalLink: String, domain: String) -> VerifyContext {
        // Link mode messages are delivered directly to the wallet and never pass
        // through the Verify server, so there is no attestation to validate the
        // origin against. The verify context therefore always resolves to
        // unknown with an empty origin.
        return VerifyContext(
            origin: "",
            validation: .unknown
        )
    }
}
