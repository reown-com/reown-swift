import SwiftUI

// MARK: - Close Icon Shape

/// X close icon shape from design SVG (viewBox 0 0 20 20)
struct CloseIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 20
        let sy = rect.height / 20
        var path = Path()

        // Upper-right to lower-left stroke
        path.move(to: CGPoint(x: 16.2882 * sx, y: 14.961 * sy))
        path.addCurve(
            to: CGPoint(x: 16.5633 * sx, y: 15.6251 * sy),
            control1: CGPoint(x: 16.4644 * sx, y: 15.1371 * sy),
            control2: CGPoint(x: 16.5633 * sx, y: 15.376 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 16.2882 * sx, y: 16.2891 * sy),
            control1: CGPoint(x: 16.5633 * sx, y: 15.8741 * sy),
            control2: CGPoint(x: 16.4644 * sx, y: 16.113 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 15.6242 * sx, y: 16.5642 * sy),
            control1: CGPoint(x: 16.1121 * sx, y: 16.4652 * sy),
            control2: CGPoint(x: 15.8733 * sx, y: 16.5642 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 14.9601 * sx, y: 16.2891 * sy),
            control1: CGPoint(x: 15.3751 * sx, y: 16.5642 * sy),
            control2: CGPoint(x: 15.1362 * sx, y: 16.4652 * sy)
        )
        path.addLine(to: CGPoint(x: 9.99997 * sx, y: 11.3274 * sy))
        path.addLine(to: CGPoint(x: 5.03825 * sx, y: 16.2876 * sy))
        path.addCurve(
            to: CGPoint(x: 4.37418 * sx, y: 16.5626 * sy),
            control1: CGPoint(x: 4.86213 * sx, y: 16.4637 * sy),
            control2: CGPoint(x: 4.62326 * sx, y: 16.5626 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 3.71012 * sx, y: 16.2876 * sy),
            control1: CGPoint(x: 4.12511 * sx, y: 16.5626 * sy),
            control2: CGPoint(x: 3.88624 * sx, y: 16.4637 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 3.43506 * sx, y: 15.6235 * sy),
            control1: CGPoint(x: 3.534 * sx, y: 16.1114 * sy),
            control2: CGPoint(x: 3.43506 * sx, y: 15.8726 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 3.71012 * sx, y: 14.9594 * sy),
            control1: CGPoint(x: 3.43506 * sx, y: 15.3744 * sy),
            control2: CGPoint(x: 3.534 * sx, y: 15.1356 * sy)
        )
        path.addLine(to: CGPoint(x: 8.67184 * sx, y: 9.99928 * sy))
        path.addLine(to: CGPoint(x: 3.71168 * sx, y: 5.03756 * sy))
        path.addCurve(
            to: CGPoint(x: 3.43662 * sx, y: 4.3735 * sy),
            control1: CGPoint(x: 3.53556 * sx, y: 4.86144 * sy),
            control2: CGPoint(x: 3.43662 * sx, y: 4.62257 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 3.71168 * sx, y: 3.70944 * sy),
            control1: CGPoint(x: 3.43662 * sx, y: 4.12443 * sy),
            control2: CGPoint(x: 3.53556 * sx, y: 3.88556 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 4.37575 * sx, y: 3.43437 * sy),
            control1: CGPoint(x: 3.8878 * sx, y: 3.53332 * sy),
            control2: CGPoint(x: 4.12668 * sx, y: 3.43437 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 5.03981 * sx, y: 3.70944 * sy),
            control1: CGPoint(x: 4.62482 * sx, y: 3.43437 * sy),
            control2: CGPoint(x: 4.86369 * sx, y: 3.53332 * sy)
        )
        path.addLine(to: CGPoint(x: 9.99997 * sx, y: 8.67116 * sy))
        path.addLine(to: CGPoint(x: 14.9617 * sx, y: 3.70866 * sy))
        path.addCurve(
            to: CGPoint(x: 15.6257 * sx, y: 3.43359 * sy),
            control1: CGPoint(x: 15.1378 * sx, y: 3.53254 * sy),
            control2: CGPoint(x: 15.3767 * sx, y: 3.43359 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 16.2898 * sx, y: 3.70866 * sy),
            control1: CGPoint(x: 15.8748 * sx, y: 3.43359 * sy),
            control2: CGPoint(x: 16.1137 * sx, y: 3.53254 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 16.5649 * sx, y: 4.37272 * sy),
            control1: CGPoint(x: 16.4659 * sx, y: 3.88478 * sy),
            control2: CGPoint(x: 16.5649 * sx, y: 4.12365 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 16.2898 * sx, y: 5.03678 * sy),
            control1: CGPoint(x: 16.5649 * sx, y: 4.62179 * sy),
            control2: CGPoint(x: 16.4659 * sx, y: 4.86066 * sy)
        )
        path.addLine(to: CGPoint(x: 11.3281 * sx, y: 9.99928 * sy))
        path.addLine(to: CGPoint(x: 16.2882 * sx, y: 14.961 * sy))
        path.closeSubpath()

        return path
    }
}

// MARK: - Modal Close Button

/// 38x38 button with 1px border, X icon 20x20
struct ModalCloseButton: View {
    let action: () -> Void
    var accessibilityId: String? = nil

    var body: some View {
        let button = Button(action: action) {
            CloseIconShape()
                .fill(AppColors.textPrimary)
                .frame(width: 20, height: 20)
                .frame(width: 38, height: 38)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing._3)
                        .stroke(AppColors.borderSecondary, lineWidth: 1)
                )
                .cornerRadius(Spacing._3)
        }
        if let accessibilityId {
            button.accessibilityIdentifier(accessibilityId)
        } else {
            button
        }
    }
}

