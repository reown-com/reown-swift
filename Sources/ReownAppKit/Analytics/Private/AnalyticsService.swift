import Foundation

class AnalyticsService: AnalyticsProvider, ObservableObject {
    private(set) static var shared = AnalyticsService(providers: [
//        LoggingAnalyticsProvider(),
        ClickstreamAnalyticsProvider()
    ])

    private let providers: [AnalyticsProvider]
    var method: AnalyticsEvent.Method = .mobile

    var isAnalyticsEnabled: Bool {
        return UserDefaults.standard.bool(forKey: analyticsEnabledKey)
    }

    // Key to store the state of analytics
    private let analyticsEnabledKey = "com.walletconnect.w3m.analyticsEnabled"

    init(providers: [AnalyticsProvider]) {
        self.providers = providers
        // Set default value for analytics enabled if it's not already set
        if UserDefaults.standard.object(forKey: analyticsEnabledKey) == nil {
            UserDefaults.standard.set(true, forKey: analyticsEnabledKey)
        }
    }

    func track(_ event: AnalyticsEvent) {
        guard isAnalyticsEnabled else { return }

        providers.forEach {
            $0.track(event)
        }
        if case .SELECT_WALLET(_, let platform) = event {
            self.method = platform
        }
    }

    func disable() {
        UserDefaults.standard.set(false, forKey: analyticsEnabledKey)
    }

    func enable() {
        UserDefaults.standard.set(true, forKey: analyticsEnabledKey)
    }
}

import SwiftUI

struct AnalyticsServiceKey: EnvironmentKey {
    static var defaultValue: AnalyticsService = .shared
}

extension EnvironmentValues {
    var analyticsService: AnalyticsService {
        get { self[AnalyticsServiceKey.self] }
        set { self[AnalyticsServiceKey.self] = newValue }
    }
}
