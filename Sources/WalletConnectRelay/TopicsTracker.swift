import Foundation

// Protocol defining the interface for tracking topics
public protocol TopicsTracking {
    func addTopics(_ topics: [String])
    func removeTopics(_ topics: [String])
    func isTrackingAnyTopics() -> Bool
    func getAllTopics() -> [String] 
}

// Concrete implementation of TopicsTracking
public final class TopicsTracker: TopicsTracking {
    // MARK: - Properties
    
    // Synchronization queue to ensure thread safety
    private let syncQueue = DispatchQueue(label: "com.walletconnect.sdk.topics_tracker.sync", qos: .utility)
    
    // Set of topics being tracked (using Set for efficient lookup, add, and remove operations)
    private var topics: Set<String> = []
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - TopicsTracking Methods
    
    /// Add topics to the tracker
    /// - Parameter topics: Array of topics to add
    public func addTopics(_ topics: [String]) {
        guard !topics.isEmpty else { return }
        
        syncQueue.sync {
            self.topics.formUnion(topics)
        }
    }
    
    /// Remove topics from the tracker
    /// - Parameter topics: Array of topics to remove
    public func removeTopics(_ topics: [String]) {
        guard !topics.isEmpty else { return }
        
        syncQueue.sync {
            self.topics.subtract(topics)
        }
    }
    
    /// Check if any topics are being tracked
    /// - Returns: Boolean indicating if at least one topic is being tracked
    public func isTrackingAnyTopics() -> Bool {
        return syncQueue.sync {
            !self.topics.isEmpty
        }
    }
    /// Get all currently tracked topics
    /// - Returns: Array of all tracked topics
    public func getAllTopics() -> [String] {
        return syncQueue.sync {
            Array(self.topics)
        }
    }
}

#if DEBUG
// Mock implementation for testing
public final class TopicsTrackerMock: TopicsTracking {
    public var addTopicsCallCount = 0
    public var removeTopicsCallCount = 0
    public var isTrackingAnyTopicsCallCount = 0
    
    public var isTrackingAnyTopicsReturnValue = false
    
    private var topics: Set<String> = []
    
    public init() {}
    
    public func addTopics(_ topics: [String]) {
        addTopicsCallCount += 1
        self.topics.formUnion(topics)
    }
    
    public func removeTopics(_ topics: [String]) {
        removeTopicsCallCount += 1
        self.topics.subtract(topics)
    }
    
    public func isTrackingAnyTopics() -> Bool {
        isTrackingAnyTopicsCallCount += 1
        return isTrackingAnyTopicsReturnValue
    }
    
    public func getAllTopics() -> [String] {
        return Array(topics)
    }
}
#endif 
