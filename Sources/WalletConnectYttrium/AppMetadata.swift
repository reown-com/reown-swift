import Foundation

/**
 A structure that identifies a peer connected through a WalletConnect session.
 
 You can provide human-readable information about your app so that it can be shared with a connected peer, for example,
 during a session proposal event.
 
 This information should make the identity of your app clear to the end-user and easily verifiable. Therefore, it is a
 suitable place to briefly communicate your brand.
 */
public struct AppMetadata: Codable, Equatable {

    public struct Redirect: Codable, Equatable {
        enum Errors: Error {
            case invalidLinkModeUniversalLink
            case invalidUniversalLinkURL
        }
        /// Native deeplink URL string.
        public let native: String?

        /// Universal link URL string.
        public let universal: String?

        public let linkMode: Bool?

        /**
         Creates a new Redirect object with the specified information.

         - parameters:
         - native: Native deeplink URL string.
         - universal: Universal link URL string.
         */
        public init(native: String, universal: String?, linkMode: Bool = false) throws {
            if linkMode && universal == nil {
                throw Errors.invalidLinkModeUniversalLink
            }

            if let universal = universal, !Redirect.isValidURL(universal) {
                throw Errors.invalidUniversalLinkURL
            }

            self.native = native
            self.universal = universal
            self.linkMode = linkMode
        }

        private static func isValidURL(_ urlString: String) -> Bool {
            let regex = "^(https?|ftp)://[^\\s/$.?#].[^\\s]*$|^www\\.[^\\s/$.?#].[^\\s]*$"
            return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: urlString)
        }
    }

    /// The name of the app.
    public let name: String

    /// A brief textual description of the app that can be displayed to peers.
    public let description: String

    /// The URL string that identifies the official domain of the app.
    public let url: String

    /// An array of URL strings pointing to the icon assets on the web.
    public let icons: [String]

    /// Redirect links which could be manually used on wallet side.
    public let redirect: Redirect?

    private enum CodingKeys: String, CodingKey {
        case name
        case description
        case url
        case icons
        case redirect
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decode(String.self, forKey: .description)
        self.url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
        self.icons = try container.decode([String].self, forKey: .icons)
        self.redirect = try container.decodeIfPresent(Redirect.self, forKey: .redirect)
    }

    /**
     Creates a new metadata object with the specified information.
     
     - parameters:
        - name: The name of the app.
        - description: A brief textual description of the app that can be displayed to peers.
        - url: The URL string that identifies the official domain of the app.
        - icons: An array of URL strings pointing to the icon assets on the web.
        - redirect: Redirect links which could be manually used on wallet side.
     */
    public init(
        name: String,
        description: String,
        url: String,
        icons: [String],
        redirect: Redirect
    ) {
        self.name = name
        self.description = description
        self.url = url
        self.icons = icons
        self.redirect = redirect
    }
}

#if DEBUG
public extension AppMetadata {
    static func stub() -> AppMetadata {
        AppMetadata(
            name: "Wallet Connect",
            description: "A protocol to connect blockchain wallets to dapps.",
            url: "https://walletconnect.com/",
            icons: [],
            redirect: try! AppMetadata.Redirect(native: "", universal: nil)
        )
    }
}
#endif
