// swift-tools-version:5.5

import PackageDescription

// Determine if Yttrium should be used in debug (local) mode
let yttriumDebug = true


// Define dependencies array
var dependencies: [Package.Dependency] = [
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0"),
    .package(url: "https://github.com/WalletConnect/QRCode", from: "14.3.1"),
    .package(name: "CoinbaseWalletSDK", url: "https://github.com/WalletConnect/wallet-mobile-sdk", from: "1.0.0"),
//    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", .upToNextMinor(from: "1.10.0")),
]
var yttriumTarget: Target!
// Conditionally add Yttrium dependency
if yttriumDebug {
    var yttriumSwiftSettings: [SwiftSetting] = []
    dependencies.append(.package(path: "../yttrium/crates/ffi/YttriumCore"))
    yttriumSwiftSettings.append(.define("YTTRIUM_DEBUG"))
    yttriumTarget = .target(
        name: "YttriumWrapper",
        dependencies: [.product(name: "YttriumCore", package: "YttriumCore")],
        path: "Sources/YttriumWrapper",
        swiftSettings: yttriumSwiftSettings
    )
} else {
    dependencies.append(.package(url: "https://github.com/reown-com/yttrium", .upToNextMinor(from: "0.0.24")))
    yttriumTarget = .target(
        name: "YttriumWrapper",
        dependencies: [.product(name: "Yttrium", package: "yttrium")],
        path: "Sources/YttriumWrapper"
    )
}

let package = Package(
    name: "WalletConnect",
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
            name: "ReownAppKit",
            targets: ["ReownAppKit"]),
        .library(
            name: "ReownAppKitUI",
            targets: ["ReownAppKitUI"]),
        .library(
            name: "YttriumWrapper",
            targets: ["YttriumWrapper"])
    ],
    dependencies: dependencies,
    targets: [
        .target(
            name: "WalletConnectSign",
            dependencies: ["WalletConnectPairing", "WalletConnectVerify", "WalletConnectSigner", "Events"],
            path: "Sources/WalletConnectSign",
            resources: [.process("Resources/PrivacyInfo.xcprivacy")]),
        .target(
            name: "ReownWalletKit",
            dependencies: ["WalletConnectSign", "WalletConnectPush", "WalletConnectVerify"],
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
            name: "ReownAppKit",
            dependencies: [
                "QRCode",
                "WalletConnectSign",
                "ReownAppKitUI",
                "ReownAppKitBackport",
                "CoinbaseWalletSDK"
            ],
            path: "Sources/ReownAppKit",
            resources: [
                .process("Resources/Assets.xcassets"),
                .copy("PackageConfig.json")
            ]
        ),
        .target(
            name: "ReownAppKitUI",
            dependencies: [
                "ReownAppKitBackport"
            ],
            path: "Sources/ReownAppKitUI",
            resources: [
                .process("Resources/Assets.xcassets")
            ]
        ),
        .target(
            name: "ReownAppKitBackport",
            path: "Sources/ReownAppKitBackport"
        ),
        yttriumTarget,
        .testTarget(
            name: "WalletConnectSignTests",
            dependencies: ["WalletConnectSign", "WalletConnectUtils", "TestingUtils", "WalletConnectVerify"]),
        .testTarget(
            name: "WalletConnectPairingTests",
            dependencies: ["WalletConnectPairing", "TestingUtils"]),
        .testTarget(
            name: "NotifyTests",
            dependencies: ["WalletConnectNotify", "TestingUtils"]),
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
//        .testTarget(
//            name: "ReownAppKitTests",
//            dependencies: [
//                "ReownAppKit",
//                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
//            ]
//        ),
//        .testTarget(
//            name: "ReownAppKitUITests",
//            dependencies: [
//                "ReownAppKitUI",
//                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
//            ]
//        )
    ],
    swiftLanguageVersions: [.v5]
)

