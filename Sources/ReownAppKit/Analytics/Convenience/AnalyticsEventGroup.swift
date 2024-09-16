/// A group of analytics events tracked together in response to a common trigger
struct AnalyticsEventGroup {
    // MARK: Properties
    
    /// The trigger causing the analytics events to be tracked
    let trigger: AnalyticsEventTrigger
    
    /// The events being tracked
    let events: [AnalyticsEvent]
    
    // MARK: Initializers
    
    init(_ trigger: AnalyticsEventTrigger, events: [AnalyticsEvent]) {
        self.trigger = trigger
        self.events = events
    }
}

extension AnalyticsEventGroup {
    /// Initialize with a trigger and event builder
    init(_ trigger: AnalyticsEventTrigger, @AnalyticsEventBuilder events: () -> [AnalyticsEvent]) {
        self.init(trigger, events: events())
    }
}
