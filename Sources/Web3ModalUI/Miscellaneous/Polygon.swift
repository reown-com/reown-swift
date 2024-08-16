import SwiftUI

/// Animatable Polygon
public struct Polygon: Shape {
    
    let count: Int
    
    enum CornerRadius {
        case relative(CGFloat)
        case constant(CGFloat)
        func relativeRadius(maxRadius: CGFloat) -> CGFloat {
            switch self {
            case .relative(let relativeRadius):
                return relativeRadius
            case .constant(let radius):
                return radius / maxRadius
            }
        }
        var animatablePair: AnimatablePair<CGFloat, CGFloat> {
            get {
                switch self {
                case .relative(let relativeRadius):
                    return AnimatablePair(0.0, relativeRadius)
                case .constant(let radius):
                    return AnimatablePair(1.0, radius)
                }
            }
            set {
                if newValue.first == 0.0 {
                    self = .relative(newValue.second)
                } else {
                    self = .constant(newValue.second)
                }
            }
        }
    }
    
    var cornerRadius: CornerRadius
    
    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get {
            cornerRadius.animatablePair
        }
        set {
            cornerRadius.animatablePair = newValue
        }
    }
    
    public init(count: Int, cornerRadius: CGFloat = 0.0) {
        self.count = max(count, 3)
        self.cornerRadius = .constant(max(cornerRadius, 0.0))
    }
    
    /// `relativeCornerRadius` is between `0.0` and `1.0`, where `0.0` is a pure polygon and `1.0` is a circle.
    public init(count: Int, relativeCornerRadius: CGFloat) {
        self.count = max(count, 3)
        self.cornerRadius = .relative(min(max(relativeCornerRadius, 0.0), 1.0))
    }
    
    public func path(in rect: CGRect) -> Path {
        
        var path = Path()
        
        let size: CGSize = rect.size
        
        let maxRadius = maxRadius(size: size)
        let relativeCornerRadius = cornerRadius.relativeRadius(maxRadius: maxRadius)
       
        if relativeCornerRadius == 0.0 {
        
            for i in 0..<count {
                
                if i == 0 {
                    let currentPoint: CGPoint = point(angle: angle(index: CGFloat(i)), size: size)
                    path.move(to: currentPoint)
                }
                
                let nextPoint: CGPoint = point(angle: angle(index: CGFloat(i) + 1.0), size: size)
                path.addLine(to: nextPoint)
                
            }
            
            path.closeSubpath()
            
        } else if relativeCornerRadius < 1.0 {
            
            let cornerRadius: CGFloat = relativeCornerRadius * maxRadius
            
            for i in 0..<count {
                
                let prevPoint: CGPoint = point(angle: angle(index: CGFloat(i) - 1.0), size: size)
                let currentPoint: CGPoint = point(angle: angle(index: CGFloat(i)), size: size)
                let nextPoint: CGPoint = point(angle: angle(index: CGFloat(i) + 1.0), size: size)
                
                let cornerCircle: RounedCornerCircle = rounedCornerCircle(leading: prevPoint,
                                                                          center: currentPoint,
                                                                          trailing: nextPoint,
                                                                          cornerRadius: cornerRadius)
                
                let startAngle = angle(index: CGFloat(i) - 0.5)
                let startAngleInRadians: Angle = .radians(Double(startAngle) * .pi * 2.0)
                let endAngle = angle(index: CGFloat(i) + 0.5)
                let endAngleInRadians: Angle = .radians(Double(endAngle) * .pi * 2.0)
                
                path.addArc(center: cornerCircle.center,
                            radius: cornerRadius,
                            startAngle: startAngleInRadians,
                            endAngle: endAngleInRadians,
                            clockwise: false)
                
            }
            
            path.closeSubpath()
            
        } else {
            
            let circleSize = CGSize(width: maxRadius * 2,
                                    height: maxRadius * 2)
            let circleFrame = CGRect(origin: CGPoint(x: size.width / 2 - circleSize.width / 2,
                                                     y: size.height / 2 - circleSize.height / 2),
                                     size: circleSize)
            path.addEllipse(in: circleFrame)
        }
        
        return path
    }

    func radius(size: CGSize) -> CGFloat {
        min(size.width, size.height) / 2.0
    }

    func angle(index: CGFloat) -> CGFloat {
        index / CGFloat(count) - 0.25
    }

    func point(angle: CGFloat, size: CGSize) -> CGPoint {
        let x: CGFloat = size.width / 2.0 + cos(angle * .pi * 2.0) * radius(size: size)
        let y: CGFloat = size.height / 2.0 + sin(angle * .pi * 2.0) * radius(size: size)
        return CGPoint(x: x, y: y)
    }

    func maxRadius(size: CGSize) -> CGFloat {

        let currentPoint: CGPoint = point(angle: angle(index: 0.0), size: size)
        let nextPoint: CGPoint = point(angle: angle(index: 1.0), size: size)

        let midPoint: CGPoint = CGPoint(x: (currentPoint.x + nextPoint.x) / 2,
                                        y: (currentPoint.y + nextPoint.y) / 2)

        let centerPoint: CGPoint = CGPoint(x: size.width / 2,
                                           y: size.height / 2)

        let pointDistance: CGPoint = CGPoint(x: abs(midPoint.x - centerPoint.x),
                                             y: abs(midPoint.y - centerPoint.y))
        let distance: CGFloat = hypot(pointDistance.x, pointDistance.y)

        return distance

    }
    
    struct RounedCornerCircle {
        let center: CGPoint
        let leading: CGPoint
        let trailing: CGPoint
    }

    func rounedCornerCircle(leading: CGPoint,
                            center: CGPoint,
                            trailing: CGPoint,
                            cornerRadius: CGFloat) -> RounedCornerCircle {
        rounedCornerCircle(center, leading, trailing, cornerRadius)
    }

    private func rounedCornerCircle(_ p: CGPoint,
                                    _ p1: CGPoint,
                                    _ p2: CGPoint,
                                    _ r: CGFloat) -> RounedCornerCircle {

        var r: CGFloat = r

        //Vector 1
        let dx1: CGFloat = p.x - p1.x
        let dy1: CGFloat = p.y - p1.y

        //Vector 2
        let dx2: CGFloat = p.x - p2.x
        let dy2: CGFloat = p.y - p2.y

        //Angle between vector 1 and vector 2 divided by 2
        let angle: CGFloat = (atan2(dy1, dx1) - atan2(dy2, dx2)) / 2

        // The length of segment between angular point and the
        // points of intersection with the circle of a given radius
        let _tan: CGFloat = abs(tan(angle))
        var segment: CGFloat = r / _tan

        //Check the segment
        let length1: CGFloat = sqrt(pow(dx1, 2) + pow(dy1, 2))
        let length2: CGFloat = sqrt(pow(dx2, 2) + pow(dy2, 2))

        let _length: CGFloat = min(length1, length2)

        if segment > _length {
            segment = _length;
            r = _length * _tan;
        }

        // Points of intersection are calculated by the proportion between
        // the coordinates of the vector, length of vector and the length of the segment.
        let p1Cross: CGPoint = proportion(p, segment, length1, dx1, dy1)
        let p2Cross: CGPoint = proportion(p, segment, length2, dx2, dy2)

        // Calculation of the coordinates of the circle
        // center by the addition of angular vectors.
        let dx: CGFloat = p.x * 2 - p1Cross.x - p2Cross.x
        let dy: CGFloat = p.y * 2 - p1Cross.y - p2Cross.y

        let L: CGFloat = sqrt(pow(dx, 2) + pow(dy, 2))
        let d: CGFloat = sqrt(pow(segment, 2) + pow(r, 2))

        let circlePoint: CGPoint = proportion(p, d, L, dx, dy)

        return RounedCornerCircle(center: circlePoint, leading: p1Cross, trailing: p2Cross)

    }

    private func proportion(_ point: CGPoint,
                            _ segment: CGFloat,
                            _ length: CGFloat,
                            _ dx: CGFloat,
                            _ dy: CGFloat) -> CGPoint {
        let factor: CGFloat = segment / length
        return CGPoint(x: point.x - dx * factor,
                       y: point.y - dy * factor)
    }
}

struct Polygon_Previews: PreviewProvider {
    static var previews: some View {
        Polygon(count: 6, relativeCornerRadius: 0.5)
    }
}
