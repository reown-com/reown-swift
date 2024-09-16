protocol AnalyticsEventMapper {
    func eventName(for event: AnalyticsEvent) -> String
    func parameters(for event: AnalyticsEvent) -> [String: String]
}