// MARK: - Modal Container

/// Wraps content in the standard modal sheet layout with rounded corners and background
struct ModalContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing._5)
        .padding(.bottom, Spacing._5)
        .background(AppColors.backgroundPrimary)
        .cornerRadius(AppRadius._8)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Modal Header Bar

/// Standard header bar with optional back button and close button
struct ModalHeaderBar: View {
    var showBack: Bool = false
    var backAction: (() -> Void)?
    var closeAction: () -> Void
    var leadingContent: AnyView?
    var backAccessibilityId: String? = nil
    var closeAccessibilityId: String? = nil

    var body: some View {
        HStack {
            if showBack, let backAction {
                ModalBackButton(action: backAction, accessibilityId: backAccessibilityId)
            }

            if let leadingContent {
                leadingContent
            }

            Spacer()

            ModalCloseButton(action: closeAction, accessibilityId: closeAccessibilityId)
        }
        .padding(.top, Spacing._4)
    }
}

// MARK: - Copy Icon Shape

/// Copy/paste icon shape from design SVG (viewBox 0 0 20 20)
struct CopyIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 20
        let sy = rect.height / 20
        var path = Path()

        path.move(to: CGPoint(x: 16.875 * sx, y: 2.5 * sy))
        path.addLine(to: CGPoint(x: 6.875 * sx, y: 2.5 * sy))
        path.addCurve(
            to: CGPoint(x: 6.25 * sx, y: 3.125 * sy),
            control1: CGPoint(x: 6.70924 * sx, y: 2.5 * sy),
            control2: CGPoint(x: 6.25 * sx, y: 2.95924 * sy)
        )
        path.addLine(to: CGPoint(x: 6.25 * sx, y: 6.25 * sy))
        path.addLine(to: CGPoint(x: 3.125 * sx, y: 6.25 * sy))
        path.addCurve(
            to: CGPoint(x: 2.5 * sx, y: 6.875 * sy),
            control1: CGPoint(x: 2.95924 * sx, y: 6.25 * sy),
            control2: CGPoint(x: 2.5 * sx, y: 6.70924 * sy)
        )
        path.addLine(to: CGPoint(x: 2.5 * sx, y: 16.875 * sy))
        path.addCurve(
            to: CGPoint(x: 3.125 * sx, y: 17.5 * sy),
            control1: CGPoint(x: 2.5 * sx, y: 17.0408 * sy),
            control2: CGPoint(x: 2.95924 * sx, y: 17.5 * sy)
        )
        path.addLine(to: CGPoint(x: 13.125 * sx, y: 17.5 * sy))
        path.addCurve(
            to: CGPoint(x: 13.75 * sx, y: 16.875 * sy),
            control1: CGPoint(x: 13.2908 * sx, y: 17.5 * sy),
            control2: CGPoint(x: 13.75 * sx, y: 17.0408 * sy)
        )
        path.addLine(to: CGPoint(x: 13.75 * sx, y: 13.75 * sy))
        path.addLine(to: CGPoint(x: 16.875 * sx, y: 13.75 * sy))
        path.addCurve(
            to: CGPoint(x: 17.5 * sx, y: 13.125 * sy),
            control1: CGPoint(x: 17.0408 * sx, y: 13.75 * sy),
            control2: CGPoint(x: 17.5 * sx, y: 13.2908 * sy)
        )
        path.addLine(to: CGPoint(x: 17.5 * sx, y: 3.125 * sy))
        path.addCurve(
            to: CGPoint(x: 16.875 * sx, y: 2.5 * sy),
            control1: CGPoint(x: 17.5 * sx, y: 2.95924 * sy),
            control2: CGPoint(x: 17.0408 * sx, y: 2.5 * sy)
        )
        path.closeSubpath()

        // Inner cutout path
        path.move(to: CGPoint(x: 16.25 * sx, y: 12.5 * sy))
        path.addLine(to: CGPoint(x: 13.75 * sx, y: 12.5 * sy))
        path.addLine(to: CGPoint(x: 13.75 * sx, y: 6.875 * sy))
        path.addCurve(
            to: CGPoint(x: 13.125 * sx, y: 6.25 * sy),
            control1: CGPoint(x: 13.75 * sx, y: 6.70924 * sy),
            control2: CGPoint(x: 13.2908 * sx, y: 6.25 * sy)
        )
        path.addLine(to: CGPoint(x: 7.5 * sx, y: 6.25 * sy))
        path.addLine(to: CGPoint(x: 7.5 * sx, y: 3.75 * sy))
        path.addLine(to: CGPoint(x: 16.25 * sx, y: 3.75 * sy))
        path.addLine(to: CGPoint(x: 16.25 * sx, y: 12.5 * sy))
        path.closeSubpath()

        return path
    }
}

// MARK: - Modal Back Button

/// Reusable back arrow button
struct ModalBackButton: View {
    let action: () -> Void
    var accessibilityId: String? = nil

    var body: some View {
        let button = Button(action: action) {
            Image(systemName: "arrow.left")
                .appFont(.lg, weight: .medium)
                .foregroundColor(AppColors.textPrimary)
                .frame(width: 38, height: 38)
                .cornerRadius(Spacing._3)
        }
        if let accessibilityId {
            button.accessibilityIdentifier(accessibilityId)
        } else {
            button
        }
    }
}

// MARK: - Sheet Background

extension View {
    func sheetBackground() -> some View {
        modifier(_SheetBackgroundModifier())
    }
}

private struct _SheetBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content.presentationBackground(AppColors.backgroundPrimary)
        } else {
            content
        }
    }
}
