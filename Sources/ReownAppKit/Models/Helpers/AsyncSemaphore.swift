import Foundation

// Simple implementation of semaphore using continuations. Please revise before using for anything else.
actor AsyncSemaphore {
    private var count = 0
    private var waiters = [UnsafeContinuation<Void, Never>]()
    
    public init(count: Int) {
        self.count = count
    }
    
    private func wait() async {
        count -= 1
        if count >= 0 { return }
        await withUnsafeContinuation {
            waiters.append($0)
        }
    }
    
    private func signal() {
        count += 1
        if waiters.isEmpty { return }
        waiters.removeFirst().resume()
    }
    
    public func withTurn(_ procedure: @Sendable () async throws -> Void) async rethrows {
        await wait()
        defer { signal() }
        try await procedure()
    }
}
