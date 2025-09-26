//
//  File.swift
//  reown
//
//  Created by BARTOSZ ROZWARSKI on 25/09/2025.
//

import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - App State Observer
class WalletKitAppStateObserver {
    @objc var onWillEnterForeground: (() -> Void)?
    @objc var onWillEnterBackground: (() -> Void)?

    init() {
        subscribeNotificationCenter()
    }

    private func subscribeNotificationCenter() {
#if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterBackground),
            name: UIApplication.willResignActiveNotification,
            object: nil)
#elseif os(macOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: NSApplication.willBecomeActiveNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterBackground),
            name: NSApplication.willResignActiveNotification,
            object: nil)
#endif
    }

    @objc
    private func appWillEnterBackground() {
        onWillEnterBackground?()
    }

    @objc
    private func appWillEnterForeground() {
        onWillEnterForeground?()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
