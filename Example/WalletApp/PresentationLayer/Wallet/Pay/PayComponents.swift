import SwiftUI

// MARK: - Pay Icon Shapes

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

/// Question mark icon shape from design SVG (viewBox 0 0 20 20)
struct QuestionIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 20
        let sy = rect.height / 20
        var path = Path()

        // Question mark curve
        path.move(to: CGPoint(x: 15.3125 * sx, y: 7.5 * sy))
        path.addCurve(
            to: CGPoint(x: 10.9375 * sx, y: 12.1141 * sy),
            control1: CGPoint(x: 15.3125 * sx, y: 9.80234 * sy),
            control2: CGPoint(x: 13.4211 * sx, y: 11.7227 * sy)
        )
        path.addLine(to: CGPoint(x: 10.9375 * sx, y: 12.1875 * sy))
        path.addCurve(
            to: CGPoint(x: 10.6629 * sx, y: 12.8504 * sy),
            control1: CGPoint(x: 10.9375 * sx, y: 12.4361 * sy),
            control2: CGPoint(x: 10.8387 * sx, y: 12.6746 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 10 * sx, y: 13.125 * sy),
            control1: CGPoint(x: 10.4871 * sx, y: 13.0262 * sy),
            control2: CGPoint(x: 10.2486 * sx, y: 13.125 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 9.33709 * sx, y: 12.8504 * sy),
            control1: CGPoint(x: 9.75136 * sx, y: 13.125 * sy),
            control2: CGPoint(x: 9.5129 * sx, y: 13.0262 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 9.0625 * sx, y: 12.1875 * sy),
            control1: CGPoint(x: 9.16127 * sx, y: 12.6746 * sy),
            control2: CGPoint(x: 9.0625 * sx, y: 12.4361 * sy)
        )
        path.addLine(to: CGPoint(x: 9.0625 * sx, y: 11.25 * sy))
        path.addCurve(
            to: CGPoint(x: 9.33709 * sx, y: 10.5871 * sy),
            control1: CGPoint(x: 9.0625 * sx, y: 11.0014 * sy),
            control2: CGPoint(x: 9.16127 * sx, y: 10.7629 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 10 * sx, y: 10.3125 * sy),
            control1: CGPoint(x: 9.5129 * sx, y: 10.4113 * sy),
            control2: CGPoint(x: 9.75136 * sx, y: 10.3125 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 13.4375 * sx, y: 7.5 * sy),
            control1: CGPoint(x: 11.8953 * sx, y: 10.3125 * sy),
            control2: CGPoint(x: 13.4375 * sx, y: 9.05078 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 10 * sx, y: 4.6875 * sy),
            control1: CGPoint(x: 13.4375 * sx, y: 5.94922 * sy),
            control2: CGPoint(x: 11.8953 * sx, y: 4.6875 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 6.5625 * sx, y: 7.5 * sy),
            control1: CGPoint(x: 8.10469 * sx, y: 4.6875 * sy),
            control2: CGPoint(x: 6.5625 * sx, y: 5.94922 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 6.28791 * sx, y: 8.16291 * sy),
            control1: CGPoint(x: 6.5625 * sx, y: 7.74864 * sy),
            control2: CGPoint(x: 6.46373 * sx, y: 7.9871 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 5.625 * sx, y: 8.4375 * sy),
            control1: CGPoint(x: 6.1121 * sx, y: 8.33873 * sy),
            control2: CGPoint(x: 5.87364 * sx, y: 8.4375 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 4.96209 * sx, y: 8.16291 * sy),
            control1: CGPoint(x: 5.37636 * sx, y: 8.4375 * sy),
            control2: CGPoint(x: 5.1379 * sx, y: 8.33873 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 4.6875 * sx, y: 7.5 * sy),
            control1: CGPoint(x: 4.78627 * sx, y: 7.9871 * sy),
            control2: CGPoint(x: 4.6875 * sx, y: 7.74864 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 10 * sx, y: 2.8125 * sy),
            control1: CGPoint(x: 4.6875 * sx, y: 4.91562 * sy),
            control2: CGPoint(x: 7.07031 * sx, y: 2.8125 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 15.3125 * sx, y: 7.5 * sy),
            control1: CGPoint(x: 12.9297 * sx, y: 2.8125 * sy),
            control2: CGPoint(x: 15.3125 * sx, y: 4.91562 * sy)
        )
        path.closeSubpath()

        // Dot below question mark
        path.move(to: CGPoint(x: 10 * sx, y: 14.6875 * sy))
        path.addCurve(
            to: CGPoint(x: 9.13192 * sx, y: 14.9508 * sy),
            control1: CGPoint(x: 9.69097 * sx, y: 14.6875 * sy),
            control2: CGPoint(x: 9.38887 * sx, y: 14.7791 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 8.55644 * sx, y: 15.6521 * sy),
            control1: CGPoint(x: 8.87497 * sx, y: 15.1225 * sy),
            control2: CGPoint(x: 8.6747 * sx, y: 15.3665 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 8.46752 * sx, y: 16.5548 * sy),
            control1: CGPoint(x: 8.43818 * sx, y: 15.9376 * sy),
            control2: CGPoint(x: 8.40723 * sx, y: 16.2517 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 8.89515 * sx, y: 17.3549 * sy),
            control1: CGPoint(x: 8.52781 * sx, y: 16.8579 * sy),
            control2: CGPoint(x: 8.67663 * sx, y: 17.1363 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 9.69517 * sx, y: 17.7825 * sy),
            control1: CGPoint(x: 9.11367 * sx, y: 17.5734 * sy),
            control2: CGPoint(x: 9.39208 * sx, y: 17.7222 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 10.5979 * sx, y: 17.6936 * sy),
            control1: CGPoint(x: 9.99827 * sx, y: 17.8428 * sy),
            control2: CGPoint(x: 10.3124 * sx, y: 17.8118 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 11.2992 * sx, y: 17.1181 * sy),
            control1: CGPoint(x: 10.8835 * sx, y: 17.5753 * sy),
            control2: CGPoint(x: 11.1275 * sx, y: 17.375 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 11.5625 * sx, y: 16.25 * sy),
            control1: CGPoint(x: 11.4709 * sx, y: 16.8611 * sy),
            control2: CGPoint(x: 11.5625 * sx, y: 16.559 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 11.1049 * sx, y: 15.1451 * sy),
            control1: CGPoint(x: 11.5625 * sx, y: 15.8356 * sy),
            control2: CGPoint(x: 11.3979 * sx, y: 15.4382 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 10 * sx, y: 14.6875 * sy),
            control1: CGPoint(x: 10.8118 * sx, y: 14.8521 * sy),
            control2: CGPoint(x: 10.4144 * sx, y: 14.6875 * sy)
        )
        path.closeSubpath()

        return path
    }
}

