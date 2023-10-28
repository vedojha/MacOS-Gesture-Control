import Foundation
import Vision

// Coordinate calculations
class CoordinateCalcs {
    
    lazy var kalmanFilter = KalmanFilter()
    var lastMovementTime: Date?
    
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
        zip(recentCoords, newCoords).map { $0.interpolate(with: $1, factor: HandConstants.interpolationFactor) }
    }
    
    func filteredCoordinates(point: CGPoint) -> CGPoint { // Returns 0 velocity, needs work
        let currentVelocity = calculateVelocity(currentPoint: point, lastPoint: point)
        let dynamicSpeedFactor = 1.4 + currentVelocity
        let measurementVector = SIMD2<Double>(point.x * dynamicSpeedFactor, point.y * dynamicSpeedFactor)
        
        kalmanFilter.predict()
        kalmanFilter.update(measurement: measurementVector, measurementConfidence: 0.5)
        let currentEstimate = kalmanFilter.currentEstimate
        let smoothedPoint = CGPoint(x: currentEstimate.x, y: currentEstimate.y)
        return CGPoint(
            x: min(max(smoothedPoint.x, 0), HandConstants.screenBounds.width),
            y: min(max(smoothedPoint.y, 0), HandConstants.screenBounds.height)
        )
    }
    
    func convertToScreenCoordinates(normalizedPoint: CGPoint) -> CGPoint {
        let screenHeight = HandConstants.screenBounds.height
        let screenWidth = HandConstants.screenBounds.width
        let convertedY = screenHeight - (normalizedPoint.y * screenHeight) - 200
        let convertedX = normalizedPoint.x * screenWidth - 300
        let clampedX = max(min(convertedX, screenWidth), 0)
        let clampedY = max(min(convertedY, screenHeight), 0)
        return CGPoint(x: clampedX, y: clampedY)
    }
    
    func calculateVelocity(currentPoint: CGPoint, lastPoint: CGPoint) -> CGFloat {
        let distance = currentPoint.distance(to: lastPoint)
        let currentTime = Date()

        defer { lastMovementTime = currentTime }
        guard let lastTime = lastMovementTime, currentTime.timeIntervalSince(lastTime) >= 0.05 else {
            return 0.0
        }
        return distance >= 0.01 ? distance / currentTime.timeIntervalSince(lastTime) : 0.0
    }
}

extension CGPoint {
    func interpolate(with point: CGPoint, factor: CGFloat) -> CGPoint {
        return CGPoint(x: self.x + (point.x - self.x) * factor, y: self.y + (point.y - self.y) * factor)
    }
}
