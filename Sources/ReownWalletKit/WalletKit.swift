import Foundation
import Combine
import WalletConnectPay

#if SWIFT_PACKAGE
public typealias VerifyContext = WalletConnectVerify.VerifyContext
#endif

/// WalletKit instance wrapper
///
/// ```Swift
/// let metadata = AppMetadata(
///     name: "Swift wallet",
///     description: "wallet",
///     url: "wallet.connect",
///     icons:  ["https://my_icon.com/1"]
/// )
/// WalletKit.configure(metadata: metadata, account: account)
/// WalletKit.instance.getSessions()
/// ```
public class WalletKit {
    /// WalletKit client instance
    public static var instance: WalletKitClient = {
        guard let config = WalletKit.config else {
            fatalError("Error - you must call WalletKit.configure(_:) before accessing the shared instance.")
        }
        return WalletKitClientFactory.create(
            signClient: Sign.instance,
            pairingClient: Pair.instance as! PairingClient,
            pushClient: Push.instance,
            config: config
        )
    }()
    
    private static var config: Config?

    private init() { }

    /// Wallet instance wallet config method.
    /// - Parameters:
    ///   - metadata: App metadata
    ///   - crypto: Auth crypto utils
    ///   - pushHost: Push notification host
    ///   - environment: APNS environment
    ///   - pimlicoApiKey: Optional Pimlico API key
    ///   - payLogging: Enable Pay SDK debug logging
    static public func configure(
        metadata: AppMetadata,
        crypto: CryptoProvider,
        pushHost: String = "echo.walletconnect.com",
        environment: APNSEnvironment = .production,
        pimlicoApiKey: String? = nil,
        payLogging: Bool = false
    ) {
        Pair.configure(metadata: metadata)
        Push.configure(pushHost: pushHost, environment: environment)
        Sign.configure(crypto: crypto)
        WalletKit.config = WalletKit.Config(crypto: crypto, pimlicoApiKey: pimlicoApiKey)

        // Configure Pay SDK using projectId from Networking
        WalletConnectPay.configure(appId: Networking.projectId, logging: payLogging)
    }

    /// Check if a string is a WalletConnect Pay payment link
    ///
    /// This static method can be called before `WalletKit.configure()` to quickly
    /// detect if a scanned QR code or deep link is a payment link.
    ///
    /// - Parameter string: The string to check (URL, WC URI, or bare payment ID)
    /// - Returns: `true` if the string appears to be a payment link
    public static func isPaymentLink(_ string: String) -> Bool {
        PaymentLinkDetector.isPaymentLink(string)
    }
}
