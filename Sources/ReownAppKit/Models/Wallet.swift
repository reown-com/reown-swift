import Foundation

public struct Wallet: Codable, Identifiable {
    public let id: String
    let name: String
    let homepage: String
    let imageId: String?
    let imageUrl: String?
    let order: Int
    let mobileLink: String?
    let linkMode: String?
    let desktopLink: String?
    let webappLink: String?
    let appStore: String?
    
    var lastTimeUsed: Date?
    var isInstalled: Bool = false
    var alternativeConnectionMethod: (() -> Void)? = nil
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case homepage
        case imageId = "image_id"
        case imageUrl = "image_url"
        case order
        case mobileLink = "mobile_link"
        case linkMode = "link_mode"
        case desktopLink = "desktop_link"
        case webappLink = "webapp_link"
        case appStore = "app_store"
        
        // Decorated
        case lastTimeUsed
        case isInstalled
    }
    
    public init(
        id: String,
        name: String, 
        homepage: String, 
        imageId: String? = nil,
        imageUrl: String? = nil,
        order: Int,
        mobileLink: String?, 
        linkMode: String?,
        desktopLink: String? = nil,
        webappLink: String? = nil, 
        appStore: String? = nil, 
        lastTimeUsed: Date? = nil, 
        isInstalled: Bool = false,
        alternativeConnectionMethod: (() -> Void)? = nil
    ) {
        self.id = id
        self.name = name
        self.homepage = homepage
        self.imageId = imageId
        self.imageUrl = imageUrl
        self.order = order
        self.mobileLink = mobileLink
        self.linkMode = linkMode
        self.desktopLink = desktopLink
        self.webappLink = webappLink
        self.appStore = appStore
        self.lastTimeUsed = lastTimeUsed
        self.isInstalled = isInstalled
        self.alternativeConnectionMethod = alternativeConnectionMethod
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.homepage = try container.decode(String.self, forKey: .homepage)
        self.imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        self.imageId = try container.decodeIfPresent(String.self, forKey: .imageId)
        self.order = try container.decode(Int.self, forKey: .order)
        self.linkMode = try container.decodeIfPresent(String.self, forKey: .linkMode)
        self.mobileLink = try container.decodeIfPresent(String.self, forKey: .mobileLink)
        self.desktopLink = try container.decodeIfPresent(String.self, forKey: .desktopLink)
        self.webappLink = try container.decodeIfPresent(String.self, forKey: .webappLink)
        self.appStore = try container.decodeIfPresent(String.self, forKey: .appStore)
        self.lastTimeUsed = try container.decodeIfPresent(Date.self, forKey: .lastTimeUsed)
        self.isInstalled = try container.decodeIfPresent(Bool.self, forKey: .isInstalled) ?? false
    }
}

extension Wallet: Equatable {
    public static func == (lhs: Wallet, rhs: Wallet) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Wallet: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#if DEBUG

extension Wallet {
    static let stubList: [Wallet] = [
        Wallet(
            id: UUID().uuidString,
            name: "Sample Wallet",
            homepage: "https://example.com/cool",
            imageId: "0528ee7e-16d1-4089-21e3-bbfb41933100",
            order: 1,
            mobileLink: "https://sample.com/foo/universal",
            linkMode: "https://lab.web3modal.com/wallet", desktopLink: "sampleapp://deeplink",
            webappLink: "https://sample.com/foo/webapp",
            appStore: ""
        ),
        Wallet(
            id: UUID().uuidString,
            name: "Cool Wallet",
            homepage: "https://example.com/cool",
            imageId: "5195e9db-94d8-4579-6f11-ef553be95100",
            order: 2,
            mobileLink: "awsomeapp://",
            linkMode: "https://lab.web3modal.com/wallet", desktopLink: "awsomeapp://deeplink",
            webappLink: "https://awesome.com/foo/webapp",
            appStore: ""
        ),
        Wallet(
            id: UUID().uuidString,
            name: "Cool Wallet",
            homepage: "https://example.com/cool",
            imageId: "3913df81-63c2-4413-d60b-8ff83cbed500",
            order: 3,
            mobileLink: "https://cool.com/foo/universal",
            linkMode: "https://lab.web3modal.com/wallet",
            desktopLink: "coolapp://deeplink",
            webappLink: "https://cool.com/foo/webapp",
            appStore: ""
        )
    ]
}

#endif
