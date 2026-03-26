import UserNotifications
import ReownWalletKit

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        self.bestAttemptContent = request.content

        if let content = bestAttemptContent,
           let topic = content.userInfo["topic"] as? String,
           let ciphertext = content.userInfo["message"] as? String,
           let tag = content.userInfo["tag"] as? UInt {

            if WalletKitDecryptionService.canHandle(tag: tag) {
                let mutableContent = handleWalletKitNotification(content: content, topic: topic, tag: tag, ciphertext: ciphertext)
                contentHandler(mutableContent)
            } else {
                let mutableContent = content.mutableCopy() as! UNMutableNotificationContent
                mutableContent.title = "Error: unknown message tag"
                contentHandler(mutableContent)
            }
        }
    }

    private func handleWalletKitNotification(content: UNNotificationContent, topic: String, tag: UInt, ciphertext: String) -> UNMutableNotificationContent {

        do {
            let WalletKitDecryptionService = try WalletKitDecryptionService(groupIdentifier: "group.com.walletconnect.sdk")

            let decryptedPayload = try WalletKitDecryptionService.decryptMessage(topic: topic, ciphertext: ciphertext, tag: tag)

            let mutableContent = content.mutableCopy() as! UNMutableNotificationContent

            guard let metadata = WalletKitDecryptionService.getMetadata(topic: topic) else {
                mutableContent.title = "Error: Cannot get peer's metadata"
                return mutableContent
            }

            switch decryptedPayload.requestMethod {
            case .sessionProposal:
                mutableContent.title = "New session proposal!"
                mutableContent.body = "A new session proposal arrived from \(metadata.name), please check your wallet"
            case .sessionRequest:
                if let payload = decryptedPayload as? RequestPayload {
                    mutableContent.title = "New session request!"
                    mutableContent.body =  "A new session request \(payload.request.method) arrived from \(metadata.name), please check your wallet"
                }
            case .authRequest:
                mutableContent.title = "New authentication request!"
                mutableContent.body = "A new authentication request arrived from \(metadata.name), please check your wallet"
            }

            return mutableContent
        } catch {
            let mutableContent = content.mutableCopy() as! UNMutableNotificationContent
            mutableContent.title = "Error"
            mutableContent.body = error.localizedDescription

            return mutableContent
        }
    }


    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }


}