// MARK: - Pay Close Button

/// 38x38 button with 1px border, X icon 20x20
struct PayCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
    }
}

// MARK: - Pay Question Button

/// 38x38 button with 1px border, ? icon 20x20
struct PayQuestionButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            QuestionIconShape()
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
    }
}

// MARK: - Pay Back Button

/// Reusable back arrow button used in Pay sub-screens
struct PayBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.left")
                .appFont(.lg, weight: .medium)
                .foregroundColor(AppColors.textPrimary)
                .frame(width: 38, height: 38)
                .cornerRadius(Spacing._3)
        }
    }
}

// MARK: - Pay Modal Container

/// Wraps Pay content in the standard modal sheet layout with rounded corners and background
struct PayModalContainer<Content: View>: View {
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
    }
}

// MARK: - Pay Header Bar

/// Standard header bar with optional back button and close button
struct PayHeaderBar: View {
    var showBack: Bool = false
    var backAction: (() -> Void)?
    var closeAction: () -> Void
    var leadingContent: AnyView?

    var body: some View {
        HStack {
            if showBack, let backAction {
                PayBackButton(action: backAction)
            }

            if let leadingContent {
                leadingContent
            }

            Spacer()

            PayCloseButton(action: closeAction)
        }
        .padding(.top, Spacing._4)
    }
}

// MARK: - Pay Primary Button

/// Standard primary action button used across Pay screens
struct PayPrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: Spacing._11)
            } else {
                Text(title)
                    .frame(maxWidth: .infinity)
                    .frame(height: Spacing._11)
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .opacity(isEnabled ? 1.0 : 0.5)
        .disabled(!isEnabled || isLoading)
    }
}

