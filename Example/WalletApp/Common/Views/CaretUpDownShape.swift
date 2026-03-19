import SwiftUI

/// Custom caret up/down icon matching the design SVG.
/// Use as: `CaretUpDownShape().frame(width: 20, height: 20)`
struct CaretUpDownShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 20
        let sy = rect.height / 20

        var path = Path()

        // Down arrow
        path.move(to: CGPoint(x: 14.4133 * sx, y: 13.0865 * sy))
        path.addCurve(
            to: CGPoint(x: 14.6173 * sx, y: 13.391 * sy),
            control1: CGPoint(x: 14.5007 * sx, y: 13.1736 * sy),
            control2: CGPoint(x: 14.57 * sx, y: 13.2771 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 14.689 * sx, y: 13.7505 * sy),
            control1: CGPoint(x: 14.6647 * sx, y: 13.505 * sy),
            control2: CGPoint(x: 14.689 * sx, y: 13.6272 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 14.6173 * sx, y: 14.1101 * sy),
            control1: CGPoint(x: 14.689 * sx, y: 13.8739 * sy),
            control2: CGPoint(x: 14.6647 * sx, y: 13.9961 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 14.4133 * sx, y: 14.4146 * sy),
            control1: CGPoint(x: 14.57 * sx, y: 14.224 * sy),
            control2: CGPoint(x: 14.5007 * sx, y: 14.3275 * sy)
        )
        path.addLine(to: CGPoint(x: 10.6633 * sx, y: 18.1646 * sy))
        path.addCurve(
            to: CGPoint(x: 10.3587 * sx, y: 18.3687 * sy),
            control1: CGPoint(x: 10.5762 * sx, y: 18.252 * sy),
            control2: CGPoint(x: 10.4727 * sx, y: 18.3214 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 9.99922 * sx, y: 18.4403 * sy),
            control1: CGPoint(x: 10.2448 * sx, y: 18.416 * sy),
            control2: CGPoint(x: 10.1226 * sx, y: 18.4403 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 9.6397 * sx, y: 18.3687 * sy),
            control1: CGPoint(x: 9.87583 * sx, y: 18.4403 * sy),
            control2: CGPoint(x: 9.75365 * sx, y: 18.416 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 9.33515 * sx, y: 18.1646 * sy),
            control1: CGPoint(x: 9.52574 * sx, y: 18.3214 * sy),
            control2: CGPoint(x: 9.42225 * sx, y: 18.252 * sy)
        )
        path.addLine(to: CGPoint(x: 5.58515 * sx, y: 14.4146 * sy))
        path.addCurve(
            to: CGPoint(x: 5.31009 * sx, y: 13.7505 * sy),
            control1: CGPoint(x: 5.40903 * sx, y: 14.2385 * sy),
            control2: CGPoint(x: 5.31009 * sx, y: 13.9996 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 5.58515 * sx, y: 13.0865 * sy),
            control1: CGPoint(x: 5.31009 * sx, y: 13.5015 * sy),
            control2: CGPoint(x: 5.40903 * sx, y: 13.2626 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 6.24922 * sx, y: 12.8114 * sy),
            control1: CGPoint(x: 5.76127 * sx, y: 12.9104 * sy),
            control2: CGPoint(x: 6.00014 * sx, y: 12.8114 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 6.91328 * sx, y: 13.0865 * sy),
            control1: CGPoint(x: 6.49829 * sx, y: 12.8114 * sy),
            control2: CGPoint(x: 6.73716 * sx, y: 12.9104 * sy)
        )
        path.addLine(to: CGPoint(x: 10 * sx, y: 16.1716 * sy))
        path.addLine(to: CGPoint(x: 13.0867 * sx, y: 13.0841 * sy))
        path.addCurve(
            to: CGPoint(x: 13.3913 * sx, y: 12.8812 * sy),
            control1: CGPoint(x: 13.1739 * sx, y: 12.9971 * sy),
            control2: CGPoint(x: 13.2775 * sx, y: 12.9282 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 13.7505 * sx, y: 12.8104 * sy),
            control1: CGPoint(x: 13.5052 * sx, y: 12.8342 * sy),
            control2: CGPoint(x: 13.6273 * sx, y: 12.8101 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 14.1094 * sx, y: 12.8824 * sy),
            control1: CGPoint(x: 13.8737 * sx, y: 12.8106 * sy),
            control2: CGPoint(x: 13.9956 * sx, y: 12.8351 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 14.4133 * sx, y: 13.0865 * sy),
            control1: CGPoint(x: 14.2231 * sx, y: 12.9298 * sy),
            control2: CGPoint(x: 14.3264 * sx, y: 12.9992 * sy)
        )
        path.closeSubpath()

        // Up arrow
        path.move(to: CGPoint(x: 6.91328 * sx, y: 6.91461 * sy))
        path.addLine(to: CGPoint(x: 10 * sx, y: 3.82789 * sy))
        path.addLine(to: CGPoint(x: 13.0867 * sx, y: 6.91539 * sy))
        path.addCurve(
            to: CGPoint(x: 13.7508 * sx, y: 7.19045 * sy),
            control1: CGPoint(x: 13.2628 * sx, y: 7.09151 * sy),
            control2: CGPoint(x: 13.5017 * sx, y: 7.19045 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 14.4148 * sx, y: 6.91539 * sy),
            control1: CGPoint(x: 13.9998 * sx, y: 7.19045 * sy),
            control2: CGPoint(x: 14.2387 * sx, y: 7.09151 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 14.6899 * sx, y: 6.25132 * sy),
            control1: CGPoint(x: 14.591 * sx, y: 6.73927 * sy),
            control2: CGPoint(x: 14.6899 * sx, y: 6.5004 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 14.4148 * sx, y: 5.58726 * sy),
            control1: CGPoint(x: 14.6899 * sx, y: 6.00225 * sy),
            control2: CGPoint(x: 14.591 * sx, y: 5.76338 * sy)
        )
        path.addLine(to: CGPoint(x: 10.6648 * sx, y: 1.83726 * sy))
        path.addCurve(
            to: CGPoint(x: 10.3603 * sx, y: 1.6332 * sy),
            control1: CGPoint(x: 10.5777 * sx, y: 1.74986 * sy),
            control2: CGPoint(x: 10.4742 * sx, y: 1.68052 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 10.0008 * sx, y: 1.56152 * sy),
            control1: CGPoint(x: 10.2463 * sx, y: 1.58588 * sy),
            control2: CGPoint(x: 10.1242 * sx, y: 1.56152 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 9.64126 * sx, y: 1.6332 * sy),
            control1: CGPoint(x: 9.87739 * sx, y: 1.56152 * sy),
            control2: CGPoint(x: 9.75522 * sx, y: 1.58588 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 9.33672 * sx, y: 1.83726 * sy),
            control1: CGPoint(x: 9.52731 * sx, y: 1.68052 * sy),
            control2: CGPoint(x: 9.42381 * sx, y: 1.74986 * sy)
        )
        path.addLine(to: CGPoint(x: 5.58672 * sx, y: 5.58726 * sy))
        path.addCurve(
            to: CGPoint(x: 5.31165 * sx, y: 6.25132 * sy),
            control1: CGPoint(x: 5.4106 * sx, y: 5.76338 * sy),
            control2: CGPoint(x: 5.31165 * sx, y: 6.00225 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 5.58672 * sx, y: 6.91539 * sy),
            control1: CGPoint(x: 5.31165 * sx, y: 6.5004 * sy),
            control2: CGPoint(x: 5.4106 * sx, y: 6.73927 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 6.25078 * sx, y: 7.19045 * sy),
            control1: CGPoint(x: 5.76284 * sx, y: 7.09151 * sy),
            control2: CGPoint(x: 6.00171 * sx, y: 7.19045 * sy)
        )
        path.addCurve(
            to: CGPoint(x: 6.91484 * sx, y: 6.91539 * sy),
            control1: CGPoint(x: 6.49985 * sx, y: 7.19045 * sy),
            control2: CGPoint(x: 6.73872 * sx, y: 7.09151 * sy)
        )
        path.addLine(to: CGPoint(x: 6.91328 * sx, y: 6.91461 * sy))
        path.closeSubpath()

        return path
    }
}

/// Convenience view wrapping CaretUpDownShape with standard styling.
struct CaretUpDownIcon: View {
    var color: Color = AppColors.iconInvert

    var body: some View {
        CaretUpDownShape()
            .fill(color)
            .frame(width: 20, height: 20)
    }
}
