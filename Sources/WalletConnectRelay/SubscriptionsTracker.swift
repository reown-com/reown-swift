import Foundation

protocol SubscriptionsTracking {
    func setSubscription(for topic: String, id: String)
    func getSubscription(for topic: String) -> String?
    func removeSubscription(for topic: String)
    func isSubscribed() -> Bool
    func getTopics() -> [String]
}

public final class SubscriptionsTracker: SubscriptionsTracking {
    private var subscriptions: [String: String] = [:]
    private let concurrentQueue = DispatchQueue(label: "com.walletconnect.sdk.subscriptions_tracker", attributes: .concurrent)
    private let logger: ConsoleLogging

    init(logger: ConsoleLogging) {
        self.logger = logger
    }

    func setSubscription(for topic: String, id: String) {
        logger.debug("Setting subscription for topic: \(topic) with id: \(id)")
        concurrentQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.subscriptions[topic] = id
            self.logger.debug("Subscription set: \(self.subscriptions)")
        }
    }

    func getSubscription(for topic: String) -> String? {
        logger.debug("Getting subscription for topic: \(topic)")
        var result: String?
        concurrentQueue.sync { [weak self] in
            guard let self = self else { return }
            result = self.subscriptions[topic]
            self.logger.debug("Retrieved subscription: \(String(describing: result)) for topic: \(topic)")
        }
        return result
    }

    func removeSubscription(for topic: String) {
        logger.debug("Removing subscription for topic: \(topic)")
        concurrentQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.subscriptions[topic] = nil
            self.logger.debug("Subscription removed for topic: \(topic). Current subscriptions: \(self.subscriptions)")
        }
    }

    func isSubscribed() -> Bool {
        logger.debug("Checking if there are any active subscriptions")
        var result = false
        concurrentQueue.sync { [weak self] in
            guard let self = self else { return }
            result = !self.subscriptions.isEmpty
            self.logger.debug("Is subscribed: \(result)")
        }
        return result
    }

    func getTopics() -> [String] {
        logger.debug("Getting all subscription topics")
        var topics: [String] = []
        concurrentQueue.sync { [weak self] in
            guard let self = self else { return }
            topics = Array(self.subscriptions.keys)
            self.logger.debug("Retrieved topics: \(topics)")
        }
        return topics
    }
}

#if DEBUG
final class SubscriptionsTrackerMock: SubscriptionsTracking {
    var isSubscribedReturnValue: Bool = false
    private var subscriptions: [String: String] = [:]

    func setSubscription(for topic: String, id: String) {
        subscriptions[topic] = id
    }

    func getSubscription(for topic: String) -> String? {
        return subscriptions[topic]
    }

    func removeSubscription(for topic: String) {
        subscriptions[topic] = nil
    }

    func isSubscribed() -> Bool {
        return isSubscribedReturnValue
    }

    func getTopics() -> [String] {
        return Array(subscriptions.keys)
    }
}
#endif
