class DefaultAnalyticsEventMapper: AnalyticsEventMapper {
    func eventName(for event: AnalyticsEvent) -> String {
        switch event {
        case .MODAL_LOADED:
            return "MODAL_LOADED"
        case .MODAL_OPEN:
            return "MODAL_OPEN"
        case .MODAL_CLOSE:
            return "MODAL_CLOSE"
        case .CLICK_ALL_WALLETS:
            return "CLICK_ALL_WALLETS"
        case .SELECT_WALLET:
            return "SELECT_WALLET"
        case .CLICK_NETWORKS:
            return "CLICK_NETWORKS"
//        case .OPEN_ACTIVITY_VIEW:
//            return "OPEN_ACTIVITY_VIEW"
        case .SWITCH_NETWORK:
            return "SWITCH_NETWORK"
        case .CONNECT_SUCCESS:
            return "CONNECT_SUCCESS"
        case .CONNECT_ERROR:
            return "CONNECT_ERROR"
        case .DISCONNECT_SUCCESS:
            return "DISCONNECT_SUCCESS"
        case .DISCONNECT_ERROR:
            return "DISCONNECT_ERROR"
        case .CLICK_WALLET_HELP:
            return "CLICK_WALLET_HELP"
        case .CLICK_NETWORK_HELP:
            return "CLICK_NETWORK_HELP"
        case .CLICK_GET_WALLET:
            return "CLICK_GET_WALLET"
        }
    }

    func parameters(for event: AnalyticsEvent) -> [String: String] {
        switch event {
        case .MODAL_LOADED:
            return [:]
        case let .MODAL_OPEN(connected):
            return ["connected": connected.description]
        case let .MODAL_CLOSE(connected):
            return ["connected": connected.description]
        case .CLICK_ALL_WALLETS:
            return [:]
        case let .SELECT_WALLET(name, platform):
            return ["wallet": name, "platform": platform.rawValue]
        case .CLICK_NETWORKS:
            return [:]
//        case .OPEN_ACTIVITY_VIEW:
//            return [:]
        case let .SWITCH_NETWORK(network):
            return ["network": network.id]
        case let .CONNECT_SUCCESS(method, name):
            return ["method": method.rawValue, "name": name]
        case let .CONNECT_ERROR(message):
            return ["message": message]
        case .DISCONNECT_SUCCESS:
            return [:]
        case .DISCONNECT_ERROR:
            return [:]
        case .CLICK_WALLET_HELP:
            return [:]
        case .CLICK_NETWORK_HELP:
            return [:]
        case .CLICK_GET_WALLET:
            return [:]
        }
    }
}
