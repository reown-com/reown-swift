import QRCode
import SwiftUI

struct QRCodeView: View {
    let uri: String
    var imageData: Data? = nil
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        let size: CGSize = .init(
            width: UIScreen.main.bounds.width - Spacing.xl * 2,
            height: UIScreen.main.bounds.height * 0.4
        )
        
        VStack(alignment: .center) {
            render(
                content: uri,
                size: .init(width: size.width, height: size.width)
            )
            .id(colorScheme)
            .colorScheme(.light)
            .cornerRadius(Radius.l)
        }
    }
            
    @MainActor private func render(content: String, size: CGSize) -> Image {
        let doc = QRCode.Document(
            utf8String: content,
            errorCorrection: .quantize
        )
        doc.design.shape.eye = QRCode.EyeShape.Squircle2()
        doc.design.shape.onPixels = QRCode.PixelShape.Vertical(
            insetFraction: 0.15,
            cornerRadiusFraction: 1
        )
        
        doc.design.additionalQuietZonePixels = 2
        
        doc.design.style.eye = QRCode.FillStyle.Solid(UIColor.Foreground100.cgColor)
        doc.design.style.pupil = QRCode.FillStyle.Solid(UIColor.Foreground100.cgColor)
        doc.design.style.onPixels = QRCode.FillStyle.Solid(UIColor.Foreground100.cgColor)
        doc.design.style.background = QRCode.FillStyle.Solid(UIColor.Background125.cgColor)
        
        let uiImage = imageData != nil ?
            UIImage(data: imageData!) :
            UIImage(named: "imageLogo", in: .coreModule, compatibleWith: nil)?.withColor(UIColor.Blue100)
        
        if let uiImage = uiImage {
            let cgImage = uiImage.cgImage!
            
            let logoSize = 0.25
            let pathWidth = logoSize * (uiImage.size.width / uiImage.size.height)
            let pathHeight = logoSize
                        
            doc.logoTemplate = QRCode.LogoTemplate(
                image: cgImage,
                path: CGPath(
                    rect: CGRect(x: (1 - pathWidth) / 2, y: (1 - pathHeight) / 2, width: pathWidth, height: pathHeight),
                    transform: nil
                ),
                inset: 20
            )
        }
        return doc.imageUI(
            size.applying(.init(scaleX: 3, y: 3)),
            dpi: 72 * 3,
            label: Text("QR code with URI")
        )!
    }
}

private extension UIImage {
    func withColor(_ color: UIColor) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        let drawRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        color.setFill()
        UIRectFill(drawRect)
        draw(in: drawRect, blendMode: .destinationIn, alpha: 1)
        let tintedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return tintedImage!
    }
}

#if DEBUG
public struct QRCodeViewPreviewView: View {
    public init() {}
    
    static let stubUri: String = Array(repeating: ["a", "b", "c", "1", "2", "3"], count: 10)
        .flatMap { $0 }
        .joined()
    
    public var body: some View {
        VStack {
            QRCodeView(
                uri: QRCodeViewPreviewView.stubUri,
                imageData: UIImage(named: "MockWalletImage", in: .coreModule, compatibleWith: nil)?.pngData()
            )
            .previewLayout(.sizeThatFits)
            
            QRCodeView(uri: QRCodeViewPreviewView.stubUri)
        }
    }
}

struct QRCodeView_Previews: PreviewProvider {
    static var previews: some View {
        QRCodeViewPreviewView()
            .previewLayout(.sizeThatFits)
    }
}
#endif

extension QRCode.EyeShape {
    /// A 'squircle' eye style
    @objc(QRCodeEyeShapeSquircle2) class Squircle2: NSObject, QRCodeEyeShapeGenerator {
        @objc public static let Name = "squircle"
        @objc public static var Title: String { "Squircle2" }
        @objc public static func Create(_ settings: [String: Any]?) -> QRCodeEyeShapeGenerator {
            return QRCode.EyeShape.Squircle2()
        }

        @objc public func settings() -> [String: Any] { return [:] }
        @objc public func supportsSettingValue(forKey key: String) -> Bool { false }
        @objc public func setSettingValue(_ value: Any?, forKey key: String) -> Bool { false }

        /// Make a copy of the object
        @objc public func copyShape() -> QRCodeEyeShapeGenerator {
            return Self.Create(settings())
        }

        public func eyePath() -> CGPath {
            
            let strokeWidth: CGFloat = 10
            let size: CGFloat = 65
            let cornerRadius: CGFloat = min(25, size/2)
            let offset: CGFloat = (90 - size) / 2
            
            let path = CGMutablePath()
            path.addRoundedRect(in: CGRect(x: offset, y: offset, width: size, height: size), cornerWidth: cornerRadius, cornerHeight: cornerRadius)
            
            return path.copy(strokingWithWidth: strokeWidth, lineCap: .round, lineJoin: .round, miterLimit: 1)
        }

        @objc public func eyeBackgroundPath() -> CGPath {
            CGPath(rect: CGRect(origin: .zero, size: CGSize(width: 90, height: 90)), transform: nil)
        }

        private static let _defaultPupil = QRCode.PupilShape.Squircle2()
        public func defaultPupil() -> QRCodePupilShapeGenerator { Self._defaultPupil }
    }
}


extension QRCode.PupilShape {
    /// A 'squircle' pupil style
    @objc(QRCodePupilShapeSquircle2) class Squircle2: NSObject, QRCodePupilShapeGenerator {
        @objc public static var Name: String { "squircle2" }
        /// The generator title
        @objc public static var Title: String { "Squircle2" }

        @objc public static func Create(_ settings: [String : Any]?) -> QRCodePupilShapeGenerator {
            Squircle2()
        }

        /// Make a copy of the object
        @objc public func copyShape() -> QRCodePupilShapeGenerator { Squircle2() }

        @objc public func settings() -> [String : Any] { [:] }
        @objc public func supportsSettingValue(forKey key: String) -> Bool { false }
        @objc public func setSettingValue(_ value: Any?, forKey key: String) -> Bool { false }

        /// The pupil centered in the 90x90 square
        @objc public func pupilPath() -> CGPath {
     
            let size: CGFloat = 35
            let cornerRadius: CGFloat = min(12, size/2)
            let offset: CGFloat = (90 - size) / 2
            
            let path = CGMutablePath()
            path.addRoundedRect(in: CGRect(x: offset, y: offset, width: size, height: size), cornerWidth: cornerRadius, cornerHeight: cornerRadius)
            
            return path
        }
    }
}
