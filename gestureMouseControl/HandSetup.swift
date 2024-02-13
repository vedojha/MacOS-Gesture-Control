import CoreGraphics

struct Hand {
    struct Fingertips {
        var index: CGPoint
        var middle: CGPoint
        var ring: CGPoint
        var little: CGPoint
        var thumb: CGPoint
    }
    
    static var defaultData: Hand {
        return Hand(
            fingertips: Fingertips(
                index: .zero,
                middle: .zero,
                ring: .zero,
                little: .zero,
                thumb: .zero
            ),
            screenPoint: .zero,
            normalizationFactor: 1.0
        )
    }
    let fingertips: Fingertips
    let screenPoint: CGPoint
    var lastScreenPoint: CGPoint?
    var normalizationFactor: CGFloat
    
    init(fingertips: Fingertips, screenPoint: CGPoint, lastScreenPoint: CGPoint? = nil, normalizationFactor: CGFloat = 1.0) {
        self.fingertips = fingertips
        self.screenPoint = screenPoint
        self.lastScreenPoint = lastScreenPoint
        self.normalizationFactor = normalizationFactor
//        self.updateNormalizationFactor(with: HandBaselineDistances.shared.distances)
    }

    // Thresholds based on the normalization factor
    var pinchThreshold: CGFloat { 0.012 * normalizationFactor }
    var zoomThreshold: CGFloat { 0.17 * normalizationFactor }

    var distances: [CGFloat] {
        [
            fingertips.thumb.distance(to: fingertips.index),
            fingertips.thumb.distance(to: fingertips.middle),
            fingertips.thumb.distance(to: fingertips.ring),
            fingertips.thumb.distance(to: fingertips.little),
            fingertips.index.distance(to: fingertips.middle)
        ]
    }

    var isIndexPinchActive: Bool {
        distances[0] < pinchThreshold
    }
    var isMiddlePinchActive: Bool {
        distances[1] < pinchThreshold
    }
    var isDoublePinchActive: Bool {
        isIndexPinchActive && isMiddlePinchActive
    }
    var isZoomInActive: Bool {
        distances[0] < zoomThreshold && distances[1] < zoomThreshold && distances[2] < zoomThreshold
    }
    var isZoomOutActive: Bool {
        distances[0] > zoomThreshold && distances[1] > zoomThreshold && distances[2] > zoomThreshold
    }

    // Update the normalization factor based on baseline distances
    mutating func updateNormalizationFactor(with baselineDistances: [CGFloat]?) {
        guard let baselineDistances = baselineDistances, !baselineDistances.isEmpty else { return }
        let currentAverageDistance = distances.average
        let baselineAverageDistance = baselineDistances.average
        normalizationFactor = baselineAverageDistance / currentAverageDistance
//        printNumbers()
//        print(screenPoint)
    }
    
    func printNumbers() {
        print("Index: \(distances[0])")
        print("Middle: \(distances[1])")
        print("Norm: \(normalizationFactor)")
    }
}

extension Hand: Equatable {
    static func == (lhs: Hand, rhs: Hand) -> Bool {
        return lhs.fingertips == rhs.fingertips &&
               lhs.screenPoint == rhs.screenPoint &&
               lhs.normalizationFactor == rhs.normalizationFactor
    }
}

extension Hand.Fingertips: Equatable {
    static func == (lhs: Hand.Fingertips, rhs: Hand.Fingertips) -> Bool {
        return lhs.index == rhs.index && 
               lhs.middle == rhs.middle &&
               lhs.ring == rhs.ring &&
               lhs.little == rhs.little &&
               lhs.thumb == rhs.thumb
    }
}

class HandBaselineDistances {
    static let shared = HandBaselineDistances()
    private init() {}
    
    var distances: [CGFloat] = []
}

extension Array where Element: BinaryFloatingPoint {
    var average: Element {
        guard !isEmpty else { return 0 }
        let sum = reduce(0, +)
        return sum / Element(count)
    }
}
