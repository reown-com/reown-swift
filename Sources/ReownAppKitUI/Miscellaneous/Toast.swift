import SwiftUI

public struct Toast: Equatable {
    let style: ToastStyle
    let message: String
    var duration: Double = 1.5
    var width: Double = .infinity
    
    public init(style: ToastStyle, message: String, duration: Double = 1.5, width: Double = .infinity) {
        self.style = style
        self.message = message
        self.duration = duration
        self.width = width
    }
}

public enum ToastStyle {
    case error
    case success
    case info
  
    var icon: Image {
        switch self {
        case .info: return Image.Original.toastInfo
        case .success: return Image.Original.toastSuccess
        case .error: return Image.Original.toastError
        }
    }
}

struct ToastView: View {
    var style: ToastStyle
    var message: String

    var onCancelTapped: () -> Void
  
    public var body: some View {
        HStack(alignment: .center, spacing: Spacing.xs) {
            style.icon
                
            Text(message.prefix(100))
                .font(.paragraph600)
                .foregroundColor(.Foreground100)
      
        }
        .onTapGesture {
            onCancelTapped()
        }
        .padding(.leading, Spacing.xs)
        .padding(.trailing, Spacing.l)
        .padding(.vertical, Spacing.xs)
        .background(Color.Background125)
        .cornerRadius(Radius.l)
        .backport
        .overlay {
            RoundedRectangle(cornerRadius: Radius.l)
                .stroke(.GrayGlass005, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 32, x: 0, y: 14)
        .shadow(color: .black.opacity(0.12), radius: 11, x: 0, y: 8)
    }
}

public struct ToastModifier: ViewModifier {
    @Binding var toast: Toast?
    @State private var workItem: DispatchWorkItem?
  
    public func body(content: Content) -> some View {
        content
            .overlay(
                ZStack {
                    mainToastView()
                        .padding(Spacing.s)
                }
                .animation(.spring(), value: toast)
            )
            .backport.onChange(of: toast) { _ in
                showToast()
            }
    }
  
    @ViewBuilder func mainToastView() -> some View {
        if let toast = toast {
            VStack {
                ToastView(
                    style: toast.style,
                    message: toast.message
                ) {
                    dismissToast()
                }
                
                Spacer()
                    .allowsHitTesting(false)
            }
        }
    }
  
    private func showToast() {
        guard let toast = toast else { return }
    
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light)
            .impactOccurred()
        #endif
        
        if toast.duration > 0 {
            workItem?.cancel()
      
            let task = DispatchWorkItem {
                dismissToast()
            }
      
            workItem = task
            DispatchQueue.main.asyncAfter(deadline: .now() + toast.duration, execute: task)
        }
    }
  
    private func dismissToast() {
        withAnimation {
            toast = nil
        }
    
        workItem?.cancel()
        workItem = nil
    }
}

public extension View {
    func toastView(toast: Binding<Toast?>) -> some View {
        modifier(ToastModifier(toast: toast))
    }
}

#if DEBUG

public struct ToastViewPreviewView: View {
    public init() {}
    
    public var body: some View {
        VStack {
            ToastView(style: .info, message: "Hello World", onCancelTapped: {})
            ToastView(style: .error, message: "Hello World", onCancelTapped: {})
            ToastView(style: .success, message: "Address copied", onCancelTapped: {})
        }
        .padding()
        .background(Color.Overgray002)
    }
}

struct ToastView_Preview: PreviewProvider {
    static var previews: some View {
        ToastViewPreviewView()
            .previewLayout(.sizeThatFits)
    }
}

#endif
