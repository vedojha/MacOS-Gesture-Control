import simd

class KalmanFilter {
    private var stateEstimate: SIMD2<Double>
    private var errorCovariance: simd_double2x2
    
    private let stateTransitionMatrix: simd_double2x2
    private let controlInputModel: simd_double2x2
    private let measurementMatrix: simd_double2x2
    private let processNoise: simd_double2x2
    private let measurementNoise: simd_double2x2
    
    private let epsilon: Double

    init(initialEstimate: SIMD2<Double>,
         initialErrorCovariance: simd_double2x2,
         stateTransitionMatrix: simd_double2x2,
         controlInputModel: simd_double2x2? = nil,
         measurementMatrix: simd_double2x2,
         processNoise: simd_double2x2,
         measurementNoise: simd_double2x2,
         epsilon: Double = 1e-9) {
        self.stateEstimate = initialEstimate
        self.errorCovariance = initialErrorCovariance
        self.stateTransitionMatrix = stateTransitionMatrix
        self.controlInputModel = controlInputModel ?? simd_double2x2(0)
        self.measurementMatrix = measurementMatrix
        self.processNoise = processNoise
        self.measurementNoise = measurementNoise
        self.epsilon = epsilon
    }
    
    convenience init() {
        let screenSize = SIMD2<Double>(HandConstants.screenBounds.width, HandConstants.screenBounds.height)
        let initialState = SIMD2<Double>(screenSize.x / 2, screenSize.y / 2)
        let matrixDiagonalOne = simd_double2x2(diagonal: SIMD2<Double>(1.0, 1.0))
        let matrixDiagonalLowNoise = simd_double2x2(diagonal: SIMD2<Double>(0.1, 0.1))
        let matrixDiagonalHighNoise = simd_double2x2(diagonal: SIMD2<Double>(0.4, 0.4))

        self.init(initialEstimate: initialState,
                  initialErrorCovariance: matrixDiagonalOne,
                  stateTransitionMatrix: matrixDiagonalOne,
                  measurementMatrix: matrixDiagonalOne,
                  processNoise: matrixDiagonalLowNoise,
                  measurementNoise: matrixDiagonalHighNoise)
    }
    
    func predict(controlInput: SIMD2<Double>? = nil) {
        let controlEffect = controlInputModel * (controlInput ?? SIMD2<Double>(0, 0))
        stateEstimate = stateTransitionMatrix * stateEstimate + controlEffect
        errorCovariance = stateTransitionMatrix * errorCovariance * stateTransitionMatrix.transpose + processNoise
        errorCovariance = errorCovariance.symmetrize().makePositiveDefinite(epsilon: epsilon)
    }
    
    func update(measurement: SIMD2<Double>, measurementConfidence: Double) {
        let adjustedMeasurementNoise = measurementNoise * (1 / max(measurementConfidence, epsilon))
        let innovationCovariance = measurementMatrix * errorCovariance * measurementMatrix.transpose + adjustedMeasurementNoise
        guard let innovationCovarianceInverse = innovationCovariance.invertible(epsilon: epsilon) else { return }
        
        let kalmanGain = errorCovariance * measurementMatrix.transpose * innovationCovarianceInverse
        stateEstimate += kalmanGain * (measurement - measurementMatrix * stateEstimate)
        errorCovariance = (simd_double2x2(1) - kalmanGain * measurementMatrix) * errorCovariance
    }

    var currentEstimate: SIMD2<Double> {
        return stateEstimate
    }
}

private extension simd_double2x2 {
    func symmetrize() -> simd_double2x2 {
        let averageOffDiagonal = (self[1, 0] + self[0, 1]) * 0.5
        return simd_double2x2(rows: [SIMD2<Double>(self[0, 0], averageOffDiagonal),
                                     SIMD2<Double>(averageOffDiagonal, self[1, 1])])
    }

    func makePositiveDefinite(epsilon: Double) -> simd_double2x2 {
        var corrected = self
        corrected[0, 0] = max(self[0, 0], epsilon)
        corrected[1, 1] = max(self[1, 1], epsilon)
        return corrected
    }
    
    func invertible(epsilon: Double) -> simd_double2x2? {
        let det = self.determinant
        return abs(det) < epsilon ? nil : self.inverse
    }
}