// MARK: - Result Icon Shapes (from Figma/RN SVG assets)

/// CheckCircle icon (viewBox 0 0 17 17) — matches RN CheckCircle.tsx, fill #30A46B
struct CheckCircleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 17
        let sy = rect.height / 17
        var path = Path()

        // Outer circle
        path.move(to: CGPoint(x: 8.125 * sx, y: 0 * sy))
        path.addCurve(to: CGPoint(x: 3.611 * sx, y: 1.36931 * sy),
                      control1: CGPoint(x: 6.51803 * sx, y: 0 * sy),
                      control2: CGPoint(x: 4.94714 * sx, y: 0.476523 * sy))
        path.addCurve(to: CGPoint(x: 0.618482 * sx, y: 5.0157 * sy),
                      control1: CGPoint(x: 2.27485 * sx, y: 2.2621 * sy),
                      control2: CGPoint(x: 1.23344 * sx, y: 3.53105 * sy))
        path.addCurve(to: CGPoint(x: 0.156123 * sx, y: 9.71011 * sy),
                      control1: CGPoint(x: 0.00352044 * sx, y: 6.50035 * sy),
                      control2: CGPoint(x: -0.157382 * sx, y: 8.13401 * sy))
        path.addCurve(to: CGPoint(x: 2.37976 * sx, y: 13.8702 * sy),
                      control1: CGPoint(x: 0.469628 * sx, y: 11.2862 * sy),
                      control2: CGPoint(x: 1.24346 * sx, y: 12.7339 * sy))
        path.addCurve(to: CGPoint(x: 6.53989 * sx, y: 16.0939 * sy),
                      control1: CGPoint(x: 3.51606 * sx, y: 15.0065 * sy),
                      control2: CGPoint(x: 4.9638 * sx, y: 15.7804 * sy))
        path.addCurve(to: CGPoint(x: 11.2343 * sx, y: 15.6315 * sy),
                      control1: CGPoint(x: 8.11599 * sx, y: 16.4074 * sy),
                      control2: CGPoint(x: 9.74966 * sx, y: 16.2465 * sy))
        path.addCurve(to: CGPoint(x: 14.8807 * sx, y: 12.639 * sy),
                      control1: CGPoint(x: 12.719 * sx, y: 15.0166 * sy),
                      control2: CGPoint(x: 13.9879 * sx, y: 13.9752 * sy))
        path.addCurve(to: CGPoint(x: 16.25 * sx, y: 8.125 * sy),
                      control1: CGPoint(x: 15.7735 * sx, y: 11.3029 * sy),
                      control2: CGPoint(x: 16.25 * sx, y: 9.73197 * sy))
        path.addCurve(to: CGPoint(x: 13.8677 * sx, y: 2.38227 * sy),
                      control1: CGPoint(x: 16.2477 * sx, y: 5.97081 * sy),
                      control2: CGPoint(x: 15.391 * sx, y: 3.90551 * sy))
        path.addCurve(to: CGPoint(x: 8.125 * sx, y: 0 * sy),
                      control1: CGPoint(x: 12.3445 * sx, y: 0.85903 * sy),
                      control2: CGPoint(x: 10.2792 * sx, y: 0.00227486 * sy))
        path.closeSubpath()

        // Checkmark
        path.move(to: CGPoint(x: 11.6922 * sx, y: 6.69219 * sy))
        path.addLine(to: CGPoint(x: 7.31719 * sx, y: 11.0672 * sy))
        path.addCurve(to: CGPoint(x: 6.875 * sx, y: 11.2505 * sy),
                      control1: CGPoint(x: 7.19022 * sx, y: 11.1714 * sy),
                      control2: CGPoint(x: 7.03847 * sx, y: 11.2343 * sy))
        path.addCurve(to: CGPoint(x: 6.43282 * sx, y: 11.0672 * sy),
                      control1: CGPoint(x: 6.71154 * sx, y: 11.2505 * sy),
                      control2: CGPoint(x: 6.55979 * sx, y: 11.2029 * sy))
        path.addLine(to: CGPoint(x: 4.55782 * sx, y: 9.19219 * sy))
        path.addCurve(to: CGPoint(x: 4.55782 * sx, y: 8.30781 * sy),
                      control1: CGPoint(x: 4.44054 * sx, y: 9.07491 * sy),
                      control2: CGPoint(x: 4.44054 * sx, y: 8.42509 * sy))
        path.addCurve(to: CGPoint(x: 5.44219 * sx, y: 8.30781 * sy),
                      control1: CGPoint(x: 4.67509 * sx, y: 8.19054 * sy),
                      control2: CGPoint(x: 5.16586 * sx, y: 8.19054 * sy))
        path.addLine(to: CGPoint(x: 6.875 * sx, y: 9.74141 * sy))
        path.addLine(to: CGPoint(x: 10.8078 * sx, y: 5.80781 * sy))
        path.addCurve(to: CGPoint(x: 11.6922 * sx, y: 5.80781 * sy),
                      control1: CGPoint(x: 10.9251 * sx, y: 5.69054 * sy),
                      control2: CGPoint(x: 11.5749 * sx, y: 5.69054 * sy))
        path.addCurve(to: CGPoint(x: 11.6922 * sx, y: 6.69219 * sy),
                      control1: CGPoint(x: 11.8095 * sx, y: 5.92509 * sy),
                      control2: CGPoint(x: 11.8095 * sx, y: 6.57491 * sy))
        path.closeSubpath()

        return path
    }
}

