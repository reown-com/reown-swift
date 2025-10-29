//
//  URLExtension.swift
//  WalletApp
//
//  Created by BARTOSZ ROZWARSKI on 13/08/2025.
//

import Foundation

extension URL {
    var queryParameters: [AnyHashable: Any] {
        guard
            let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
            let items = components.queryItems,
            !items.isEmpty
        else { return [:] }

        return items.reduce(into: [AnyHashable: Any]()) { result, item in
            result[item.name] = item.value
        }
    }
}
