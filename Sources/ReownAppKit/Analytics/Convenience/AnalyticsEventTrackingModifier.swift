import SwiftUI

/// A view modifier that tracks analytics events
struct AnalyticsEventTrackingModifier: ViewModifier {
    
    @EnvironmentObject var analyticsService: AnalyticsService
    
    /// The groups of analytics events to track
    let groups: [AnalyticsEventGroup]
        
    func body(content: Content) -> some View {
        content
            .onAppear {
                trackAll(in: groups(for: .onAppear))
            }
            .onDisappear {
                trackAll(in: groups(for: .onDisappear))
            }
            .onTapGesture {
                trackAll(in: groups(for: .onTapGesture))
            }
    }
    
    // MARK: Helpers
    
    /// Returns the group for the given trigger
    private func groups(for trigger: AnalyticsEventTrigger) -> [AnalyticsEventGroup] {
        groups.filter { $0.trigger == trigger }
    }
    
    /// Track all events in the given group
    private func trackAll(in group: [AnalyticsEventGroup]) {
        groups
            .flatMap { $0.events }
            .forEach { event in
                analyticsService.track(event)
            }
    }
}
