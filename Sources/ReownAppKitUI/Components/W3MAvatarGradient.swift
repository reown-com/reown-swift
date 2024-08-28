import SwiftUI

public struct W3MAvatarGradient: View {
    let address: String
    
    public init(address: String) {
        self.address = address
    }
    
    public var body: some View {
        let colors = generateAvatarColors(address: address)
        
        GeometryReader { proxy in
            // Create Orb like gradient
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: .white, location: 0.0052),
                    .init(color: colors[4], location: 0.3125),
                    .init(color: colors[2], location: 0.5156),
                    .init(color: colors[1], location: 0.6563),
                    .init(color: colors[0], location: 0.8229),
                    .init(color: colors[3], location: 1.0)
                ]),
                center: UnitPoint(x: 0.6496, y: 0.2436),
                startRadius: 0,
                endRadius: proxy.frame(in: .local).height * 0.8
            )
        }
        .clipShape(Circle())
    }

    func generateAvatarColors(address: String) -> [Color] {
        let hash = address.lowercased().replacingOccurrences(of: "0x", with: "")
        let baseColor = String(hash.prefix(6))
        let rgbColor = hexToRgb(hex: baseColor)
        var colors: [Color] = []
        for i in 0 ..< 5 {
            let tintedColor = tintColor(rgb: rgbColor, tint: 0.15 * Double(i))
            colors.append(
                Color(
                    red: CGFloat(tintedColor.0)/255.0,
                    green: CGFloat(tintedColor.1)/255.0,
                    blue: CGFloat(tintedColor.2)/255.0,
                    opacity: 1.0
                )
            )
        }
        
        return colors
    }

    func hexToRgb(hex: String) -> (Int, Int, Int) {
        guard let bigint = Int64(hex, radix: 16) else { return (0, 0, 0) }
        
        let r = Int((bigint >> 16) & 255)
        let g = Int((bigint >> 8) & 255)
        let b = Int(bigint & 255)
        return (r, g, b)
    }

    func tintColor(rgb: (Int, Int, Int), tint: Double) -> (Int, Int, Int) {
        let (r, g, b) = rgb
        let tintedR = Int(round(Double(r) + (255.0 - Double(r)) * tint))
        let tintedG = Int(round(Double(g) + (255.0 - Double(g)) * tint))
        let tintedB = Int(round(Double(b) + (255.0 - Double(b)) * tint))
        return (tintedR, tintedG, tintedB)
    }
}

struct W3MAvatarGradient_Preview: PreviewProvider {
    static var previews: some View {
        VStack {
            W3MAvatarGradient(address: "0x5C8877144D858E41D8C33F5BAA7E67A5E0027E37")
                .frame(width: 128, height: 128)
            W3MAvatarGradient(address: "0x6E7E5B77B0EE215E6471713EF7EB1F69982A0603")
                .frame(width: 16, height: 16)
            W3MAvatarGradient(address: "0x7542D32A86402165DD13E09360A01DF0662401E9")
                .frame(width: 32, height: 32)
            W3MAvatarGradient(address: "0xEF56528723AA4ECC52E115DCF18628ADB773658B")
                .frame(width: 64, height: 64)
        }
    }
}
