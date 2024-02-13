import Foundation
import Vision
import SwiftUI

struct CoordConstants {
    static var screenBounds: CGRect = NSScreen.main?.frame ?? .zero
    static var allScreenBounds: [CGRect] {
        return NSScreen.screens.map { $0.frame }
    }
    static let interpolationFactor: CGFloat = 0.5
    static let kalmanConfidence: CGFloat = 0.5
}

class CoordinateCalcs {
    lazy var kalmanFilter = KalmanFilter()
    var lastMovementTime: Date?
    
//    init() {
//        NotificationCenter.default.addObserver(
//            self,
//            selector: #selector(updateScreenParameters),
//            name: NSApplication.didChangeScreenParametersNotification,
//            object: nil
//        )
//        print(NSScreen.screens)
//    }
    
    func getCoordinates(from hand: VNHumanHandPoseObservation, joints: [VNHumanHandPoseObservation.JointName], confidence: Float) -> [CGPoint]? {
        return joints.compactMap { try? hand.recognizedPoint($0) }
                     .filter { $0.confidence > confidence }
                     .map { $0.location }
    }
    
    func averageCoordinates(from coordinates: [CGPoint]) -> CGPoint {
        let totalPoints = CGFloat(coordinates.count)
        return coordinates.reduce(CGPoint.zero) { $0 + $1 } / totalPoints
    }
    
    func interpolateCoordinates(recentCoords: [CGPoint], newCoords: [CGPoint]) -> [CGPoint] {
        zip(recentCoords, newCoords).map { $0.interpolate(with: $1, factor: CoordConstants.interpolationFactor) }
    }
    
    func smoothedCoordinates(point: CGPoint) -> CGPoint { // Returns 0 velocity, needs work
        let currentVelocity = calculateVelocity(currentPoint: point, lastPoint: point)
        let dynamicSpeedFactor = 1.4 + currentVelocity
        let measurementVector = SIMD2<Double>(point.x * dynamicSpeedFactor, point.y * dynamicSpeedFactor)
        
        kalmanFilter.predict()
        kalmanFilter.update(measurement: measurementVector, measurementConfidence: CoordConstants.kalmanConfidence)
        
        let currentEstimate = kalmanFilter.currentEstimate
        let smoothedPoint = CGPoint(x: currentEstimate.x, y: currentEstimate.y)
        return CGPoint(
            x: min(max(smoothedPoint.x, 0), CoordConstants.screenBounds.width),
            y: min(max(smoothedPoint.y, 0), CoordConstants.screenBounds.height)
        )
    }
    
    func convertToScreenCoordinates(normalizedPoint: CGPoint) -> CGPoint {
        let screenHeight = CoordConstants.screenBounds.height
        let screenWidth = CoordConstants.screenBounds.width
        let convertedY = screenHeight * (1 - normalizedPoint.y) - 200
        let convertedX = screenWidth * normalizedPoint.x  - 340
        let clampedX = max(min(convertedX, screenWidth), 0)
        let clampedY = max(min(convertedY, screenHeight), 0)
        return CGPoint(x: clampedX, y: clampedY)
    }
    
//    func convertToScreenCoordinates(normalizedPoint: CGPoint) -> CGPoint {
//        let screen = screenForPoint(normalizedPoint: normalizedPoint)
//        let screenHeight = screen.frame.height
//        let screenWidth = screen.frame.width
//
//        let convertedX = normalizedPoint.x * screenWidth
//        let convertedY = (1 - normalizedPoint.y) * screenHeight
//
//        return CGPoint(x: convertedX, y: convertedY)
//    }

//    func screenForPoint(normalizedPoint: CGPoint) -> NSScreen {
//        let totalScreenFrame = CoordConstants.allScreenBounds.reduce(CGRect.null, { $0.union($1) })
//        let absolutePoint = CGPoint(x: normalizedPoint.x * totalScreenFrame.width,
//                                    y: (1 - normalizedPoint.y) * totalScreenFrame.height)
//
//        for screen in NSScreen.screens {
//            if screen.frame.contains(absolutePoint) {
//                return screen
//            }
//        }
//
//        return NSScreen.main!
//    }

    func calculateVelocity(currentPoint: CGPoint, lastPoint: CGPoint) -> CGFloat {
        let distance = currentPoint.distance(to: lastPoint)
        let currentTime = Date()

        defer { lastMovementTime = currentTime }
        guard let lastTime = lastMovementTime, currentTime.timeIntervalSince(lastTime) >= 0.05 else {
            return 0.0
        }
        return distance >= 0.01 ? distance / currentTime.timeIntervalSince(lastTime) : 0.0
    }

//    @objc func updateScreenParameters() {
//        CoordConstants.screenBounds = NSScreen.main?.frame ?? .zero
//    }
}

extension CGPoint {
    static func + (left: CGPoint, right: CGPoint) -> CGPoint {
        return CGPoint(x: left.x + right.x, y: left.y + right.y)
    }
    static func / (point: CGPoint, scalar: CGFloat) -> CGPoint {
        return CGPoint(x: point.x / scalar, y: point.y / scalar)
    }
    func distance(to point: CGPoint) -> CGFloat {
        return hypot(self.x - point.x, self.y - point.y)
    }
    func interpolate(with point: CGPoint, factor: CGFloat) -> CGPoint {
        return CGPoint(x: self.x + (point.x - self.x) * factor, y: self.y + (point.y - self.y) * factor)
    }
}