/// WarningCircle icon (viewBox 0 0 40 40) — matches RN WarningCircle.tsx, fill #0988F0
struct WarningCircleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 40
        let sy = rect.height / 40
        var path = Path()

        // Circle
        path.move(to: CGPoint(x: 20 * sx, y: 3.75 * sy))
        path.addCurve(to: CGPoint(x: 10.972 * sx, y: 6.48862 * sy),
                      control1: CGPoint(x: 16.7861 * sx, y: 3.75 * sy),
                      control2: CGPoint(x: 13.6443 * sx, y: 4.70305 * sy))
        path.addCurve(to: CGPoint(x: 4.98696 * sx, y: 13.7814 * sy),
                      control1: CGPoint(x: 8.29969 * sx, y: 8.27419 * sy),
                      control2: CGPoint(x: 6.21689 * sx, y: 10.8121 * sy))
        path.addCurve(to: CGPoint(x: 4.06225 * sx, y: 23.1702 * sy),
                      control1: CGPoint(x: 3.75704 * sx, y: 16.7507 * sy),
                      control2: CGPoint(x: 3.43524 * sx, y: 20.018 * sy))
        path.addCurve(to: CGPoint(x: 8.50952 * sx, y: 31.4905 * sy),
                      control1: CGPoint(x: 4.68926 * sx, y: 26.3224 * sy),
                      control2: CGPoint(x: 6.23692 * sx, y: 29.2179 * sy))
        path.addCurve(to: CGPoint(x: 16.8298 * sx, y: 35.9378 * sy),
                      control1: CGPoint(x: 10.7821 * sx, y: 33.7631 * sy),
                      control2: CGPoint(x: 13.6776 * sx, y: 35.3107 * sy))
        path.addCurve(to: CGPoint(x: 26.2186 * sx, y: 35.013 * sy),
                      control1: CGPoint(x: 19.982 * sx, y: 36.5648 * sy),
                      control2: CGPoint(x: 23.2493 * sx, y: 36.243 * sy))
        path.addCurve(to: CGPoint(x: 33.5114 * sx, y: 29.028 * sy),
                      control1: CGPoint(x: 29.1879 * sx, y: 33.7831 * sy),
                      control2: CGPoint(x: 31.7258 * sx, y: 31.7003 * sy))
        path.addCurve(to: CGPoint(x: 36.25 * sx, y: 20 * sy),
                      control1: CGPoint(x: 35.297 * sx, y: 26.3557 * sy),
                      control2: CGPoint(x: 36.25 * sx, y: 23.2139 * sy))
        path.addCurve(to: CGPoint(x: 31.4855 * sx, y: 8.51454 * sy),
                      control1: CGPoint(x: 36.2455 * sx, y: 15.6916 * sy),
                      control2: CGPoint(x: 34.5319 * sx, y: 11.561 * sy))
        path.addCurve(to: CGPoint(x: 20 * sx, y: 3.75 * sy),
                      control1: CGPoint(x: 28.439 * sx, y: 5.46806 * sy),
                      control2: CGPoint(x: 24.3084 * sx, y: 3.75455 * sy))
        path.closeSubpath()

        // Exclamation line
        path.move(to: CGPoint(x: 18.75 * sx, y: 12.5 * sy))
        path.addCurve(to: CGPoint(x: 20 * sx, y: 11.25 * sy),
                      control1: CGPoint(x: 18.75 * sx, y: 12.1685 * sy),
                      control2: CGPoint(x: 19.3505 * sx, y: 11.25 * sy))
        path.addCurve(to: CGPoint(x: 21.25 * sx, y: 12.5 * sy),
                      control1: CGPoint(x: 20.6495 * sx, y: 11.25 * sy),
                      control2: CGPoint(x: 21.25 * sx, y: 11.8505 * sy))
        path.addLine(to: CGPoint(x: 21.25 * sx, y: 21.25 * sy))
        path.addCurve(to: CGPoint(x: 20 * sx, y: 22.5 * sy),
                      control1: CGPoint(x: 21.25 * sx, y: 21.5815 * sy),
                      control2: CGPoint(x: 20.6495 * sx, y: 22.5 * sy))
        path.addCurve(to: CGPoint(x: 18.75 * sx, y: 21.25 * sy),
                      control1: CGPoint(x: 19.3505 * sx, y: 22.5 * sy),
                      control2: CGPoint(x: 18.75 * sx, y: 21.8995 * sy))
        path.closeSubpath()

        // Dot
        path.move(to: CGPoint(x: 20 * sx, y: 28.75 * sy))
        path.addCurve(to: CGPoint(x: 18.2677 * sx, y: 27.5925 * sy),
                      control1: CGPoint(x: 19.2667 * sx, y: 28.64 * sy),
                      control2: CGPoint(x: 18.65 * sx, y: 28.228 * sy))
        path.addCurve(to: CGPoint(x: 18.161 * sx, y: 26.5092 * sy),
                      control1: CGPoint(x: 18.1258 * sx, y: 27.2499 * sy),
                      control2: CGPoint(x: 18.0887 * sx, y: 26.8729 * sy))
        path.addCurve(to: CGPoint(x: 18.6742 * sx, y: 25.5492 * sy),
                      control1: CGPoint(x: 18.2334 * sx, y: 26.1455 * sy),
                      control2: CGPoint(x: 18.412 * sx, y: 25.8114 * sy))
        path.addCurve(to: CGPoint(x: 19.6342 * sx, y: 25.036 * sy),
                      control1: CGPoint(x: 18.9364 * sx, y: 25.287 * sy),
                      control2: CGPoint(x: 19.2705 * sx, y: 25.1084 * sy))
        path.addCurve(to: CGPoint(x: 20.7175 * sx, y: 25.1427 * sy),
                      control1: CGPoint(x: 19.9979 * sx, y: 24.9637 * sy),
                      control2: CGPoint(x: 20.3749 * sx, y: 25.0008 * sy))
        path.addCurve(to: CGPoint(x: 21.559 * sx, y: 25.8333 * sy),
                      control1: CGPoint(x: 21.0601 * sx, y: 25.2846 * sy),
                      control2: CGPoint(x: 21.353 * sx, y: 25.525 * sy))
        path.addCurve(to: CGPoint(x: 21.875 * sx, y: 26.875 * sy),
                      control1: CGPoint(x: 21.765 * sx, y: 26.1416 * sy),
                      control2: CGPoint(x: 21.875 * sx, y: 26.5042 * sy))
        path.addCurve(to: CGPoint(x: 21.3258 * sx, y: 28.2008 * sy),
                      control1: CGPoint(x: 21.875 * sx, y: 27.3723 * sy),
                      control2: CGPoint(x: 21.6775 * sx, y: 27.8492 * sy))
        path.addCurve(to: CGPoint(x: 20 * sx, y: 28.75 * sy),
                      control1: CGPoint(x: 20.9742 * sx, y: 28.5525 * sy),
                      control2: CGPoint(x: 20.4973 * sx, y: 28.75 * sy))
        path.closeSubpath()

        return path
    }
}

