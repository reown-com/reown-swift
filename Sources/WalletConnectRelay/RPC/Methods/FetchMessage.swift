import Foundation

/// `irn_fetchMessages` — fetches messages that were published to a topic while the
/// client had no active subscription (relay mailbox). The relay does not always push
/// mailboxed messages on subscribe, so clients must explicitly fetch them after
/// subscribing to a freshly-paired topic. See WalletConnect relay-server-rpc spec.
struct FetchMessage: RelayRPC {

    struct Params: Codable {
        let topic: String
    }

    let params: Params

    var method: String {
        "irn_fetchMessages"
    }
}

/// Result of an `irn_fetchMessages` call.
struct FetchMessagesResult: Codable {
    struct ReceivedMessage: Codable {
        let topic: String
        let message: String
        let publishedAt: Date
        let tag: Int?
        let attestation: String?

        enum CodingKeys: String, CodingKey {
            case topic, message, publishedAt, tag, attestation
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            topic = try container.decode(String.self, forKey: .topic)
            message = try container.decode(String.self, forKey: .message)
            tag = try? container.decode(Int.self, forKey: .tag)
            attestation = try? container.decode(String.self, forKey: .attestation)
            let publishedAtMilliseconds = try container.decode(UInt64.self, forKey: .publishedAt)
            publishedAt = Date(milliseconds: publishedAtMilliseconds)
        }
    }

    let messages: [ReceivedMessage]
    let hasMore: Bool?
}
