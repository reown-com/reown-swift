import Foundation

class LinkModeTopicsStorage {
    static let shared = LinkModeTopicsStorage()
    
    private init() {}
    
    private var topics = Set<String>()
    
    func addTopic(_ topic: String) {
        topics.insert(topic)
    }
    
    func containsTopic(_ topic: String) -> Bool {
        return topics.contains(topic)
    }
    
    func clearAll() {
        topics.removeAll()
    }
} 