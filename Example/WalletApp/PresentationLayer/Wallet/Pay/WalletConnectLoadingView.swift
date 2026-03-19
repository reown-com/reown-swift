import SwiftUI
import Combine

/// Port of the React Native WalletConnectLoading component.
/// 4 squares in a 2x2 grid with staggered opacity fade-in/out and corner radius morphing.
struct WalletConnectLoadingView: View {
    let size: CGFloat

    init(size: CGFloat = 80) {
        self.size = size
    }

    private let totalDuration: Double = 4.0
    private let gap: CGFloat = 2

    @State private var progress: Double = 0
    @State private var timerCancellable: AnyCancellable?

    private var squareSize: CGFloat { (size - gap) / 2 }
    private var halfSquare: CGFloat { squareSize / 2 }

    var body: some View {
        ZStack {
            // Top-left — light gray #E8E8E8
            squareView(
                color: Color(red: 232/255, green: 232/255, blue: 232/255),
                width: squareSize,
                height: squareSize,
                x: 0,
                y: 0,
                opacity: opacityTL,
                cornerRadius: cornerTL
            )

            // Top-right — dark gray #363636
            squareView(
                color: Color(red: 54/255, green: 54/255, blue: 54/255),
                width: squareSize,
                height: squareSize,
                x: squareSize + gap,
                y: 0,
                opacity: opacityTR,
                cornerRadius: cornerTR
            )

            // Bottom-left — gray #6C6C6C (half-height pill)
            squareView(
                color: Color(red: 108/255, green: 108/255, blue: 108/255),
                width: squareSize,
                height: halfSquare,
                x: 0,
                y: squareSize + gap + halfSquare,
                opacity: opacityBL,
                cornerRadius: cornerBL
            )

            // Bottom-right — accent primary
            squareView(
                color: AppColors.backgroundAccentPrimary,
                width: squareSize,
                height: squareSize,
                x: squareSize + gap,
                y: squareSize + gap,
                opacity: opacityBR,
                cornerRadius: cornerBR
            )
        }
        .frame(width: size, height: size)
        .onAppear {
            timerCancellable = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    progress += (1.0 / 60.0) / totalDuration
                    if progress >= 1.0 {
                        progress -= 1.0
                    }
                }
        }
        .onDisappear {
            timerCancellable?.cancel()
            timerCancellable = nil
        }
    }

    private func squareView(
        color: Color,
        width: CGFloat,
        height: CGFloat,
        x: CGFloat,
        y: CGFloat,
        opacity: Double,
        cornerRadius: CGFloat
    ) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(color)
            .frame(width: width, height: height)
            .opacity(opacity)
            .position(x: x + width / 2, y: y + height / 2)
    }

    // MARK: - Opacity Calculations

    // Bottom-left: appears at 30ms (0.0075), disappears at 3580ms (0.895)
    private var opacityBL: Double {
        fadeOpacity(appearAt: 0.0075, disappearAt: 0.895, fadeDuration: 0.02)
    }

    // Bottom-right: appears at 120ms (0.03), disappears at 3660ms (0.915)
    private var opacityBR: Double {
        fadeOpacity(appearAt: 0.03, disappearAt: 0.915, fadeDuration: 0.02)
    }

    // Top-right: appears at 200ms (0.05), disappears at 3740ms (0.935)
    private var opacityTR: Double {
        fadeOpacity(appearAt: 0.05, disappearAt: 0.935, fadeDuration: 0.02)
    }

    // Top-left: appears at 250ms (0.0625), disappears at 3780ms (0.945)
    private var opacityTL: Double {
        fadeOpacity(appearAt: 0.0625, disappearAt: 0.945, fadeDuration: 0.02)
    }

    private func fadeOpacity(appearAt: Double, disappearAt: Double, fadeDuration: Double) -> Double {
        let t = progress
        if t < appearAt { return 0 }
        if t < appearAt + fadeDuration { return (t - appearAt) / fadeDuration }
        if t < disappearAt { return 1 }
        if t < disappearAt + fadeDuration { return 1 - (t - disappearAt) / fadeDuration }
        return 0
    }

    // MARK: - Corner Radius Calculations

    // Bottom-left corner radius keyframes (based on half-height pill)
    private var cornerBL: CGFloat {
        let s = halfSquare // Use half-height for BL since it's a pill
        let keyframes: [(Double, CGFloat)] = [
            (0.0075, s * 0.1),   // 30ms: appear
            (0.02, s * 0.15),    // 80ms
            (0.3075, s * 0.15),  // 1230ms
            (0.5575, s * 0.25),  // 2230ms: pill shape
            (0.6825, s * 0.25),  // 2730ms
            (0.9325, s * 0.1),   // 3730ms: return
            (1.0, s * 0.1),
        ]
        return interpolateKeyframes(keyframes)
    }

    // Bottom-right corner radius keyframes
    private var cornerBR: CGFloat {
        let s = squareSize
        let keyframes: [(Double, CGFloat)] = [
            (0.03, s * 0.12),    // 120ms: appear
            (0.2425, s * 0.2),   // 970ms
            (0.3925, s * 0.2),   // 1570ms
            (0.6675, s * 0.48),  // 2670ms: nearly circle
            (0.8925, s * 0.12),  // 3570ms: return
            (1.0, s * 0.12),
        ]
        return interpolateKeyframes(keyframes)
    }

    // Top-right corner radius keyframes
    private var cornerTR: CGFloat {
        let s = squareSize
        let keyframes: [(Double, CGFloat)] = [
            (0.05, s * 0.12),    // 200ms: appear
            (0.25, s * 0.45),    // 1000ms
            (0.375, s * 0.45),   // 1500ms
            (0.6, s * 0.2),      // 2400ms
            (0.75, s * 0.2),     // 3000ms
            (0.925, s * 0.12),   // 3700ms: return
            (1.0, s * 0.12),
        ]
        return interpolateKeyframes(keyframes)
    }

    // Top-left corner radius keyframes
    private var cornerTL: CGFloat {
        let s = squareSize
        let keyframes: [(Double, CGFloat)] = [
            (0.0625, s * 0.12),  // 250ms: appear
            (0.25, s * 0.3),     // 1000ms
            (0.4, s * 0.3),      // 1600ms
            (0.65, s * 0.2),     // 2600ms
            (0.9, s * 0.2),      // 3600ms
            (1.0, s * 0.12),     // 4000ms: return
        ]
        return interpolateKeyframes(keyframes)
    }

    /// Linearly interpolate between keyframe values based on current progress
    private func interpolateKeyframes(_ keyframes: [(time: Double, value: CGFloat)]) -> CGFloat {
        let t = progress
        guard let first = keyframes.first else { return 0 }
        if t <= first.time { return first.value }
        guard let last = keyframes.last else { return first.value }
        if t >= last.time { return last.value }

        for i in 0..<(keyframes.count - 1) {
            let current = keyframes[i]
            let next = keyframes[i + 1]
            if t >= current.time && t < next.time {
                let localProgress = (t - current.time) / (next.time - current.time)
                // easeInOut curve
                let eased = easeInOut(localProgress)
                return current.value + (next.value - current.value) * CGFloat(eased)
            }
        }
        return last.value
    }

    /// Standard ease-in-out curve
    private func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }
}

#if DEBUG
struct WalletConnectLoadingView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.1)
            WalletConnectLoadingView()
        }
    }
}
#endif
