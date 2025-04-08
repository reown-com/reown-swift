import Foundation
@testable import WalletConnectSign

final class WalletServiceSessionRequesterMock: WalletServiceSessionRequestable {
    // Track calls to methods
    private(set) var requestWasCalled = false
    private(set) var requestCalls: [(request: Request, url: URL)] = []
    
    // Mock response or error
    var mockResponse: AnyCodable?
    var mockError: Error?
    
    func request(_ request: Request, to url: URL) async throws -> AnyCodable {
        requestWasCalled = true
        requestCalls.append((request: request, url: url))
        
        if let error = mockError {
            throw error
        }
        
        return mockResponse ?? AnyCodable(["result": "Mock response"])
    }
} 