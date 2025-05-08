// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "reown",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
        .tvOS(.v13)
    ],
    products: [
        .library(
            name: "WalletConnect",
            targets: ["WalletConnectSign"]),
        .library(
            name: "ReownWalletKit",
            targets: ["ReownWalletKit"]),
        .library(
            name: "WalletConnectPairing",
            targets: ["WalletConnectPairing"]),
        .library(
            name: "WalletConnectNotify",
            targets: ["WalletConnectNotify"]),
        .library(
            name: "WalletConnectPush",
            targets: ["WalletConnectPush"]),
        .library(
            name: "ReownRouter",
            targets: ["ReownRouter", "WalletConnectRouterLegacy"]),
        .library(
            name: "WalletConnectNetworking",
            targets: ["WalletConnectNetworking"]),
        .library(
            name: "WalletConnectVerify",
            targets: ["WalletConnectVerify"]),
        .library(
            name: "WalletConnectIdentity",
            targets: ["WalletConnectIdentity"]),
        .library(
            name: "YttriumWrapper",
            targets: ["YttriumWrapper"])
    ],
    dependencies: [
        .package(url: "https://github.com/reown-com/yttrium", .exact("0.9.0"))
    ],
    targets: [
        .target(
            name: "WalletConnectSign",
            dependencies: ["WalletConnectPairing", "WalletConnectVerify", "WalletConnectSigner", "Events", "YttriumWrapper"],
            path: "Sources/WalletConnectSign",
            resources: [.process("Resources/PrivacyInfo.xcprivacy")]),
        .target(
            name: "ReownWalletKit",
            dependencies: ["WalletConnectSign", "WalletConnectPush", "WalletConnectVerify", "YttriumWrapper"],
            path: "Sources/ReownWalletKit",
            resources: [.process("Resources/PrivacyInfo.xcprivacy")]),
        .target(
            name: "WalletConnectNotify",
            dependencies: ["WalletConnectPairing", "WalletConnectIdentity", "WalletConnectPush", "WalletConnectSigner", "Database"],
            path: "Sources/WalletConnectNotify",
            resources: [.process("Resources/PrivacyInfo.xcprivacy")]),
        .target(
            name: "WalletConnectPush",
            dependencies: ["WalletConnectNetworking", "WalletConnectJWT"],
            path: "Sources/WalletConnectPush",
            resources: [.process("Resources/PrivacyInfo.xcprivacy")]),
        .target(
            name: "WalletConnectRelay",
            dependencies: ["WalletConnectJWT"],
            path: "Sources/WalletConnectRelay",
            resources: [.copy("PackageConfig.json"), .process("Resources/PrivacyInfo.xcprivacy")]),
        .target(
            name: "WalletConnectKMS",
            dependencies: ["WalletConnectUtils"],
            path: "Sources/WalletConnectKMS"),
        .target(
            name: "WalletConnectPairing",
            dependencies: ["WalletConnectNetworking", "Events"],
            resources: [.process("Resources/PrivacyInfo.xcprivacy")]),
        .target(
            name: "WalletConnectSigner",
            dependencies: ["WalletConnectNetworking"]),
        .target(
            name: "WalletConnectJWT",
            dependencies: ["WalletConnectKMS"]),
        .target(
            name: "WalletConnectIdentity",
            dependencies: ["WalletConnectNetworking"],
            resources: [.process("Resources/PrivacyInfo.xcprivacy")]),
        .target(
            name: "WalletConnectUtils",
            dependencies: ["JSONRPC"]),
        .target(
            name: "JSONRPC",
            dependencies: ["Commons"]),
        .target(
            name: "Commons",
            dependencies: []),
        .target(
            name: "HTTPClient",
            dependencies: []),
        .target(
            name: "WalletConnectNetworking",
            dependencies: ["HTTPClient", "WalletConnectRelay"]),
        .target(
            name: "WalletConnectRouterLegacy",
            dependencies: [],
            path: "Sources/ReownRouter/RouterLegacy"),
        .target(
            name: "ReownRouter",
            dependencies: ["WalletConnectRouterLegacy"],
            path: "Sources/ReownRouter/Router"),
        .target(
            name: "WalletConnectVerify",
            dependencies: ["WalletConnectUtils", "WalletConnectNetworking", "WalletConnectJWT"],
            resources: [.process("Resources/PrivacyInfo.xcprivacy")]),
        .target(
            name: "Database",
            dependencies: ["WalletConnectUtils"]),
        .target(
            name: "Events",
            dependencies: ["WalletConnectUtils", "WalletConnectNetworking"]),
        .target(
            name: "YttriumWrapper",
            dependencies: [.product(name: "Yttrium", package: "yttrium")],
            path: "Sources/YttriumWrapper"
        ),
        .testTarget(
            name: "WalletConnectSignTests",
            dependencies: ["WalletConnectSign", "WalletConnectUtils", "TestingUtils", "WalletConnectVerify"]),
        .testTarget(
            name: "WalletConnectPairingTests",
            dependencies: ["WalletConnectPairing", "TestingUtils"]),
        .testTarget(
            name: "NotifyTests",
            dependencies: ["WalletConnectNotify", "TestingUtils", "YttriumWrapper"]),
        .testTarget(
            name: "RelayerTests",
            dependencies: ["WalletConnectRelay", "WalletConnectUtils", "TestingUtils"]),
        .testTarget(
            name: "VerifyTests",
            dependencies: ["WalletConnectVerify", "TestingUtils", "WalletConnectSign"]),
        .testTarget(
            name: "WalletConnectKMSTests",
            dependencies: ["WalletConnectKMS", "WalletConnectUtils", "TestingUtils"]),
        .target(
            name: "TestingUtils",
            dependencies: ["WalletConnectPairing"],
            path: "Tests/TestingUtils"),
        .testTarget(
            name: "WalletConnectUtilsTests",
            dependencies: ["WalletConnectUtils", "TestingUtils"]),
        .testTarget(
            name: "JSONRPCTests",
            dependencies: ["JSONRPC", "TestingUtils"]),
        .testTarget(
            name: "CommonsTests",
            dependencies: ["Commons", "TestingUtils"]),
        .testTarget(
            name: "EventsTests",
            dependencies: ["Events"]),
    ],
    swiftLanguageVersions: [.v5]
)