/// CoinStack icon (viewBox 0 0 40 40) — matches RN CoinStack.tsx, fill #0988F0
struct CoinStackShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 40
        let sy = rect.height / 40
        var path = Path()

        path.move(to: CGPoint(x: 28.75 * sx, y: 13.9953 * sy))
        path.addLine(to: CGPoint(x: 28.75 * sx, y: 13.125 * sy))
        path.addCurve(to: CGPoint(x: 15 * sx, y: 6.25 * sy),
                      control1: CGPoint(x: 28.75 * sx, y: 9.20625 * sy),
                      control2: CGPoint(x: 22.8391 * sx, y: 6.25 * sy))
        path.addCurve(to: CGPoint(x: 1.25 * sx, y: 13.125 * sy),
                      control1: CGPoint(x: 7.16094 * sx, y: 6.25 * sy),
                      control2: CGPoint(x: 1.25 * sx, y: 9.20625 * sy))
        path.addLine(to: CGPoint(x: 1.25 * sx, y: 19.375 * sy))
        path.addCurve(to: CGPoint(x: 11.25 * sx, y: 26.0094 * sy),
                      control1: CGPoint(x: 1.25 * sx, y: 22.6391 * sy),
                      control2: CGPoint(x: 5.35156 * sx, y: 25.2328 * sy))
        path.addLine(to: CGPoint(x: 11.25 * sx, y: 26.875 * sy))
        path.addCurve(to: CGPoint(x: 25 * sx, y: 33.75 * sy),
                      control1: CGPoint(x: 11.25 * sx, y: 30.7938 * sy),
                      control2: CGPoint(x: 17.1609 * sx, y: 33.75 * sy))
        path.addCurve(to: CGPoint(x: 38.75 * sx, y: 26.875 * sy),
                      control1: CGPoint(x: 32.8391 * sx, y: 33.75 * sy),
                      control2: CGPoint(x: 38.75 * sx, y: 30.7938 * sy))
        path.addLine(to: CGPoint(x: 38.75 * sx, y: 20.625 * sy))
        path.addCurve(to: CGPoint(x: 28.75 * sx, y: 13.9953 * sy),
                      control1: CGPoint(x: 38.75 * sx, y: 17.3906 * sy),
                      control2: CGPoint(x: 34.7781 * sx, y: 14.7937 * sy))
        path.closeSubpath()

        path.move(to: CGPoint(x: 8.75 * sx, y: 22.9484 * sy))
        path.addCurve(to: CGPoint(x: 3.75 * sx, y: 19.375 * sy),
                      control1: CGPoint(x: 5.68906 * sx, y: 22.0937 * sy),
                      control2: CGPoint(x: 3.75 * sx, y: 20.6859 * sy))
        path.addLine(to: CGPoint(x: 3.75 * sx, y: 17.1766 * sy))
        path.addCurve(to: CGPoint(x: 8.75 * sx, y: 19.2969 * sy),
                      control1: CGPoint(x: 5.025 * sx, y: 18.0797 * sy),
                      control2: CGPoint(x: 6.73281 * sx, y: 18.8078 * sy))
        path.closeSubpath()

        path.move(to: CGPoint(x: 21.25 * sx, y: 19.2969 * sy))
        path.addCurve(to: CGPoint(x: 26.25 * sx, y: 17.1766 * sy),
                      control1: CGPoint(x: 23.2672 * sx, y: 18.8078 * sy),
                      control2: CGPoint(x: 24.975 * sx, y: 18.0797 * sy))
        path.addLine(to: CGPoint(x: 26.25 * sx, y: 19.375 * sy))
        path.addCurve(to: CGPoint(x: 21.25 * sx, y: 22.9484 * sy),
                      control1: CGPoint(x: 26.25 * sx, y: 20.6859 * sy),
                      control2: CGPoint(x: 24.3109 * sx, y: 22.0937 * sy))
        path.closeSubpath()

        path.move(to: CGPoint(x: 18.75 * sx, y: 30.4484 * sy))
        path.addCurve(to: CGPoint(x: 13.75 * sx, y: 26.875 * sy),
                      control1: CGPoint(x: 15.6891 * sx, y: 29.5938 * sy),
                      control2: CGPoint(x: 13.75 * sx, y: 28.1859 * sy))
        path.addLine(to: CGPoint(x: 13.75 * sx, y: 26.2234 * sy))
        path.addCurve(to: CGPoint(x: 15 * sx, y: 26.25 * sy),
                      control1: CGPoint(x: 14.1609 * sx, y: 26.2391 * sy),
                      control2: CGPoint(x: 14.5766 * sx, y: 26.25 * sy))
        path.addCurve(to: CGPoint(x: 16.7797 * sx, y: 26.1953 * sy),
                      control1: CGPoint(x: 15.6062 * sx, y: 26.25 * sy),
                      control2: CGPoint(x: 16.1984 * sx, y: 26.2297 * sy))
        path.addCurve(to: CGPoint(x: 18.75 * sx, y: 26.7828 * sy),
                      control1: CGPoint(x: 17.4254 * sx, y: 26.4265 * sy),
                      control2: CGPoint(x: 18.0831 * sx, y: 26.6226 * sy))
        path.closeSubpath()

        path.move(to: CGPoint(x: 18.75 * sx, y: 23.4766 * sy))
        path.addCurve(to: CGPoint(x: 15 * sx, y: 23.75 * sy),
                      control1: CGPoint(x: 17.5084 * sx, y: 23.66 * sy),
                      control2: CGPoint(x: 16.255 * sx, y: 23.7514 * sy))
        path.addCurve(to: CGPoint(x: 11.25 * sx, y: 23.4766 * sy),
                      control1: CGPoint(x: 13.745 * sx, y: 23.7514 * sy),
                      control2: CGPoint(x: 12.4916 * sx, y: 23.66 * sy))
        path.addLine(to: CGPoint(x: 11.25 * sx, y: 19.7594 * sy))
        path.addCurve(to: CGPoint(x: 15 * sx, y: 20 * sy),
                      control1: CGPoint(x: 12.4934 * sx, y: 19.9214 * sy),
                      control2: CGPoint(x: 13.7461 * sx, y: 20.0018 * sy))
        path.addCurve(to: CGPoint(x: 18.75 * sx, y: 19.7594 * sy),
                      control1: CGPoint(x: 16.2539 * sx, y: 20.0018 * sy),
                      control2: CGPoint(x: 17.5066 * sx, y: 19.9214 * sy))
        path.closeSubpath()

        path.move(to: CGPoint(x: 28.75 * sx, y: 30.9766 * sy))
        path.addCurve(to: CGPoint(x: 21.25 * sx, y: 30.9766 * sy),
                      control1: CGPoint(x: 26.2633 * sx, y: 31.3411 * sy),
                      control2: CGPoint(x: 23.7367 * sx, y: 31.3411 * sy))
        path.addLine(to: CGPoint(x: 21.25 * sx, y: 27.25 * sy))
        path.addCurve(to: CGPoint(x: 25 * sx, y: 27.5 * sy),
                      control1: CGPoint(x: 22.493 * sx, y: 27.4171 * sy),
                      control2: CGPoint(x: 23.7458 * sx, y: 27.5006 * sy))
        path.addCurve(to: CGPoint(x: 28.75 * sx, y: 27.2594 * sy),
                      control1: CGPoint(x: 26.2539 * sx, y: 27.5018 * sy),
                      control2: CGPoint(x: 27.5066 * sx, y: 27.4214 * sy))
        path.closeSubpath()

        path.move(to: CGPoint(x: 36.25 * sx, y: 26.875 * sy))
        path.addCurve(to: CGPoint(x: 31.25 * sx, y: 30.4484 * sy),
                      control1: CGPoint(x: 36.25 * sx, y: 28.1859 * sy),
                      control2: CGPoint(x: 34.3109 * sx, y: 29.5938 * sy))
        path.addLine(to: CGPoint(x: 31.25 * sx, y: 26.7969 * sy))
        path.addCurve(to: CGPoint(x: 36.25 * sx, y: 24.6766 * sy),
                      control1: CGPoint(x: 33.2672 * sx, y: 26.3078 * sy),
                      control2: CGPoint(x: 34.975 * sx, y: 25.5797 * sy))
        path.closeSubpath()

        return path
    }
}
