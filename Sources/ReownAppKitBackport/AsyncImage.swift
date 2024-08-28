import SwiftUI

@available(iOS, deprecated: 15.0)
public extension Backport where Wrapped == Any {

    @ViewBuilder
    static func AsyncImage(url: URL?, scale: CGFloat = 1) -> some View {
        _AsyncImage(url: url, scale: scale)
    }

    @ViewBuilder
    static func AsyncImage<I: View, P: View>(url: URL?, scale: CGFloat = 1, @ViewBuilder content: @escaping (Image) -> I, @ViewBuilder placeholder: @escaping () -> P) -> some View {
        _AsyncImage(url: url, scale: scale, content: content, placeholder: placeholder)
    }

    @ViewBuilder
    static func AsyncImage<Content: View>(url: URL?, scale: CGFloat = 1, transaction: Transaction = Transaction(), @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) -> some View {
        _AsyncImage(url: url, scale: scale, transaction: transaction, content: content)
    }

    enum AsyncImagePhase {
        case empty
        case success(Image)
        case failure(Error)

        public var image: Image? {
            guard case let .success(image) = self else { return nil }
            return image
        }

        public var error: Error? {
            guard case let .failure(error) = self else { return nil }
            return error
        }
    }

    // An iOS 13+ async/await backport implementation
    private struct _AsyncImage<Content: View>: View {
        @State private var phase: AsyncImagePhase = .empty

        var url: URL?
        var scale: CGFloat = 1
        var transaction: Transaction = .init()
        var content: (Backport<Any>.AsyncImagePhase) -> Content

        public var body: some View {
            ZStack {
                content(phase)
            }
            .backport.task(id: url) {
                do {
                    guard !Task.isCancelled, let url = url else { return }
                    let (data, _) = try await URLSession.shared.data(from: url)
                    guard !Task.isCancelled else { return }

                    #if os(macOS)
                    if let image = NSImage(data: data) {
                        withTransaction(transaction) {
                            phase = .success(Image(nsImage: image))
                        }
                    }
                    #else
                    if let image = UIImage(data: data, scale: scale) {
                        withTransaction(transaction) {
                            phase = .success(Image(uiImage: image))
                        }
                    }
                    #endif
                } catch {
                    phase = .failure(error)
                }
            }
        }

        init(url: URL?, scale: CGFloat = 1) where Content == AnyView {
            self.url = url
            self.scale = scale
            self.content = { AnyView($0.image) }
        }

        init<I, P>(url: URL?, scale: CGFloat = 1, @ViewBuilder content: @escaping (Image) -> I, @ViewBuilder placeholder: @escaping () -> P) where Content == _ConditionalContent<I, P> {
            self.url = url
            self.scale = scale
            self.transaction = Transaction()
            self.content = { phase -> _ConditionalContent<I, P> in
                if let image = phase.image {
                    return ViewBuilder.buildEither(first: content(image))
                } else {
                    return ViewBuilder.buildEither(second: placeholder())
                }
            }
        }

        init(url: URL?, scale: CGFloat = 1, transaction: Transaction = Transaction(), @ViewBuilder content: @escaping (Backport<Any>.AsyncImagePhase) -> Content) {
            self.url = url
            self.scale = scale
            self.transaction = transaction
            self.content = content
        }
    }

}

import SwiftUI
import Combine

@available(iOS, deprecated: 15.0)
@available(macOS, deprecated: 12.0)
@available(tvOS, deprecated: 15.0)
@available(watchOS, deprecated: 8.0)
extension Backport where Wrapped: View {

    @ViewBuilder
    func task(priority: TaskPriority = .userInitiated, @_inheritActorContext _ action: @escaping @Sendable () async -> Void) -> some View {
        wrapped.modifier(
            TaskModifier(
                id: 0,
                priority: priority,
                action: action
            )
        )
    }

    @ViewBuilder
    func task<T: Equatable>(id: T, priority: TaskPriority = .userInitiated, @_inheritActorContext _ action: @escaping @Sendable () async -> Void) -> some View {
        wrapped.modifier(
            TaskModifier(
                id: id,
                priority: priority,
                action: action
            )
        )
    }

}

private struct TaskModifier<ID: Equatable>: ViewModifier {

    var id: ID
    var priority: TaskPriority
    var action: @Sendable () async -> Void

    @State private var task: Task<Void, Never>?
    @State private var publisher = PassthroughSubject<(), Never>()

    init(id: ID, priority: TaskPriority, action: @Sendable @escaping () async -> Void) {
        self.id = id
        self.priority = priority
        self.action = action
    }

    func body(content: Content) -> some View {
        content
            .backport.onChange(of: id) { _ in
                publisher.send()
            }
            .onReceive(publisher) { _ in
                task?.cancel()
                task = Task(priority: priority, operation: action)
            }
            .onAppear {
                task?.cancel()
                task = Task(priority: priority, operation: action)
            }
            .onDisappear {
                task?.cancel()
                task = nil
            }
    }

}
