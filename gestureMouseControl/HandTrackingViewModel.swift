import SwiftUI
import Vision
import AVFoundation
import Combine

struct HandConstants {
    static let tipConfidence: Float = 0.5
    static let baseConfidence: Float = 0.5
}

class HandTrackingViewModel: NSObject, ObservableObject {
    @Published var hand: Hand = Hand.defaultData
    private var stateMachine: HandGestureStateMachine?
    private var coordinateCalcs = CoordinateCalcs()
    private var recentTipCoords: [CGPoint] = Array(repeating: .zero, count: 5)
    private var recentBasePoints: [CGPoint] = Array(repeating: .zero, count: 5)
    var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        stateMachine = HandGestureStateMachine(
            initialState: HoverState(),
            handData: self.hand,
            mouseEventHandler: MouseEventHandler.shared
        )
    }

    func process(hand observation: VNHumanHandPoseObservation) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let tipKeyPoints: [VNHumanHandPoseObservation.JointName] = [.indexTip, .middleTip, .ringTip, .littleTip, .thumbTip]
            let baseKeyPoints: [VNHumanHandPoseObservation.JointName] = [.indexPIP, .middlePIP, .ringPIP, .littlePIP, .thumbCMC]

            guard let newFingerTipCoords = self.coordinateCalcs.getCoordinates(from: observation, joints: tipKeyPoints, confidence: HandConstants.tipConfidence),
                  newFingerTipCoords.count == 5 else {
                return
            }
            self.setBaselineDistancesIfNecessary(tipCoords: newFingerTipCoords)
            
            guard let newBaseFingerCoords = self.coordinateCalcs.getCoordinates(from: observation, joints: baseKeyPoints, confidence: HandConstants.baseConfidence),
                  newBaseFingerCoords.count == 5 else {
                return
            }
            
            var handData = self.createHandData(tipCoords: newFingerTipCoords, baseCoords: newBaseFingerCoords)
            handData.updateNormalizationFactor(with: HandBaselineDistances.shared.distances)
            self.hand = handData
            self.stateMachine?.transition(handData: self.hand)
        }
    }
    
    private func createHandData(tipCoords: [CGPoint], baseCoords: [CGPoint]) -> Hand {
        let interpolatedTipCoords = self.coordinateCalcs.interpolateCoordinates(recentCoords: recentTipCoords, newCoords: tipCoords)
        recentTipCoords = interpolatedTipCoords
        let interpolatedBaseCoords = self.coordinateCalcs.interpolateCoordinates(recentCoords: recentBasePoints, newCoords: baseCoords)
        recentBasePoints = interpolatedBaseCoords
        
        let baseScreenPoint = self.coordinateCalcs.convertToScreenCoordinates(normalizedPoint: self.coordinateCalcs.averageCoordinates(from: interpolatedBaseCoords))
        let smoothedScreenPoint = self.coordinateCalcs.smoothedCoordinates(point: baseScreenPoint)
        
        return Hand(
            fingertips: Hand.Fingertips(
                index: interpolatedTipCoords[0],
                middle: interpolatedTipCoords[1],
                ring: interpolatedTipCoords[2],
                little: interpolatedTipCoords[3],
                thumb: interpolatedTipCoords[4]
            ),
            screenPoint: smoothedScreenPoint
        )
    }

    func setBaselineDistancesIfNecessary(tipCoords: [CGPoint]) {
        if HandBaselineDistances.shared.distances.isEmpty {
            let distances = [
                tipCoords[0].distance(to: tipCoords[4]),
                tipCoords[1].distance(to: tipCoords[4]),
                tipCoords[2].distance(to: tipCoords[4]),
                tipCoords[3].distance(to: tipCoords[4])
            ]
            HandBaselineDistances.shared.distances = distances
        }
    }
}
