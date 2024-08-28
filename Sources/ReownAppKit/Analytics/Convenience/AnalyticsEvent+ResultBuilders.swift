import Foundation

/// A builder resulting in an array of analytics event groups
@resultBuilder enum AnalyticsEventGroupBuilder {
    /// Return an array of analytics event groups given a closure containing statements of analytics event groups
    static func buildBlock(_ eventGroups: AnalyticsEventGroup...) -> [AnalyticsEventGroup] {
        eventGroups
    }
}

/// A builder resulting in an array of analytics events
@resultBuilder enum AnalyticsEventBuilder {
    /// Return an array of analytics events given a closure containing statements of analytics events.
    static func buildBlock(_ events: AnalyticsEvent...) -> [AnalyticsEvent] {
        events
    }
}
