class LoggingAnalyticsProvider: AnalyticsProvider {
    private let eventMapper = DefaultAnalyticsEventMapper()

    func track(_ event: AnalyticsEvent) {
        let name = eventMapper.eventName(for: event)
        let properties = eventMapper.parameters(for: event)
        print("📊 Event reported: \(name), properties: \(properties)")
    }
}
